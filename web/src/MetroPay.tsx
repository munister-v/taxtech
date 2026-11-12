import { useEffect, useRef, useState, type CSSProperties } from 'react';
import qrcode from 'qrcode-generator';
import { api, type QrInvoice } from './city/cityApi';
import { chime } from './paySound';
import './metroPay.css';

// Line T, at every stop: the train stands, a phone with the TaxTech app scans the QR at a place by the exit,
// confirms with Face ID (3-D Secure at stop II), and the payment runs the bank's pipeline - the nine stops of the
// line are its nine mechanisms, lit one after another. "Pay it for real" turns the phone round: on its back is a
// live invoice (POST /api/city/qr) that any phone can scan and pay through /pay/<code> or the app.

export type MetroStop = { kind: string; title: string; text: string; proof: string };

// The place by each exit (a real venue of Roma Live, server/backend/assets/rome_city.json) and what it costs there.
const SPOTS: { venue: number; name: string; amount: number }[] = [
  { venue: 601, name: 'Antico Caffé San Pietro', amount: 180 },
  { venue: 749, name: 'La Fraschetta di Castel Sant Angelo', amount: 1240 },
  { venue: 1295, name: 'Pompi Navona', amount: 220 },
  { venue: 1205, name: 'Vitty al Pantheon', amount: 160 },
  { venue: 3281, name: 'Trinita Bar', amount: 380 },
  { venue: 2556, name: 'Trevi Cafe', amount: 240 },
  { venue: 2270, name: 'Bar Campidoglio', amount: 150 },
  { venue: 2139, name: 'La Biga al Colosseo', amount: 210 },
  { venue: 2067, name: 'Ad Hoc Circo Massimo', amount: 860 },
];
// What each mechanism writes to the log while the payment passes it.
const LOG: Record<string, (a: number) => string> = {
  passkey: () => 'assertion ✓ · UV = 1',
  tds: () => 'OTP 481 902 · token 300 s',
  idem: () => 'Idempotency-Key 7c1e…a4 → new',
  fraud: () => 'score 0.03 · Noisy-OR · allow',
  hold: a => `hold ${a} → capture ${a}`,
  atomic: a => `UPDATE … WHERE balance ≥ ${a}`,
  ledger: a => `DR ${a} · CR ${a} · Σ = 0`,
  chain: () => 'sha256(prev ‖ tx) = 9f3a…c21',
  receipt: () => 'TT-7K2M-9QDA-X4RP',
};
const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];
// Server time of each mechanism for one payment, ms (a trace of a local run); 3-D Secure only from 1000 TAX.
const SPAN: Record<string, number> = { passkey: 38, tds: 24, idem: 6, fraud: 22, hold: 9, atomic: 14, ledger: 7, chain: 5, receipt: 4 };
function trace(kinds: string[], amount: number) {
  let at = 0;
  const rows = kinds.map(k => {
    const skip = k === 'tds' && amount < 1000;
    const d = skip ? 0 : SPAN[k] ?? 5;
    const r = { kind: k, start: at, dur: d, skip };
    at += d;
    return r;
  });
  return { rows, total: at };
}
const START = 24000;
// The script of one stop, ms after the train has stopped: camera, lock on the code, invoice, Face ID, pipeline, paid.
const AT = [0, 700, 1900, 2500, 3500, 4900, 6700];
const fmt = (n: number) => n.toLocaleString('uk-UA', { maximumFractionDigits: 2 }).replace(/\s/g, ' ');
const romeTime = () => new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Rome', hour: '2-digit', minute: '2-digit' }).format(new Date());

function Qr({ text, className }: { text: string; className?: string }) {
  const q = qrcode(0, 'M');
  q.addData(text);
  q.make();
  const n = q.getModuleCount();
  let d = '';
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (q.isDark(r, c)) d += `M${c} ${r}h1v1h-1z`;
  return (
    <svg className={className} viewBox={`-2 -2 ${n + 4} ${n + 4}`} shapeRendering="crispEdges" aria-label="QR">
      <rect x={-2} y={-2} width={n + 4} height={n + 4} fill="#fff" /><path d={d} fill="#0b0c11" />
    </svg>
  );
}

