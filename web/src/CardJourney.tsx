import React, { useEffect, useRef, useState } from 'react';
import { LOOKS, T, clamp, ss } from './cardLooks';
import type { JourneyApi } from './cardJourneyScene';
import { chime } from './paySound';
import './cardJourney.css';

// The top of the landing: one 3D card pinned to the screen while the page scrolls through two chapters.
// Hero (the name and one button) and the tap on a terminal. The WebGL scene loads after
// the first paint; without WebGL the same chapters run with a flat card.

type Chapter = 'hero' | 'tap';

export default function CardJourney({ t, rosette, amount, toast, fallback, onOpen, backdrop }: {
  t: (uk: string, en: string) => string;
  rosette: string;
  amount: string;
  toast: React.ReactNode;
  fallback: React.ReactNode;
  onOpen: () => void;
  backdrop?: string;   // a photograph behind the scene: the card then plays without its own hero
}) {
  const secRef = useRef<HTMLElement | null>(null);
  const stageRef = useRef<HTMLDivElement | null>(null);
  const glRef = useRef<HTMLCanvasElement | null>(null);
  const [paid, setPaid] = useState(false);
  const [chapter, setChapter] = useState<Chapter>('hero');
  const [gl, setGl] = useState<'wait' | 'on' | 'off'>('wait');

  useEffect(() => {
    const sec = secRef.current, stage = stageRef.current, cv = glRef.current;
    const root = sec?.closest<HTMLElement>('.bl');
    if (!sec || !stage || !cv || !root) return;
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    let api: JourneyApi | null = null, dead = false, raf = 0, wasPaid = false, lastCh: Chapter = 'hero';

    const apply = () => {
      raf = 0;
      const p = clamp((root.scrollTop - sec.offsetTop) / Math.max(1, sec.offsetHeight - stage.offsetHeight));
      api?.setProgress(p);
      stage.style.setProperty('--hero', (1 - ss(T.heroOut[0], T.heroOut[1], p)).toFixed(3));
      stage.style.setProperty('--tap', (ss(T.tapIn[0], T.tapIn[1], p) * (1 - ss(T.tapOut[0], T.tapOut[1], p))).toFixed(3));
      const nowPaid = p >= T.pay && p < T.tapOut[1];
      if (nowPaid !== wasPaid) { wasPaid = nowPaid; setPaid(nowPaid); if (nowPaid) chime(0.55); }
      const ch: Chapter = p < (T.heroOut[1] + T.tapIn[0]) / 2 ? 'hero' : 'tap';
      if (ch !== lastCh) { lastCh = ch; setChapter(ch); }
    };
    const onScroll = () => { if (!raf) raf = requestAnimationFrame(apply); };
    root.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    apply();

    const ro = new ResizeObserver(() => { api?.resize(); onScroll(); });
    ro.observe(stage);
    const io = new IntersectionObserver(([e]) => api?.setVisible(e.isIntersecting), { root });
    io.observe(sec);
    const fine = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
    const move = (e: PointerEvent) => {
      const r = stage.getBoundingClientRect();
      api?.setPointer(((e.clientX - r.left) / r.width - 0.5) * 2, ((e.clientY - r.top) / r.height - 0.5) * 2);
    };
    const leave = () => api?.setPointer(0, 0);
    if (fine && !still) { stage.addEventListener('pointermove', move); stage.addEventListener('pointerleave', leave); }

    // three.js is a separate chunk: it starts loading once the headline is on screen
    const start = window.setTimeout(() => {
      import('./cardJourneyScene')
        .then(m => m.createJourney(cv, { rosette, amount, markUrl: '/icons/mark-white.svg', still, onLook: () => {}, onReady: () => setGl('on') }))
        .then(a => { if (dead) { a.dispose(); return; } api = a; apply(); })
        .catch(() => { if (!dead) setGl('off'); });
    }, 60);

    return () => {
      dead = true; window.clearTimeout(start); if (raf) cancelAnimationFrame(raf);
      root.removeEventListener('scroll', onScroll); window.removeEventListener('resize', onScroll);
      stage.removeEventListener('pointermove', move); stage.removeEventListener('pointerleave', leave);
      ro.disconnect(); io.disconnect(); api?.dispose();
    };
  }, []);

  const anchor = (p: number) => ({ top: `calc((100% - 100svh) * ${p})` });
  const cur = LOOKS[0];

  return (
    <section id={backdrop ? 'pay' : 'top'} className={`cj${backdrop ? ' cj-bare' : ''}`} ref={secRef}>
      {!backdrop && <span id="pay" className="cj-anchor" style={anchor(T.pay + 0.12)} />}
      <div className={`cj-stage cj-gl-${gl}${paid ? ' cj-paid' : ''}`} ref={stageRef} style={{ ['--tint' as string]: cur.tint }}>
        {backdrop && <div className="cj-back" aria-hidden style={{ backgroundImage: `url(${backdrop})` }} />}
        <div className="cj-glow" aria-hidden />
        <svg className="cj-rose" viewBox="0 0 100 100" aria-hidden><path d={rosette} fill="none" stroke="currentColor" strokeWidth=".12" /></svg>
        <canvas className="cj-gl" ref={glRef} aria-hidden />
        {gl === 'off' && <div className="cj-flat" aria-hidden>{fallback}</div>}

        <div className="cj-ch cj-hero" inert={chapter !== 'hero' || !!backdrop}>
          <h1>{['TaxTech', 'Bank'].map((w, i) => <span key={w} className={`cj-w${i ? ' cj-goldw' : ''}`} style={{ ['--i' as string]: i }}>{w}</span>)}</h1>
          <button type="button" className="bl-pill" onClick={onOpen}>{t('Відкрити рахунок', 'Open an account')}</button>
        </div>

        <div className="cj-ch cj-tap" inert={chapter !== 'tap'}>
          <h2><span>{t('Дотик.', 'Tap.')}</span> <span className="cj-paidw">{t('Оплачено.', 'Paid.')}</span></h2>
          <div className="cj-toast">{toast}</div>
        </div>
      </div>
    </section>
  );
}
