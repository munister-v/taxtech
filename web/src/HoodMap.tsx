import { useEffect, useRef, useState } from 'react';

// "Under the hood": the night map of Rome from the hero (romeMapData.ts, loaded on demand) with one rail line across it.
// Nine stations, one architectural feature each, in the order a payment goes through the bank. An electric train runs the
// line, brakes into a station, stands there while the card shows the feature, then goes on. A pin sends it to that station.
// Streets are painted once on a canvas; the line, the train and the pins share one projection.

type Data = typeof import('./romeMapData')['ROME'];
type Side = 'l' | 'r' | 't' | 'b';

// Stations in map units of romeMapData (2400 × 1747), in the order of HOOD in BankLanding.
export const HOOD_PLACES: { name: string; x: number; y: number; side: Side }[] = [
  { name: 'San Pietro', x: 463, y: 663, side: 'b' },
  { name: 'Castel Sant’Angelo', x: 875, y: 623, side: 't' },
  { name: 'Piazza Navona', x: 1103, y: 797, side: 'b' },
  { name: 'Pantheon', x: 1230, y: 824, side: 'r' },
  { name: 'Piazza di Spagna', x: 1427, y: 493, side: 'l' },
  { name: 'Fontana di Trevi', x: 1443, y: 721, side: 'r' },
  { name: 'Foro Romano', x: 1510, y: 1097, side: 'l' },
  { name: 'Colosseo', x: 1740, y: 1200, side: 'r' },
  { name: 'Circo Massimo', x: 1510, y: 1382, side: 'r' },
];
// Bends that are not stations: they turn the line round Spagna (up one side of the street, back down the other).
const BENDS: Record<number, { x: number; y: number }[]> = { 3: [{ x: 1290, y: 640 }], 4: [{ x: 1580, y: 600 }] };
const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];
const X0 = 463, X1 = 1740, Y0 = 493, Y1 = 1382;
const N_CARS = 4;

const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const ease = (k: number) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);

function railPath(pts: { x: number; y: number }[], r: number): string {
  let d = `M${pts[0].x.toFixed(1)} ${pts[0].y.toFixed(1)}`;
  for (let i = 1; i < pts.length - 1; i++) {
    const a = pts[i - 1], b = pts[i], c = pts[i + 1];
    const l1 = Math.hypot(a.x - b.x, a.y - b.y), l2 = Math.hypot(c.x - b.x, c.y - b.y), rr = Math.min(r, l1 / 2, l2 / 2);
    d += `L${(b.x + (a.x - b.x) * rr / l1).toFixed(1)} ${(b.y + (a.y - b.y) * rr / l1).toFixed(1)}Q${b.x.toFixed(1)} ${b.y.toFixed(1)} ${(b.x + (c.x - b.x) * rr / l2).toFixed(1)} ${(b.y + (c.y - b.y) * rr / l2).toFixed(1)}`;
  }
  const z = pts[pts.length - 1];
  return d + `L${z.x.toFixed(1)} ${z.y.toFixed(1)}`;
}

type Props = {
  titles: string[];
  shown: number;                         // station whose card is on screen
  target: number;                        // station the train is heading for
  onSelect: (i: number) => void;         // visitor picked a station
  onDepart: (ms: number) => void;
  onArrive: (i: number) => void;
};

