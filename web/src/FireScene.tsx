import { useEffect, useRef } from 'react';
import type { Spot } from './fireData';

type Props = {
  src: string;
  ratio: number;            // image width / height
  focusX?: number;          // 0 = crop from the left, 1 = from the right (matters on narrow screens)
  focusY?: number;          // 0 = crop from the top, 1 = from the bottom (like background-position)
  spots: Spot[];            // lit arches, % of the image
  embers?: number;          // 0 turns the sparks off
  className?: string;
  dawn?: boolean;           // lights come on one by one when the scene appears
};

/**
 * A photograph that behaves like `background-size: cover`, with the lit arches given a living glow
 * and sparks rising from them. Everything is placed in image coordinates, so it stays on the arches.
 */
export default function FireScene({ src, ratio, focusX = 0.5, focusY = 0.4, spots, embers = 90, className = '', dawn = false }: Props) {
  const box = useRef<HTMLDivElement | null>(null);
  const wrap = useRef<HTMLDivElement | null>(null);
  const cv = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const outer = box.current, inner = wrap.current, canvas = cv.current;
    const host = outer?.parentElement;
    if (!outer || !inner || !canvas || !host) return;
    let w = 0, h = 0, dpr = 1;
    const fit = () => {
      const W = host.clientWidth, H = host.clientHeight;
      const s = Math.max(W / ratio, H);              // cover: image height at which both sides are filled
      w = s * ratio; h = s;
      inner.style.width = `${w}px`; inner.style.height = `${h}px`;
      inner.style.left = `${(W - w) * focusX}px`; inner.style.top = `${(H - h) * focusY}px`;
      dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
    };
    fit();
    const ro = new ResizeObserver(fit);
    ro.observe(host);

    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (still || !embers) return () => ro.disconnect();
    const ctx = canvas.getContext('2d');
    if (!ctx) return () => ro.disconnect();

    // Emitters: the lower edge of the biggest arches. Sparks leave from there and drift up.
    const em = spots.filter(s => s[2] * s[3] > 3).map(s => ({ x: s[0] / 100, y: (s[1] + s[3] * 0.25) / 100, w: s[2] / 100 }));
    type P = { x: number; y: number; vx: number; vy: number; life: number; age: number; r: number; hue: number; ph: number };
    const ps: P[] = [];
    // Glow sprites, one per hue step, drawn once: a gradient per spark per frame was the costliest part of the scene.
    const SPR = 64, HUES = 6;
    const sprites = Array.from({ length: HUES }, (_, j) => {
      const hue = 22 + (26 * j) / (HUES - 1);
      const c = document.createElement('canvas'); c.width = c.height = SPR;
      const g2 = c.getContext('2d')!, m = SPR / 2;
      const g = g2.createRadialGradient(m, m, 0, m, m, m);
      g.addColorStop(0, `hsla(${hue},100%,72%,1)`);
      g.addColorStop(0.2, `hsla(${hue},100%,58%,.6)`);
      g.addColorStop(1, `hsla(${hue},100%,50%,0)`);
      g2.fillStyle = g; g2.fillRect(0, 0, SPR, SPR);
      return c;
    });
    const cores = Array.from({ length: HUES }, (_, j) => `hsl(${22 + (26 * j) / (HUES - 1)},100%,88%)`);
    let visible = true, raf = 0, last = performance.now();
    const spawn = () => {
      const e = em[(Math.random() * em.length) | 0];
      if (!e) return;
      ps.push({ x: (e.x + (Math.random() - 0.5) * e.w) * w, y: e.y * h, vx: (Math.random() - 0.35) * 0.12, vy: -(0.07 + Math.random() * 0.2), life: 2400 + Math.random() * 3800, age: 0, r: 1 + Math.random() * 2.8, hue: 22 + Math.random() * 26, ph: Math.random() * 6.28 });
    };
    const tick = (now: number) => {
      raf = visible ? requestAnimationFrame(tick) : 0;   // off screen the loop stops until the scene is back
      const dt = Math.min(48, now - last); last = now;
      for (let i = 0; i < 3 && ps.length < embers; i++) if (Math.random() < 0.7) spawn();
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);
      ctx.globalCompositeOperation = 'lighter';
      ctx.globalAlpha = 1;
      for (let i = ps.length - 1; i >= 0; i--) {
        const p = ps[i];
        p.age += dt;
        if (p.age >= p.life) { ps.splice(i, 1); continue; }
        p.ph += dt * 0.003;
        p.x += (p.vx + Math.sin(p.ph) * 0.05) * dt * (w / 1400);
        p.y += p.vy * dt * (h / 900);
        const k = p.age / p.life;
        const a = Math.sin(Math.PI * Math.min(1, k * 1.15)) * (0.55 + 0.45 * Math.sin(p.ph * 6));
        const r = p.r * (w / 1400 + 0.6) * (1 - k * 0.5);
        const R = r * 5, al = Math.max(0, Math.min(1, a)), hi = Math.min(HUES - 1, Math.round(((p.hue - 22) / 26) * (HUES - 1)));
        ctx.globalAlpha = al;
        ctx.drawImage(sprites[hi], p.x - R, p.y - R, R * 2, R * 2);
        ctx.fillStyle = cores[hi];
        ctx.globalAlpha = al * 0.95;
        ctx.beginPath(); ctx.arc(p.x, p.y, Math.max(0.7, r * 0.75), 0, 6.2832); ctx.fill();
      }
    };
    const io = new IntersectionObserver(es => {
      visible = es[es.length - 1]?.isIntersecting ?? true;
      if (visible && !raf) { last = performance.now(); raf = requestAnimationFrame(tick); }
    }, { threshold: 0 });
    io.observe(host);
    raf = requestAnimationFrame(tick);
    return () => { cancelAnimationFrame(raf); io.disconnect(); ro.disconnect(); };
  }, [ratio, focusX, focusY, spots, embers]);

  return (
    <div ref={box} className={`bl-fire ${dawn ? 'bl-fire-dawn' : ''} ${className}`} aria-hidden>
      <div ref={wrap} className="bl-fire-in">
        <img src={src} alt="" draggable={false} />
        {spots.map((s, i) => (
          <i key={i} className="bl-fire-glow" style={{
            left: `${s[0]}%`, top: `${s[1]}%`, width: `${Math.max(s[2] * 2.6, 3)}%`, height: `${Math.max(s[3] * 2.2, 4)}%`,
            ['--d' as string]: `${(600 + i * 70).toFixed(0)}ms`,
            ['--f' as string]: `${(1.1 + ((i * 37) % 17) / 10).toFixed(2)}s`,
            ['--o' as string]: `${((i * 0.17) % 0.6).toFixed(2)}s`,
          }} />
        ))}
        <canvas ref={cv} className="bl-fire-cv" />
      </div>
    </div>
  );
}
