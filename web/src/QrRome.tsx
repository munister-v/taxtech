import { useEffect, useRef, useState } from 'react';
import qrcode from 'qrcode-generator';
import { chime } from './paySound';
import './qrRome.css';

// "Rome by QR code": the night map of Rome around a real café of Roma Live and a real invoice for it
// (POST /api/city/qr). Scanned with a phone it opens /pay/<code> - the TaxTech app takes it as a universal link,
// any other phone pays it in the browser. The page polls the invoice; once paid, a line of light runs from the
// phone to the place on the map, the place rings out, and the card shows who paid and the authorisation code.
// The payment is a real one of the bank: it is in the payer's statement and on everyone's map at /roma.

type Data = typeof import('./romeMapData')['ROME'];
type Inv = { code: string; name: string; rione: string; amount: number; status: string; expires_in: number; who?: string; auth_code?: string; three_ds?: boolean };

// Real places of Roma Live (server/backend/assets/rome_city.json: index, metres east/north of 41.8985 N 12.4765 E).
const SPOTS = [
  { v: 1205, x: 7, y: 120, a: 160 },
  { v: 2556, x: 606, y: 253, a: 240 },
  { v: 1295, x: -407, y: 73, a: 220 },
  { v: 2139, x: 1338, y: -773, a: 210 },
  { v: 2270, x: 363, y: -458, a: 150 },
  { v: 3281, x: 731, y: 728, a: 380 },
  { v: 601, x: -1345, y: 444, a: 180 },
];
// city metres → units of the street map (the same least-squares fit on the seven landmarks both maps share)
const toMap = (cx: number, cy: number) => ({ x: 0.43917 * cx + 0.011974 * cy + 1196.24, y: -0.404683 * cy + 828.49 });
const Z = 2.1, FY = 0.42;
const fmt = (n: number) => Math.round(n).toLocaleString('uk-UA').replace(/\s/g, ' ');
const ease = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

function Qr({ text }: { text: string }) {
  const q = qrcode(0, 'M');
  q.addData(text);
  q.make();
  const n = q.getModuleCount();
  let d = '';
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (q.isDark(r, c)) d += `M${c} ${r}h1v1h-1z`;
  return <svg viewBox={`-2 -2 ${n + 4} ${n + 4}`} shapeRendering="crispEdges" aria-label="QR"><rect x={-2} y={-2} width={n + 4} height={n + 4} fill="#fff" /><path d={d} fill="#0b0c11" /></svg>;
}

async function call<T>(path: string, body?: unknown): Promise<T> {
  const r = await fetch(path, { method: body ? 'POST' : 'GET', headers: body ? { 'Content-Type': 'application/json' } : undefined, body: body ? JSON.stringify(body) : undefined });
  const j = await r.json().catch(() => null);
  if (!r.ok || !j?.ok) throw new Error(j?.error || String(r.status));
  return j.data as T;
}

