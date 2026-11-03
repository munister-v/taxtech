// A scene that plays by itself: the page scrolls like an ordinary page, and the scene runs on a clock once it is
// (mostly) on screen. `p` is the progress of the clock (0..1) and `g` the share of the scene that is "engaged" (0..1,
// eased), for scenes that share a background with their neighbours and have to blend in and out of it.
//
//  - enters the screen (`enter` of it visible): starts after `delay` ms and runs for `duration` ms, then holds the last frame;
//  - leaves downward: pauses where it is, so coming back to a half-played scene finishes it;
//  - leaves upward (`leave: 'up'`: as soon as less than half is visible; `'any'`: once it is out of sight): rewinds, so the next visit plays it again.

export type AutoplayOpts = {
  duration: number;
  delay?: number;
  enter?: number;
  leave?: 'up' | 'any';
  still?: boolean;
  onFrame: (p: number, g: number) => void;
};

export type Autoplay = { seek: (p: number) => void; dispose: () => void };

const FADE_MS = 450;

export function autoplay(el: Element, opts: AutoplayOpts): Autoplay {
  const { duration, delay = 0, enter = 0.6, leave = 'up', still = false, onFrame } = opts;
  const root = el.closest('.bl');
  let p = 0, g = 0, gT = 0, playing = false, wait = delay, raf = 0, last = 0;

  const tick = (now: number) => {
    raf = 0;
    const dt = Math.min(64, now - (last || now));
    last = now;
    if (playing) {
      if (wait > 0) wait -= dt;
      else p = Math.min(1, p + dt / duration);
      if (p >= 1) playing = false;
    }
    if (g !== gT) g = gT > g ? Math.min(gT, g + dt / FADE_MS) : Math.max(gT, g - dt / FADE_MS);
    if (gT === 0 && g === 0 && !playing) p = 0;
    onFrame(p, g);
    if (playing || g !== gT) raf = requestAnimationFrame(tick); else last = 0;
  };
  const run = () => { if (!raf) raf = requestAnimationFrame(tick); };

  if (still) {
    // Reduced motion: no clock, the scene stands on its last frame.
    p = 1; g = 1;
    onFrame(p, g);
    return { seek: () => {}, dispose: () => {} };
  }

  const io = new IntersectionObserver(es => {
    const e = es[es.length - 1];
    if (!e) return;
    const r = e.intersectionRatio;
    if (r >= enter) {
      gT = 1;
      if (p < 1) { playing = true; if (p === 0) wait = delay; }
    } else if (r < 0.5) {
      playing = false;
      // the scene sits below the top edge: the visitor has scrolled back up past it (not down past it)
      const scrolledBack = e.boundingClientRect.top > (e.rootBounds?.top ?? 0);
      if (leave === 'any' ? r < 0.02 : scrolledBack) { gT = 0; if (leave === 'any') { g = 0; p = 0; } }
    }
    run();
  }, { root, threshold: [0, 0.02, 0.5, enter] });
  io.observe(el);

  return {
    seek: v => { p = Math.max(0.0005, Math.min(1, v)); gT = 1; wait = 0; playing = p < 1; run(); },
    dispose: () => { io.disconnect(); if (raf) cancelAnimationFrame(raf); },
  };
}
