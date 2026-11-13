import { useEffect, useRef } from 'react';

// The hero's chrome objects (heroChromeScene.ts): loaded after the first paint, so the headline never waits for three.js.
export default function HeroChrome() {
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let api: { dispose(): void } | null = null, alive = true;
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const start = () => import('./heroChromeScene').then(m => {
      if (!alive || !box.current) return;
      api = m.createChromeScene(box.current, { still });
      box.current.classList.add('on');
    }).catch(() => {});
    const ric = (window as unknown as { requestIdleCallback?: (f: () => void, o?: { timeout: number }) => number }).requestIdleCallback;
    const id = ric ? ric(start, { timeout: 900 }) : window.setTimeout(start, 200);
    return () => { alive = false; if (!ric) clearTimeout(id); api?.dispose(); };
  }, []);
  return <div className="hc" ref={box} aria-hidden />;
}
