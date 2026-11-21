// Делает квадратную иконку 512x512 без прозрачных углов из assets/icon/app_icon.png.
// Прозрачные углы заливаются цветом градиента той же строки (градиент вертикальный).
const puppeteer = require('puppeteer-core');
const http = require('http');
const fs = require('fs');
const path = require('path');

const [, , srcPng, outPng] = process.argv;

const html = `<!doctype html><canvas id=c width=1024 height=1024></canvas><script>
window.run = async () => {
  const img = new Image();
  img.src = '/icon.png';
  await img.decode();
  const c = document.getElementById('c');
  const ctx = c.getContext('2d');
  ctx.drawImage(img, 0, 0, 1024, 1024);
  const d = ctx.getImageData(0, 0, 1024, 1024);
  const px = (y) => (y * 1024 + 512) * 4;
  const top = px(10), bot = px(1013);
  for (let y = 0; y < 1024; y++) {
    const t = (y - 10) / (1013 - 10);
    const ref = [0, 1, 2].map((k) => d.data[top + k] + (d.data[bot + k] - d.data[top + k]) * t);
    for (let x = 0; x < 1024; x++) {
      const i = (y * 1024 + x) * 4;
      if (d.data[i + 3] < 255) {
        const a = d.data[i + 3] / 255;
        d.data[i] = Math.round(d.data[i] * a + ref[0] * (1 - a));
        d.data[i + 1] = Math.round(d.data[i + 1] * a + ref[1] * (1 - a));
        d.data[i + 2] = Math.round(d.data[i + 2] * a + ref[2] * (1 - a));
        d.data[i + 3] = 255;
      }
    }
  }
  ctx.putImageData(d, 0, 0);
  const o = document.createElement('canvas');
  o.width = o.height = 512;
  const octx = o.getContext('2d');
  octx.imageSmoothingQuality = 'high';
  octx.drawImage(c, 0, 0, 512, 512);
  return o.toDataURL('image/png');
};
</script>`;

const server = http.createServer((req, res) => {
  if (req.url === '/icon.png') {
    res.writeHead(200, { 'Content-Type': 'image/png' });
    fs.createReadStream(srcPng).pipe(res);
  } else {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
  }
}).listen(0, '127.0.0.1', async () => {
  const port = server.address().port;
  const browser = await puppeteer.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true,
  });
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${port}/`);
  const dataUrl = await page.evaluate(() => window.run());
  fs.writeFileSync(outPng, Buffer.from(dataUrl.split(',')[1], 'base64'));
  await browser.close();
  server.close();
  console.log('icon written', outPng);
});
