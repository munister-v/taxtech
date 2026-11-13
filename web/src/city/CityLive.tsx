import { useEffect, useMemo, useRef, useState } from 'react';
import qrcode from 'qrcode-generator';
import romeUrl from './rome.json?url';
import { CATS, CAT_COLOR, CitySim, type Cat, type CityData, type CityEvent, type ServerPay, type ServerShop, type ServerStats, type Tx, type Venue, type Weather } from './citySim';
import type { SceneApi } from './cityScene';
import { initialLandingLang, landingText, LANDING_LANGS, saveLandingLang, type LandingLang } from '../landingLang';
import { api, returnHere, type ApiErr, type Me, type MyShop, type PayRes, type QrInvoice } from './cityApi';
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

const afterLogin = () => returnHere('/roma');
// ?film=1: only the city, for recording the landing's hero video
const FILM = typeof location !== 'undefined' && new URLSearchParams(location.search).get('film') === '1';

type Live = { now: number; rome: string; hour: number; busy: number; day: string; stats: ServerStats; payments: ServerPay[]; last_id: number; weather?: Weather; events?: CityEvent[] };

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

/** A QR code as one SVG path (dark modules on a light tile, so any phone camera reads it) */
function QrSvg({ text }: { text: string }) {
  const q = qrcode(0, 'M');
  q.addData(text);
  q.make();
  const n = q.getModuleCount();
  let d = '';
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (q.isDark(r, c)) d += `M${c} ${r}h1v1h-1z`;
  return <svg className="cl-qr-svg" viewBox={`-2 -2 ${n + 4} ${n + 4}`} shapeRendering="crispEdges" aria-label="QR"><rect x={-2} y={-2} width={n + 4} height={n + 4} fill="#fff" /><path d={d} fill="#0b0c11" /></svg>;
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

const romeTime = (ts: number) => new Date(ts * 1000).toLocaleTimeString('it-IT', { timeZone: 'Europe/Rome', hour: '2-digit', minute: '2-digit' });
const evDist = (e: CityEvent, x: number, y: number) => Math.hypot(e.x - x, e.y - y);
/** WMO weather code -> a small icon */
const wIcon = (w: Weather) => w.rain || (w.code >= 51 && w.code < 100)
  ? <svg viewBox="0 0 24 24"><path d="M7 15a4 4 0 0 1 .5-8 5 5 0 0 1 9.6 1.5A3.5 3.5 0 0 1 17 15H7Z" /><path d="M9 18l-1 2M13 18l-1 2M17 18l-1 2" /></svg>
  : w.code >= 2 ? <svg viewBox="0 0 24 24"><path d="M7 17a4 4 0 0 1 .5-8 5 5 0 0 1 9.6 1.5A3.5 3.5 0 0 1 17 17H7Z" /></svg>
  : <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4" /><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6 7 7M17 17l1.4 1.4M5.6 18.4 7 17M17 7l1.4-1.4" /></svg>;
const SHOP_CATS: MyShop['cat'][] = ['cafe', 'food', 'bar', 'shop'];
const PRICES: [MyShop['price'], string, string][] = [['low', 'Дешевше', 'Cheaper'], ['fair', 'Звичайно', 'Fair'], ['high', 'Дорожче', 'Pricier']];
const OPEN_FEE = 2000;
type Draft = { b: number; x: number; y: number; z: number; rione: string; name: string; cat: MyShop['cat']; price: MyShop['price']; busy?: boolean; err?: string };

type Detail = { id: number; rev: number; n: number; hours: number[]; mix: Record<'res' | 'tou' | 'com' | 'user', number>; rank: number; of: number; last: ServerPay[] };
type Tds = { venue: Venue; amount: number; challenge: string; otp: string; hint: string; phone?: string; busy?: boolean; err?: string };
type Flash = { ok: boolean; text: string; sub?: string };

const Ico = {
  city: <svg viewBox="0 0 24 24"><path d="M4 20V9l5-3v14M9 20V4l6 3v13M15 20v-9l5 2v7M3 20h18" /></svg>,
  live: <svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h10M4 17h13" /></svg>,
  tag: <svg viewBox="0 0 24 24"><path d="M4 12V5h7l9 9-7 7-9-9Z" /><circle cx="8" cy="9" r="1.2" /></svg>,
  home: <svg viewBox="0 0 24 24"><path d="M12 3v3M12 18v3M3 12h3M18 12h3" /><circle cx="12" cy="12" r="5" /></svg>,
  search: <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5" /><path d="m16 16 4.5 4.5" /></svg>,
  store: <svg viewBox="0 0 24 24"><path d="M4 10v10h16V10M3 10l2-6h14l2 6M3 10c0 1.7 1.3 3 3 3s3-1.3 3-3c0 1.7 1.3 3 3 3s3-1.3 3-3c0 1.7 1.3 3 3 3s3-1.3 3-3M10 20v-5h4v5" /></svg>,
  qr: <svg viewBox="0 0 24 24"><path d="M4 9V5a1 1 0 0 1 1-1h4M15 4h4a1 1 0 0 1 1 1v4M20 15v4a1 1 0 0 1-1 1h-4M9 20H5a1 1 0 0 1-1-1v-4M8 8h3v3H8zM13 13h3v3h-3zM13 8h3M8 13v3h3" /></svg>,
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
  const [payMode, setPayMode] = useState<'card' | 'qr'>('card');
  const [ask, setAsk] = useState<{ venue: Venue; amount: number } | null>(null);     // confirm step before a card payment
  const [qr, setQr] = useState<(QrInvoice & { url: string; at: number }) | null>(null);
  const [flash, setFlash] = useState<Flash | null>(null);
  const [panel, setPanel] = useState<'city' | 'feed' | null>(null);
  // Il tuo locale: your own place on the map
  const [myShop, setMyShop] = useState<MyShop | null | undefined>(undefined);
  const [claiming, setClaiming] = useState(false);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [shopBusy, setShopBusy] = useState(false);
  const [shopsTick, setShopsTick] = useState(0);
  const myShopRef = useRef<MyShop | null>(null);
  myShopRef.current = myShop || null;

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
      // a sale in your own place: the till rings
      const sceneTx = sim.onTx;
      sim.onTx = tx => {
        sceneTx?.(tx);
        const mine = myShopRef.current;
        if (mine && tx.ok && tx.venue.i === mine.id) sayRef.current({ ok: true, text: `${mine.name} · +${fmt(tx.amount * (1 - mine.mdr))} TAX`, sub: tx.acc.real ? `${tx.acc.id} · ${t0('клієнт TaxTech', 'TaxTech client')}` : tx.acc.id });
      };
      setReady(true);
    }).catch(() => {});
    const iv = window.setInterval(() => setTick(x => x + 1), 1000);
    return () => { alive = false; clearInterval(iv); stop?.(); apiRef.current?.dispose(); apiRef.current = null; };
  }, []);

  // who is looking: a signed-in client pays with their real account
  const loadShops = () => api<ServerShop[]>('/api/city/shops').then(list => { simRef.current?.setShops(list); setShopsTick(x => x + 1); }).catch(() => {});
  const loadMyShop = () => api<MyShop | null>('/api/city/shop').then(setMyShop).catch(() => setMyShop(null));
  useEffect(() => {
    if (!ready || !online) return;
    loadShops();
    const iv = window.setInterval(loadShops, 60000);
    return () => clearInterval(iv);
  }, [ready, online]);
  useEffect(() => {
    if (!me) return;
    loadMyShop();
    const iv = window.setInterval(() => { if (!document.hidden) loadMyShop(); }, 15000);
    return () => clearInterval(iv);
  }, [!!me]);
  // what is on in town: tags on the map, refreshed with the clock
  const evKey = (simRef.current?.events || []).map(e => e.id + (e.on ? '1' : '0')).join(',');
  useEffect(() => {
    const s = simRef.current;
    if (!s || !apiRef.current) return;
    apiRef.current.setEvents(s.events.map(e => ({ x: e.x, y: e.y, on: e.on, text: e.on ? e.name : `${e.name} · ${romeTime(e.start)}` })));
  }, [evKey, ready]);
  // the gold tags over client places, yours and the one being opened
  useEffect(() => {
    const s = simRef.current;
    if (!s || !apiRef.current) return;
    apiRef.current.setShops([...s.shops.values()], myShop?.id ?? null, draft ? { x: draft.x, y: draft.y, z: draft.z, name: draft.name.trim() || t('Твій заклад', 'Your place') } : null);
  }, [shopsTick, myShop?.id, draft?.b, draft?.name, ready, lang]);

  const loadMe = () => api<Me>('/api/city/me').then(m => {
    setMe(m);
    const s = simRef.current;
    if (s) { m.payments.forEach(p => s.mine.add(p.id)); if (!s.you) s.join(m.name || 'You', 0, 0, m.balance); s.you!.bal = m.balance; s.you!.id = m.who; }
  }).catch(() => setMe(null));
  useEffect(() => { if (ready) loadMe(); }, [ready]);
  // not signed in on this screen: a QR for a phone is the way to pay
  useEffect(() => { if (me === null) setPayMode('qr'); }, [me]);

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
      if (e.key === 'Escape') { pickRef.current(null); setPanel(null); setTds(null); stopClaimRef.current(); }
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
    setQ(''); setSearching(false); setTds(null); setAsk(null);
    setQr(old => { if (old && old.status === 'pending') api(`/api/city/qr/${old.code}/cancel`, {}).catch(() => {}); return null; });
    if (v) setPanel(p => (p === 'feed' ? null : p));
  };
  const pickRef = useRef(pick);
  pickRef.current = pick;

  // Pay by QR, from the top bar: the place on screen (or a café of central Rome), the camera flies there and its
  // card opens straight on a live code. The landing's "See it on the map" lands here as /roma?venue=<id>, and
  // /roma?qr=1 opens on a code.
  const QR_CAFES = [1205, 2556, 1295, 2139, 2270, 3281, 601];
  const quickQr = (v?: Venue | null) => {
    const s = simRef.current;
    if (!s) return;
    const w = v || sel || s.venues[QR_CAFES[Math.floor(Math.random() * QR_CAFES.length)]];
    if (!w) return;
    setPanel(null);
    pick(w);
    setPayMode('qr');
    const chips = CHIPS[w.cat];
    showQr(w, chips[Math.min(1, chips.length - 1)]);
  };
  useEffect(() => {
    const s = simRef.current;
    if (!ready || !s) return;
    const u = new URLSearchParams(location.search);
    const id = Number(u.get('venue'));
    const v = u.has('venue') && Number.isInteger(id) ? s.at(id) || null : null;
    if (u.get('qr') === '1') quickQr(v);
    else if (v) pick(v);
    if (u.has('venue') || u.has('qr')) history.replaceState(null, '', location.pathname);
  }, [ready]);
  const setLang = (l: LandingLang) => { setLangS(l); saveLandingLang(l); };

  const say = (f: Flash) => { setFlash(f); window.setTimeout(() => setFlash(x => (x === f ? null : x)), 3600); };
  const sayRef = useRef(say);
  sayRef.current = say;
  const t0Ref = useRef(t);
  t0Ref.current = t;
  function t0(uk: string, en: string) { return t0Ref.current(uk, en); }

  // ── Il tuo locale ──
  const stopClaim = () => { setClaiming(false); setDraft(null); apiRef.current?.setClaim(null); };
  const stopClaimRef = useRef(stopClaim);
  stopClaimRef.current = stopClaim;
  const onClaim = (b: number) => {
    const s = simRef.current;
    if (!s) return;
    if (s.taken(b)) { sayRef.current({ ok: false, text: t0('Тут уже є заклад. Оберіть порожню будівлю', 'Taken. Choose an empty building') }); return; }
    const [x, y] = s.centre(b);
    setDraft(d => ({ b, x, y, z: s.heights[b] + 2, rione: s.rioneAt(x, y), name: d?.name || '', cat: d?.cat || 'cafe', price: d?.price || 'fair' }));
    apiRef.current?.flyTo(x, y, 380);
  };
  const startClaim = () => {
    if (myShop) { const v = simRef.current?.at(myShop.id); if (v) pick(v); return; }
    pick(null); setPanel(null); setClaiming(true); setDraft(null);
    apiRef.current?.setClaim(b => onClaim(b));
  };
  const openShop = async () => {
    if (!draft || draft.busy) return;
    setDraft({ ...draft, busy: true, err: undefined });
    try {
      const sh = await api<MyShop>('/api/city/shop', { b: draft.b, x: draft.x, y: draft.y, name: draft.name.trim(), cat: draft.cat, price: draft.price, rione: draft.rione });
      setMyShop(sh);
      stopClaim();
      await loadShops();
      const v = simRef.current?.at(sh.id);
      if (v) pick(v);
      say({ ok: true, text: `${sh.name} · ${t('відчинено', 'open')}`, sub: `${t('Ліцензія', 'Licence')} −${fmt(OPEN_FEE)} TAX` });
      loadMe();
    } catch (e) {
      setDraft(d => (d ? { ...d, busy: false, err: (e as Error).message } : d));
    }
  };
  const shopAction = async (path: string, body: unknown = {}) => {
    if (shopBusy) return;
    setShopBusy(true);
    try {
      const r = await api<MyShop | null>(path, body);
      setMyShop(r);
      return r;
    } catch (e) { say({ ok: false, text: (e as Error).message }); }
    finally { setShopBusy(false); }
  };
  const payout = async () => {
    const before = myShop?.payable || 0;
    if (await shopAction('/api/city/shop/payout')) { say({ ok: true, text: `${t('На рахунок', 'To your account')} +${fmt(before)} TAX`, sub: myShop?.name }); loadMe(); }
  };
  const closeShop = async () => {
    if (!myShop || !window.confirm(`${myShop.name}\n\n${t('Закрити заклад? Каса піде на рахунок, ліцензія не повертається.', 'Close the place? The till goes to your account, the licence is not refunded.')}`)) return;
    await shopAction('/api/city/shop/close');
    pick(null); await loadShops(); loadMe();
  };

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

  // QR: the screen shows a code, a phone confirms it (/pay/<code>), the status comes back here
  const showQr = async (v: Venue, amount: number) => {
    try {
      const q = await api<QrInvoice>('/api/city/qr', { venue: v.i, amount });
      setQr({ ...q, url: `${location.origin}/pay/${q.code}`, at: Date.now() });
    } catch (e) { say({ ok: false, text: (e as Error).message }); }
  };
  const qrCode = qr?.code, qrStatus = qr?.status;
  useEffect(() => {
    if (!qrCode || qrStatus !== 'pending') return;
    let alive = true;
    const iv = window.setInterval(async () => {
      try {
        const q = await api<QrInvoice>(`/api/city/qr/${qrCode}`);
        if (!alive) return;
        setQr(o => (o && o.code === q.code ? { ...o, ...q } : o));
        if (q.status === 'paid' || q.status === 'declined') {
          const s = simRef.current, v = s?.at(q.venue);
          if (s && v && q.status === 'paid') {
            apiRef.current?.flyTo(v.x, v.y, 300);
            // the phone's payment flies in from the street in front of the place
            s.play({ id: -Date.now(), t: Date.now() / 1000, acc: { i: -1, id: q.who || 'TaxTech', kind: 'resident', hx: 0, hy: 0, x: 0, y: 0, lastT: 0, recent: [], bal: 0, real: true }, venue: v, amount: q.amount, ok: true, fx: v.x - 160, fy: v.y - 110, fz: 1 });
          }
          say(q.status === 'paid'
            ? { ok: true, text: `QR · ${q.name} · −${fmt(q.amount)} TAX`, sub: `${t('Код', 'Auth')} ${q.auth_code} · RRN ${q.rrn}${q.three_ds ? ' · 3-D Secure' : ''}` }
            : { ok: false, text: `QR · ${t('Відхилено', 'Declined')} · ${q.response_code}` });
          if (me) loadMe();
        }
      } catch { /* keep polling */ }
    }, 1500);
    return () => { alive = false; clearInterval(iv); };
  }, [qrCode, qrStatus]);
  const qrLeft = qr ? Math.max(0, qr.expires_in - Math.floor((Date.now() - qr.at) / 1000)) : 0;

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
  const top = panel === 'city' && sim && st && st.n ? sim.top(6) : [];
  let bMax = 20000;
  if (sim) for (let i = 0; i < sim.bRev.length; i++) if (sim.bRev[i] > bMax) bMax = sim.bRev[i];
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
        {sel.own && <p className="cl-v-own">{myShop && sel.i === myShop.id ? t('Ваш заклад', 'Your place') : `${t('Власник', 'Owner')} ${sel.own.owner}`} · {t('з', 'since')} {new Date(sel.own.since * 1000).toLocaleDateString({ uk: 'uk-UA', en: 'en-GB', it: 'it-IT', de: 'de-DE', ru: 'ru-RU' }[lang] || 'en-GB', { day: 'numeric', month: 'short' })}</p>}
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
        {myShop && sel.i === myShop.id && (
          <div className="cl-own">
            <div className="cl-own-till">
              <div><span>{t('Каса', 'Till')}</span><b>{fmt(myShop.till_real + myShop.till_sim)}<small>TAX</small></b></div>
              <button type="button" className="cl-btn cl-btn-y" disabled={shopBusy || myShop.payable <= 0} onClick={payout}>{t('На рахунок', 'To account')} {myShop.payable > 0 ? fmt(myShop.payable) : ''}</button>
            </div>
            <div className="cl-own-row"><span>{t('Ціна', 'Prices')}</span>
              <div className="cl-seg">{PRICES.map(([k, uk, en]) => <button key={k} type="button" className={myShop.price === k ? 'on' : ''} disabled={shopBusy} onClick={() => myShop.price !== k && shopAction('/api/city/shop/price', { price: k })}>{t(uk, en)}</button>)}</div>
            </div>
            {sim && sim.events.filter(e => evDist(e, myShop.x, myShop.y) < e.r + 700).slice(0, 2).map(e => (
              <div key={e.id + e.start} className={`cl-own-evt${e.on ? ' on' : ''}`}><i /><span>{e.name}</span><em>{e.on ? t('зараз', 'now') : romeTime(e.start)} · {fmt(evDist(e, myShop.x, myShop.y))} m</em></div>
            ))}
            <div className="cl-own-row"><span>{t('Виведено всього', 'Paid out')}</span><b>{fmt(myShop.paid_total)} TAX</b></div>
            <button type="button" className="cl-link" onClick={closeShop}>{t('Закрити заклад', 'Close the place')}</button>
          </div>
        )}
        {!(myShop && sel.i === myShop.id) && <div className="cl-paymode" role="tablist">
          <button type="button" role="tab" aria-selected={payMode === 'card'} className={payMode === 'card' ? 'on' : ''} onClick={() => { setPayMode('card'); setQr(null); }}>{t('Карткою', 'Card')}</button>
          <button type="button" role="tab" aria-selected={payMode === 'qr'} className={payMode === 'qr' ? 'on' : ''} onClick={() => { setPayMode('qr'); setAsk(null); setTds(null); }}>QR</button>
        </div>}
        {payMode === 'qr' || (myShop && sel.i === myShop.id) ? (
          qr && qr.venue === sel.i ? (
            <div className={`cl-qr is-${qr.status}`}>
              {qr.status === 'pending' || qr.status === 'processing' ? (
                <>
                  <a href={qr.url} target="_blank" rel="noreferrer" className="cl-qr-tile"><QrSvg text={qr.url} /></a>
                  <div className="cl-qr-side">
                    <b>{fmt(qr.amount)} <small>TAX</small></b>
                    <span>{t('Скануйте телефоном і підтвердьте', 'Scan with a phone and confirm')}</span>
                    <em>{qr.status === 'processing' ? t('Підтверджується…', 'Confirming…') : `${Math.floor(qrLeft / 60)}:${String(qrLeft % 60).padStart(2, '0')}`}</em>
                    <button type="button" className="cl-link" onClick={() => { api(`/api/city/qr/${qr.code}/cancel`, {}).catch(() => {}); setQr(null); }}>{t('Скасувати', 'Cancel')}</button>
                  </div>
                </>
              ) : (
                <div className="cl-qr-done">
                  <b>{qr.status === 'paid' ? `✓ ${t('Оплачено', 'Paid')}` : qr.status === 'declined' ? `✕ ${t('Відхилено', 'Declined')}` : t('Час вийшов', 'Expired')}</b>
                  {qr.auth_code && <span>{t('Код', 'Auth')} {qr.auth_code} · RRN {qr.rrn}</span>}
                  <button type="button" className="cl-link" onClick={() => setQr(null)}>{t('Новий код', 'New code')}</button>
                </div>
              )}
            </div>
          ) : (
            <div className="cl-pay">
              {CHIPS[sel.cat].map(a => <button key={a} type="button" disabled={!online} onClick={() => showQr(sel, a)}>{fmt(a)}</button>)}
            </div>
          )
        ) : tds && tds.venue === sel ? (
          <form className="cl-tds" onSubmit={e => { e.preventDefault(); confirmTds(); }}>
            <span>3-D Secure · {fmt(tds.amount)} TAX</span>
            <p>{t('Код підтвердження', 'Confirmation code')}{tds.phone ? ` · ${tds.phone}` : ''} <em>{t('демо', 'demo')}: {tds.hint}</em></p>
            <div>
              <input autoFocus inputMode="numeric" maxLength={6} value={tds.otp} onChange={e => setTds({ ...tds, otp: e.target.value.replace(/\D/g, '') })} placeholder="••••••" />
              <button type="submit" className="cl-btn cl-btn-y" disabled={tds.otp.length < 6 || tds.busy}>{t('Підтвердити', 'Confirm')}</button>
            </div>
            {tds.err && <p className="cl-err">{tds.err}</p>}
          </form>
        ) : me && ask && ask.venue === sel ? (
          <div className="cl-ask">
            <div className="cl-ask-row"><span>{t('Сума', 'Amount')}</span><b>{fmt(ask.amount)} TAX</b></div>
            <div className="cl-ask-row"><span>{t('З рахунку', 'From')}</span><b>{me.card_last4 ? `•••• ${me.card_last4}` : me.who} · {fmt(me.balance)}</b></div>
            {ask.amount >= 1000 && <div className="cl-ask-row"><span>SCA</span><b>3-D Secure</b></div>}
            <div className="cl-ask-btns">
              <button type="button" className="cl-btn cl-btn-glass" onClick={() => setAsk(null)}>{t('Скасувати', 'Cancel')}</button>
              <button type="button" className="cl-btn cl-btn-y" disabled={paying} onClick={() => { const a = ask; setAsk(null); pay(a.venue, a.amount); }}>{paying ? '…' : t('Підтвердити', 'Confirm')}</button>
            </div>
          </div>
        ) : me ? (
          <div className="cl-pay">
            {CHIPS[sel.cat].map(a => <button key={a} type="button" disabled={paying || !online} onClick={() => setAsk({ venue: sel, amount: a })}>{fmt(a)}{a >= 1000 ? <small>3DS</small> : null}</button>)}
          </div>
        ) : me === null ? (
          <a className="cl-btn cl-btn-y cl-wide" href="/#login" onClick={afterLogin}>{t('Увійти, щоб платити', 'Sign in to pay')}</a>
        ) : null}
      </section>
    );
  })();

  return (
    <div className={`cl${FILM ? ' cl-film' : ''}${ready ? ' ready' : ''}${panel ? ' p-' + panel : ''}${sel || draft ? ' has-sel' : ''}`}>
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
        {sim?.weather && sim.weather.t != null && (
          <div className={`cl-wx${sim.weather.rain ? ' rain' : ''}`} title={`Roma · ${Math.round(sim.weather.t)}°`}>{wIcon(sim.weather)}<b>{Math.round(sim.weather.t)}°</b></div>
        )}
        <div className="cl-top-r">
          <button type="button" className="cl-qrbtn" onClick={() => quickQr()} disabled={!ready || !online} title={t('Оплатити за QR-кодом', 'Pay by QR code')}>
            {Ico.qr}<span>{t('Оплатити за QR-кодом', 'Pay by QR code')}</span>
          </button>
          <button type="button" className={`cl-shopbtn${myShop ? ' has' : ''}${claiming ? ' on' : ''}`} onClick={() => (claiming ? stopClaim() : startClaim())} disabled={!ready || !online} title={myShop ? myShop.name : t('Відкрити свій заклад', 'Open your own place')}>
            {Ico.store}<span>{myShop ? myShop.name : t('Свій заклад', 'Your place')}</span>
          </button>
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
          {me === null && <a className="cl-btn cl-btn-y" href="/#register" onClick={afterLogin}>{t('Відкрити рахунок', 'Open account')}</a>}
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
        {sim && sim.events.length > 0 && (
          <>
            <h4>{t('Події', 'Events')}</h4>
            <div className="cl-evts">
              {sim.events.map(e => (
                <button key={e.id + e.start} type="button" className={e.on ? 'on' : ''} onClick={() => { pick(null); apiRef.current?.flyTo(e.x, e.y, 900); }}>
                  <i /><span>{e.name}</span><em>{e.on ? t('зараз', 'now') : romeTime(e.start)}</em>
                </button>
              ))}
            </div>
          </>
        )}
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

      <div className="cl-card-wrap">{draft ? (
        <section className="cl-venue cl-draft" style={{ ['--c' as string]: CAT_COLOR[draft.cat] }}>
          <button type="button" className="cl-x" aria-label={t('Скасувати', 'Cancel')} onClick={stopClaim}>×</button>
          <span className="cl-v-kind"><i />{t('Новий заклад', 'New place')}{draft.rione ? ` · ${draft.rione}` : ''}</span>
          <input className="cl-draft-name" autoFocus maxLength={40} value={draft.name} placeholder={t('Назва', 'Name')} onChange={e => setDraft({ ...draft, name: e.target.value, err: undefined })} spellCheck={false} />
          <div className="cl-draft-cats">{SHOP_CATS.map(c => <button key={c} type="button" className={draft.cat === c ? 'on' : ''} style={{ ['--c' as string]: CAT_COLOR[c] }} onClick={() => setDraft({ ...draft, cat: c })}><i />{t(...CAT_NAME[c])}</button>)}</div>
          <div className="cl-own-row"><span>{t('Ціна', 'Prices')}</span>
            <div className="cl-seg">{PRICES.map(([k, uk, en]) => <button key={k} type="button" className={draft.price === k ? 'on' : ''} onClick={() => setDraft({ ...draft, price: k })}>{t(uk, en)}</button>)}</div>
          </div>
          <div className="cl-ask">
            <div className="cl-ask-row"><span>{t('Ліцензія', 'Licence')}</span><b>{fmt(OPEN_FEE)} TAX</b></div>
            {me && <div className="cl-ask-row"><span>{t('З рахунку', 'From')}</span><b>{me.card_last4 ? `•••• ${me.card_last4}` : me.who} · {fmt(me.balance)}</b></div>}
            {draft.err && <p className="cl-err">{draft.err}</p>}
            {me ? (
              <div className="cl-ask-btns">
                <button type="button" className="cl-btn cl-btn-glass" onClick={stopClaim}>{t('Скасувати', 'Cancel')}</button>
                <button type="button" className="cl-btn cl-btn-y" disabled={draft.busy || draft.name.trim().length < 2} onClick={openShop}>{draft.busy ? '…' : t('Відчинити', 'Open the place')}</button>
              </div>
            ) : <a className="cl-btn cl-btn-y cl-wide" href="/#login" onClick={afterLogin}>{t('Увійти, щоб відчинити', 'Sign in to open')}</a>}
          </div>
        </section>
      ) : venueCard}</div>
      {claiming && !draft && (
        <div className="cl-claim"><span>{t('Торкніться порожньої будівлі', 'Tap an empty building')}</span><button type="button" className="cl-link" onClick={stopClaim}>{t('Скасувати', 'Cancel')}</button></div>
      )}

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
            <a className="cl-btn cl-btn-glass" href="/#login" onClick={afterLogin}>{t('Увійти', 'Sign in')}</a>
          ) : null}
          {flash && <div className={`cl-flash${flash.ok ? '' : ' no'}`}>{flash.text}{flash.sub && <small>{flash.sub}</small>}</div>}
        </div>
        <div className="cl-legend" aria-hidden>
          <small>{t('Оборот будівлі', 'Building turnover')}</small>
          <i />
          <div><span>0</span><span>{short(bMax)}</span></div>
        </div>
      </footer>
    </div>
  );
}
