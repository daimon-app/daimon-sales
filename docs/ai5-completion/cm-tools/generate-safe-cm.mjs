import playwright from '../../../claude-fallback/node_modules/playwright/index.js';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const { chromium } = playwright;
const outDir = path.resolve('docs/ai5-completion/cm-generated');
await mkdir(outDir, { recursive: true });

const products = [
  { id: 'daimon', name: 'DAIMON', hook: 'ズレたら、戻ればいい。', benefit: '朝・仕事・夜・逆境の4モード', cta: '月額2,500円｜公開準備中' },
  { id: 'kirikae-switch', name: '切り替えスイッチ', hook: '休憩から、次の一手へ。', benefit: '短い休憩と再始動を支えるPWA', cta: '0円・無料公開β｜準備中' },
  { id: 'daiku-ai-cad', name: '大工AI CAD', hook: '割付と材料拾いを、現場で検証。', benefit: 'FIELD-001 実証参加者を募集中', cta: 'FIELD VALIDATION｜準備中' },
];
const durations = [6, 15, 30];
const variants = [
  { id: 'captioned', captioned: true },
  { id: 'no-caption', captioned: false },
];
const formats = [
  { id: 'master', width: 1080, height: 1920 },
  { id: 'x', width: 720, height: 1280 },
];

const selectedProducts = process.env.CM_PRODUCT ? products.filter(product => product.id === process.env.CM_PRODUCT) : products;
const specs = formats.flatMap(format => selectedProducts.flatMap(product => durations.flatMap(seconds => variants.map(variant => ({ format, product, seconds, variant })) )));
const browser = await chromium.launch({ executablePath: 'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });

async function render(spec) {
  const { format, product, seconds, variant } = spec;
  const page = await browser.newPage({ viewport: { width: format.width, height: format.height } });
  await page.setContent('<canvas id="c"></canvas>');
  const base64 = await page.evaluate(async ({ format, product, seconds, variant }) => {
    const canvas = document.querySelector('#c');
    canvas.width = format.width;
    canvas.height = format.height;
    const ctx = canvas.getContext('2d');
    const fps = 5;
    const stream = canvas.captureStream(fps);
    const mime = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'].find(t => MediaRecorder.isTypeSupported(t));
    if (!mime) throw new Error('No supported WebM MediaRecorder codec');
    const chunks = [];
    const recorder = new MediaRecorder(stream, { mimeType: mime, videoBitsPerSecond: format.id === 'master' ? 900000 : 550000 });
    recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
    const done = new Promise(resolve => recorder.onstop = resolve);
    const started = performance.now();
    const draw = () => {
      const elapsed = (performance.now() - started) / 1000;
      const phase = Math.min(1, elapsed / seconds);
      const w = canvas.width, h = canvas.height;
      const gradient = ctx.createLinearGradient(0, 0, w, h);
      gradient.addColorStop(0, '#08090d');
      gradient.addColorStop(0.55, product.id === 'kirikae-switch' ? '#10261d' : product.id === 'daiku-ai-cad' ? '#102033' : '#24120d');
      gradient.addColorStop(1, '#050506');
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, w, h);
      const pulse = 0.5 + 0.5 * Math.sin(elapsed * 2.4);
      ctx.strokeStyle = `rgba(226,177,87,${0.30 + pulse * 0.35})`;
      ctx.lineWidth = Math.max(3, w * 0.006);
      ctx.beginPath();
      ctx.arc(w / 2, h * 0.29, w * (0.13 + pulse * 0.015), 0, Math.PI * 2);
      ctx.stroke();
      ctx.textAlign = 'center';
      ctx.fillStyle = '#e9b85e';
      ctx.font = `700 ${Math.round(w * 0.055)}px sans-serif`;
      ctx.fillText(product.name, w / 2, h * 0.12);
      ctx.fillStyle = '#ffffff';
      ctx.font = `700 ${Math.round(w * 0.062)}px sans-serif`;
      const lines = product.hook.length > 15 ? [product.hook.slice(0, Math.ceil(product.hook.length / 2)), product.hook.slice(Math.ceil(product.hook.length / 2))] : [product.hook];
      lines.forEach((line, index) => ctx.fillText(line, w / 2, h * 0.52 + index * w * 0.08));
      ctx.fillStyle = '#d4d4d8';
      ctx.font = `500 ${Math.round(w * 0.034)}px sans-serif`;
      ctx.fillText(product.benefit, w / 2, h * 0.69);
      ctx.fillStyle = '#e9b85e';
      ctx.font = `700 ${Math.round(w * 0.036)}px sans-serif`;
      ctx.fillText(product.cta, w / 2, h * 0.86);
      ctx.fillStyle = 'rgba(255,255,255,.22)';
      ctx.fillRect(w * 0.1, h * 0.92, w * 0.8, Math.max(4, h * 0.004));
      ctx.fillStyle = '#e9b85e';
      ctx.fillRect(w * 0.1, h * 0.92, w * 0.8 * phase, Math.max(4, h * 0.004));
      if (variant.captioned) {
        ctx.fillStyle = 'rgba(0,0,0,.72)';
        ctx.fillRect(w * 0.08, h * 0.755, w * 0.84, h * 0.055);
        ctx.fillStyle = '#fff';
        ctx.font = `600 ${Math.round(w * (product.hook.length > 15 ? 0.023 : 0.029))}px sans-serif`;
        ctx.fillText(product.hook, w / 2, h * 0.79);
      }
      if (elapsed < seconds) requestAnimationFrame(draw);
    };
    recorder.start(1000);
    draw();
    await new Promise(resolve => setTimeout(resolve, seconds * 1000));
    recorder.stop();
    await done;
    stream.getTracks().forEach(track => track.stop());
    const blob = new Blob(chunks, { type: mime });
    const bytes = new Uint8Array(await blob.arrayBuffer());
    let binary = '';
    const block = 0x8000;
    for (let i = 0; i < bytes.length; i += block) binary += String.fromCharCode(...bytes.subarray(i, i + block));
    return btoa(binary);
  }, spec);
  const filename = `${spec.product.id}-${spec.seconds}s-${spec.variant.id}-${spec.format.id}-${spec.format.width}x${spec.format.height}.webm`;
  await writeFile(path.join(outDir, filename), Buffer.from(base64, 'base64'));
  await page.close();
  return filename;
}

for (let i = 0; i < specs.length; i += 6) {
  const batch = specs.slice(i, i + 6);
  const files = await Promise.all(batch.map(render));
  process.stdout.write(files.join('\n') + '\n');
}
await browser.close();
