import playwright from '../../../claude-fallback/node_modules/playwright/index.js';
import { readFile, mkdir } from 'node:fs/promises';
import path from 'node:path';

const { chromium } = playwright;
const root = process.cwd();
const records = JSON.parse(await readFile(path.join(root, 'docs/ai5-completion/cm-machine-audit.json'), 'utf8'));
const sheetDir = path.join(root, 'docs/ai5-completion/cm-qa-sheets');
await mkdir(sheetDir, { recursive: true });
const groups = [
  ['daimon', 'master'], ['daimon', 'x'],
  ['kirikae-switch', 'master'], ['kirikae-switch', 'x'],
  ['daiku-ai-cad', 'master'], ['daiku-ai-cad', 'x'],
];
const browser = await chromium.launch({ executablePath: 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe', headless: true });
for (const [product, format] of groups) {
  const selected = records.filter(record => record.file.startsWith(`${product}-`) && record.file.includes(`-${format}-`));
  const figures = [];
  for (const record of selected) {
    for (let index = 0; index < record.frames.length; index++) {
      const data = await readFile(path.join(root, record.frames[index]));
      figures.push(`<figure><img src="data:image/jpeg;base64,${data.toString('base64')}"><figcaption>${record.file}<br>${['start','mid','end'][index]}</figcaption></figure>`);
    }
  }
  const page = await browser.newPage({ viewport: { width: 1600, height: 2400 } });
  await page.setContent(`<style>body{margin:0;background:#111;color:#fff;font:14px sans-serif}h1{padding:16px}.grid{display:grid;grid-template-columns:repeat(6,1fr);gap:8px;padding:8px}figure{margin:0;background:#222;padding:5px}img{width:100%;height:290px;object-fit:contain;background:#000}figcaption{font-size:10px;word-break:break-all}</style><h1>${product}-${format}</h1><div class="grid">${figures.join('')}</div>`);
  await page.screenshot({ path: path.join(sheetDir, `${product}-${format}.png`), fullPage: true });
  await page.close();
}
await browser.close();
console.log(JSON.stringify({ sheets: groups.length }));
