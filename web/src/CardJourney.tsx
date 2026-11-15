import React, { useEffect, useRef, useState } from 'react';
import { LOOKS, T, clamp, lookAt, lookProgress, ss } from './cardLooks';
import type { JourneyApi } from './cardJourneyScene';
import { chime } from './paySound';
import './cardJourney.css';

// The top of the landing: one 3D card pinned to the screen while the page scrolls through three chapters.
// Hero (the name and one button), the tap on a terminal, and the looks of the card. The WebGL scene loads after
// the first paint; without WebGL the same chapters run with a flat card.

type Chapter = 'hero' | 'tap' | 'looks';

export default function CardJourney({ t, rosette, amount, toast, fallback, onOpen }: {
  t: (uk: string, en: string) => string;
  rosette: string;
  amount: string;
  toast: React.ReactNode;
  fallback: React.ReactNode;
  onOpen: () => void;
}) {
  const secRef = useRef<HTMLElement | null>(null);
  const stageRef = useRef<HTMLDivElement | null>(null);
  const glRef = useRef<HTMLCanvasElement | null>(null);
  const [look, setLook] = useState(0);
  const [paid, setPaid] = useState(false);
  const [chapter, setChapter] = useState<Chapter>('hero');
  const [gl, setGl] = useState<'wait' | 'on' | 'off'>('wait');

  useEffect(() => {
    const sec = secRef.current, stage = stageRef.current, cv = glRef.current;
    const root = sec?.closest<HTMLElement>('.bl');
    if (!sec || !stage || !cv || !root) return;
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    let api: JourneyApi | null = null, dead = false, raf = 0, wasPaid = false, lastLook = 0, lastCh: Chapter = 'hero';

    const apply = () => {
      raf = 0;
      const p = clamp((root.scrollTop - sec.offsetTop) / Math.max(1, sec.offsetHeight - stage.offsetHeight));
      api?.setProgress(p);
      stage.style.setProperty('--hero', (1 - ss(T.heroOut[0], T.heroOut[1], p)).toFixed(3));
      stage.style.setProperty('--tap', (ss(T.tapIn[0], T.tapIn[1], p) * (1 - ss(T.tapOut[0], T.tapOut[1], p))).toFixed(3));
      stage.style.setProperty('--looks', ss(T.looksIn[0], T.looksIn[1], p).toFixed(3));
      const nowPaid = p >= T.pay && p < T.tapOut[1];
      if (nowPaid !== wasPaid) { wasPaid = nowPaid; setPaid(nowPaid); if (nowPaid) chime(0.55); }
      const ch: Chapter = p < (T.heroOut[1] + T.tapIn[0]) / 2 ? 'hero' : p < (T.tapOut[1] + T.looksIn[0]) / 2 ? 'tap' : 'looks';
      if (ch !== lastCh) { lastCh = ch; setChapter(ch); }
      if (!api) { const i = lookAt(p).i; if (i !== lastLook) { lastLook = i; setLook(i); } }
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
        .then(m => m.createJourney(cv, { rosette, amount, markUrl: '/icons/mark-white.svg', still, onLook: i => { lastLook = i; setLook(i); }, onReady: () => setGl('on') }))
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

  const go = (i: number) => {
    const sec = secRef.current, stage = stageRef.current, root = sec?.closest<HTMLElement>('.bl');
    if (!sec || !stage || !root) return;
    root.scrollTo({ top: sec.offsetTop + lookProgress(i) * (sec.offsetHeight - stage.offsetHeight) });
  };
  const anchor = (p: number) => ({ top: `calc((100% - 100svh) * ${p})` });
  const cur = LOOKS[look];

  return (
    <section id="top" className="cj" ref={secRef}>
      <span id="pay" className="cj-anchor" style={anchor(T.pay + 0.05)} />
      <span id="card" className="cj-anchor" style={anchor(T.looks[0])} />
      <div className={`cj-stage cj-gl-${gl}${paid ? ' cj-paid' : ''}`} ref={stageRef} style={{ ['--tint' as string]: cur.tint }}>
        <div className="cj-glow" aria-hidden />
        <svg className="cj-rose" viewBox="0 0 100 100" aria-hidden><path d={rosette} fill="none" stroke="currentColor" strokeWidth=".12" /></svg>
        <canvas className="cj-gl" ref={glRef} aria-hidden />
        {gl === 'off' && <div className="cj-flat" aria-hidden>{fallback}</div>}

        <div className="cj-ch cj-hero" inert={chapter !== 'hero'}>
          <h1>{['TaxTech', 'Bank'].map((w, i) => <span key={w} className={`cj-w${i ? ' cj-goldw' : ''}`} style={{ ['--i' as string]: i }}>{w}</span>)}</h1>
          <button type="button" className="bl-pill" onClick={onOpen}>{t('Відкрити рахунок', 'Open an account')}</button>
        </div>

        <div className="cj-ch cj-tap" inert={chapter !== 'tap'}>
          <h2><span>{t('Дотик.', 'Tap.')}</span> <span className="cj-paidw">{t('Оплачено.', 'Paid.')}</span></h2>
          <div className="cj-toast">{toast}</div>
        </div>

        <div className="cj-ch cj-looks" inert={chapter !== 'looks'}>
          <h2>{t('Вісім облич.', 'Eight faces.')}</h2>
          <div className="cj-pick">
            <p className="cj-name" key={cur.id}>{t(cur.uk, cur.en)}</p>
            <div className="cj-sw" role="radiogroup" aria-label={t('Оздоблення', 'Design')}>
              {LOOKS.map((l, i) => (
                <button key={l.id} type="button" role="radio" aria-checked={i === look} aria-label={t(l.uk, l.en)} className={i === look ? 'on' : ''} onClick={() => go(i)}
                  style={{ backgroundImage: l.photo ? `url(${l.photo})` : `linear-gradient(145deg, ${l.a}, ${l.b})` }} />
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