export default function HoodMap({ titles, shown, target, onSelect, onDepart, onArrive }: Props) {
  const wrap = useRef<HTMLDivElement | null>(null);
  const cvs = useRef<HTMLCanvasElement | null>(null);
  const probe = useRef<SVGPathElement | null>(null);
  const done = useRef<SVGPathElement | null>(null);
  const cars = useRef<(SVGGElement | null)[]>([]);
  const pinEls = useRef<(HTMLButtonElement | null)[]>([]);
  const [D, setD] = useState<Data | null>(null);
  const [box, setBox] = useState({ w: 0, h: 0 });
  const [geo, setGeo] = useState<{ d: string; total: number; st: { x: number; y: number; s: number }[] } | null>(null);
  const pos = useRef(0);                 // train position along the line, px
  const cb = useRef({ onDepart, onArrive });
  cb.current = { onDepart, onArrive };

  useEffect(() => {
    let on = true;
    import('./romeMapData').then(m => { if (on) setD(m.ROME); }).catch(() => {});
    return () => { on = false; };
  }, []);

  useEffect(() => {
    const el = wrap.current;
    if (!el) return;
    const read = () => setBox({ w: el.clientWidth, h: el.clientHeight });
    read();
    const ro = new ResizeObserver(read);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  // Projection: fit the nine stations with room for their labels, centred.
  const wide = box.w > 560;
  const x0 = X0 - (wide ? 150 : 90), x1 = X1 + (wide ? 330 : 90), y0 = Y0 - (wide ? 150 : 90), y1 = Y1 + (wide ? 150 : 90);
  const sc = box.w && box.h ? Math.min(box.w / (x1 - x0), box.h / (y1 - y0)) : 1;
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  const sx = (x: number) => box.w / 2 + (x - cx) * sc, sy = (y: number) => box.h / 2 + (y - cy) * sc;

  useEffect(() => {
    const canvas = cvs.current;
    if (!D || !canvas || !box.w || !box.h) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(box.w * dpr); canvas.height = Math.round(box.h * dpr);
    ctx.setTransform(dpr * sc, 0, 0, dpr * sc, dpr * (box.w / 2 - cx * sc), dpr * (box.h / 2 - cy * sc));
    ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    const stroke = (d: string, color: string, width: number) => { ctx.strokeStyle = color; ctx.lineWidth = width / sc; ctx.stroke(new Path2D(d)); };
    stroke(D.river, 'rgba(110,150,225,.22)', 9);
    stroke(D.minor, 'rgba(255,255,255,.14)', 0.7);
    stroke(D.mid, 'rgba(255,255,255,.24)', 1);
    stroke(D.major, 'rgba(255,226,140,.45)', 1.5);
  }, [D, box.w, box.h, sc, cx, cy]);

  // The line: stations joined with rounded bends; each station is pinned to the nearest point of the line.
  useEffect(() => {
    const p = probe.current;
    if (!box.w || !p) return;
    const pts: { x: number; y: number }[] = [];
    HOOD_PLACES.forEach((pl, i) => {
      (BENDS[i] || []).forEach(b => pts.push({ x: sx(b.x), y: sy(b.y) }));
      pts.push({ x: sx(pl.x), y: sy(pl.y) });
    });
    const d = railPath(pts, wide ? 34 : 22);
    p.setAttribute('d', d);
    const total = p.getTotalLength();
    const samples: { x: number; y: number; s: number }[] = [];
    for (let s = 0; s <= total; s += 2) { const q = p.getPointAtLength(s); samples.push({ x: q.x, y: q.y, s }); }
    let from = 0;
    const st = HOOD_PLACES.map(pl => {
      const px = sx(pl.x), py = sy(pl.y);
      let best = samples[from], bd = Infinity;
      for (let k = from; k < samples.length; k++) { const dd = Math.hypot(samples[k].x - px, samples[k].y - py); if (dd < bd) { bd = dd; best = samples[k]; } }
      from = Math.max(0, samples.indexOf(best));
      return best;
    });
    setGeo({ d, total, st });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [box.w, box.h]);

  const place = (s: number) => {
    const p = probe.current;
    if (!p || !geo) return;
    const L = wide ? 36 : 26, gap = 3;
    cars.current.forEach((g, k) => {
      if (!g) return;
      const sk = clamp(s - k * (L + gap), 0, geo.total);
      const a = p.getPointAtLength(sk), b = p.getPointAtLength(Math.min(geo.total, sk + 1.5)), c = p.getPointAtLength(Math.max(0, sk - 1.5));
      g.setAttribute('transform', `translate(${a.x.toFixed(1)} ${a.y.toFixed(1)}) rotate(${(Math.atan2(b.y - c.y, b.x - c.x) * 180 / Math.PI).toFixed(1)})`);
    });
    if (done.current) { done.current.style.strokeDasharray = `${geo.total}`; done.current.style.strokeDashoffset = `${geo.total - s}`; }
    geo.st.forEach((q, i) => pinEls.current[i]?.classList.toggle('pass', q.s <= s + 1));
  };

  // Drive the train: from where it stands to the target station, easing out of one and into the next.
  const first = useRef(true);
  const geoRef = useRef(geo); geoRef.current = geo;
  const targetRef = useRef(target); targetRef.current = target;
  // A new projection (first paint, resize) puts the train straight on its station of the new line.
  useEffect(() => {
    if (!geo) return;
    pos.current = geo.st[targetRef.current].s; place(pos.current);
    if (first.current) { first.current = false; cb.current.onArrive(targetRef.current); }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [geo]);
  useEffect(() => {
    const g = geoRef.current;
    if (first.current || !g) return;
    const to = g.st[target].s, from = pos.current;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) { pos.current = to; place(to); cb.current.onArrive(target); return; }
    if (Math.abs(to - from) < 1) { cb.current.onArrive(target); return; }
    const dur = clamp(Math.abs(to - from) / (g.total / 5.5) * 1000, 1000, 3800);
    let raf = 0, t0 = 0;
    cb.current.onDepart(dur);
    const step = (now: number) => {
      if (!t0) t0 = now;
      const k = clamp((now - t0) / dur);
      pos.current = from + (to - from) * ease(k);
      place(pos.current);
      if (k < 1) raf = requestAnimationFrame(step); else cb.current.onArrive(target);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target]);

  const L = wide ? 36 : 26, W = wide ? 14 : 11, nWin = Math.floor((L - 8) / 7);
  return (
    <div className="hm" ref={wrap}>
      <canvas ref={cvs} className={`hm-cv${D ? ' on' : ''}`} aria-hidden />
      <div className="hm-vig" aria-hidden />
      <svg className="hm-rail" width={box.w} height={box.h} aria-hidden>
        <defs>
          <linearGradient id="hmbody" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#ffe55c" /><stop offset="1" stopColor="#e0b000" /></linearGradient>
          <linearGradient id="hmbeam" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stopColor="#fff6c8" stopOpacity=".85" /><stop offset="1" stopColor="#fff6c8" stopOpacity="0" /></linearGradient>
        </defs>
        <path ref={probe} className="hm-line-bed" fill="none" />
        {geo && <path d={geo.d} className="hm-line" fill="none" />}
        {geo && <path d={geo.d} className="hm-line-in" fill="none" />}
        {geo && <path ref={done} d={geo.d} className="hm-done" fill="none" />}
        {geo && Array.from({ length: N_CARS }, (_, k) => (
          <g key={k} ref={el => { cars.current[k] = el; }} className="hm-car">
            {k === 0 && <path d={`M${L / 2 - 2} ${-W * 0.55}L${L / 2 + 60} ${-W * 1.9}L${L / 2 + 60} ${W * 1.9}L${L / 2 - 2} ${W * 0.55}Z`} fill="url(#hmbeam)" />}
            <rect x={-L / 2} y={-W / 2} width={L} height={W} rx={k === 0 ? 4 : 2.5} fill="url(#hmbody)" />
            {Array.from({ length: nWin }, (_, w) => <rect key={w} x={-L / 2 + 4 + w * ((L - 8) / nWin)} y={-W / 2 + 2.2} width={(L - 8) / nWin - 1.6} height={W * 0.36} rx="1.2" fill="#1b1400" opacity=".8" />)}
            <rect x={-L / 2 + 3} y={W / 2 - 3.2} width={L - 6} height="1.4" rx=".7" fill="#1b1400" opacity=".35" />
            {k === 0 && <rect x={L / 2 - 4.5} y={-W / 2 + 1.4} width="3" height={W - 2.8} rx="1" fill="#1b1400" opacity=".85" />}
          </g>
        ))}
      </svg>
      {geo && HOOD_PLACES.map((p, i) => (
        <button key={p.name} type="button" ref={el => { pinEls.current[i] = el; }}
          className={`hm-pin hm-${p.side}${i === shown ? ' on' : ''}${i === target && i !== shown ? ' next' : ''}`}
          style={{ transform: `translate(${geo.st[i].x.toFixed(1)}px, ${geo.st[i].y.toFixed(1)}px)` }}
          aria-label={`${ROMAN[i]}. ${titles[i]} — ${p.name}`} aria-pressed={i === shown} onClick={() => onSelect(i)}>
          <i className="hm-ring" /><b>{ROMAN[i]}</b><span>{p.name}</span>
        </button>
      ))}
    </div>
  );
}
