import { useEffect, useMemo, useRef, useState } from 'react';
import romeUrl from './rome.json?url';
import { CATS, CAT_COLOR, CitySim, type Cat, type CityData, type ServerPay, type ServerStats, type Tx, type Venue } from './citySim';
import type { SceneApi } from './cityScene';
import { initialLandingLang, landingText, LANDING_LANGS, saveLandingLang, type LandingLang } from '../landingLang';
import './city.css';

// Roma Live (/roma). The city runs on the bank's server (server/backend/services/city_service.py) on Rome's real clock:
// every visitor sees the same payments, the same totals, the same roofs lit. A signed-in client pays a place with
// their real TaxTech account through the POS pipeline (3-D Secure from 1000 TAX) and the payment lands in their
// statement and on everyone's map. If the API cannot be reached the page falls back to a local simulation.
// CityPreview is the same city, held still, for the landing.

let dataP: Promise<CityData> | null = null;
export const loadCity = () => (dataP ??= fetch(romeUrl).then(r => r.json()));
const loadScene = () => import('./cityScene');

const fmt = (n: number) => Math.round(n).toLocaleString('uk-UA').replace(/\s/g, ' ');
const short = (n: number) => n >= 1e6 ? (n / 1e6).toFixed(n >= 1e7 ? 0 : 1).replace('.', ',') + ' M' : n >= 1e4 ? Math.round(n / 1e3) + ' k' : fmt(n);

const token = () => { try { return localStorage.getItem('army_bank_token') || ''; } catch { return ''; } };
type ApiErr = Error & { status?: number };
async function api<T>(path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const tk = token();
  if (tk) headers.Authorization = `Bearer ${tk}`;
  const r = await fetch(path, { method: body ? 'POST' : 'GET', credentials: 'include', headers, body: body ? JSON.stringify(body) : undefined });
  const j = await r.json().catch(() => null);
  if (!r.ok || !j?.ok) { const e: ApiErr = new Error(j?.error || String(r.status)); e.status = r.status; throw e; }
  return j.data as T;
}

type Live = { now: number; rome: string; hour: number; busy: number; day: string; stats: ServerStats; payments: ServerPay[]; last_id: number };

/** Follow the server's city: first snapshot, then a poll every 3 s and fresh roof heat every 30 s. Null if offline. */
async function follow(sim: CitySim): Promise<(() => void) | null> {
  try {
    const [live, ven] = await Promise.all([api<Live>('/api/city/live?since=0'), api<{ rev: Record<string, [number, number]> }>('/api/city/venues')]);
    sim.sync(live);
    sim.setRev(ven.rev);
    sim.ingest(live.payments, true);
    let last = live.last_id, busy = false, n = 0;
    const iv = window.setInterval(async () => {
      if (busy || document.hidden) return;
      busy = true;
      try {
        const d = await api<Live>(`/api/city/live?since=${last}`);
        sim.sync(d);
        sim.ingest(d.payments);
        last = d.last_id;
        if (++n % 10 === 0) sim.setRev((await api<{ rev: Record<string, [number, number]> }>('/api/city/venues')).rev);
      } catch { /* keep the last state */ }
      busy = false;
    }, 3000);
    return () => clearInterval(iv);
  } catch {
    return null;
  }
}

const CAT_NAME: Record<Cat, [string, string]> = {
  cafe: ['Кава', 'Coffee'], food: ['Їжа', 'Food'], bar: ['Бари', 'Bars'], shop: ['Крамниці', 'Shops'],
  stay: ['Готелі', 'Hotels'], culture: ['Культура', 'Culture'], money: ['Банки', 'Banks'], health: ['Аптеки', 'Pharmacy'],
};
const REASON: Record<NonNullable<Tx['reason']>, [string, string]> = {
  velocity: ['Частота', 'Velocity'], travel: ['Неможлива подорож', 'Impossible travel'], limit: ['Ліміт', 'Limit'], funds: ['Бракує коштів', 'No funds'],
};
const CHIPS: Record<Cat, number[]> = {
  cafe: [45, 90, 180], food: [420, 850, 1600], bar: [180, 340, 700], shop: [900, 2400, 6000], stay: [3800, 7200],
  culture: [380, 720], money: [1000, 3000], health: [160, 420],
};

