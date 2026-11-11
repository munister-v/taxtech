import { useEffect, useMemo, useRef, useState } from 'react';
import romeUrl from './rome.json?url';
import { CATS, CAT_COLOR, CitySim, type Cat, type CityData, type Tx, type Venue } from './citySim';
import type { SceneApi } from './cityScene';
import { initialLandingLang, landingText, LANDING_LANGS, saveLandingLang, type LandingLang } from '../landingLang';
import './city.css';

// Roma Live (/roma): the bank turned into a city. Real places from OpenStreetMap, simulated accounts paying them,
// the visitor's own account among them. The map is the page: panels stay closed until asked for.
// CityPreview is the same city, hands-off, for the landing.

let dataP: Promise<CityData> | null = null;
export const loadCity = () => (dataP ??= fetch(romeUrl).then(r => r.json()));
const loadScene = () => import('./cityScene');

const fmt = (n: number) => Math.round(n).toLocaleString('uk-UA').replace(/\s/g, ' ');
const short = (n: number) => n >= 1e6 ? (n / 1e6).toFixed(n >= 1e7 ? 0 : 1).replace('.', ',') + ' M' : n >= 1e4 ? Math.round(n / 1e3) + ' k' : fmt(n);

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

const YOU_KEY = 'roma-live-you';
type YouSave = { name: string; id?: string; bal: number; x: number; y: number; n: number; spent: number };
const readYou = (): YouSave | null => { try { return JSON.parse(localStorage.getItem(YOU_KEY) || 'null'); } catch { return null; } };

const Ico = {
  city: <svg viewBox="0 0 24 24"><path d="M4 20V9l5-3v14M9 20V4l6 3v13M15 20v-9l5 2v7M3 20h18" /></svg>,
  live: <svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h10M4 17h13" /></svg>,
  tag: <svg viewBox="0 0 24 24"><path d="M4 12V5h7l9 9-7 7-9-9Z" /><circle cx="8" cy="9" r="1.2" /></svg>,
  home: <svg viewBox="0 0 24 24"><path d="M12 3v3M12 18v3M3 12h3M18 12h3" /><circle cx="12" cy="12" r="5" /></svg>,
  search: <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5" /><path d="m16 16 4.5 4.5" /></svg>,
  play: <svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>,
  pause: <svg viewBox="0 0 24 24"><path d="M7 5h3.5v14H7zM13.5 5H17v14h-3.5z" /></svg>,
};

// ── Landing preview ──
export function CityPreview({ onStats }: { onStats?: (s: { vol: number; n: number; clock: string; venues: number }) => void }) {
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let api: SceneApi | null = null, alive = true, iv = 0;
    Promise.all([loadCity(), loadScene()]).then(([d, m]) => {
      if (!alive || !box.current) return;
      const sim = new CitySim(d);
      sim.minute = 9 * 60; sim.speed = 3; sim.rate = 1.2;
      for (let i = 0; i < 200; i++) sim.step(1);
      api = m.createCityScene(box.current, sim, { preview: true });
      box.current.classList.add('on');
      iv = window.setInterval(() => onStats?.({ vol: sim.stats.vol, n: sim.stats.n, clock: sim.clock(), venues: sim.venues.length }), 1000);
    }).catch(() => {});
    return () => { alive = false; clearInterval(iv); api?.dispose(); };
  }, []);
  return <div className="cl-prev" ref={box} aria-hidden />;
}

