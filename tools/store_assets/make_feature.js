// Рекламная картинка Google Play 1024x500 (JPEG, без альфа-канала).
// usage: node make_feature.js <screenshotsDir> <iconPng> <out.jpg> <lang ru|uz|en>
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const [, , shotsDir, iconPng, out, lang] = process.argv;
const T = {
  ru: { tag: 'Играйте — ноты запишутся сами', chips: ['Запись нот на лету', 'Тренажёр по PDF', 'Без рекламы и интернета'] },
  uz: { tag: 'Çaling — notalar óziyoq yoziladi', chips: ['Notaga yoziş', 'PDF bóyiça trenajyor', 'Reklamasiz va internetsiz'] },
  en: { tag: 'Play — the notes write themselves', chips: ['Live note recording', 'PDF practice trainer', 'No ads, no internet'] },
}[lang];

const b64 = (p) => 'data:' + (p.endsWith('.png') ? 'image/png' : 'image/jpeg') + ';base64,' + fs.readFileSync(p).toString('base64');
const rec = b64(path.join(shotsDir, '01_record_simple.jpg'));
const pra = b64(path.join(shotsDir, '03_practice.jpg'));
const icon = b64(iconPng);

const html = `<!doctype html><meta charset="utf-8"><style>
  * { box-sizing: border-box; margin: 0; }
  body { width: 1024px; height: 500px; overflow: hidden; position: relative;
    font-family: 'Segoe UI', Roboto, Arial, sans-serif; color: #fff;
    background: radial-gradient(900px 500px at 85% 20%, #9b45ff 0%, rgba(155,69,255,0) 60%),
                linear-gradient(135deg, #8118ff 0%, #5a16bf 100%); }
  .icon { position: absolute; left: 52px; top: 48px; width: 104px; height: 104px; border-radius: 24px;
    box-shadow: 0 8px 24px rgba(20,0,60,.35); }
  h1 { position: absolute; left: 176px; top: 66px; font-size: 44px; font-weight: 800; letter-spacing: -.5px; line-height: 1.05; }
  .sub { position: absolute; left: 178px; top: 118px; font-size: 20px; opacity: .85; }
  .tag { position: absolute; left: 52px; top: 178px; width: 480px; font-size: 36px; font-weight: 700; line-height: 1.2; }
  .chips { position: absolute; left: 52px; top: 306px; width: 470px; display: flex; flex-direction: column; gap: 10px; }
  .chip { align-self: flex-start; background: rgba(255,255,255,.16); border: 1.5px solid rgba(255,255,255,.35);
    border-radius: 999px; padding: 7px 18px 8px; font-size: 21px; font-weight: 600; }
  .card { position: absolute; width: 400px; height: 225px; border-radius: 16px; overflow: hidden;
    box-shadow: 0 14px 36px rgba(15,0,50,.5); border: 3px solid rgba(255,255,255,.9); background: #fff; }
  .card img { width: 100%; height: 100%; display: block; object-fit: cover; }
  .c1 { left: 584px; top: 40px; }
  .c2 { left: 606px; top: 208px; }
</style>
<img class="icon" src="${icon}">
<h1>Piano Notation</h1>
<div class="sub">GeSys</div>
<div class="tag">${T.tag}</div>
<div class="chips">${T.chips.map((c) => `<div class="chip">${c}</div>`).join('')}</div>
<div class="card c1"><img src="${rec}"></div>
<div class="card c2"><img src="${pra}"></div>`;

(async () => {
  const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
  const page = await browser.newPage();
  await page.setViewport({ width: 1024, height: 500, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: 'load' });
  await new Promise((r) => setTimeout(r, 500));
  fs.mkdirSync(path.dirname(out), { recursive: true });
  await page.screenshot({ path: out, type: 'jpeg', quality: 95 });
  await browser.close();
  console.log('feature graphic', out);
})();
