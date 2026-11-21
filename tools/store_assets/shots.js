// Снимает скриншоты для магазинов из живого приложения (dev-сервер на :8765).
// usage: node shots.js <outDir> <lang 0|1|2> <dsf> <scene,...|all>
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const os = require('os');
const path = require('path');

const [, , outDir, langArg = '0', dsfArg = '1', scenesArg = 'all'] = process.argv;
const W = 960, H = 540; // 960x540 css * DSF 2 = 1920x1080 (16:9)
const DSF = Number(dsfArg);
const scenes = scenesArg === 'all' ? ['record', 'grand', 'practice', 'help', 'settings'] : scenesArg.split(',');
fs.mkdirSync(outDir, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Кнопки верхней панели отсчитаны от правого края.
const bar = {
  settings: [W - 20, 28], pdf: [W - 60, 28], reset: [W - 100, 28], render: [W - 141, 28],
  record: [W - 180, 28], folder: [W - 220, 28], help: [W - 260, 28], hideKb: [W - 300, 28],
};
const whiteX = (i) => 12 + 54 * i + 27; // i — номер белой клавиши от A0
const keyY = H - 40;
const BEAT = 60000 / 90; // 90 BPM

async function launch(lang, staffMode, downloadDir, dsf = 1) {
  const browser = await puppeteer.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true,
  });
  const page = await browser.newPage();
  await page.setViewport({ width: W, height: H, deviceScaleFactor: dsf });
  await page.evaluateOnNewDocument((lang, staffMode) => {
    localStorage.setItem('flutter.settings.language', String(lang));
    localStorage.setItem('flutter.settings.staffMode', String(staffMode));
    localStorage.setItem('flutter.settings.themeMode', '1'); // светлая
  }, Number(lang), staffMode);
  if (downloadDir) {
    const cdp = await page.createCDPSession();
    await cdp.send('Page.setDownloadBehavior', { behavior: 'allow', downloadPath: downloadDir });
  }
  await page.goto('http://127.0.0.1:8766/', { waitUntil: 'load' });
  await sleep(6500);
  await page.mouse.click(W / 2, 100); // фокус на приложении
  await sleep(300);
  return { browser, page };
}

async function tap(page, [x, y], wait = 450) { await page.mouse.click(x, y); await sleep(wait); }

// Партитура с абсолютным временем: каждая нота — {beat, dur (в долях), keys:[...] | x}.
// Задержки команд Chrome не накапливаются, т.к. ждём до отметки от старта, а не «спим».
async function perform(page, notes) {
  const t0 = Date.now();
  const at = async (ms) => { const d = t0 + ms - Date.now(); if (d > 0) await sleep(d); };
  const ev = [];
  for (const n of notes) {
    ev.push({ t: n.beat * BEAT, kind: 'down', n });
    ev.push({ t: (n.beat + n.dur) * BEAT - 45, kind: 'up', n });
  }
  ev.sort((a, b) => a.t - b.t || (a.kind === 'up' ? -1 : 1));
  for (const e of ev) {
    await at(e.t);
    if (e.n.keys) {
      await Promise.all(e.n.keys.map((k) => (e.kind === 'down' ? page.keyboard.down(k) : page.keyboard.up(k))));
    } else if (e.kind === 'down') {
      await page.mouse.move(e.n.x, keyY);
      await page.mouse.down();
    } else {
      await page.mouse.up();
    }
  }
  await sleep(300);
}

// «Мерцай, мерцай, звёздочка»: До До Соль Соль | Ля Ля Соль(½) | Фа Фа Ми Ми
const twinkle = [
  ['z', 1], ['z', 1], ['b', 1], ['b', 1], ['n', 1], ['n', 1], ['b', 2],
  ['v', 1], ['v', 1], ['c', 1], ['c', 1],
].reduce((acc, [k, d]) => {
  const last = acc[acc.length - 1];
  acc.push({ beat: last ? last.beat + last.dur : 0, dur: d, keys: [k] });
  return acc;
}, []);

// Первое нажатие физической клавиши прокручивает клавиатуру к До4 и тормозит кадр —
// делаем его заранее, до записи.
async function prime(page) {
  await page.keyboard.down('z'); await sleep(120); await page.keyboard.up('z'); await sleep(1200);
}

async function recordTwinkle(page) {
  await prime(page);
  await tap(page, bar.record, 600);
  await perform(page, twinkle);
  await tap(page, bar.record, 900);
}

