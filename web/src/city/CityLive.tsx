import { useEffect, useMemo, useRef, useState } from 'react';
import romeUrl from './rome.json?url';
import { CATS, CAT_COLOR, CitySim, type Cat, type CityData, type Tx, type Venue } from './citySim';
import type { SceneApi } from './cityScene';
import { initialLandingLang, landingText, LANDING_LANGS, saveLandingLang, type LandingLang } from '../landingLang';
import './city.css';

// Roma Live (/roma): the bank turned into a city. Real places from OpenStreetMap, simulated accounts paying them,
// the visitor's own account among them. CityPreview is the same city, smaller and hands-off, for the landing.

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
type YouSave = { name: string; bal: number; x: number; y: number; n: number; spent: number };

// ── Landing preview ──
export function CityPreview({ onStats }: { onStats?: (s: { vol: number; n: number; clock: string; venues: number }) => void }) {
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let api: SceneApi | null = null, alive = true, iv = 0;
    Promise.all([loadCity(), loadScene()]).then(([d, m]) => {
      if (!alive || !box.current) return;
      const sim = new CitySim(d);
      sim.minute = 18 * 60 + 40; sim.speed = 3; sim.rate = 1.8;
      // a warm start: the afternoon already booked, so the buildings are lit from the first frame
      for (let i = 0; i < 520; i++) sim.step(1);
      sim.minute = 18 * 60 + 40;
      api = m.createCityScene(box.current, sim, { preview: true });
      box.current.classList.add('on');
      iv = window.setInterval(() => onStats?.({ vol: sim.stats.vol, n: sim.stats.n, clock: sim.clock(), venues: sim.venues.length }), 400);
    }).catch(() => {});
    return () => { alive = false; clearInterval(iv); api?.dispose(); };
  }, []);
  return <div className="cl-prev" ref={box} aria-hidden />;
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
  const [joinName, setJoinName] = useState('');
  const [joining, setJoining] = useState(false);
  const [flash, setFlash] = useState<Tx | null>(null);
  const [panel, setPanel] = useState<'feed' | 'stats' | null>(null);

  useEffect(() => { document.title = 'Roma Live · TaxTech'; }, []);

  useEffect(() => {
    let alive = true;
    Promise.all([loadCity(), loadScene()]).then(([d, m]) => {
      if (!alive || !box.current) return;
      const sim = new CitySim(d);
      sim.minute = 7 * 60 + 10; sim.speed = 4;
      for (let i = 0; i < 40; i++) sim.step(1);
      try {
        const s = JSON.parse(localStorage.getItem(YOU_KEY) || 'null') as YouSave | null;
        if (s?.name) { const a = sim.join(s.name, s.x, s.y, s.bal); a.recent = []; (a as unknown as { n: number }).n = s.n; }
      } catch { /* ignore */ }
      simRef.current = sim;
      apiRef.current = m.createCityScene(box.current, sim, { onPick: v => { setSel(v); apiRef.current?.select(v); if (v) apiRef.current?.flyTo(v.x, v.y, 480); } });
      setReady(true);
    }).catch(() => {});
    const iv = window.setInterval(() => setTick(x => x + 1), 250);
    return () => { alive = false; clearInterval(iv); apiRef.current?.dispose(); apiRef.current = null; };
  }, []);

  useEffect(() => { if (simRef.current) simRef.current.speed = paused ? 0 : speed; }, [speed, paused, ready]);
  useEffect(() => { if (simRef.current) { simRef.current.on = on; apiRef.current?.setCats(on); } }, [on, ready]);
  useEffect(() => {
    const k = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement)?.tagName === 'INPUT') return;
      if (e.key === 'Escape') { setSel(null); apiRef.current?.select(null); }
      if (e.key === ' ') { e.preventDefault(); setPaused(p => !p); }
    };
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, []);

  const sim = simRef.current;
  const you = sim?.you || null;
  const results = useMemo(() => (sim ? sim.search(q) : []), [q, sim]);

  const pick = (v: Venue | null) => { setSel(v); apiRef.current?.select(v); if (v) apiRef.current?.flyTo(v.x, v.y, 480); setQ(''); setPanel(null); };
  const setLang = (l: LandingLang) => { setLangS(l); saveLandingLang(l); };

  const save = () => {
    const a = simRef.current?.you;
    if (!a) return;
    const prev = (() => { try { return JSON.parse(localStorage.getItem(YOU_KEY) || 'null') as YouSave | null; } catch { return null; } })();
    try { localStorage.setItem(YOU_KEY, JSON.stringify({ name: a.name, bal: a.bal, x: a.x, y: a.y, n: (prev?.n || 0), spent: prev?.spent || 0 })); } catch { /* ignore */ }
  };
  const join = () => {
    const s = simRef.current;
    const name = joinName.trim();
    if (!s || !name) return;
    // you live where you are looking
    const at = sel ? [sel.x + 40, sel.y - 30] : [0, 0];
    s.join(name.slice(0, 22), at[0], at[1], 24000);
    setJoining(false);
    save();
  };
  const payHere = (amount: number) => {
    const s = simRef.current;
    if (!s || !s.you || !sel) return;
    const tx = s.pay(s.you, sel, amount);
    try {
      const prev = JSON.parse(localStorage.getItem(YOU_KEY) || 'null') as YouSave | null;
      localStorage.setItem(YOU_KEY, JSON.stringify({ name: s.you.name, bal: s.you.bal, x: s.you.x, y: s.you.y, n: (prev?.n || 0) + (tx.ok ? 1 : 0), spent: (prev?.spent || 0) + (tx.ok ? amount : 0) }));
    } catch { /* ignore */ }
    setFlash(tx);
    window.setTimeout(() => setFlash(f => (f === tx ? null : f)), 2600);
  };
  const leave = () => {
    try { localStorage.removeItem(YOU_KEY); } catch { /* ignore */ }
    location.reload();
  };

  const st = sim?.stats;
  const catTotal = st ? Math.max(1, ...CATS.map(c => st.byCat[c])) : 1;
  const top = sim && st && st.n ? sim.top(5) : [];
  const busy = sim ? sim.busy() : 0;

  return (
    <div className={`cl${ready ? ' ready' : ''}`}>
      <div className="cl-map" ref={box} />
      {!ready && <div className="cl-load"><span>Roma</span><i /></div>}

      <header className="cl-top">
        <a className="cl-brand" href="/" aria-label="TaxTech"><img src="/icons/mark-white.svg" alt="" /><span>Roma <b>Live</b></span></a>
        <div className="cl-clock">
          <b>{sim?.clock() || '07:10'}</b>
          <span>{t('День', 'Day')} {sim?.day || 1}</span>
          <i className="cl-busy" style={{ ['--b' as string]: busy.toFixed(2) }} />
        </div>
        <div className="cl-speed" role="group" aria-label={t('Швидкість', 'Speed')}>
          <button type="button" className={paused ? 'on' : ''} onClick={() => setPaused(p => !p)} aria-label={paused ? t('Далі', 'Play') : t('Пауза', 'Pause')}>
            {paused ? <svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg> : <svg viewBox="0 0 24 24"><path d="M7 5h3.5v14H7zM13.5 5H17v14h-3.5z" /></svg>}
          </button>
          {[1, 4, 15, 60].map(s => <button key={s} type="button" className={!paused && speed === s ? 'on' : ''} onClick={() => { setSpeed(s); setPaused(false); }}>{s}×</button>)}
        </div>
        <div className="cl-top-r">
          <div className="cl-lang">{LANDING_LANGS.map(l => <button key={l.id} type="button" className={lang === l.id ? 'on' : ''} onClick={() => setLang(l.id)}>{l.label}</button>)}</div>
          <a className="cl-pill" href="/#register">{t('Відкрити рахунок', 'Open account')}</a>
        </div>
      </header>

      {/* left: the city in numbers */}
      <aside className={`cl-side cl-left${panel === 'stats' ? ' open' : ''}`}>
        <div className="cl-kpis">
          <div><span>{t('Оборот', 'Turnover')}</span><b>{short(st?.vol || 0)}<small>TAX</small></b></div>
          <div><span>{t('Платежі', 'Payments')}</span><b>{fmt(st?.n || 0)}</b></div>
          <div><span>{t('За хвилину', 'Per minute')}</span><b>{(st?.perMin || 0).toFixed(1).replace('.', ',')}</b></div>
          <div className="cl-red"><span>{t('Відхилено', 'Declined')}</span><b>{fmt(st?.declined || 0)}</b></div>
        </div>
        <div className="cl-cats">
          {CATS.map(c => (
            <button key={c} type="button" className={on[c] ? 'on' : ''} onClick={() => setOn(o => ({ ...o, [c]: !o[c] }))} style={{ ['--c' as string]: CAT_COLOR[c] }}>
              <i /><span>{t(...CAT_NAME[c])}</span><em>{short(st?.byCat[c] || 0)}</em>
              <u style={{ width: `${((st?.byCat[c] || 0) / catTotal) * 100}%` }} />
            </button>
          ))}
        </div>
        {top.length > 0 && (
          <div className="cl-top5">
            <h4>{t('Лідери дня', 'Top today')}</h4>
            {top.map((v, i) => <button key={v.i} type="button" onClick={() => pick(v)}><small>{i + 1}</small><span>{v.name}</span><em>{short(v.rev)}</em></button>)}
          </div>
        )}
        <p className="cl-src">{fmt(sim?.venues.length || 0)} {t('місць', 'places')} · {fmt(sim?.D.b.length || 0)} {t('будівель', 'buildings')} · {fmt((sim?.accounts.length || 0))} {t('рахунків', 'accounts')}<br />© OpenStreetMap</p>
      </aside>

      {/* right: search, the venue, the live feed */}
      <aside className={`cl-side cl-right${panel === 'feed' ? ' open' : ''}${sel ? ' sel' : ''}`}>
        <div className="cl-search">
          <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5" /><path d="m16 16 4.5 4.5" /></svg>
          <input value={q} onChange={e => setQ(e.target.value)} placeholder={t('Знайти місце', 'Find a place')} spellCheck={false} />
          {results.length > 0 && (
            <div className="cl-res">{results.map(v => <button key={v.i} type="button" onClick={() => pick(v)} style={{ ['--c' as string]: CAT_COLOR[v.cat] }}><i /><span>{v.name}</span><em>{t(...CAT_NAME[v.cat])}</em></button>)}</div>
          )}
        </div>

        {sel ? (
          <div className="cl-venue" style={{ ['--c' as string]: CAT_COLOR[sel.cat] }}>
            <button type="button" className="cl-x" aria-label={t('Закрити', 'Close')} onClick={() => pick(null)}>×</button>
            <span className="cl-v-kind"><i />{t(...CAT_NAME[sel.cat])}{sel.sub && sel.sub !== sel.cat ? ` · ${sel.sub.replace(/_/g, ' ')}` : ''}</span>
            <h3>{sel.name}</h3>
            <div className="cl-v-kpi">
              <div><span>{t('Сьогодні', 'Today')}</span><b>{fmt(sel.rev)} <small>TAX</small></b></div>
              <div><span>{t('Платежі', 'Payments')}</span><b>{sel.n}</b></div>
              <div><span>{t('Середній чек', 'Avg ticket')}</span><b>{sel.n ? fmt(sel.rev / sel.n) : '—'}</b></div>
            </div>
            <div className="cl-hours" aria-hidden>
              {Array.from(sel.hours).map((h, i) => { const m = Math.max(1, ...Array.from(sel.hours)); return <i key={i} className={sim && sim.hour() === i ? 'now' : ''} style={{ height: `${6 + (h / m) * 94}%` }} />; })}
            </div>
            <div className="cl-hours-ax"><span>00</span><span>06</span><span>12</span><span>18</span><span>24</span></div>
            {sel.last.length > 0 && (
              <ul className="cl-v-last">
                {sel.last.slice(0, 4).map(x => <li key={x.id} className={x.ok ? '' : 'no'}><span>{x.acc.you ? x.acc.name : x.acc.id}</span><b>{x.ok ? '' : '✕ '}{fmt(x.amount)}</b></li>)}
              </ul>
            )}
            {you ? (
              <div className="cl-pay">
                <span>{t('Оплатити', 'Pay')}</span>
                <div>{CHIPS[sel.cat].map(a => <button key={a} type="button" onClick={() => payHere(a)}>{fmt(a)}</button>)}</div>
              </div>
            ) : (
              <button type="button" className="cl-join-btn" onClick={() => setJoining(true)}>{t('Платити тут', 'Pay here')}</button>
            )}
          </div>
        ) : (
          <div className="cl-feed">
            <h4><i />{t('Наживо', 'Live')}</h4>
            <ul>
              {(sim?.feed || []).slice(0, 13).map(x => (
                <li key={x.id} className={`${x.ok ? '' : 'no'}${x.acc.you ? ' you' : ''}`} style={{ ['--c' as string]: CAT_COLOR[x.venue.cat] }} onClick={() => pick(x.venue)}>
                  <i />
                  <div><b>{x.venue.name}</b><span>{x.acc.you ? x.acc.name : x.acc.id}{x.ok ? '' : ` · ${t(...REASON[x.reason!])}`}</span></div>
                  <em>{x.ok ? '−' : '✕ '}{fmt(x.amount)}</em>
                </li>
              ))}
            </ul>
          </div>
        )}
      </aside>

      {/* bottom: you */}
      <div className="cl-you">
        {you ? (
          <div className="cl-card">
            <div><span>{you.name}</span><small>{you.id}</small></div>
            <b>{fmt(you.bal)} <small>TAX</small></b>
            <button type="button" className="cl-you-x" onClick={leave} aria-label={t('Вийти з міста', 'Leave the city')}>×</button>
          </div>
        ) : joining ? (
          <form className="cl-join" onSubmit={e => { e.preventDefault(); join(); }}>
            <input autoFocus value={joinName} maxLength={22} onChange={e => setJoinName(e.target.value)} placeholder={t('Ваше імʼя', 'Your name')} />
            <button type="submit" disabled={!joinName.trim()}>{t('Увійти в місто', 'Enter the city')}</button>
          </form>
        ) : (
          <button type="button" className="cl-join-btn" onClick={() => setJoining(true)}>{t('Стати мешканцем', 'Move in')}</button>
        )}
        {flash && <div className={`cl-flash${flash.ok ? '' : ' no'}`}>{flash.ok ? `${flash.venue.name} · −${fmt(flash.amount)} TAX` : `${t('Відхилено', 'Declined')} · ${t(...REASON[flash.reason!])}`}</div>}
      </div>

      <nav className="cl-tabs">
        <button type="button" className={panel === 'stats' ? 'on' : ''} onClick={() => setPanel(p => (p === 'stats' ? null : 'stats'))}>{t('Місто', 'City')}</button>
        <button type="button" className={panel === 'feed' ? 'on' : ''} onClick={() => setPanel(p => (p === 'feed' ? null : 'feed'))}>{t('Наживо', 'Live')}</button>
      </nav>
    </div>
  );
}