export default function QrRome({ t }: { t: (uk: string, en: string) => string }) {
  const sec = useRef<HTMLElement | null>(null);
  const box = useRef<HTMLDivElement | null>(null);
  const cvs = useRef<HTMLCanvasElement | null>(null);
  const [D, setD] = useState<Data | null>(null);
  const [near, setNear] = useState(false);
  const [seen, setSeen] = useState(false);
  const [spot, setSpot] = useState(() => Math.floor(Math.random() * SPOTS.length));
  const [inv, setInv] = useState<(Inv & { at: number }) | null>(null);
  const [err, setErr] = useState('');
  const [left, setLeft] = useState(0);
  const [busy, setBusy] = useState(false);
  const cam = useRef<{ x: number; y: number } | null>(null);
  const [size, setSize] = useState({ w: 600, h: 500 });
  const touch = typeof window !== 'undefined' && window.matchMedia('(pointer: coarse)').matches;
  const s = SPOTS[spot];
  const paid = inv?.status === 'paid';
  const url = inv ? `${location.origin}/pay/${inv.code}` : '';

  // load the map and the first code only when the section comes close
  useEffect(() => {
    const el = sec.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => { if (e.isIntersecting) setNear(true); setSeen(e.isIntersecting); }, { rootMargin: '400px 0px' });
    io.observe(el);
    return () => io.disconnect();
  }, []);
  useEffect(() => { if (near && !D) import('./romeMapData').then(m => setD(m.ROME)).catch(() => {}); }, [near]);

  const fresh = async (i: number) => {
    setBusy(true); setErr('');
    try {
      const q = await call<Inv>('/api/city/qr', { venue: SPOTS[i].v, amount: SPOTS[i].a });
      setInv({ ...q, at: Date.now() }); setLeft(q.expires_in);
    } catch (e) { setErr((e as Error).message); setInv(null); }
    setBusy(false);
  };
  useEffect(() => { if (near && !inv && !err) fresh(spot); }, [near]);
  const another = () => {
    if (inv?.status === 'pending') call(`/api/city/qr/${inv.code}/cancel`, {}).catch(() => {});
    const i = (spot + 1 + Math.floor(Math.random() * (SPOTS.length - 1))) % SPOTS.length;
    setSpot(i); fresh(i);
  };

  // the invoice comes back as paid within a couple of seconds of the phone's confirmation
  const code = inv?.code, status = inv?.status;
  useEffect(() => {
    if (!code || status !== 'pending' || !seen) return;
    let alive = true;
    const iv = window.setInterval(async () => {
      if (document.hidden) return;
      try {
        const q = await call<Inv>(`/api/city/qr/${code}`);
        if (!alive) return;
        setInv(o => (o && o.code === q.code ? { ...o, ...q } : o));
        if (q.status === 'paid') chime(0.8);
      } catch { /* keep polling */ }
    }, 2000);
    return () => { alive = false; clearInterval(iv); };
  }, [code, status, seen]);
  useEffect(() => {
    if (!inv || inv.status !== 'pending') return;
    const id = window.setInterval(() => {
      const l = Math.max(0, inv.expires_in - Math.floor((Date.now() - inv.at) / 1000));
      setLeft(l);
      if (l <= 0) setInv(o => (o ? { ...o, status: 'expired' } : o));
    }, 500);
    return () => clearInterval(id);
  }, [inv?.code, inv?.status]);

  // the map: streets on a canvas, centred on the place; the camera glides to a new place
  useEffect(() => {
    const el = box.current, canvas = cvs.current;
    if (!D || !el || !canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const layers = { river: new Path2D(D.river), minor: new Path2D(D.minor), mid: new Path2D(D.mid), major: new Path2D(D.major) };
    const to = toMap(s.x, s.y);
    const from = cam.current || to;
    const t0 = performance.now();
    let raf = 0;
    const draw = (now: number) => {
      const W = el.clientWidth, H = el.clientHeight;
      if (!W || !H) return;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      if (canvas.width !== Math.round(W * dpr) || canvas.height !== Math.round(H * dpr)) { canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr); }
      const k = ease(Math.min(1, (now - t0) / 1300));
      const cx = from.x + (to.x - from.x) * k, cy = from.y + (to.y - from.y) * k;
      cam.current = { x: cx, y: cy };
      const ppu = Math.max(W / D.w, H / D.h) * (W < 600 ? 1.5 : 1);
      const sc = ppu * Z, sw = 0.75 + 0.25 * Z, px = (n: number) => (n * sw) / sc;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.setTransform(dpr * sc, 0, 0, dpr * sc, dpr * (W / 2 - sc * cx), dpr * (H * FY - sc * cy));
      ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      const stroke = (p: Path2D, c: string, w: number) => { ctx.strokeStyle = c; ctx.lineWidth = px(w); ctx.stroke(p); };
      stroke(layers.river, 'rgba(90,135,225,.34)', 14);
      stroke(layers.minor, 'rgba(255,255,255,.13)', 0.8);
      stroke(layers.mid, 'rgba(255,255,255,.26)', 1.15);
      stroke(layers.major, 'rgba(240,210,140,.55)', 1.7);
      // a warm glow around the place
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const gl = ctx.createRadialGradient(W / 2, H * FY, 0, W / 2, H * FY, Math.min(W, H) * 0.45);
      gl.addColorStop(0, 'rgba(255,200,60,.16)'); gl.addColorStop(1, 'rgba(255,200,60,0)');
      ctx.fillStyle = gl; ctx.fillRect(0, 0, W, H);
      // the landmarks, for orientation
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.font = '600 10.5px -apple-system, "SF Pro Text", Inter, system-ui, sans-serif';
      for (const q of Object.values(D.pois)) {
        const x = W / 2 + sc * (q.x - cx), y = H * FY + sc * (q.y - cy);
        if (x < -40 || x > W + 40 || y < -20 || y > H + 20) continue;
        if (Math.hypot(x - W / 2, y - H * FY) < 70) continue; // the place's own label is there
        ctx.fillStyle = 'rgba(255,212,0,.55)';
        ctx.beginPath(); ctx.arc(x, y, 2.4, 0, 6.283); ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,.42)';
        ctx.fillText(q.name.toUpperCase(), x + 8, y + 3.5);
      }
      if (k < 1) raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    const ro = new ResizeObserver(() => { setSize({ w: el.clientWidth, h: el.clientHeight }); cancelAnimationFrame(raf); raf = requestAnimationFrame(draw); });
    ro.observe(el);
    return () => { cancelAnimationFrame(raf); ro.disconnect(); };
  }, [D, spot]);

  const state = paid ? 'paid' : !inv ? (err ? 'error' : 'wait') : inv.status === 'pending' ? 'open' : inv.status === 'declined' ? 'declined' : 'expired';

  return (
    <section id="qr" className={`qr is-${state}`} ref={sec}>
      <div className="bl-wrap qr-in">
        <div className="qr-map" ref={box} aria-hidden>
          <canvas ref={cvs} />
          <div className="qr-pin" key={`${spot}-${paid}`}><i /><i /><i /><b /><span>{inv?.name || ''}</span></div>
          <svg className="qr-fly" viewBox={`0 0 ${size.w} ${size.h}`} key={`f${paid}`}>
            <path d={`M${size.w / 2} ${size.h - 40} Q ${size.w * (spot % 2 ? 0.2 : 0.8)} ${size.h * (1 + FY) / 2} ${size.w / 2} ${size.h * FY}`} pathLength={1} />
          </svg>
          <div className="qr-phone"><i /></div>
        </div>

        <div className="qr-side">
          <h2 className="bl-h">{t('Рим за QR-кодом.', 'Rome by QR code.')}</h2>
          <div className="qr-card" aria-live="polite">
            {state === 'paid' && inv ? (
              <div className="qr-done">
                <span className="qr-tick"><svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg></span>
                <em>{t('Сплачено', 'Paid')}</em>
                <b className="qr-amt">−{fmt(inv.amount)} <small>TAX</small></b>
                <h3>{inv.name}</h3>
                <p>{inv.who || 'TaxTech'}{inv.auth_code ? ` · ${t('Код', 'Auth')} ${inv.auth_code}` : ''}{inv.three_ds ? ' · 3-D Secure' : ''}</p>
                <div className="qr-acts">
                  <a className="bl-pill" href="/roma">{t('Дивитися на карті', 'See it on the map')}</a>
                  <button type="button" className="bl-ghost" onClick={another}>{t('Ще раз', 'Again')}</button>
                </div>
              </div>
            ) : (
              <>
                <div className="qr-head">
                  <div><h3>{inv?.name || ' '}</h3><p>{inv ? `${inv.rione} · Roma` : ' '}</p></div>
                  <b className="qr-amt">{fmt(inv?.amount ?? s.a)} <small>TAX</small></b>
                </div>
                <a className={`qr-code${state === 'open' ? '' : ' off'}`} href={state === 'open' ? url : undefined} target="_blank" rel="noreferrer">
                  {state === 'open' ? <Qr text={url} /> : state === 'wait' ? <span className="qr-spin" /> : (
                    <span>{state === 'expired' ? t('Код сплив', 'Code expired') : state === 'declined' ? t('Відхилено', 'Declined') : t('Не вдалося створити код', 'Could not create a code')}</span>
                  )}
                </a>
                {state === 'open' && touch && <a className="bl-pill qr-open" href={url}>{t('Сплатити в застосунку', 'Pay in the app')}</a>}
                <p className="qr-hint">{t('Скануйте камерою телефону або в застосунку TaxTech.', 'Scan with your phone camera or in the TaxTech app.')}</p>
                <div className="qr-foot">
                  <span>{state === 'open' ? `${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}` : ''}</span>
                  <button type="button" onClick={state === 'open' || state === 'wait' ? another : () => fresh(spot)} disabled={busy}>
                    {state === 'open' || state === 'wait' ? t('Інше місце', 'Another place') : t('Новий код', 'New code')}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
