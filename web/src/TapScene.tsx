import { useEffect, useRef } from 'react';
import type { ReactNode } from 'react';

type Props = { src: string; tapText: string; paidText: string; toast: ReactNode };

// Where the card meets the terminal in pay-tap.webp, as a share of the image.
const PX = 0.47, PY = 0.525, RATIO = 1600 / 2400;

/**
 * Pinned scene: the camera pushes in on the terminal as you scroll; at the moment of the tap the NFC waves
 * ring out, the frame flashes and "Tap." turns into "Paid.". Scrolling back un-pays it.
 */
export default function TapScene({ src, tapText, paidText, toast }: Props) {
  const sec = useRef<HTMLElement | null>(null);
  const cam = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const s = sec.current, c = cam.current;
    const root = s?.closest('.bl') as HTMLElement | null;
    if (!s || !c || !root) return;
    const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
    let raf = 0;
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
      s.classList.toggle('hit', p >= 0.5);
    };
    const onScroll = () => { if (!raf) raf = requestAnimationFrame(frame); };
    const onResize = () => { fit(); onScroll(); };
    fit(); frame();
    root.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onResize);
    return () => { root.removeEventListener('scroll', onScroll); window.removeEventListener('resize', onResize); if (raf) cancelAnimationFrame(raf); };
  }, []);

  return (
    <section id="tap" ref={sec} className="bl-tap">
      <div className="bl-tap-stage">
        <div ref={cam} className="bl-tap-cam" aria-hidden>
          <img src={src} alt="" draggable={false} />
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
        </div>
      </div>
    </section>
  );
}
