import React, { useEffect, useRef, useState } from 'react';
import './cine.css';

// The cinematic layer of the landing: photographs of Rome's architecture lead, everything else follows.
// CineHero: a full-screen still that slowly changes (four photographs, a slow push on each), the name and one button.
// CinePlate: a wide still between sections, like a location card in a film (slow drift, one line of text).

const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const ss = (a: number, b: number, v: number) => { const k = clamp((v - a) / (b - a)); return k * k * (3 - 2 * k); };

const REEL = ['/landing/cine-stairs.webp', '/landing/cine-eur.webp', '/landing/cine-dome.webp', '/landing/cine-colosseum.webp'];

export function CineHero({ cta, onOpen }: { cta: string; onOpen: () => void }) {
  const [reel, setReel] = useState(false);     // the other photographs load after the first one is on screen
  useEffect(() => { const t = window.setTimeout(() => setReel(true), 1200); return () => window.clearTimeout(t); }, []);
  return (
    <section id="top" className="ch">
      <div className="ch-reel" aria-hidden>
        {REEL.map((src, i) => <i key={src} style={{ backgroundImage: i === 0 || reel ? `url(${src})` : undefined, ['--i' as string]: i }} />)}
      </div>
      <div className="ch-shade" aria-hidden />
      <div className="ch-title">
        <h1><span>TaxTech</span> <span className="ch-gold">Bank</span></h1>
        <button type="button" className="bl-pill" onClick={onOpen}>{cta}</button>
      </div>
    </section>
  );
}

export function CinePlate({ id, src, pos = '50% 50%', title, children, tall = false }: {
  id?: string; src: string; pos?: string; title?: string; children?: React.ReactNode; tall?: boolean;
}) {
  const ref = useRef<HTMLElement | null>(null);
  const [near, setNear] = useState(false);
  useEffect(() => {
    const el = ref.current, root = el?.closest<HTMLElement>('.bl');
    if (!el || !root) return;
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    let raf = 0, seen = false;
    const apply = () => {
      raf = 0;
      const r = el.getBoundingClientRect(), vh = root.clientHeight;
      el.style.setProperty('--k', clamp((r.top + r.height / 2 - vh / 2) / (vh / 2 + r.height / 2), -1, 1).toFixed(3));
    };
    const onScroll = () => { if (seen && !still && !raf) raf = requestAnimationFrame(apply); };
    const io = new IntersectionObserver(([e]) => { seen = e.isIntersecting; if (seen) { setNear(true); el.classList.add('in'); onScroll(); } }, { root, rootMargin: '600px 0px' });
    io.observe(el);
    root.addEventListener('scroll', onScroll, { passive: true });
    return () => { io.disconnect(); root.removeEventListener('scroll', onScroll); if (raf) cancelAnimationFrame(raf); };
  }, []);
  return (
    <section id={id} className={`cp${tall ? ' cp-tall' : ''}`} ref={ref}>
      <div className="cp-frame">
        <div className="cp-img" aria-hidden style={{ backgroundImage: near ? `url(${src})` : undefined, backgroundPosition: pos }} />
        {(title || children) && <div className="cp-shade" aria-hidden />}
        {(title || children) && (
          <div className="cp-text">
            {title && <h2>{title}</h2>}
            {children}
          </div>
        )}
      </div>
    </section>
  );
}
