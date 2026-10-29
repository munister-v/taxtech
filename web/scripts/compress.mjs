// After `vite build`: write .br and .gz next to every built script, stylesheet and SVG, so the server can send the
// compressed copy (server/backend/app.py) without compressing on each request.
import { readdirSync, readFileSync, writeFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { brotliCompressSync, gzipSync, constants } from 'node:zlib';

const dir = new URL('../../server/frontend/assets/', import.meta.url).pathname;
let before = 0, after = 0;
for (const name of readdirSync(dir)) {
  if (!/\.(js|css|svg|json)$/.test(name)) continue;
  const file = join(dir, name), buf = readFileSync(file);
  if (statSync(file).size < 1024) continue;
  const br = brotliCompressSync(buf, { params: { [constants.BROTLI_PARAM_QUALITY]: 11, [constants.BROTLI_PARAM_SIZE_HINT]: buf.length } });
  writeFileSync(file + '.br', br);
  writeFileSync(file + '.gz', gzipSync(buf, { level: 9 }));
  before += buf.length; after += br.length;
}
console.log(`compressed assets: ${(before / 1024).toFixed(0)} KB → ${(after / 1024).toFixed(0)} KB (brotli)`);
