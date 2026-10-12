// Frame-accurate MP4 export of kindsift-ad.html (1080 x 1920, 6.0 s).
//
//   npm i -D playwright && npx playwright install chromium
//   node render.mjs [out.mp4] [fps]
//
// Requires ffmpeg on PATH. Each frame is seeked with window.KS.seek(t) and
// screenshotted, so the result never drops frames, whatever the machine speed.

import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.resolve(process.argv[2] || path.join(here, 'kindsift-ad.mp4'));
const fps = Number(process.argv[3]) || 60;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(path.join(here, 'kindsift-ad.html')).href + '?render=1');
await page.waitForFunction(() => window.KS && window.KS.ready, null, { timeout: 30000 });
const duration = await page.evaluate(() => window.KS.duration);

const ffmpeg = spawn('ffmpeg', [
  '-y', '-loglevel', 'error',
  '-f', 'image2pipe', '-framerate', String(fps), '-i', '-',
  '-c:v', 'libx264', '-preset', 'slow', '-crf', '14',
  '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
  out,
], { stdio: ['pipe', 'inherit', 'inherit'] });
const encoded = new Promise((resolve, reject) => {
  ffmpeg.on('error', reject);
  ffmpeg.on('close', (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg exited with ${code}`))));
});

const frames = Math.round(duration * fps);
for (let i = 0; i < frames; i++) {
  await page.evaluate((t) => window.KS.seek(t), i / fps);
  const png = await page.screenshot({ type: 'png' });
  if (!ffmpeg.stdin.write(png)) await new Promise((r) => ffmpeg.stdin.once('drain', r));
  if (i % fps === 0) process.stdout.write(`\r${(i / fps).toFixed(1)}s / ${duration}s`);
}
ffmpeg.stdin.end();
await encoded;
await browser.close();
console.log(`\rWrote ${out} (${frames} frames at ${fps} fps)`);
