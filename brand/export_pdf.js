// Exporta el brand board a PDF y a PNG (página completa) con Chromium.
const { chromium } = require('/root/qa-tools/node_modules/playwright');
const path = require('path');

const BRAND = '/root/proyectos/celdapro/brand';
const HTML = 'file://' + path.join(BRAND, 'brand-board.html');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 794, height: 1123 },
                                       deviceScaleFactor: 1 });
  await page.goto(HTML, { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);

  await page.pdf({
    path: path.join(BRAND, 'out', 'CeldaPro-Brand-Board.pdf'),
    format: 'A4',
    printBackground: true,
    margin: { top: 0, right: 0, bottom: 0, left: 0 },
  });
  console.log('  ✓ PDF generado');

  // PNG de la lámina completa
  await page.setViewportSize({ width: 794, height: 1123 });
  await page.screenshot({
    path: path.join(BRAND, 'out', 'CeldaPro-Brand-Board.png'),
    fullPage: true,
  });
  console.log('  ✓ PNG generado');

  await browser.close();
})().catch((e) => { console.error('ERROR', e.message); process.exit(1); });
