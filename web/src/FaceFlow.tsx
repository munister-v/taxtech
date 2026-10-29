import { useEffect, useRef } from 'react';
import type { ReactNode } from 'react';

type Props = {
  count: number;
  active: number;
  onChange: (i: number) => void;
  renderCard: (i: number) => ReactNode;
  labelPrev: string;
  labelNext: string;
};

/**
 * Cover-flow of cards in 3D: drag, swipe, click a side card, use the arrows or the keyboard.
 * The position is a float that eases towards the chosen card, so every move glides.
 */
export default function FaceFlow({ count, active, onChange, renderCard, labelPrev, labelNext }: Props) {
  const box = useRef<HTMLDivElement | null>(null);
  const items = useRef<(HTMLDivElement | null)[]>([]);
  const tilts = useRef<(HTMLDivElement | null)[]>([]);
  const st = useRef({ pos: active, target: active, raf: 0, drag: false, sx: 0, sp: 0, moved: 0, lastX: 0, lastT: 0, v: 0, pid: 0, cap: false });
  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;
  const still = typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const apply = () => {
    const s = st.current;
    const cw = items.current[0]?.offsetWidth || 400;
    items.current.forEach((el, i) => {
      if (!el) return;
      const o = i - s.pos, a = Math.abs(o);
      const rot = -Math.max(-1.4, Math.min(1.4, o)) * 44;
      el.style.transform = `translate3d(${(o * cw * 0.76).toFixed(1)}px,0,${(-a * 120).toFixed(1)}px) rotateY(${rot.toFixed(1)}deg) scale(${(1 - Math.min(a, 3) * 0.06).toFixed(3)})`;
      el.style.opacity = Math.max(0, 1 - Math.max(0, a - 0.25) * 0.34).toFixed(3);
      el.style.zIndex = String(100 - Math.round(a * 10));
      el.classList.toggle('on', a < 0.5);
    });
  };
  const loop = () => {
    const s = st.current;
    s.raf = 0;
    if (!s.drag) s.pos += (s.target - s.pos) * (still ? 1 : 0.14);
    apply();
    if (s.drag || Math.abs(s.target - s.pos) > 0.001) s.raf = requestAnimationFrame(loop);
    else { s.pos = s.target; apply(); }
  };
  const kick = () => { if (!st.current.raf) st.current.raf = requestAnimationFrame(loop); };

  useEffect(() => { st.current.target = active; kick(); }, [active]);
  useEffect(() => {
    apply();
    const el = box.current;
    const ro = el ? new ResizeObserver(apply) : null;
    if (el && ro) ro.observe(el);
    return () => { ro?.disconnect(); cancelAnimationFrame(st.current.raf); st.current.raf = 0; };
  }, []);

  const clampIdx = (i: number) => Math.max(0, Math.min(count - 1, i));
  const go = (i: number) => { const n = clampIdx(i); st.current.target = n; onChangeRef.current(n); kick(); };

  const down = (e: React.PointerEvent) => {
    const s = st.current;
    s.drag = true; s.sx = e.clientX; s.sp = s.pos; s.moved = 0; s.lastX = e.clientX; s.lastT = performance.now(); s.v = 0;
    s.pid = e.pointerId; s.cap = false;
    kick();
  };
  const move = (e: React.PointerEvent) => {
    const s = st.current, el = box.current;
    if (s.drag) {
      const cw = items.current[0]?.offsetWidth || 400;
      const dx = e.clientX - s.sx;
      s.moved = Math.max(s.moved, Math.abs(dx));
      // Capture only once it is a real drag, so a plain click still reaches the card.
      if (s.moved > 6 && !s.cap) { s.cap = true; try { el?.setPointerCapture(s.pid); } catch { /* pointer already gone */ } }
      s.pos = Math.max(-0.4, Math.min(count - 0.6, s.sp - dx / (cw * 0.76)));
      const now = performance.now();
      s.v = (e.clientX - s.lastX) / Math.max(1, now - s.lastT);
      s.lastX = e.clientX; s.lastT = now;
    }
    // Glare and tilt on the card in front.
    const i = Math.round(s.pos), card = items.current[i], tilt = tilts.current[i];
    if (card && tilt && el && e.pointerType === 'mouse') {
      const r = card.getBoundingClientRect();
      const nx = clampN((e.clientX - r.left) / r.width), ny = clampN((e.clientY - r.top) / r.height);
      tilt.style.setProperty('--mx', `${(nx * 100).toFixed(1)}%`);
      tilt.style.setProperty('--my', `${(ny * 100).toFixed(1)}%`);
      tilt.style.setProperty('--tx', `${((0.5 - ny) * 14).toFixed(2)}deg`);
      tilt.style.setProperty('--ty', `${((nx - 0.5) * 18).toFixed(2)}deg`);
    }
  };
  const clampN = (v: number) => Math.max(0, Math.min(1, v));
  const up = () => {
    const s = st.current;
    if (!s.drag) return;
    s.drag = false;
    if (s.moved < 6) return;               // a click, handled by the card itself
    go(Math.round(s.pos - s.v * 220));
  };
  const leave = () => tilts.current.forEach(t => { if (!t) return; t.style.setProperty('--tx', '0deg'); t.style.setProperty('--ty', '0deg'); t.style.setProperty('--mx', '50%'); t.style.setProperty('--my', '40%'); });
  const key = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowRight') { e.preventDefault(); go(Math.round(st.current.target) + 1); }
    if (e.key === 'ArrowLeft') { e.preventDefault(); go(Math.round(st.current.target) - 1); }
  };

  return (
    <div className="bl-flow" ref={box} tabIndex={0} role="group" onKeyDown={key}
      onPointerDown={down} onPointerMove={move} onPointerUp={up} onPointerCancel={up} onPointerLeave={leave}>
      {Array.from({ length: count }, (_, i) => (
        <div key={i} className="bl-flow-card" ref={el => { items.current[i] = el; }}
          onClick={() => { if (st.current.moved < 6 && i !== Math.round(st.current.target)) go(i); }}>
          <div className="bl-flow-tilt" ref={el => { tilts.current[i] = el; }}>
            {renderCard(i)}
            <i className="bl-flow-glare" aria-hidden />
          </div>
        </div>
      ))}
      <button type="button" className="bl-flow-btn bl-flow-prev" aria-label={labelPrev} onClick={() => go(Math.round(st.current.target) - 1)} disabled={active <= 0}>‹</button>
      <button type="button" className="bl-flow-btn bl-flow-next" aria-label={labelNext} onClick={() => go(Math.round(st.current.target) + 1)} disabled={active >= count - 1}>›</button>
    </div>
  );
}
