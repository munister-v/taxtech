import { useEffect, useRef, useState } from 'react';

// Night map of central Rome drawn from OpenStreetMap streets (romeMapData.ts, loaded on demand).
// It is the background of the hero and of "One evening in Rome": the camera starts wide over the city, then
// follows a payment along real streets from the Forum to the Pantheon to the Trevi Fountain as the page scrolls.

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
  const [D, setD] = useState<Data | null>(null);

  useEffect(() => {
    let on = true;
    import('./romeMapData').then(m => { if (on) setD(m.ROME); }).catch(() => {});
    return () => { on = false; };
  }, []);

  useEffect(() => {
    const el = wrap.current;
    if (!D || !el) return;
    const root = el.closest<HTMLElement>('.bl');
    const hero = root?.querySelector<HTMLElement>('.bl-hero');
    const rome = root?.querySelector<HTMLElement>('.bl-rome');
    const cam = el.querySelector<SVGGElement>('.rm-cam');
    const svg = el.querySelector<SVGSVGElement>('.rm-svg');
    const l1 = el.querySelector<SVGPathElement>('[data-leg="l1"]');
    const l2 = el.querySelector<SVGPathElement>('[data-leg="l2"]');
    const t1 = el.querySelector<SVGPathElement>('[data-trail="l1"]');
    const t2 = el.querySelector<SVGPathElement>('[data-trail="l2"]');
    const dot = el.querySelector<SVGGElement>('.rm-dot');
    if (!root || !hero || !rome || !cam || !svg || !l1 || !l2 || !t1 || !t2 || !dot) return;
    const pinEls = PINS.map(k => ({ k, g: el.querySelector<SVGGElement>(`[data-pin="${k}"]`)! }));
    const legs = [l1, l2];
    const lens = legs.map(p => p.getTotalLength());
    const foro = D.pois.foro;
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    let raf = 0, ppu = 1;

    const update = () => {
      raf = 0;
      const W = el.clientWidth, Hh = el.clientHeight;
      ppu = Math.max(W / D.w, Hh / D.h) || 1;
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
      cam.setAttribute('transform', `translate(${(D.w / 2 + ox).toFixed(1)} ${(D.h / 2 + oy).toFixed(1)}) scale(${z.toFixed(3)}) translate(${(-fx).toFixed(1)} ${(-fy).toFixed(1)})`);
      svg.style.setProperty('--sw', (0.75 + 0.25 * z).toFixed(2));
      const inv = 1 / (z * ppu);
      for (const { k: name, g } of pinEls) {
        const q = D.pois[name];
        g.setAttribute('transform', `translate(${q.x} ${q.y}) scale(${inv.toFixed(4)})`);
        const i = STOPS.indexOf(name as typeof STOPS[number]);
        g.style.setProperty('--on', i < 0 ? '0' : clamp(1 - Math.abs(s - (i + 0.5)) * 2).toFixed(2));
      }
      dot.setAttribute('transform', `translate(${pt.x.toFixed(1)} ${pt.y.toFixed(1)}) scale(${inv.toFixed(4)})`);
      dot.style.opacity = p > 0 ? '1' : '0';
      t1.style.strokeDashoffset = String(1 - (u < 1 ? e : 1));
      t2.style.strokeDashoffset = String(1 - (u < 1 ? 0 : e));
    };
    const onScroll = () => { if (!raf) raf = requestAnimationFrame(update); };
    root.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    update();

    // The streets light up outward from the middle of the screen.
    let rv = 0;
    if (still) { el.classList.add('rm-lit'); }
    else {
      const t0 = performance.now();
      const step = (now: number) => {
        const t = clamp((now - t0 - 250) / 2600);
        rv = 1 - Math.pow(1 - t, 3);
        el.style.setProperty('--rv', (rv * 140).toFixed(1));
        if (t < 1) rv = requestAnimationFrame(step); else el.classList.add('rm-lit');
      };
      el.style.setProperty('--rv', '0');
      rv = requestAnimationFrame(step);
    }
    return () => {
      root.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
      if (raf) cancelAnimationFrame(raf);
      cancelAnimationFrame(rv);
    };
  }, [D]);

  return (
    <div className="rm" ref={wrap} aria-hidden>
      <div className="rm-glow" />
      {D && (
        <svg className="rm-svg" viewBox={`0 0 ${D.w} ${D.h}`} preserveAspectRatio="xMidYMid slice">
          <defs>
            <radialGradient id="rm-lamp">
              <stop offset="0" stopColor="#ffd400" stopOpacity=".5" />
              <stop offset=".35" stopColor="#ffd400" stopOpacity=".16" />
              <stop offset="1" stopColor="#ffd400" stopOpacity="0" />
            </radialGradient>
          </defs>
          <g className="rm-cam">
            <path className="rm-river" d={D.river} />
            <path className="rm-minor" d={D.minor} />
            <path className="rm-mid" d={D.mid} />
            <path className="rm-major" d={D.major} />
            {AMBIENT.map(a => <path key={`b${a}`} className="rm-route" d={D.routes[a]} />)}
            {AMBIENT.map((a, i) => (
              <path key={`p${a}`} className="rm-pulse" d={D.routes[a]} pathLength={100}
                style={{ animationDuration: `${7 + (i % 4) * 1.6}s`, animationDelay: `${-i * 1.7}s` }} />
            ))}
            <path data-leg="l1" className="rm-leg" d={D.routes.l1} />
            <path data-leg="l2" className="rm-leg" d={D.routes.l2} />
            <path data-trail="l1" className="rm-trail" d={D.routes.l1} pathLength={1} />
            <path data-trail="l2" className="rm-trail" d={D.routes.l2} pathLength={1} />
            {PINS.map(k => (
              <g key={k} data-pin={k} className="rm-pin">
                <circle className="rm-ring" r="10" />
                <circle className="rm-core" r="3.2" />
                <text x="17" y="4">{D.pois[k].name}</text>
              </g>
            ))}
            <g className="rm-dot">
              <circle r="64" fill="url(#rm-lamp)" />
              <circle className="rm-dot-ring" r="12" />
              <circle r="4.6" fill="#fff" />
            </g>
          </g>
        </svg>
      )}
      <div className="rm-vig" />
    </div>
  );
}
