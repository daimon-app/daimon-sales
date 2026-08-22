import playwright from '../../../claude-fallback/node_modules/playwright/index.js';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';

const { chromium } = playwright;
const dir = path.resolve('docs/ai5-completion/cm-generated');
const files = (await readdir(dir)).filter(name => name.endsWith('.webm')).sort();
const browser = await chromium.launch({ executablePath: 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe', headless: true });
const page = await browser.newPage();
const rows = [];

for (const name of files) {
  const match = name.match(/^(daimon|kirikae-switch|daiku-ai-cad)-(6|15|30)s-(captioned|no-caption)-(master|x)-(\d+)x(\d+)\.webm$/);
  const bytes = await readFile(path.join(dir, name));
  const sha256 = createHash('sha256').update(bytes).digest('hex').toUpperCase();
  const url = `data:video/webm;base64,${bytes.toString('base64')}`;
  let media;
  try { media = await page.evaluate(async url => {
    const video = document.createElement('video');
    video.muted = true;
    video.src = url;
    await new Promise((resolve, reject) => { video.onloadedmetadata = resolve; video.onerror = () => reject(new Error('decode metadata failed')); });
    const duration = video.duration;
    video.currentTime = Math.max(0, duration - 0.15);
    await new Promise((resolve, reject) => { video.onseeked = resolve; video.onerror = () => reject(new Error('seek failed')); });
    return { duration, width: video.videoWidth, height: video.videoHeight };
  }, url); } catch (error) { media = { duration: 0, width: 0, height: 0, decodeError: error.message }; }
  const expected = match ? { seconds: Number(match[2]), width: Number(match[5]), height: Number(match[6]) } : null;
  const machinePass = Boolean(expected && Math.abs(media.duration - expected.seconds) <= 0.75 && media.width === expected.width && media.height === expected.height && bytes.length > 1000);
  rows.push({ name, bytes: bytes.length, sha256, ...media, machinePass });
}
await browser.close();

const lines = [
  '# Generated safe CM hash and machine-QA ledger', '',
  `Generated/checked: ${new Date().toISOString()}`, '',
  'All outputs use only programmatic shapes and original product text. They have no audio track and use no downloaded image, music, narration, or footage. This is machine QA only; visual, language, accessibility, platform, and human listening QA remain UNVERIFIED.', '',
  `Files: ${rows.length}; machine PASS: ${rows.filter(row => row.machinePass).length}; machine FAIL: ${rows.filter(row => !row.machinePass).length}`, '',
  '| File | Bytes | Duration | Dimensions | SHA-256 | Machine QA | Human QA |',
  '|---|---:|---:|---:|---|---|---|',
  ...rows.map(row => `| \`${row.name}\` | ${row.bytes} | ${row.duration.toFixed(3)}s | ${row.width}×${row.height} | \`${row.sha256}\` | ${row.machinePass ? 'PASS' : 'FAIL'} | UNVERIFIED |`),
  '',
];
await writeFile(path.resolve('docs/ai5-completion/CM_GENERATED_HASH_QA.md'), lines.join('\n'), 'utf8');
if (rows.length !== 36 || rows.some(row => !row.machinePass)) process.exitCode = 1;
console.log(JSON.stringify({ files: rows.length, pass: rows.filter(row => row.machinePass).length, fail: rows.filter(row => !row.machinePass).length }));
