import { useEffect, useRef, useState } from 'react';

// Night map of central Rome drawn from OpenStreetMap streets (romeMapData.ts, loaded on demand).
// It is the background of the hero and of "One evening in Rome": the camera starts wide over the city, then
// follows a payment along real streets from the Forum to the Pantheon to the Trevi Fountain as the page scrolls.
// The streets are painted on a canvas (thousands of segments, redrawn only when the camera moves or while the hero
// pulses); pins and the moving point are a handful of DOM nodes positioned with transforms.

type Data = typeof import('./romeMapData')['ROME'];

const HERO = { x: 1390, y: 930 };            // wide view: the cluster of landmarks
const Z_HERO = 1.15, Z_NEAR = 2.9;
const AMBIENT = ['l0', 'a0', 'a1', 'a2', 'a3', 'a4', 'l1', 'l2'] as const;
const PINS = ['colosseo', 'foro', 'pantheon', 'trevi', 'navona', 'vaticano', 'spagna'] as const;
const STOPS = ['foro', 'pantheon', 'trevi'] as const; // same order as DAY in BankLanding

const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const smooth = (a: number, b: number, x: number) => { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); };
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

export default function RomeMap() {
  const wrap = useRef<HTMLDivElement | null>(null);
  const cvs = useRef<HTMLCanvasElement | null>(null);
  const probes = useRef<SVGSVGElement | null>(null);
  const [D, setD] = useState<Data | null>(null);

  useEffect(() => {
    let on = true;
    import('./romeMapData').then(m => { if (on) setD(m.ROME); }).catch(() => {});
    return () => { on = false; };
  }, []);

  useEffect(() => {
    const el = wrap.current, canvas = cvs.current, svg = probes.current;
    if (!D || !el || !canvas || !svg) return;
    const root = el.closest<HTMLElement>('.bl');
    const hero = root?.querySelector<HTMLElement>('.bl-hero');
    const rome = root?.querySelector<HTMLElement>('.bl-rome');
    const ctx = canvas.getContext('2d');
    const dot = el.querySelector<HTMLElement>('.rm-dot');
    if (!root || !hero || !rome || !ctx || !dot) return;
    const pinEls = PINS.map(k => ({ k, g: el.querySelector<HTMLElement>(`[data-pin="${k}"]`)! }));
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    // Geometry: one Path2D per layer; route lengths and the moving point are measured on hidden SVG paths.
    const layers = { river: new Path2D(D.river), minor: new Path2D(D.minor), mid: new Path2D(D.mid), major: new Path2D(D.major) };
    const routes: Record<string, { path: Path2D; len: number }> = {};
    const probe: Record<string, SVGPathElement> = {};
    for (const a of AMBIENT) {
      probe[a] = svg.querySelector<SVGPathElement>(`[data-r="${a}"]`)!;
      routes[a] = { path: new Path2D(D.routes[a]), len: probe[a].getTotalLength() };
    }
    const legs = [probe.l1, probe.l2];
    const lens = legs.map(p => p.getTotalLength());
    const foro = D.pois.foro;

    let W = 0, Hh = 0, dpr = 1, ppu = 1, raf = 0, intro = still ? 1 : 0, introT0 = 0, visible = true;
    let lastKey = '';

    const resize = () => {
      W = el.clientWidth; Hh = el.clientHeight;
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      while (W * Hh * dpr * dpr > 6e6 && dpr > 1) dpr -= 0.25;
      canvas.width = Math.round(W * dpr); canvas.height = Math.round(Hh * dpr);
      ppu = Math.max(W / D.w, Hh / D.h) || 1;
      lastKey = '';
    };

    const frame = (now: number) => {
      raf = 0;
      if (!W || !Hh) resize();
      if (!W || !Hh) return;
      if (intro < 1) {
        if (!introT0) introT0 = now;
        intro = clamp((now - introT0 - 250) / 2600);
      }
      const box = root.getBoundingClientRect();
      const h = clamp(root.scrollTop / Math.max(1, hero.offsetHeight));
      const p = clamp(-(rome.getBoundingClientRect().top - box.top) / Math.max(1, rome.offsetHeight - root.clientHeight));
      const s = p * STOPS.length;
      const u = clamp(s - 0.5, 0, STOPS.length - 1);
      const k = Math.min(legs.length - 1, Math.floor(u));
      const e = smooth(0.2, 0.8, u - k);
      const pt = legs[k].getPointAtLength(e * lens[k]);
      let fx: number, fy: number, z: number;
      if (p > 0) {
        fx = pt.x; fy = pt.y; z = Z_NEAR - 1.1 * Math.sin(Math.PI * e);
      } else {
        const he = smooth(0, 1, h);
        const hx = W > 860 ? HERO.x : 1460, hz = W > 860 ? Z_HERO : 1;
        fx = lerp(hx, foro.x, he); fy = lerp(HERO.y, foro.y, he); z = lerp(hz, Z_NEAR, he);
      }
      // On wide screens the text sits left and the card right, so the point of interest rides in the lower middle.
      const wide = W > 860;
      const ox = wide ? 0.02 * W / ppu : 0, oy = wide ? 0.2 * Hh / ppu : 0.02 * Hh / ppu;
      const pulsing = !still && h < 0.95 && p <= 0;
      const pulseA = pulsing ? 1 - smooth(0, 0.9, h) : 0;
      const t = now / 1000;
      const animating = intro < 1 || pulsing;

      // Repaint only when something visible changed.
      const key = animating ? '' : `${W}|${Hh}|${fx.toFixed(1)}|${fy.toFixed(1)}|${z.toFixed(3)}|${e.toFixed(3)}|${k}|${u < 1 ? 0 : 1}|${p > 0 ? 1 : 0}`;
      if (key === '' || key !== lastKey) {
        lastKey = key;
        const sc = ppu * z, sw = 0.75 + 0.25 * z, px = (n: number) => (n * sw) / sc;
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.setTransform(dpr * sc, 0, 0, dpr * sc, dpr * (W / 2 + ppu * (ox - z * fx)), dpr * (Hh / 2 + ppu * (oy - z * fy)));
        ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        const stroke = (path: Path2D, color: string, width: number) => { ctx.strokeStyle = color; ctx.lineWidth = px(width); ctx.stroke(path); };
        stroke(layers.river, 'rgba(110,150,225,.2)', 9);
        stroke(layers.minor, 'rgba(255,255,255,.17)', 0.7);
        stroke(layers.mid, 'rgba(255,255,255,.3)', 1);
        stroke(layers.major, 'rgba(255,226,140,.62)', 1.5);
        for (const a of AMBIENT) stroke(routes[a].path, 'rgba(255,212,0,.28)', 2);
        if (pulseA > 0.01) {
          AMBIENT.forEach((a, i) => {
            const r = routes[a], dur = 7 + (i % 4) * 1.6;
            const ph = (((t - i * 1.7) / dur) % 1 + 1) % 1;
            ctx.setLineDash([r.len * 0.04, r.len * 0.96]); ctx.lineDashOffset = -ph * r.len;
            ctx.globalAlpha = pulseA * 0.28; stroke(r.path, '#ffd400', 8);
            ctx.globalAlpha = pulseA; stroke(r.path, '#ffd400', 2.6);
          });
          ctx.setLineDash([]); ctx.lineDashOffset = 0; ctx.globalAlpha = 1;
        }
        if (p > 0) {
          const trail = (name: 'l1' | 'l2', prog: number) => {
            if (prog <= 0.001) return;
            const r = routes[name];
            ctx.setLineDash([r.len * prog, r.len * 2]);
            ctx.globalAlpha = 0.3; stroke(r.path, '#ffd400', 9);
            ctx.globalAlpha = 1; stroke(r.path, '#ffd400', 3);
          };
          trail('l1', u < 1 ? e : 1);
          trail('l2', u < 1 ? 0 : e);
          ctx.setLineDash([]); ctx.globalAlpha = 1;
        }
        if (intro < 1) {
          // The streets light up outward from the middle of the screen.
          const rv = 1 - Math.pow(1 - intro, 3);
          const R = Math.hypot(W, Hh) * 0.77 * dpr, r0 = Math.max(1, R * rv - R * 0.22);
          const cx = canvas.width / 2, cy = canvas.height / 2;
          const g = ctx.createRadialGradient(cx, cy, r0, cx, cy, Math.max(r0 + 1, R * rv));
          g.addColorStop(0, '#000'); g.addColorStop(1, 'rgba(0,0,0,0)');
          ctx.setTransform(1, 0, 0, 1, 0, 0);
          ctx.globalCompositeOperation = 'destination-in';
          ctx.fillStyle = g; ctx.fillRect(0, 0, canvas.width, canvas.height);
          ctx.globalCompositeOperation = 'source-over';
        }
      }

      // Pins and the moving point: DOM nodes placed with transforms.
      const sx = (x: number) => W / 2 + ppu * (ox + z * (x - fx));
      const sy = (y: number) => Hh / 2 + ppu * (oy + z * (y - fy));
      const fade = intro < 1 ? clamp((intro - 0.35) / 0.4) : 1;
      for (const { k: name, g } of pinEls) {
        const q = D.pois[name], x = sx(q.x), y = sy(q.y);
        const on = x > -160 && x < W + 160 && y > -40 && y < Hh + 40;
        g.style.visibility = on ? 'visible' : 'hidden';
        if (!on) continue;
        g.style.transform = `translate3d(${x.toFixed(1)}px, ${y.toFixed(1)}px, 0)`;
        g.style.opacity = String(fade);
        const i = STOPS.indexOf(name as typeof STOPS[number]);
        g.style.setProperty('--on', i < 0 ? '0' : clamp(1 - Math.abs(s - (i + 0.5)) * 2).toFixed(2));
      }
      dot.style.transform = `translate3d(${sx(pt.x).toFixed(1)}px, ${sy(pt.y).toFixed(1)}px, 0)`;
      dot.style.opacity = p > 0 ? '1' : '0';

      if (animating && visible) raf = requestAnimationFrame(frame);
    };
    const request = () => { if (!raf) raf = requestAnimationFrame(frame); };
    const onResize = () => { resize(); request(); };

    const io = new IntersectionObserver(es => {
      visible = es[es.length - 1]?.isIntersecting ?? true;
      if (visible) { lastKey = ''; request(); }
    });
    io.observe(el);
    const ro = new ResizeObserver(onResize);
    ro.observe(el);
    root.addEventListener('scroll', request, { passive: true });
    resize();
    request();
    return () => {
      root.removeEventListener('scroll', request);
      io.disconnect(); ro.disconnect();
      if (raf) cancelAnimationFrame(raf);
    };
  }, [D]);

  return (
    <div className="rm" ref={wrap} aria-hidden>
      <div className="rm-glow" />
      <canvas className="rm-cv" ref={cvs} />
      {D && (
        <svg ref={probes} width="0" height="0" style={{ position: 'absolute', visibility: 'hidden' }} aria-hidden>
          {AMBIENT.map(a => <path key={a} data-r={a} d={D.routes[a]} />)}
        </svg>
      )}
      <div className="rm-over">
        {PINS.map(k => (
          <div key={k} data-pin={k} className="rm-pin">
            <i className="rm-ring" /><i className="rm-core" />
            <span>{D?.pois[k].name}</span>
          </div>
        ))}
        <div className="rm-dot"><i className="rm-lamp" /><i className="rm-dot-ring" /><i className="rm-dot-core" /></div>
      </div>
      <div className="rm-vig" />
    </div>
  );
}
