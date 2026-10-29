import { useEffect, useRef } from 'react';
import type { ReactNode } from 'react';
import { chime } from './paySound';

type Props = { src: string; tapText: string; paidText: string; toast: ReactNode; receipt?: ReactNode };

// Where the card meets the terminal in pay-tap.webp, as a share of the image.
const PX = 0.47, PY = 0.525, RATIO = 1600 / 2400;

/**
 * Pinned scene: the camera pushes in on the terminal as you scroll; at the moment of the tap the NFC waves
 * ring out, the frame flashes and "Tap." turns into "Paid.". Scrolling back un-pays it.
 */
export default function TapScene({ src, tapText, paidText, toast, receipt }: Props) {
  const sec = useRef<HTMLElement | null>(null);
  const cam = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const s = sec.current, c = cam.current;
    const root = s?.closest('.bl') as HTMLElement | null;
    if (!s || !c || !root) return;
    const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
    let raf = 0, cnt = 0;
    // The amount on the receipt runs up from zero at the moment of the tap.
    const countUp = () => {
      const els = Array.from(s.querySelectorAll<HTMLElement>('.bl-count'));
      cancelAnimationFrame(cnt);
      const t0 = performance.now();
      const step = (now: number) => {
        const k = clamp((now - t0 - 700) / 900), e = 1 - Math.pow(1 - k, 3);
        for (const el of els) el.textContent = Math.round(Number(el.dataset.v) * e).toLocaleString('uk-UA').replace(/\u00a0/g, ' ');
        if (k < 1) cnt = requestAnimationFrame(step);
      };
      cnt = requestAnimationFrame(step);
    };
    const fit = () => {
      const W = s.clientWidth, H = root.clientHeight;
      const cx = W > 860 ? W * 0.6 : W * 0.5, cy = W > 860 ? H * 0.5 : H * 0.4;
      // Smallest image that still covers the stage with the contact point sitting at (cx, cy).
      const w = Math.max(W * 1.3, H * RATIO * 1.05, (cx / PX) * 1.03, ((W - cx) / (1 - PX)) * 1.03);
      const h = w / RATIO;
      c.style.width = `${w}px`; c.style.height = `${h}px`;
      c.style.left = `${cx - PX * w}px`; c.style.top = `${cy - PY * h}px`;
    };
    const frame = () => {
      raf = 0;
      const p = clamp(-(s.getBoundingClientRect().top - root.getBoundingClientRect().top) / Math.max(1, s.offsetHeight - root.clientHeight));
      const k = Math.min(1, p / 0.5);
      s.style.setProperty('--pz', (1 + 0.95 * k * k * (3 - 2 * k) + 0.25 * Math.max(0, p - 0.5) * 2).toFixed(3));
      s.style.setProperty('--pd', (0.12 + 0.5 * p).toFixed(3));
      s.style.setProperty('--pc', clamp(p / 0.5).toFixed(3));
      const hit = p >= 0.5;
      if (hit && !s.classList.contains('hit')) { chime(); countUp(); try { navigator.vibrate?.(35); } catch { /* not supported */ } }
      s.classList.toggle('hit', hit);
    };
    const onScroll = () => { if (!raf) raf = requestAnimationFrame(frame); };
    const onResize = () => { fit(); onScroll(); };
    fit(); frame();
    root.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onResize);
    return () => { cancelAnimationFrame(cnt); root.removeEventListener('scroll', onScroll); window.removeEventListener('resize', onResize); if (raf) cancelAnimationFrame(raf); };
  }, []);

  return (
    <section id="tap" ref={sec} className="bl-tap">
      <div className="bl-tap-stage">
        <div ref={cam} className="bl-tap-cam" aria-hidden>
          <img src={src} alt="" draggable={false} />
          <svg className="bl-tap-charge" viewBox="0 0 100 100"><circle className="t" cx="50" cy="50" r="46" /><circle className="f" cx="50" cy="50" r="46" pathLength="1" /></svg>
          <span className="bl-tap-spot" />
          {[0, 1, 2, 3].map(i => <span key={i} className="bl-ripple" style={{ ['--i' as string]: i }} />)}
        </div>
        <div className="bl-tap-shade" aria-hidden />
        <div className="bl-tap-flash" aria-hidden />
        <div className="bl-wrap bl-tap-in">
          <h2 className="bl-tap-a">{tapText}</h2>
          <div className="bl-tap-b">
            <svg className="bl-tap-ring" viewBox="0 0 120 120" aria-hidden><circle cx="60" cy="60" r="54" /><path d="M36 62l17 17 32-36" /></svg>
            <h2>{paidText}</h2>
            {toast}
          </div>
          {receipt && <div className="bl-tap-r" aria-hidden>{receipt}</div>}
        </div>
      </div>
    </section>
  );
}