const Mark = () => <img src="/icons/mark-white.svg" alt="" />;

type Real = (QrInvoice & { url: string; at: number }) | { status: 'creating' } | { status: 'error'; message: string };

export default function MetroPay({ stops, shown, target, going, photo, t, onPick, onHold }: {
  stops: MetroStop[]; shown: number; target: number; going: boolean; photo: (kind: string) => string;
  t: (uk: string, en: string) => string; onPick: (i: number) => void; onHold: (hold: boolean) => void;
}) {
  const root = useRef<HTMLDivElement | null>(null);
  const [seen, setSeen] = useState(false);
  const [ph, setPh] = useState(0);
  const [clock, setClock] = useState(romeTime);
  const [real, setReal] = useState<Real | null>(null);
  const [left, setLeft] = useState(0);
  const still = typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const spot = SPOTS[shown] ?? SPOTS[0];
  const stop = stops[shown];
  const tds = stop?.kind === 'tds';
  const spent = SPOTS.slice(0, shown).reduce((s, x) => s + x.amount, 0);
  const balBefore = START - spent, balAfter = balBefore - spot.amount;
  const flipped = !!real && real.status !== 'error' && real.status !== 'paid' && real.status !== 'declined';
  const paidReal = !!real && 'code' in real && real.status === 'paid';

  useEffect(() => {
    const el = root.current;
    if (!el) return;
    const io = new IntersectionObserver(([e]) => setSeen(e.isIntersecting), { threshold: 0.35 });
    io.observe(el);
    return () => io.disconnect();
  }, []);
  useEffect(() => { const id = window.setInterval(() => setClock(romeTime()), 20000); return () => clearInterval(id); }, []);

  // One run of the script per stop, once the train has stopped and the phone is on screen.
  // Scrolling the phone off and back on does not replay a stop that has already been paid.
  const ran = useRef(-1);
  useEffect(() => {
    if (going) { ran.current = -1; setPh(0); return; }
    if (still) { setPh(6); return; }
    if (!seen || flipped || paidReal || ran.current === shown) return;
    ran.current = shown;
    let done = false;
    setPh(0);
    const ids = AT.slice(1).map((ms, k) => window.setTimeout(() => {
      setPh(k + 1);
      if (k + 1 === 6) { done = true; chime(0.5); }
    }, ms));
    return () => { ids.forEach(clearTimeout); if (!done) ran.current = -1; };
  }, [shown, going, seen, still, flipped, paidReal]);

  // A live invoice: the line waits at this stop while the code is on screen, the status comes back every 1.5 s.
  const code = real && 'code' in real ? real.code : '', status = real?.status;
  useEffect(() => { onHold(flipped || paidReal); }, [flipped, paidReal]);
  useEffect(() => {
    if (!code || status !== 'pending') return;
    let alive = true;
    const iv = window.setInterval(async () => {
      try {
        const q = await api<QrInvoice>(`/api/city/qr/${code}`);
        if (!alive) return;
        setReal(o => (o && 'code' in o && o.code === q.code ? { ...o, ...q } : o));
        if (q.status === 'paid') { setPh(6); chime(0.7); }
      } catch { /* keep polling */ }
    }, 1500);
    const tick = window.setInterval(() => setReal(o => {
      if (!o || !('code' in o)) return o;
      const l = Math.max(0, o.expires_in - Math.floor((Date.now() - o.at) / 1000));
      setLeft(l);
      return l <= 0 && o.status === 'pending' ? { ...o, status: 'expired' } : o;
    }), 500);
    return () => { alive = false; clearInterval(iv); clearInterval(tick); };
  }, [code, status]);
  // after a real payment the paid screen stays a little, then the line goes on
  useEffect(() => {
    if (!paidReal) return;
    const id = window.setTimeout(() => setReal(null), 9000);
    return () => clearTimeout(id);
  }, [paidReal]);

  const payReal = async () => {
    setReal({ status: 'creating' });
    try {
      const q = await api<QrInvoice>('/api/city/qr', { venue: spot.venue, amount: spot.amount });
      setLeft(q.expires_in);
      setReal({ ...q, url: `${location.origin}/pay/${q.code}`, at: Date.now() });
    } catch (e) {
      setReal({ status: 'error', message: (e as Error).message });
    }
  };
  const cancelReal = () => {
    if (code && status === 'pending') api(`/api/city/qr/${code}/cancel`, {}).catch(() => {});
    setReal(null);
  };
  const tilt = (e: React.PointerEvent<HTMLDivElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width - 0.5, y = (e.clientY - r.top) / r.height - 0.5;
    e.currentTarget.style.setProperty('--ty', `${(x * 16).toFixed(1)}deg`);
    e.currentTarget.style.setProperty('--tx', `${(-y * 10).toFixed(1)}deg`);
  };
  const untilt = (e: React.PointerEvent<HTMLDivElement>) => { e.currentTarget.style.removeProperty('--ty'); e.currentTarget.style.removeProperty('--tx'); };

  const cls = ['mp', going ? 'go' : '', flipped ? 'flip' : '', paidReal ? 'real' : '', tds ? 'tds' : '', ...Array.from({ length: ph }, (_, k) => `p${k + 1}`)].join(' ');
  const bal = ph >= 6 || paidReal ? balAfter : balBefore;
  const live = real && 'code' in real ? real : null;

  return (
    <div className={cls} style={{ ['--photo' as string]: `url(${photo(stop?.kind || '')})` } as CSSProperties}>
      {/* ── the phone ── */}
      <div className="mp-col" ref={root} onPointerMove={tilt} onPointerLeave={untilt}>
        <div className="mp-phone">
          <div className="mp-face">
            <div className="mp-scr">
              <div className="mp-isl" />
              <div className="mp-bar"><b>{clock}</b><span><i /><i /><i /><i /></span></div>

              {/* home: balance, card, scan */}
              <div className="mp-home">
                <div className="mp-hi"><span className="mp-ava">TT</span><div><em>Buonasera</em><b>Giulia</b></div></div>
                <div className="mp-bal"><em>{t('Баланс', 'Balance')}</em><b>{fmt(bal)}<small> TAX</small></b></div>
                <div className="mp-card"><Mark /><span>•••• 2026</span></div>
                <div className="mp-acts">
                  <span className="mp-act on"><svg viewBox="0 0 24 24"><path d="M4 9V5a1 1 0 0 1 1-1h4M15 4h4a1 1 0 0 1 1 1v4M20 15v4a1 1 0 0 1-1 1h-4M9 20H5a1 1 0 0 1-1-1v-4M8 12h8" /></svg><em>{t('Сканувати', 'Scan')}</em></span>
                  <span className="mp-act"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg><em>{t('Переказ', 'Transfer')}</em></span>
                  <span className="mp-act"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg><em>{t('Поповнити', 'Top up')}</em></span>
                </div>
                <div className="mp-next">
                  <span className="mp-next-t">T</span>
                  <div><em>{going ? t('Далі', 'Next') : t('Вихід', 'Exit')}</em><b>{going ? stops[target] && `${ROMAN[target]} · ${stops[target].title}` : spot.name}</b></div>
                </div>
              </div>

              {/* camera on the code at the counter */}
              <div className="mp-cam">
                <div className="mp-feed" />
                <div className="mp-stand">
                  <span>{spot.name}</span>
                  <Qr className="mp-stand-qr" text="https://bank.munister.com.ua/roma" />
                  <b>{fmt(spot.amount)} TAX</b>
                </div>
                <div className="mp-find"><i /><i /><i /><i /><u /></div>
                <p className="mp-cam-hint">{t('Наведіть на QR-код', 'Point at the QR code')}</p>
              </div>

              {/* the sheet: invoice → Face ID / 3-D Secure → pipeline */}
              <div className="mp-sheet">
                <span className="mp-grab" />
                <div className="mp-inv">
                  <em>QR · {ROMAN[shown]} · {stop?.title}</em>
                  <h4>{spot.name}</h4>
                  <b className="mp-amt">{fmt(spot.amount)}<small> TAX</small></b>
                  <p><span>{t('Картка', 'Card')}</span><span>TaxTech •• 2026</span></p>
                  <span className="mp-btn"><svg viewBox="0 0 24 24"><path d="M7 3H5a2 2 0 0 0-2 2v2M17 3h2a2 2 0 0 1 2 2v2M7 21H5a2 2 0 0 1-2-2v-2M17 21h2a2 2 0 0 0 2-2v-2M9 9v1M15 9v1M12 9v4h-1M9 16c1.6 1.3 4.4 1.3 6 0" /></svg>{t('Сплатити', 'Pay')}</span>
                </div>
                <div className="mp-auth">
                  {tds ? (
                    <>
                      <em>3-D Secure</em>
                      <h4>{t('Одноразовий код', 'One-time code')}</h4>
                      <div className="mp-otp">{'481902'.split('').map((d, k) => <span key={k} style={{ ['--k' as string]: k }}>{d}</span>)}</div>
                    </>
                  ) : (
                    <>
                      <svg className="mp-faceid" viewBox="0 0 64 64"><path pathLength={1} d="M18 6H12a6 6 0 0 0-6 6v6M46 6h6a6 6 0 0 1 6 6v6M18 58h-6a6 6 0 0 1-6-6v-6M46 58h6a6 6 0 0 0 6-6v-6M23 24v4M41 24v4M32 24v13h-3M24 44c4.5 3.6 11.5 3.6 16 0" /></svg>
                      <h4>Face ID</h4>
                    </>
                  )}
                </div>
                <div className="mp-proc">
                  <div className="mp-ring">
                    {stops.map((s, k) => <i key={s.kind} className={k === shown ? 'cur' : ''} style={{ ['--k' as string]: k }} />)}
                    <b>{ROMAN[shown]}</b>
                  </div>
                  <h4>{t('Обробка', 'Processing')}</h4>
                  <code>{stop && LOG[stop.kind]?.(spot.amount)}</code>
                </div>
              </div>

              {/* paid */}
              <div className="mp-paid">
                <span className="mp-tick"><svg viewBox="0 0 24 24"><path pathLength={1} d="M5 12.5l4.5 4.5L19 7.5" /></svg></span>
                <h4>{paidReal ? t('Оплачено по-справжньому', 'Paid for real') : t('Оплачено', 'Paid')}</h4>
                <b className="mp-amt">−{fmt(spot.amount)}<small> TAX</small></b>
                <p>{spot.name}</p>
                <code>{paidReal && live ? `${live.who || 'TaxTech'} · ${live.auth_code || ''}` : LOG.receipt(0)}</code>
              </div>
              <div className="mp-push">
                <span className="mp-push-ic"><Mark /></span>
                <div><p><b>TaxTech</b><em>{t('зараз', 'now')}</em></p><p>{t('Списання', 'Debit')} <u>−{fmt(spot.amount)} TAX</u> · {spot.name}</p></div>
              </div>
              <div className="mp-glare" />
            </div>
          </div>

          {/* the back: a live code anyone can pay */}
          <div className="mp-back">
            <div className="mp-back-in">
              <span className="mp-back-mark"><Mark /> TaxTech · QR</span>
              <h4>{spot.name}</h4>
              <b className="mp-amt">{fmt(spot.amount)}<small> TAX</small></b>
              {live && live.status !== 'expired' ? (
                <a className="mp-real-qr" href={live.url} target="_blank" rel="noreferrer"><Qr text={live.url} /></a>
              ) : (
                <div className={`mp-real-qr ${real?.status === 'creating' ? 'wait' : 'gone'}`}>
                  {real?.status === 'creating' ? <span className="mp-spin" /> : <span>{t('Код сплив', 'Code expired')}</span>}
                </div>
              )}
              <p>{live?.status === 'expired' ? '' : t('Відскануйте камерою телефону', 'Scan with your phone camera')}</p>
              {live && live.status === 'pending' && <span className="mp-left">{Math.floor(left / 60)}:{String(left % 60).padStart(2, '0')}</span>}
              <div className="mp-back-acts">
                {live?.status === 'expired' && <button type="button" onClick={payReal}>{t('Новий код', 'New code')}</button>}
                <button type="button" className="ghost" onClick={cancelReal}>{t('Скасувати', 'Cancel')}</button>
              </div>
            </div>
          </div>
        </div>

        <div className="mp-under">
          <button type="button" className="mp-real-btn" onClick={payReal} disabled={flipped}>
            <svg viewBox="0 0 24 24"><path d="M4 9V5a1 1 0 0 1 1-1h4M15 4h4a1 1 0 0 1 1 1v4M20 15v4a1 1 0 0 1-1 1h-4M9 20H5a1 1 0 0 1-1-1v-4M7 8h3v3H7zM14 13h3v3h-3zM14 8h3v3M7 16h3" /></svg>
            {t('Оплатити по-справжньому', 'Pay it for real')}
          </button>
          {real?.status === 'error' && <p className="mp-err">{t('Не вдалося створити код', 'Could not create a code')} · {real.message}</p>}
          {live?.status === 'declined' && <p className="mp-err">{t('Відхилено', 'Declined')} · {live.response_code}</p>}
        </div>
      </div>

      {/* ── the line = the payment's trace: nine stops, nine mechanisms on one time axis ── */}
      <div className="mp-rail" role="group" aria-label={t('Шлях платежу', 'The path of a payment')}>
        {(() => {
          const { rows, total } = trace(stops.map(x => x.kind), spot.amount);
          const scale = Math.max(120, Math.ceil(total / 20) * 20);
          const ticks = Array.from({ length: scale / 20 + 1 }, (_, k) => k * 20);
          return (
            <div className="mp-trace" style={{ ['--total' as string]: total } as CSSProperties}>
              <div className="mp-tr-head">
                <span>{t('Платіж', 'Payment')} · {spot.name} · {fmt(spot.amount)} TAX</span>
                <b>{total} ms</b>
              </div>
              <div className="mp-tr-axis" aria-hidden>
                <span />
                <div>{ticks.map(v => <i key={v} style={{ left: `${(v / scale) * 100}%` }}>{v}</i>)}</div>
                <span />
              </div>
              {rows.map((r, k) => (
                <button key={r.kind} type="button" style={{ ['--k' as string]: k, ['--d' as string]: `${(r.start / Math.max(total, 1)) * 1.5}s` } as CSSProperties}
                  className={`mp-tr-row${k === shown ? ' cur' : ''}${k === target && going ? ' to' : ''}${r.skip ? ' skip' : ''}`} onClick={() => onPick(k)}>
                  <span className="mp-tr-name"><em>{ROMAN[k]}</em>{stops[k].title}</span>
                  <span className="mp-tr-track">
                    {ticks.map(v => <i key={v} style={{ left: `${(v / scale) * 100}%` }} />)}
                    {r.skip
                      ? <s style={{ left: `${(r.start / scale) * 100}%` }}>{t('не потрібно', 'not required')}</s>
                      : <u style={{ left: `${(r.start / scale) * 100}%`, width: `${(r.dur / scale) * 100}%` }} />}
                  </span>
                  <span className="mp-tr-ms">{r.skip ? '—' : `${r.dur} ms`}</span>
                </button>
              ))}
            </div>
          );
        })()}
        {stop && (
          <article className="mp-info" key={stop.kind} aria-live="polite">
            <div className="mp-info-h"><span>{ROMAN[shown]}</span><h3>{stop.title}</h3></div>
            <p>{stop.text}</p>
            <div className="mp-info-f"><span>{stop.proof}</span><code>{LOG[stop.kind]?.(spot.amount)}</code></div>
          </article>
        )}
      </div>
    </div>
  );
}