function Bars({ data, now, color, peak }: { data: Float32Array; now?: number; color: string; peak?: boolean }) {
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
  const [, setTick] = useState(0);
  const [sel, setSel] = useState<Venue | null>(null);
  const [speed, setSpeed] = useState(4);
  const [paused, setPaused] = useState(false);
  const [on, setOn] = useState<Record<Cat, boolean>>(() => Object.fromEntries(CATS.map(c => [c, true])) as Record<Cat, boolean>);
  const [q, setQ] = useState('');
  const [searching, setSearching] = useState(false);
  const [labels, setLabels] = useState(true);
  const [joinName, setJoinName] = useState('');
  const [joining, setJoining] = useState(false);
  const [flash, setFlash] = useState<Tx | null>(null);
  const [panel, setPanel] = useState<'city' | 'feed' | null>(null);

  useEffect(() => { document.title = 'Roma Live · TaxTech'; }, []);

  useEffect(() => {
    let alive = true;
    Promise.all([loadCity(), loadScene()]).then(([d, m]) => {
      if (!alive || !box.current) return;
      const sim = new CitySim(d);
      sim.minute = 7 * 60; sim.speed = 4;
      for (let i = 0; i < 60; i++) sim.step(1);
      const s = readYou();
      if (s?.name) { const a = sim.join(s.name, s.x, s.y, s.bal); if (s.id) a.id = s.id; }
      simRef.current = sim;
      apiRef.current = m.createCityScene(box.current, sim, { onPick: v => pickRef.current(v, false) });
      setReady(true);
    }).catch(() => {});
    const iv = window.setInterval(() => setTick(x => x + 1), 700);
    return () => { alive = false; clearInterval(iv); apiRef.current?.dispose(); apiRef.current = null; };
  }, []);

  useEffect(() => { if (simRef.current) simRef.current.speed = paused ? 0 : speed; }, [speed, paused, ready]);
  useEffect(() => { if (simRef.current) { simRef.current.on = on; apiRef.current?.setCats(on); } }, [on, ready]);
  useEffect(() => { apiRef.current?.setLabels(labels); }, [labels, ready]);
  useEffect(() => {
    const k = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement)?.tagName === 'INPUT') { if (e.key === 'Escape') { setSearching(false); setQ(''); } return; }
      if (e.key === 'Escape') { pickRef.current(null); setPanel(null); }
      if (e.key === ' ') { e.preventDefault(); setPaused(p => !p); }
      if (e.key === '/') { e.preventDefault(); setSearching(true); }
    };
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, []);

  const sim = simRef.current;
  const you = sim?.you || null;
  const results = useMemo(() => (sim ? sim.search(q) : []), [q, sim]);

  const pick = (v: Venue | null, fly = true) => {
    setSel(v); apiRef.current?.select(v);
    if (v) apiRef.current?.flyTo(v.x, v.y, fly ? 420 : 520);
    setQ(''); setSearching(false);
    if (v) setPanel(p => (p === 'feed' ? null : p));
  };
  const pickRef = useRef(pick);
  pickRef.current = pick;
  const setLang = (l: LandingLang) => { setLangS(l); saveLandingLang(l); };

  const persist = (extra?: { n: number; spent: number }) => {
    const a = simRef.current?.you;
    if (!a) return;
    const prev = readYou();
    try { localStorage.setItem(YOU_KEY, JSON.stringify({ name: a.name, id: a.id, bal: a.bal, x: a.x, y: a.y, n: (prev?.n || 0) + (extra?.n || 0), spent: (prev?.spent || 0) + (extra?.spent || 0) })); } catch { /* ignore */ }
  };
  const join = () => {
    const s = simRef.current;
    const name = joinName.trim();
    if (!s || !name) return;
    const at = sel ? [sel.x + 30, sel.y - 25] : [0, 0];
    s.join(name.slice(0, 22), at[0], at[1], 24000);
    setJoining(false);
    persist();
  };
  const payHere = (amount: number) => {
    const s = simRef.current;
    if (!s || !s.you || !sel) return;
    const tx = s.pay(s.you, sel, amount);
    persist(tx.ok ? { n: 1, spent: amount } : undefined);
    setFlash(tx);
    window.setTimeout(() => setFlash(f => (f === tx ? null : f)), 2800);
  };
  const leave = () => { try { localStorage.removeItem(YOU_KEY); } catch { /* ignore */ } location.reload(); };

  const st = sim?.stats;
  const catTotal = st ? Math.max(1, ...CATS.map(c => st.byCat[c])) : 1;
  const top = sim && st && st.n ? sim.top(6) : [];
  const busy = sim ? sim.busy() : 0;
  const hour = sim?.hour();
  const mine = you ? readYou() : null;

  const venueCard = sel && sim && (() => {
    const mixN = sel.mix[0] + sel.mix[1] + sel.mix[2];
    const rank = sel.n ? sim.rank(sel) : 0;
    const peak = Array.from(sel.hours).reduce((b, h, i, a) => (h > a[b] ? i : b), 0);
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
          <div><span>{t('Сьогодні', 'Today')}</span><b>{fmt(sel.rev)}<small>TAX</small></b></div>
          <div><span>{t('Платежі', 'Payments')}</span><b>{sel.n}</b></div>
          <div><span>{t('Середній чек', 'Avg ticket')}</span><b>{sel.n ? fmt(sel.rev / sel.n) : '—'}</b></div>
        </div>
        {rank > 0 && <p className="cl-v-rank">#{rank} {t('з', 'of')} {fmt(sim.byCat[sel.cat].length)} · {t(...CAT_NAME[sel.cat]).toLowerCase()} · {t('пік', 'peak')} {String(peak).padStart(2, '0')}:00</p>}
        <Bars data={sel.hours} now={hour} color={CAT_COLOR[sel.cat]} peak />
        {mixN > 0 && (
          <div className="cl-mix">
            <div className="cl-mix-bar"><i style={{ flex: sel.mix[0] }} /><i style={{ flex: sel.mix[1] }} /><i style={{ flex: sel.mix[2] }} /></div>
            <div className="cl-mix-lg">
              <span>{t('Мешканці', 'Residents')} {Math.round((sel.mix[0] / mixN) * 100)}%</span>
              <span>{t('Туристи', 'Tourists')} {Math.round((sel.mix[1] / mixN) * 100)}%</span>
              <span>{t('Приїжджі', 'Commuters')} {Math.round((sel.mix[2] / mixN) * 100)}%</span>
            </div>
          </div>
        )}
        {sel.last.length > 0 && (
          <ul className="cl-v-last">
            {sel.last.slice(0, 4).map(x => <li key={x.id} className={x.ok ? '' : 'no'}><span>{x.acc.you ? x.acc.name : x.acc.id}</span><em>{x.ok ? '' : t(...REASON[x.reason!])}</em><b>{fmt(x.amount)}</b></li>)}
          </ul>
        )}
        {you ? (
          <div className="cl-pay">
            {CHIPS[sel.cat].map(a => <button key={a} type="button" onClick={() => payHere(a)}>{fmt(a)}</button>)}
          </div>
        ) : (
          <button type="button" className="cl-btn cl-btn-y cl-wide" onClick={() => setJoining(true)}>{t('Платити тут', 'Pay here')}</button>
        )}
      </section>
    );
  })();

  return (
    <div className={`cl${ready ? ' ready' : ''}${panel ? ' p-' + panel : ''}${sel ? ' has-sel' : ''}`}>
      <div className="cl-map" ref={box} />
      {!ready && <div className="cl-load"><span>Roma</span><i /></div>}

      <header className="cl-top">
        <a className="cl-brand" href="/" aria-label="TaxTech"><img src="/icons/mark-white.svg" alt="" /><span>Roma <b>Live</b></span></a>
        <div className="cl-clock" title={t('Симуляція', 'Simulation')}>
          <b>{sim?.clock() || '07:00'}</b>
          <span>{t('День', 'Day')} {sim?.day || 1}</span>
          <i className="cl-busy" style={{ ['--b' as string]: busy.toFixed(2) }} />
        </div>
        <div className="cl-seg" role="group" aria-label={t('Швидкість', 'Speed')}>
          <button type="button" className={paused ? 'on' : ''} onClick={() => setPaused(p => !p)} aria-label={paused ? t('Далі', 'Play') : t('Пауза', 'Pause')}>{paused ? Ico.play : Ico.pause}</button>
          {[1, 4, 15, 60].map(s => <button key={s} type="button" className={!paused && speed === s ? 'on' : ''} onClick={() => { setSpeed(s); setPaused(false); }}>{s}×</button>)}
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
          <a className="cl-btn cl-btn-y" href="/#register">{t('Відкрити рахунок', 'Open account')}</a>
        </div>
      </header>

      {/* the city in numbers, on demand */}
      <aside className="cl-panel cl-panel-l" aria-hidden={panel !== 'city'}>
        <div className="cl-kpis">
          <div><span>{t('Оборот', 'Turnover')}</span><b>{short(st?.vol || 0)}<small>TAX</small></b></div>
          <div><span>{t('Платежі', 'Payments')}</span><b>{fmt(st?.n || 0)}</b></div>
          <div><span>{t('За хвилину', 'Per minute')}</span><b>{(st?.perMin || 0).toFixed(1).replace('.', ',')}</b></div>
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
        <p className="cl-src">{fmt(sim?.venues.length || 0)} {t('місць', 'places')} · {fmt(sim?.D.b.length || 0)} {t('будівель', 'buildings')} · {fmt(sim?.accounts.length || 0)} {t('рахунків', 'accounts')} · © OpenStreetMap</p>
      </aside>

      {/* the live feed, on demand */}
      <aside className="cl-panel cl-panel-r" aria-hidden={panel !== 'feed'}>
        <h4><i className="cl-dot" />{t('Наживо', 'Live')}</h4>
        <ul className="cl-feed">
          {(sim?.feed || []).slice(0, 16).map(x => (
            <li key={x.id} className={`${x.ok ? '' : 'no'}${x.acc.you ? ' you' : ''}`} style={{ ['--c' as string]: CAT_COLOR[x.venue.cat] }} onClick={() => pick(x.venue)}>
              <i />
              <div><b>{x.venue.name}</b><span>{x.acc.you ? x.acc.name : x.acc.id}{x.ok ? (x.venue.rione ? ` · ${x.venue.rione}` : '') : ` · ${t(...REASON[x.reason!])}`}</span></div>
              <em>{x.ok ? '' : '✕ '}{fmt(x.amount)}</em>
            </li>
          ))}
        </ul>
      </aside>

      {/* the selected place */}
      <div className="cl-card-wrap">{venueCard}</div>

      {/* bottom: quiet numbers, you, legend */}
      <footer className="cl-bottom">
        <div className="cl-strip">
          <span><small>{t('Оборот', 'Turnover')}</small><b>{short(st?.vol || 0)}</b></span>
          <span><small>{t('Платежі', 'Payments')}</small><b>{fmt(st?.n || 0)}</b></span>
          <span className="cl-red"><small>{t('Відхилено', 'Declined')}</small><b>{fmt(st?.declined || 0)}</b></span>
        </div>
        <div className="cl-you">
          {you ? (
            <div className="cl-me">
              <div><b>{you.name}</b><small>{you.id}{mine?.n ? ` · ${mine.n} ${t('платежів', 'payments')}` : ''}</small></div>
              <strong>{fmt(you.bal)}<small>TAX</small></strong>
              <button type="button" className="cl-me-x" onClick={leave} aria-label={t('Вийти з міста', 'Leave the city')}>×</button>
            </div>
          ) : joining ? (
            <form className="cl-join" onSubmit={e => { e.preventDefault(); join(); }}>
              <input autoFocus value={joinName} maxLength={22} onChange={e => setJoinName(e.target.value)} placeholder={t('Ваше імʼя', 'Your name')} />
              <button type="submit" className="cl-btn cl-btn-y" disabled={!joinName.trim()}>{t('Увійти в місто', 'Enter the city')}</button>
            </form>
          ) : (
            <button type="button" className="cl-btn cl-btn-glass" onClick={() => setJoining(true)}>{t('Стати мешканцем', 'Move in')}</button>
          )}
          {flash && <div className={`cl-flash${flash.ok ? '' : ' no'}`}>{flash.ok ? `${flash.venue.name} · −${fmt(flash.amount)} TAX` : `${t('Відхилено', 'Declined')} · ${t(...REASON[flash.reason!])}`}</div>}
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
