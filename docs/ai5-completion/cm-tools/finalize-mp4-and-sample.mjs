import playwright from '../../../claude-fallback/node_modules/playwright/index.js';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const { chromium } = playwright;
const root = process.cwd();
const ffmpeg = path.join(root, 'marketing-workspace/.tools/ffmpeg/ffmpeg-9.0.1-essentials_build/bin/ffmpeg.exe');
const ffprobe = path.join(root, 'marketing-workspace/.tools/ffmpeg/ffmpeg-9.0.1-essentials_build/bin/ffprobe.exe');
const sourceDir = path.join(root, 'docs/ai5-completion/cm-generated');
const finalDir = path.join(root, 'docs/ai5-completion/cm-final');
const frameDir = path.join(root, 'docs/ai5-completion/cm-qa-frames');
const sheetDir = path.join(root, 'docs/ai5-completion/cm-qa-sheets');
await Promise.all([mkdir(finalDir, { recursive: true }), mkdir(frameDir, { recursive: true }), mkdir(sheetDir, { recursive: true })]);

const sources = (await readdir(sourceDir)).filter(name => name.endsWith('.webm')).sort();
if (sources.length !== 36) throw new Error(`Expected 36 WebM sources, found ${sources.length}`);
const records = [];

for (const sourceName of sources) {
  const base = sourceName.replace(/\.webm$/, '');
  const source = path.join(sourceDir, sourceName);
  const output = path.join(finalDir, `${base}.mp4`);
  const expected = base.match(/-(6|15|30)s-.*-(1080x1920|720x1280)$/);
  if (process.env.CM_AUDIT_ONLY !== '1') {
    execFileSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-y', '-i', source, '-vf', 'fps=30,tpad=stop_mode=clone:stop_duration=1', '-t', expected[1], '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-profile:v', 'high', '-level', '4.1', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', output], { stdio: 'inherit' });
  }
  const probe = JSON.parse(execFileSync(ffprobe, ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', output], { encoding: 'utf8' }));
  const video = probe.streams.filter(stream => stream.codec_type === 'video');
  const audio = probe.streams.filter(stream => stream.codec_type === 'audio');
  if (video.length !== 1 || audio.length !== 0) throw new Error(`Unexpected streams: ${base}`);
  const duration = Number(probe.format.duration);
  const bytes = await readFile(output);
  const sha256 = createHash('sha256').update(bytes).digest('hex').toUpperCase();
  const [expectedWidth, expectedHeight] = expected[2].split('x').map(Number);
  const machinePass = Math.abs(duration - Number(expected[1])) <= 0.25 && video[0].codec_name === 'h264' && video[0].pix_fmt === 'yuv420p' && video[0].avg_frame_rate === '30/1' && video[0].width === expectedWidth && video[0].height === expectedHeight && audio.length === 0;
  const times = [0.5, duration / 2, Math.max(0.1, duration - 0.5)];
  const frames = [];
  for (let index = 0; index < times.length; index++) {
    const frame = path.join(frameDir, `${base}-${['start','mid','end'][index]}.jpg`);
    execFileSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-y', '-ss', times[index].toFixed(3), '-i', output, '-frames:v', '1', '-q:v', '3', frame], { stdio: 'inherit' });
    frames.push(path.relative(root, frame).replaceAll('\\', '/'));
  }
  records.push({ file: path.basename(output), bytes: bytes.length, sha256, duration, codec: video[0].codec_name, profile: video[0].profile, pixelFormat: video[0].pix_fmt, fps: video[0].avg_frame_rate, width: video[0].width, height: video[0].height, audioStreams: audio.length, machinePass, frames });
}

await writeFile(path.join(root, 'docs/ai5-completion/cm-machine-audit.json'), JSON.stringify(records, null, 2) + '\n');
const ledger = [
  '# CM MP4 final machine ledger', '',
  `Generated/checked: ${new Date().toISOString()}`, '',
  'These are publication candidates, not published assets. Machine PASS means exact slot identity, duration tolerance, H.264, yuv420p, 30 fps, expected dimensions, zero audio streams, successful start/mid/end frame decoding, and SHA-256 evidence. Independent sampled-frame review and rights/copy decisions are recorded separately.', '',
  `Files: ${records.length}; machine PASS: ${records.filter(record => record.machinePass).length}; machine FAIL: ${records.filter(record => !record.machinePass).length}`, '',
  '| File | Bytes | Duration | Video | Audio | SHA-256 | Machine QA |',
  '|---|---:|---:|---|---:|---|---|',
  ...records.map(record => `| \`${record.file}\` | ${record.bytes} | ${record.duration.toFixed(3)}s | ${record.width}×${record.height}; ${record.codec}; ${record.pixelFormat}; ${record.fps} | ${record.audioStreams} | \`${record.sha256}\` | ${record.machinePass ? 'PASS' : 'FAIL'} |`),
  '',
];
await writeFile(path.join(root, 'docs/ai5-completion/CM_MP4_FINAL_LEDGER.md'), ledger.join('\n'), 'utf8');

const groups = [...new Set(records.map(record => record.file.match(/^(daimon|kirikae-switch|daiku-ai-cad).*-(master|x)-/).slice(1).join('-')))];
const browser = await chromium.launch({ executablePath: 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe', headless: true });
for (const group of groups) {
  const [product, format] = group.replace('kirikae-switch', 'kirikae_switch').replace('daiku-ai-cad', 'daiku_ai_cad').split('-').map(value => value.replaceAll('_', '-'));
  const selected = records.filter(record => record.file.startsWith(`${product}-`) && record.file.includes(`-${format}-`));
  const cells = selected.flatMap(record => record.frames.map((frame, index) => `<figure><img src="file:///${path.join(root, frame).replaceAll('\\','/')}"><figcaption>${record.file}<br>${['start','mid','end'][index]}</figcaption></figure>`)).join('');
  const page = await browser.newPage({ viewport: { width: 1600, height: 2400 }, deviceScaleFactor: 1 });
  await page.setContent(`<style>body{margin:0;background:#111;color:#fff;font:14px sans-serif}h1{padding:16px}.grid{display:grid;grid-template-columns:repeat(6,1fr);gap:8px;padding:8px}figure{margin:0;background:#222;padding:5px}img{width:100%;height:290px;object-fit:contain;background:#000}figcaption{font-size:10px;word-break:break-all}</style><h1>${group}</h1><div class="grid">${cells}</div>`);
  await page.screenshot({ path: path.join(sheetDir, `${group}.png`), fullPage: true });
  await page.close();
}
await browser.close();
console.log(JSON.stringify({ files: records.length, pass: records.filter(record => record.machinePass).length, fail: records.filter(record => !record.machinePass).length, sheets: groups.length }));
