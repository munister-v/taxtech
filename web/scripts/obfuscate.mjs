// After `vite build`, before compression: obfuscate our own chunks (not three.js, the map data or tiny files).
// Light settings only (string table + hex names): it slows copying down, it cannot stop it, and it keeps the bundle fast.
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import JavaScriptObfuscator from 'javascript-obfuscator';

const dir = new URL('../../server/frontend/assets/', import.meta.url).pathname;
const SKIP = /^(three\.module|romeMapData|jsx-runtime|cityApi)/;
let n = 0;
for (const name of readdirSync(dir)) {
  if (!name.endsWith('.js') || SKIP.test(name)) continue;
  const file = join(dir, name), src = readFileSync(file, 'utf8');
  if (src.length < 4000) continue;
  const out = JavaScriptObfuscator.obfuscate(src, {
    compact: true, target: 'browser', sourceMap: false,
    identifierNamesGenerator: 'hexadecimal', renameGlobals: false, renameProperties: false,
    stringArray: true, stringArrayThreshold: 0.6, stringArrayEncoding: ['base64'], stringArrayWrappersCount: 1,
    controlFlowFlattening: false, deadCodeInjection: false, selfDefending: false, debugProtection: false, disableConsoleOutput: false,
    splitStrings: false, transformObjectKeys: false, numbersToExpressions: false, simplify: true,
  }).getObfuscatedCode();
  writeFileSync(file, out); n++;
}
console.log(`obfuscated ${n} chunks`);