const C = ['z', 'c', 'b'], F = ['v', 'n', 'q'], G = ['x', 'b', 'm'];
const grandBars = [[129, C], [291, F], [345, G], [129, C], [291, F], [129, C]];
async function recordGrand(page) {
  await prime(page);
  await tap(page, bar.record, 600);
  // Бас — мышью (пока клавиатура не прокручена), аккорды правой руки — с клавиатуры.
  await perform(page, grandBars.flatMap(([x, chord], i) => [
    { beat: i * 4, dur: 2, x }, { beat: i * 4 + 2, dur: 2, keys: chord },
  ]));
  await tap(page, bar.record, 900);
}

// Ноты читаем прямо из PDF, который сохранило приложение (JSON вложен без сжатия).
function readPdfNotes(file) {
  const t = fs.readFileSync(file).toString('latin1');
  const i = t.indexOf('{"app":"piano_notation"');
  const j = t.indexOf('endstream', i);
  if (i < 0 || j < 0) return null;
  try { return JSON.parse(t.slice(i, j).trim()); } catch (e) { return null; }
}
const flat = (json) => json.measures.flat();
const expTwinkle = (json) => {
  const n = flat(json);
  return n.map((x) => x.d).join() === '4,4,4,4,4,4,8,4,4,4,4' && n.every((x) => x.p && x.p.length === 1);
};
const expGrand = (json) => {
  const n = flat(json);
  return n.length === 12 && n.every((x, i) => x.d === 8 && x.p && x.p.length === (i % 2 ? 3 : 1));
};

// Записываем, сохраняем PDF и сверяем с ожидаемым; при расхождении — всё заново.
async function recordVerified(staffMode, doRecord, expect, tries = 8) {
  for (let k = 1; k <= tries; k++) {
    const { browser, page } = await launch(langArg, staffMode);
    await doRecord(page);
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pn_dl_'));
    const cdp = await page.createCDPSession();
    await cdp.send('Page.setDownloadBehavior', { behavior: 'allow', downloadPath: dir });
    await tap(page, bar.pdf, 700);
    await tap(page, [790, 40], 600); // «Сохранить PDF»
    let file;
    for (let i = 0; i < 20 && !file; i++) { await sleep(300); file = fs.readdirSync(dir).find((f) => f.endsWith('.pdf')); }
    const json = file && readPdfNotes(path.join(dir, file));
    if (json && expect(json)) {
      console.log('запись проверена с попытки', k);
      return { browser, page, pdf: path.join(dir, file) };
    }
    console.log('попытка', k, ': запись не совпала с ожидаемой, повтор');
    await browser.close();
  }
  throw new Error('не удалось получить чистую запись за ' + tries + ' попыток');
}

async function shot(page, name, alreadyScaled = false) {
  if (DSF !== 1 && !alreadyScaled) {
    await page.setViewport({ width: W, height: H, deviceScaleFactor: DSF });
    await sleep(1800);
  }
  const file = path.join(outDir, name + '.jpg');
  await page.screenshot({ path: file, type: 'jpeg', quality: 93 });
  console.log('saved', file);
}

(async () => {
  if (scenes.includes('record')) {
    const { browser, page } = await recordVerified(0, recordTwinkle, expTwinkle);
    await shot(page, '01_record_simple');
    await browser.close();
  }

  if (scenes.includes('grand')) {
    const { browser, page } = await recordVerified(1, recordGrand, expGrand);
    await tap(page, bar.hideKb, 700); // скрыть клавиатуру — больше места под ноты
    await shot(page, '02_grand_staff');
    await browser.close();
  }

  if (scenes.includes('practice')) {
    const rec = await recordVerified(0, recordTwinkle, expTwinkle);
    await rec.browser.close();
    const { browser, page } = await launch(langArg, 0, undefined, DSF);
    const [chooser] = await Promise.all([page.waitForFileChooser({ timeout: 15000 }), page.mouse.click(...bar.folder)]);
    await chooser.accept([rec.pdf]);
    await sleep(2500);
    await page.mouse.move(W / 2, 300); // убрать подсказку кнопки
    await sleep(1200);
    await shot(page, '03_practice', true);
    await browser.close();
  }

  if (scenes.includes('help')) {
    const { browser, page } = await launch(langArg, 0);
    await tap(page, bar.help, 800);
    await shot(page, '04_help');
    await browser.close();
  }

  if (scenes.includes('settings')) {
    const { browser, page } = await recordVerified(1, recordTwinkle, expTwinkle);
    await tap(page, bar.settings, 900);
    await shot(page, '05_settings');
    await browser.close();
  }
})().catch((e) => { console.error(e); process.exit(1); });