type Me = { name: string; who: string; balance: number; card_id: number | null; card_last4: string | null; payments: ServerPay[] };
type Detail = { id: number; rev: number; n: number; hours: number[]; mix: Record<'res' | 'tou' | 'com' | 'user', number>; rank: number; of: number; last: ServerPay[] };
type PayRes = { outcome: 'approved' | 'declined' | 'sca_required'; approved: boolean; response_code?: string; message?: string; new_balance?: number; id?: number; auth_code?: string; rrn?: string; fee?: number; three_ds?: boolean };
type Tds = { venue: Venue; amount: number; challenge: string; otp: string; hint: string; phone?: string; busy?: boolean; err?: string };
type Flash = { ok: boolean; text: string; sub?: string };

const Ico = {
  city: <svg viewBox="0 0 24 24"><path d="M4 20V9l5-3v14M9 20V4l6 3v13M15 20v-9l5 2v7M3 20h18" /></svg>,
  live: <svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h10M4 17h13" /></svg>,
  tag: <svg viewBox="0 0 24 24"><path d="M4 12V5h7l9 9-7 7-9-9Z" /><circle cx="8" cy="9" r="1.2" /></svg>,
  home: <svg viewBox="0 0 24 24"><path d="M12 3v3M12 18v3M3 12h3M18 12h3" /><circle cx="12" cy="12" r="5" /></svg>,
  search: <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5" /><path d="m16 16 4.5 4.5" /></svg>,
};

// ── Landing preview ──
export function CityPreview({ onStats }: { onStats?: (s: { vol: number; n: number; clock: string; venues: number }) => void }) {
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let api: SceneApi | null = null, alive = true, iv = 0, stop: (() => void) | null = null;
    Promise.all([loadCity(), loadScene()]).then(async ([d, m]) => {
      if (!alive || !box.current) return;
      const sim = new CitySim(d);
      stop = await follow(sim);
      if (!alive || !box.current) { stop?.(); return; }
      if (!stop) { sim.minute = 12 * 60; sim.speed = 3; for (let i = 0; i < 200; i++) sim.step(1); }
      api = m.createCityScene(box.current, sim, { preview: true });
      box.current.classList.add('on');
      const tick = () => onStats?.({ vol: sim.stats.vol, n: sim.stats.n, clock: sim.clock(), venues: sim.venues.length });
      tick();
      iv = window.setInterval(tick, 3000);
    }).catch(() => {});
    return () => { alive = false; clearInterval(iv); stop?.(); api?.dispose(); };
  }, []);
  return <div className="cl-prev" ref={box} aria-hidden />;
}

function Bars({ data, now, color, peak }: { data: ArrayLike<number>; now?: number; color: string; peak?: boolean }) {
  const arr = Array.from(data), m = Math.max(1, ...arr), top = arr.indexOf(Math.max(...arr));
  return (
    <div className="cl-bars" style={{ ['--c' as string]: color }}>
      <div className="cl-bars-in">{arr.map((h, i) => <i key={i} className={`${i === now ? 'now' : ''}${peak && i === top && h > 0 ? ' peak' : ''}`} style={{ height: `${3 + (h / m) * 97}%` }} />)}</div>
      <div className="cl-bars-ax"><span>00</span><span>06</span><span>12</span><span>18</span><span>24</span></div>
    </div>
  );
}

