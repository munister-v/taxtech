import { useEffect, useRef, useState } from 'react';

// "Under the hood" map: the same night map of Rome as the hero (romeMapData.ts, loaded on demand), still, with nine pins.
// Each pin is one architectural feature of the bank, placed on its own landmark. The streets are painted once on a canvas;
// the pins are buttons positioned from the same projection.

type Data = typeof import('./romeMapData')['ROME'];

// One place per feature, in the order of HOOD in BankLanding. Coordinates are in map units of romeMapData (2400 × 1747).
export const HOOD_PLACES: { name: string; x: number; y: number; side: 'l' | 'r' }[] = [
  { name: 'Foro Romano', x: 1510, y: 1097, side: 'l' },
  { name: 'Circo Massimo', x: 1510, y: 1382, side: 'r' },
  { name: 'Fontana di Trevi', x: 1443, y: 721, side: 'r' },
  { name: 'Colosseo', x: 1740, y: 1200, side: 'r' },
  { name: 'Castel Sant’Angelo', x: 875, y: 623, side: 'r' },
  { name: 'Pantheon', x: 1230, y: 824, side: 'r' },
  { name: 'Piazza Navona', x: 1103, y: 797, side: 'l' },
  { name: 'San Pietro', x: 463, y: 663, side: 'r' },
  { name: 'Piazza di Spagna', x: 1427, y: 493, side: 'l' },
];
const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];
const X0 = 463, X1 = 1740, Y0 = 493, Y1 = 1382;

export default function HoodMap({ titles, active, onSelect }: { titles: string[]; active: number; onSelect: (i: number) => void }) {
  const wrap = useRef<HTMLDivElement | null>(null);
  const cvs = useRef<HTMLCanvasElement | null>(null);
  const [D, setD] = useState<Data | null>(null);
  const [box, setBox] = useState({ w: 0, h: 0 });

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

  // Projection shared by the canvas and the pins: fit the nine places with room for their labels, centred.
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
    stroke(D.minor, 'rgba(255,255,255,.17)', 0.7);
    stroke(D.mid, 'rgba(255,255,255,.3)', 1);
    stroke(D.major, 'rgba(255,226,140,.62)', 1.5);
  }, [D, box.w, box.h, sc, cx, cy]);

  return (
    <div className="hm" ref={wrap}>
      <canvas ref={cvs} className={`hm-cv${D ? ' on' : ''}`} aria-hidden />
      <div className="hm-vig" aria-hidden />
      {box.w > 0 && HOOD_PLACES.map((p, i) => (
        <button key={p.name} type="button" className={`hm-pin hm-${p.side}${i === active ? ' on' : ''}`}
          style={{ transform: `translate(${sx(p.x).toFixed(1)}px, ${sy(p.y).toFixed(1)}px)` }}
          aria-label={`${ROMAN[i]}. ${titles[i]} — ${p.name}`} aria-pressed={i === active} onClick={() => onSelect(i)}>
          <i className="hm-ring" /><b>{ROMAN[i]}</b><span>{p.name}</span>
        </button>
      ))}
    </div>
  );
}
