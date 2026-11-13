// Records the landing's hero video from Roma Live (/roma?film=1): headless Chrome on virtual time, one frame per
// 1/30 s however long the software renderer takes, saved as JPEGs for ffmpeg.
// Usage: node --experimental-websocket web/scripts/film-hero.mjs <url> <out dir> <width> <height> <seconds>
import { spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [url, out, w, h, secs = '11'] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const port = 9500 + Math.floor(Math.random() * 300);
const prof = mkdtempSync(join(process.env.SCRATCH || tmpdir(), 'film-'));
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${prof}`, '--hide-scrollbars',
    ...(process.env.GL === 'soft' ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] : ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist']), `--window-size=${w},${h}`, 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let target;
for (let i = 0; i < 50 && !target; i++) { await sleep(200); try { target = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find(t => t.type === 'page'); } catch {} }
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r));
let id = 0; const pending = new Map(); const waiters = [];
ws.addEventListener('message', e => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  if (m.method === 'Emulation.virtualTimeBudgetExpired') waiters.splice(0).forEach(f => f());
});
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
try {
  await send('Emulation.setDeviceMetricsOverride', { width: Number(w), height: Number(h), deviceScaleFactor: 1, mobile: false });
  await send('Page.enable');
  await send('Page.navigate', { url });
  await sleep(14000);                                   // real time: data, scene, first payments
  const frames = Math.round(Number(secs) * 30);
  for (let f = 0; f < frames; f++) {
    const done = new Promise(r => waiters.push(r));
    await send('Emulation.setVirtualTimePolicy', { policy: 'advance', budget: 1000 / 30 });
    await done;
    const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 92 });
    writeFileSync(join(out, `${String(f).padStart(4, '0')}.jpg`), Buffer.from(shot.result.data, 'base64'));
    if (f % 30 === 0) console.log('frame', f);
  }
} finally {
  ws.close(); chrome.kill();
}