// ── The full page ──
export default function CityLive() {
  const [lang, setLangS] = useState<LandingLang>(initialLandingLang);
  const t = (uk: string, en: string) => landingText(lang, uk, en);
  const box = useRef<HTMLDivElement>(null);
  const simRef = useRef<CitySim | null>(null);
  const apiRef = useRef<SceneApi | null>(null);
  const [ready, setReady] = useState(false);
  const [online, setOnline] = useState(false);
  const [, setTick] = useState(0);
  const [sel, setSel] = useState<Venue | null>(null);
  const [detail, setDetail] = useState<Detail | null>(null);
  const [on, setOn] = useState<Record<Cat, boolean>>(() => Object.fromEntries(CATS.map(c => [c, true])) as Record<Cat, boolean>);
  const [q, setQ] = useState('');
  const [searching, setSearching] = useState(false);
  const [labels, setLabels] = useState(true);
  const [me, setMe] = useState<Me | null | undefined>(undefined);  // undefined: still asking
  const [paying, setPaying] = useState(false);
  const [tds, setTds] = useState<Tds | null>(null);
  const [flash, setFlash] = useState<Flash | null>(null);
  const [panel, setPanel] = useState<'city' | 'feed' | null>(null);

  useEffect(() => { document.title = 'Roma Live · TaxTech'; }, []);

  useEffect(() => {
    let alive = true, stop: (() => void) | null = null;
    Promise.all([loadCity(), loadScene()]).then(async ([d, m]) => {
      if (!alive || !box.current) return;
      const sim = new CitySim(d);
      stop = await follow(sim);
      if (!alive || !box.current) { stop?.(); return; }
      if (!stop) { sim.minute = 9 * 60; sim.speed = 4; for (let i = 0; i < 60; i++) sim.step(1); }
      setOnline(!!stop);
      simRef.current = sim;
      apiRef.current = m.createCityScene(box.current, sim, { onPick: v => pickRef.current(v, false) });
      setReady(true);
    }).catch(() => {});
    const iv = window.setInterval(() => setTick(x => x + 1), 1000);
    return () => { alive = false; clearInterval(iv); stop?.(); apiRef.current?.dispose(); apiRef.current = null; };
  }, []);

  // who is looking: a signed-in client pays with their real account
  const loadMe = () => api<Me>('/api/city/me').then(m => {
    setMe(m);
    const s = simRef.current;
    if (s) { m.payments.forEach(p => s.mine.add(p.id)); if (!s.you) s.join(m.name || 'You', 0, 0, m.balance); s.you!.bal = m.balance; s.you!.id = m.who; }
  }).catch(() => setMe(null));
  useEffect(() => { if (ready) loadMe(); }, [ready]);

  useEffect(() => { if (simRef.current) { simRef.current.on = on; apiRef.current?.setCats(on); } }, [on, ready]);
  useEffect(() => { apiRef.current?.setLabels(labels); }, [labels, ready]);

  // the selected place, from the server, refreshed while it is open
  useEffect(() => {
    setDetail(null);
    if (!sel || !online) return;
    let alive = true;
    const get = () => api<Detail>(`/api/city/venue/${sel.i}`).then(d => { if (alive) setDetail(d); }).catch(() => {});
    get();
    const iv = window.setInterval(get, 6000);
    return () => { alive = false; clearInterval(iv); };
  }, [sel, online]);

  useEffect(() => {
    const k = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement)?.tagName === 'INPUT') { if (e.key === 'Escape') { setSearching(false); setQ(''); } return; }
      if (e.key === 'Escape') { pickRef.current(null); setPanel(null); setTds(null); }
      if (e.key === '/') { e.preventDefault(); setSearching(true); }
    };
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, []);

  const sim = simRef.current;
  const results = useMemo(() => (sim ? sim.search(q) : []), [q, sim]);

  const pick = (v: Venue | null, fly = true) => {
    setSel(v); apiRef.current?.select(v);
    if (v) apiRef.current?.flyTo(v.x, v.y, fly ? 420 : 520);
    setQ(''); setSearching(false); setTds(null);
    if (v) setPanel(p => (p === 'feed' ? null : p));
  };
  const pickRef = useRef(pick);
  pickRef.current = pick;
  const setLang = (l: LandingLang) => { setLangS(l); saveLandingLang(l); };

  const say = (f: Flash) => { setFlash(f); window.setTimeout(() => setFlash(x => (x === f ? null : x)), 3600); };

  const pay = async (v: Venue, amount: number, tdsSession?: string) => {
    const s = simRef.current;
    if (!s || !me || paying) return;
    setPaying(true);
    try {
      const from = s.you && s.you.x ? [s.you.x, s.you.y] : undefined;
      const r = await api<PayRes>('/api/city/pay', { venue: v.i, amount, card_id: me.card_id || undefined, tds_session: tdsSession, from });
      if (r.outcome === 'sca_required') {
        const ch = await api<{ challenge_id: string; demo_otp: string; masked_phone?: string }>('/api/3ds/challenge', { amount, recipient: `Roma · ${v.name}` });
        setTds({ venue: v, amount, challenge: ch.challenge_id, otp: '', hint: ch.demo_otp, phone: ch.masked_phone });
        return;
      }
      setTds(null);
      if (s.you) {
        // draw it right away; the poll will bring the same payment back and it is skipped by id
        const tx: Tx = { id: -Date.now(), t: Date.now() / 1000, acc: s.you, venue: v, amount, ok: r.approved, reason: r.approved ? undefined : r.response_code === '51' ? 'funds' : 'limit', fx: from ? from[0] : v.x - 140, fy: from ? from[1] : v.y - 90, fz: 1 };
        s.play(tx);
        if (r.approved) { s.you.x = v.x; s.you.y = v.y; }
      }
      if (r.approved) say({ ok: true, text: `${v.name} · −${fmt(amount)} TAX`, sub: `${t('Код', 'Auth')} ${r.auth_code} · RRN ${r.rrn}${r.three_ds ? ' · 3-D Secure' : ''}` });
      else say({ ok: false, text: `${t('Відхилено', 'Declined')} · ${r.response_code} ${r.message || ''}` });
      if (typeof r.new_balance === 'number') setMe(m => (m ? { ...m, balance: r.new_balance! } : m));
      loadMe();
    } catch (e) {
      const err = e as ApiErr;
      if (err.status === 401) setMe(null);
      say({ ok: false, text: err.message });
    } finally {
      setPaying(false);
    }
  };

  const confirmTds = async () => {
    if (!tds) return;
    setTds({ ...tds, busy: true, err: undefined });
    try {
      const v = await api<{ session_token: string }>('/api/3ds/verify', { challenge_id: tds.challenge, otp_code: tds.otp.trim() });
      await pay(tds.venue, tds.amount, v.session_token);
    } catch (e) {
      setTds(x => (x ? { ...x, busy: false, err: (e as Error).message } : x));
    }
  };

  const st = sim?.stats;
  const catTotal = st ? Math.max(1, ...CATS.map(c => st.byCat[c])) : 1;
  const top = sim && st && st.n ? sim.top(6) : [];
  const busy = sim ? sim.busy() : 0;
  const hour = sim?.hour();

  const venueCard = sel && sim && (() => {
    const rev = detail ? detail.rev : sel.rev, n = detail ? detail.n : sel.n;
    const mix = detail ? [detail.mix.res, detail.mix.tou, detail.mix.com, detail.mix.user] : [sel.mix[0], sel.mix[1], sel.mix[2], 0];
    const mixN = mix.reduce((a, b) => a + b, 0);
    const hours = detail ? detail.hours : sel.hours;
    const peak = Array.from(hours).reduce((b, h, i, a) => (h > a[b] ? i : b), 0);
    const last: { id: number; who: string; a: number; ok: boolean; r?: Tx['reason']; mine: boolean; real: boolean }[] = detail
      ? detail.last.map(p => ({ id: p.id, who: p.w, a: p.a, ok: p.ok, r: p.r, mine: sim.mine.has(p.id), real: p.k === 'user' }))
      : sel.last.map(x => ({ id: x.id, who: x.acc.id, a: x.amount, ok: x.ok, r: x.reason, mine: !!x.acc.you, real: !!x.acc.real }));
    return (
      <section className="cl-venue" style={{ ['--c' as string]: CAT_COLOR[sel.cat] }}>
        <button type="button" className="cl-x" aria-label={t('Закрити', 'Close')} onClick={() => pick(null)}>×</button>
        <span className="cl-v-kind"><i />{t(...CAT_NAME[sel.cat])}{sel.sub && sel.sub !== sel.cat ? ` · ${sel.sub.replace(/_/g, ' ')}` : ''}{sel.info.s ? ` · ${'★'.repeat(Math.min(5, parseInt(sel.info.s) || 0))}` : ''}</span>
        <h3>{sel.name}</h3>
        <dl className="cl-v-facts">
          {sel.info.a && <div><dt>{t('Адреса', 'Address')}</dt><dd>{sel.info.a}</dd></div>}
          {sel.rione && <div><dt>{t('Район', 'Rione')}</dt><dd>{sel.rione}</dd></div>}
          {sel.info.c && <div><dt>{t('Кухня', 'Cuisine')}</dt><dd>{sel.info.c}</dd></div>}
          {sel.info.h && <div><dt>{t('Години', 'Hours')}</dt><dd>{sel.info.h}</dd></div>}
        </dl>
        <div className="cl-v-kpi">
          <div><span>{t('Сьогодні', 'Today')}</span><b>{fmt(rev)}<small>TAX</small></b></div>
          <div><span>{t('Платежі', 'Payments')}</span><b>{n}</b></div>
          <div><span>{t('Середній чек', 'Avg ticket')}</span><b>{n ? fmt(rev / n) : '—'}</b></div>
        </div>
        {detail && detail.rank > 0 && <p className="cl-v-rank">#{detail.rank} {t('з', 'of')} {fmt(detail.of)} · {t(...CAT_NAME[sel.cat]).toLowerCase()} · {t('пік', 'peak')} {String(peak).padStart(2, '0')}:00</p>}
        <Bars data={hours} now={hour} color={CAT_COLOR[sel.cat]} peak />
        {mixN > 0 && (
          <div className="cl-mix">
            <div className="cl-mix-bar">{mix.map((x, i) => <i key={i} style={{ flex: x }} />)}</div>
            <div className="cl-mix-lg">
              <span>{t('Мешканці', 'Residents')} {Math.round((mix[0] / mixN) * 100)}%</span>
              <span>{t('Туристи', 'Tourists')} {Math.round((mix[1] / mixN) * 100)}%</span>
              <span>{t('Приїжджі', 'Commuters')} {Math.round((mix[2] / mixN) * 100)}%</span>
              {mix[3] > 0 && <span className="cl-real">{t('Клієнти', 'Clients')} {mix[3]}</span>}
            </div>
          </div>
        )}
        {last.length > 0 && (
          <ul className="cl-v-last">
            {last.slice(0, 5).map(x => <li key={x.id} className={`${x.ok ? '' : 'no'}${x.mine ? ' mine' : x.real ? ' real' : ''}`}><span>{x.mine ? t('Ви', 'You') : x.who}</span><em>{x.ok ? '' : t(...REASON[x.r || 'limit'])}</em><b>{fmt(x.a)}</b></li>)}
          </ul>
        )}
        {tds && tds.venue === sel ? (
          <form className="cl-tds" onSubmit={e => { e.preventDefault(); confirmTds(); }}>
            <span>3-D Secure · {fmt(tds.amount)} TAX</span>
            <p>{t('Код підтвердження', 'Confirmation code')}{tds.phone ? ` · ${tds.phone}` : ''} <em>{t('демо', 'demo')}: {tds.hint}</em></p>
            <div>
              <input autoFocus inputMode="numeric" maxLength={6} value={tds.otp} onChange={e => setTds({ ...tds, otp: e.target.value.replace(/\D/g, '') })} placeholder="••••••" />
              <button type="submit" className="cl-btn cl-btn-y" disabled={tds.otp.length < 6 || tds.busy}>{t('Підтвердити', 'Confirm')}</button>
            </div>
            {tds.err && <p className="cl-err">{tds.err}</p>}
          </form>
        ) : me ? (
          <div className="cl-pay">
            {CHIPS[sel.cat].map(a => <button key={a} type="button" disabled={paying || !online} onClick={() => pay(sel, a)}>{fmt(a)}{a >= 1000 ? <small>3DS</small> : null}</button>)}
          </div>
        ) : me === null ? (
          <a className="cl-btn cl-btn-y cl-wide" href="/#login">{t('Увійти, щоб платити', 'Sign in to pay')}</a>
        ) : null}
      </section>
    );
  })();

  return (
    <div className={`cl${ready ? ' ready' : ''}${panel ? ' p-' + panel : ''}${sel ? ' has-sel' : ''}`}>
      <div className="cl-map" ref={box} />
      {!ready && <div className="cl-load"><span>Roma</span><i /></div>}

      <header className="cl-top">
        <a className="cl-brand" href="/" aria-label="TaxTech"><img src="/icons/mark-white.svg" alt="" /><span>Roma <b>Live</b></span></a>
        <div className="cl-clock" title={online ? t('Римський час', 'Rome time') : t('Симуляція', 'Simulation')}>
          {online && <i className="cl-live-dot" />}
          <b>{sim?.clock() || '—'}</b>
          <span>{online ? t('Рим, наживо', 'Rome, live') : t('Симуляція', 'Simulation')}</span>
          <i className="cl-busy" style={{ ['--b' as string]: busy.toFixed(2) }} />
        </div>
        <div className="cl-top-r">
          <div className={`cl-search${searching ? ' open' : ''}`}>
            <button type="button" className="cl-ib" aria-label={t('Знайти місце', 'Find a place')} onClick={() => setSearching(s => !s)}>{Ico.search}</button>
            {searching && <input autoFocus value={q} onChange={e => setQ(e.target.value)} placeholder={t('Знайти місце', 'Find a place')} spellCheck={false} onBlur={() => !q && setSearching(false)} />}
            {results.length > 0 && (
              <div className="cl-res">{results.map(v => <button key={v.i} type="button" onMouseDown={e => e.preventDefault()} onClick={() => pick(v)} style={{ ['--c' as string]: CAT_COLOR[v.cat] }}><i /><span>{v.name}</span><em>{v.rione || t(...CAT_NAME[v.cat])}</em></button>)}</div>
            )}
          </div>
          <button type="button" className={`cl-ib${panel === 'city' ? ' on' : ''}`} aria-label={t('Місто', 'City')} title={t('Місто', 'City')} onClick={() => setPanel(p => (p === 'city' ? null : 'city'))}>{Ico.city}</button>
          <button type="button" className={`cl-ib${panel === 'feed' ? ' on' : ''}`} aria-label={t('Наживо', 'Live')} title={t('Наживо', 'Live')} onClick={() => { setPanel(p => (p === 'feed' ? null : 'feed')); if (sel) pick(null); }}>{Ico.live}</button>
          <button type="button" className={`cl-ib cl-hide-m${labels ? ' on' : ''}`} aria-label={t('Підписи', 'Labels')} title={t('Підписи', 'Labels')} onClick={() => setLabels(l => !l)}>{Ico.tag}</button>
          <button type="button" className="cl-ib cl-hide-m" aria-label={t('Весь Рим', 'All of Rome')} title={t('Весь Рим', 'All of Rome')} onClick={() => { pick(null); apiRef.current?.home(); }}>{Ico.home}</button>
          <div className="cl-lang">{LANDING_LANGS.map(l => <button key={l.id} type="button" className={lang === l.id ? 'on' : ''} onClick={() => setLang(l.id)}>{l.label}</button>)}</div>
          {me === null && <a className="cl-btn cl-btn-y" href="/#register">{t('Відкрити рахунок', 'Open account')}</a>}
        </div>
      </header>

      <aside className="cl-panel cl-panel-l" aria-hidden={panel !== 'city'}>
        <div className="cl-kpis">
          <div><span>{t('Оборот', 'Turnover')}</span><b>{short(st?.vol || 0)}<small>TAX</small></b></div>
          <div><span>{t('Платежі', 'Payments')}</span><b>{fmt(st?.n || 0)}</b></div>
          <div><span>{t('За хвилину', 'Per minute')}</span><b>{fmt(st?.perMin || 0)}</b></div>
          <div><span>{t('Середній чек', 'Avg ticket')}</span><b>{st?.n ? fmt(st.vol / st.n) : '—'}</b></div>
        </div>
        {sim && <Bars data={sim.cityHours} now={hour} color="#ffd400" />}
        <h4>{t('Категорії', 'Categories')}</h4>
        <div className="cl-cats">
          {CATS.map(c => (
            <button key={c} type="button" className={on[c] ? 'on' : ''} onClick={() => setOn(o => ({ ...o, [c]: !o[c] }))} style={{ ['--c' as string]: CAT_COLOR[c] }}>
              <i /><span>{t(...CAT_NAME[c])}</span><em>{short(st?.byCat[c] || 0)}</em>
              <u style={{ width: `${((st?.byCat[c] || 0) / catTotal) * 100}%` }} />
            </button>
          ))}
        </div>
        <h4>{t('Відхилено', 'Declined')} <b>{fmt(st?.declined || 0)}</b></h4>
        <div className="cl-reasons">
          {(Object.keys(REASON) as (keyof typeof REASON)[]).map(r => <div key={r}><span>{t(...REASON[r])}</span><b>{fmt(sim?.reasons[r] || 0)}</b></div>)}
        </div>
        {top.length > 0 && (
          <>
            <h4>{t('Лідери дня', 'Top today')}</h4>
            <div className="cl-top5">
              {top.map((v, i) => <button key={v.i} type="button" onClick={() => pick(v)} style={{ ['--c' as string]: CAT_COLOR[v.cat] }}><small>{i + 1}</small><span>{v.name}<em>{v.rione}</em></span><b>{short(v.rev)}</b></button>)}
            </div>
          </>
        )}
        <p className="cl-src">{fmt(sim?.venues.length || 0)} {t('місць', 'places')} · {fmt(sim?.D.b.length || 0)} {t('будівель', 'buildings')} · © OpenStreetMap</p>
      </aside>

      <aside className="cl-panel cl-panel-r" aria-hidden={panel !== 'feed'}>
        <h4><i className="cl-dot" />{t('Наживо', 'Live')}</h4>
        <ul className="cl-feed">
          {(sim?.feed || []).slice(0, 16).map(x => (
            <li key={x.id} className={`${x.ok ? '' : 'no'}${x.acc.you ? ' you' : x.acc.real ? ' real' : ''}`} style={{ ['--c' as string]: CAT_COLOR[x.venue.cat] }} onClick={() => pick(x.venue)}>
              <i />
              <div><b>{x.venue.name}</b><span>{x.acc.you ? t('Ви', 'You') : x.acc.id}{x.ok ? (x.venue.rione ? ` · ${x.venue.rione}` : '') : ` · ${t(...REASON[x.reason || 'limit'])}`}</span></div>
              <em>{x.ok ? '' : '✕ '}{fmt(x.amount)}</em>
            </li>
          ))}
        </ul>
      </aside>

      <div className="cl-card-wrap">{venueCard}</div>

      <footer className="cl-bottom">
        <div className="cl-strip">
          <span><small>{t('Оборот', 'Turnover')}</small><b>{short(st?.vol || 0)}</b></span>
          <span><small>{t('Платежі', 'Payments')}</small><b>{fmt(st?.n || 0)}</b></span>
          <span className="cl-red"><small>{t('Відхилено', 'Declined')}</small><b>{fmt(st?.declined || 0)}</b></span>
        </div>
        <div className="cl-you">
          {me ? (
            <a className="cl-me" href="/" title={t('Відкрити банк', 'Open the bank')}>
              <div><b>{me.name}</b><small>{me.card_last4 ? `•••• ${me.card_last4}` : me.who}{me.payments.length ? ` · ${me.payments.length} ${t('у місті сьогодні', 'in the city today')}` : ''}</small></div>
              <strong>{fmt(me.balance)}<small>TAX</small></strong>
            </a>
          ) : me === null ? (
            <a className="cl-btn cl-btn-glass" href="/#login">{t('Увійти', 'Sign in')}</a>
          ) : null}
          {flash && <div className={`cl-flash${flash.ok ? '' : ' no'}`}>{flash.text}{flash.sub && <small>{flash.sub}</small>}</div>}
        </div>
        <div className="cl-legend" aria-hidden>
          <small>{t('Оборот будівлі', 'Building turnover')}</small>
          <i />
          <div><span>0</span><span>{short(sim ? Math.max(20000, ...Array.from(sim.bRev)) : 0)}</span></div>
        </div>
      </footer>
    </div>
  );
}
