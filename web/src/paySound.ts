// The payment chime on the landing: a short two-note tone made with Web Audio (no file to download).
// Browsers start audio only after a click or a key, so the context opens on the first one; the speaker button
// in the nav turns the chime on and off, and the choice is remembered.

const KEY = 'bl-sound';
let ctx: AudioContext | null = null;
let off = (() => { try { return localStorage.getItem(KEY) === 'off'; } catch { return false; } })();
const subs = new Set<() => void>();
const emit = () => subs.forEach(f => f());

export function soundOn() { return !off && ctx?.state === 'running'; }
export function onSound(f: () => void) { subs.add(f); return () => { subs.delete(f); }; }

function open() {
  if (!ctx) {
    const AC = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    ctx.onstatechange = emit;
  }
  if (ctx.state !== 'running') ctx.resume().then(emit, () => {});
  return ctx;
}

/** Opens the audio context on the first tap, click or key anywhere on the page; returns the cleanup. */
export function armSound() {
  const evs = ['pointerdown', 'touchend', 'click', 'keydown'] as const;
  const go = () => {
    if (off || !open()) return;
    if (ctx?.state === 'running') evs.forEach(e => window.removeEventListener(e, go));
  };
  evs.forEach(e => window.addEventListener(e, go, { passive: true }));
  return () => evs.forEach(e => window.removeEventListener(e, go));
}

export function toggleSound() {
  off = soundOn();
  try { localStorage.setItem(KEY, off ? 'off' : 'on'); } catch { /* private mode */ }
  if (!off && open()) chime(0.7);
  emit();
}

/** Two bright notes, like a terminal approving a tap. */
export function chime(level = 1) {
  if (off || !ctx || ctx.state !== 'running') return;
  const t0 = ctx.currentTime + 0.01;
  const out = ctx.createGain();
  out.gain.value = 0.16 * level;
  out.connect(ctx.destination);
  ([[1174.66, 0], [1567.98, 0.1]] as const).forEach(([f, at]) => {
    for (const [mul, g] of [[1, 1], [2, 0.18]] as const) {
      const o = ctx!.createOscillator(), v = ctx!.createGain();
      o.type = 'sine'; o.frequency.value = f * mul;
      v.gain.setValueAtTime(0.0001, t0 + at);
      v.gain.exponentialRampToValueAtTime(g, t0 + at + 0.008);
      v.gain.exponentialRampToValueAtTime(0.0001, t0 + at + 0.9);
      o.connect(v).connect(out);
      o.start(t0 + at); o.stop(t0 + at + 0.95);
    }
  });
}
