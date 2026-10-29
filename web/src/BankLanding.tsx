import { useEffect, useRef, useState } from 'react';
import { FAQ } from './landingFaq';
import { LandingLangContext, LANDING_LANGS, initialLandingLang, landingText, saveLandingLang, type LandingLang } from './landingLang';
import FireScene from './FireScene';
import TapScene from './TapScene';
import RomeMap from './RomeMap';
import { armSound, chime, onSound, soundOn, toggleSound } from './paySound';
import FaceFlow from './FaceFlow';
import { SUN_SPOTS } from './fireData';
import './bankLanding.css';

// Logged-out landing. It shows the product itself: real iPhone screens of the app (web/public/landing/), the same
// guilloche rosette and engraved medallions as the app, the Rome card photos from web/public/cards/ and live
// Saint Agnes products. Black and signal yellow like the app, a cream section like the shop.

const SHOP_URL = 'https://shop.munister.com.ua/';
// Same rates and formula as server/backend/services/deposit_service.py and credit_service.py.
// Hand-picked Saint Agnes pieces, in this order (coat, teddy jacket, tweed cardigan, check jacket).
const SHOP_PICKS = ['munister-81921', 'munister-83171', 'munister-81907', 'munister-83168'];

// Card designs: the guilloche default plus the Rome photographs the app offers under "Вигляд".
type Finish = 'guilloche' | 'colosseum-night' | 'pantheon' | 'forum' | 'aqueduct' | 'marble';
// One evening in Rome, told by the scroll: the clock runs from CLOCK_FROM to CLOCK_TO while the photographs change.
const CLOCK_FROM = 18 * 60 + 30, CLOCK_TO = 23 * 60 + 55;
const DAY = [
  { img: '/landing/rome-forum-sunset.webp', pos: '50% 62%', place: { uk: 'Римський форум', en: 'Roman Forum' }, what: { uk: 'Аперитив', en: 'Aperitivo' }, merchant: 'Foro Romano', amount: 850, bal: 23150 },
  { img: '/landing/rome-pantheon-night.webp', pos: '50% 38%', place: { uk: 'Пантеон', en: 'Pantheon' }, what: { uk: 'Вечеря', en: 'Dinner' }, merchant: 'Pantheon', amount: 3200, bal: 19950 },
  { img: '/landing/rome-trevi-night.webp', pos: '50% 28%', place: { uk: 'Фонтан Треві', en: 'Trevi Fountain' }, what: { uk: 'Джелато', en: 'Gelato' }, merchant: 'Fontana di Trevi', amount: 180, bal: 19770 },
];

const FINISHES: { id: Finish; uk: string; en: string; photo?: string }[] = [
  { id: 'guilloche', uk: 'Гільйош', en: 'Guilloche' },
  { id: 'colosseum-night', uk: 'Колізей вночі', en: 'Colosseum by night', photo: '/cards/roma-colosseum-night.webp' },
  { id: 'pantheon', uk: 'Пантеон', en: 'Pantheon', photo: '/cards/roma-pantheon.webp' },
  { id: 'forum', uk: 'Форум', en: 'Forum', photo: '/cards/roma-forum.webp' },
  { id: 'aqueduct', uk: 'Акведук', en: 'Aqueduct', photo: '/cards/roma-aqueduct.webp' },
  { id: 'marble', uk: 'Мармур', en: 'Marble', photo: '/cards/roma-marble.webp' },
];

type ShopItem = { id: number; title: string; price: number | string; image_url?: string; slug?: string };

const fmt = (n: number, d = 0) => n.toLocaleString('uk-UA', { minimumFractionDigits: d, maximumFractionDigits: d }).replace(/ /g, ' ');

// Guilloche rosette: the same family of curves as the app's HeroRosette and Medallion (web/src/App.tsx).
function rosettePaths(curves: number, lobes: number, depth: number, second: number, r: number, steps = 110): string {
  let out = '';
  for (let k = 0; k < curves; k++) {
    const phase = (k / curves) * Math.PI * 2;
    for (let i = 0; i <= steps; i++) {
      const t = (i / steps) * Math.PI * 2;
      const rr = r * (1 - depth - second + depth * Math.cos(lobes * t + phase) + second * Math.cos(lobes * 2 * t - phase));
      out += (i ? 'L' : 'M') + (50 + rr * Math.cos(t)).toFixed(1) + ' ' + (50 + rr * Math.sin(t)).toFixed(1);
    }
  }
  return out;
}
const CARD_ROSETTE = rosettePaths(22, 7, 0.22, 0.07, 46, 100);
const MEDALLION_ROSETTE = rosettePaths(10, 6, 0.2, 0.06, 45, 80);
const MEDALLION_TICKS = Array.from({ length: 60 }, (_, i) => {
  const a = (i / 60) * Math.PI * 2, long = i % 5 === 0, r0 = 48.6, r1 = long ? 44.6 : 46;
  return `M${(50 + r0 * Math.cos(a)).toFixed(1)} ${(50 + r0 * Math.sin(a)).toFixed(1)}L${(50 + r1 * Math.cos(a)).toFixed(1)} ${(50 + r1 * Math.sin(a)).toFixed(1)}`;
}).join('');

// Engraved medallion (a quick-action button in the app): guilloche disc, double ring, tick scale, icon in the middle.
function Medallion({ tint, children }: { tint: string; children: React.ReactNode }) {
  return (
    <span className="bl-med" style={{ ['--tint' as string]: tint }}>
      <svg viewBox="0 0 100 100" aria-hidden>
        <circle cx="50" cy="50" r="49" fill={tint} fillOpacity="0.16" />
        <path d={MEDALLION_ROSETTE} fill="none" stroke={tint} strokeOpacity="0.5" strokeWidth="0.5" />
        <path d={MEDALLION_TICKS} fill="none" stroke={tint} strokeOpacity="0.6" strokeWidth="0.6" />
        <circle cx="50" cy="50" r="26" fill={tint} fillOpacity="0.2" />
        <circle cx="50" cy="50" r="26" fill="none" stroke="#fff" strokeOpacity="0.35" strokeWidth="0.8" />
        <circle cx="50" cy="50" r="48.5" fill="none" stroke={tint} strokeWidth="1.6" />
        <circle cx="50" cy="50" r="45.5" fill="none" stroke={tint} strokeOpacity="0.4" strokeWidth="0.6" />
      </svg>
      <i aria-hidden>{children}</i>
    </span>
  );
}

const IC = {
  eye: <svg viewBox="0 0 24 24"><path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12Z" /><circle cx="12" cy="12" r="3" /></svg>,
  snow: <svg viewBox="0 0 24 24"><path d="M12 2v20M3.5 7l17 10M3.5 17l17-10M9 3.5 12 6l3-2.5M9 20.5 12 18l3 2.5" /></svg>,
  palette: <svg viewBox="0 0 24 24"><path d="M12 3a9 9 0 1 0 0 18c1.5 0 2-1 1.4-2-.7-1.2 0-2.5 1.4-2.5H17a4 4 0 0 0 4-4C21 6.5 17 3 12 3Z" /><circle cx="7.5" cy="11" r="1" /><circle cx="10" cy="7.5" r="1" /><circle cx="14.5" cy="7.5" r="1" /></svg>,
  lock: <svg viewBox="0 0 24 24"><rect x="5" y="10.5" width="14" height="10" rx="2.5" /><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" /></svg>,
  plus: <svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg>,
  arrow: <svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg>,
  percent: <svg viewBox="0 0 24 24"><path d="M19 5 5 19" /><circle cx="7" cy="7" r="2.5" /><circle cx="17" cy="17" r="2.5" /></svg>,
  check: <svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>,
  face: <svg viewBox="0 0 24 24"><path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M9 10v1.5M15 10v1.5M12 10v3.5h-1M9 16.2c1.6 1.2 4.4 1.2 6 0" /></svg>,
};

// Section label in inscription capitals with a Roman numeral: "II · Вигляд картки".
function Card({ finish, n = '6595' }: { finish: Finish; n?: string }) {
  const f = FINISHES.find(x => x.id === finish)!;
  return (
    <div className={`bl-card${f.photo ? ' bl-card-photo' : ' bl-card-guil'}`} style={f.photo ? { backgroundImage: `url(${f.photo})` } : undefined}>
      {!f.photo && <svg className="bl-card-rose" viewBox="0 0 100 100" aria-hidden><path d={CARD_ROSETTE} fill="none" stroke="#ffd400" strokeWidth=".3" /></svg>}
      <span className="bl-card-shade" aria-hidden />
      <span className="bl-card-sheen" aria-hidden />
      <span className="bl-card-brand"><img src="/icons/mark-white.svg" alt="" /><span>Tax<b>Tech</b></span></span>
      <svg className="bl-card-nfc" viewBox="0 0 24 24" aria-hidden><path d="M8.5 7.5a6 6 0 0 1 0 9M12 5a9.5 9.5 0 0 1 0 14M15.5 2.5a13 13 0 0 1 0 19" /></svg>
      <svg className="bl-card-chip" viewBox="0 0 44 34" aria-hidden>
        <defs><linearGradient id="blchip" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#f7e7b4" /><stop offset=".35" stopColor="#d3ac55" /><stop offset=".62" stopColor="#f0d58e" /><stop offset="1" stopColor="#a47f33" /></linearGradient></defs>
        <rect x=".5" y=".5" width="43" height="33" rx="6" fill="url(#blchip)" stroke="rgba(70,45,5,.55)" />
        <path d="M.5 12h12.5q4 0 4 5t-4 5H.5M43.5 12H31q-4 0-4 5t4 5h12.5M17 .5v8.5M27 .5v8.5M17 33.5V25M27 33.5V25M17 9h10v16H17z" fill="none" stroke="rgba(70,45,5,.55)" strokeWidth=".9" />
      </svg>
      <span className="bl-card-num">•••• •••• •••• {n}</span>
      <span className="bl-card-name">DEMO USER</span>
      <span className="bl-card-virt">VIRTUAL</span>
    </div>
  );
}

export default function BankLanding({ onAuth }: { onAuth: (m: 'login' | 'register') => void }) {
  const rootRef = useRef<HTMLDivElement | null>(null);
  const [lang, setLang] = useState<LandingLang>(initialLandingLang);
  const [scrolled, setScrolled] = useState(false);
  const [sound, setSound] = useState(false);
  useEffect(() => { const disarm = armSound(), f = () => setSound(soundOn()), unsub = onSound(f); f(); return () => { disarm(); unsub(); }; }, []);
  const [menu, setMenu] = useState(false);
  useEffect(() => {
    const root = rootRef.current;
    if (!menu || !root) return;
    root.style.overflow = 'hidden';
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setMenu(false); };
    window.addEventListener('keydown', onKey);
    return () => { root.style.overflow = ''; window.removeEventListener('keydown', onKey); };
  }, [menu]);
  const [finish, setFinish] = useState<Finish>('guilloche');
  const [shop, setShop] = useState<ShopItem[]>([]);
  const t = (uk: string, en: string) => landingText(lang, uk, en);
  // Debit notification as the app sends it: icon, app name, "now", what was charged and what is left.
  const push = (merchant: string, amount: number, bal: number) => (
    <>
      <span className="bl-push-ic" aria-hidden><img src="/icons/mark-white.svg" alt="" /></span>
      <div className="bl-push-tx">
        <div className="bl-push-top"><b>TaxTech</b><em>{t('зараз', 'now')}</em></div>
        <p className="bl-push-h">{t('Списання', 'Debit')} <u>−{fmt(amount)} TAX</u> · {merchant}</p>
        <p>{t('Залишок', 'Balance')} {fmt(bal)} TAX</p>
      </div>
    </>
  );

  useEffect(() => {
    const id = window.setTimeout(() => { document.documentElement.lang = lang; }, 0);
    saveLandingLang(lang);
    document.title = t('TaxTech · картка, рахунок і магазин в одному застосунку', 'TaxTech · card, account and shop in one app');
    return () => { window.clearTimeout(id); document.documentElement.lang = 'uk'; };
  }, [lang]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    root.classList.add('bl-js');
    const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { root, threshold: 0.12 });
    root.querySelectorAll('.bl-rv').forEach(el => io.observe(el));
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const rome = root.querySelector<HTMLElement>('.bl-rome');
    const romeLayers = Array.from(root.querySelectorAll<HTMLElement>('.bl-rome-layer'));
    const romeItems = Array.from(root.querySelectorAll<HTMLElement>('.bl-rome [data-i].bl-rome-item'));
    const clockEl = root.querySelector<HTMLElement>('.bl-rome-time');
    const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));
    const photos = Array.from(root.querySelectorAll<HTMLElement>('.bl-photo, .bl-paystage-photo, .bl-hero-photo'));
    const hero = root.querySelector<HTMLElement>('.bl-hero');
    let raf = 0;
    // Photos drift slower than the page (parallax), the hero lets go as you leave it.
    // Each frame reads every box first and only then writes, so the browser lays the page out once per frame.
    let lastClock = '', lastStop = -1;
    const frame = () => {
      raf = 0;
      const box = root.getBoundingClientRect();
      const top = root.scrollTop;
      const romeTop = rome ? rome.getBoundingClientRect().top : 0;
      const romeH = rome ? rome.offsetHeight : 0;
      const heroH = hero ? hero.offsetHeight : 0;
      const drift = still ? [] : photos.map(el => {
        const r = el.parentElement?.getBoundingClientRect();
        if (!r || r.bottom < box.top - 150 || r.top > box.bottom + 150) return null;
        return { el, d: (r.top + r.height / 2) - (box.top + box.height / 2), lim: el.offsetHeight * (el.classList.contains('bl-hero-photo') ? 0.04 : 0.08) };
      });
      if (rome) {
        const n = DAY.length;
        const p = clamp(-(romeTop - box.top) / Math.max(1, romeH - root.clientHeight));
        const s = p * n;
        // Each new stop on the evening is a payment: the terminal chimes (once the visitor has turned sound on).
        const stop = p > 0 && p < 1 ? Math.min(n - 1, Math.floor(s)) : -1;
        if (stop > lastStop && stop >= 0) chime(0.55);
        lastStop = stop;
        rome.style.setProperty('--ry', `${((p - 0.5) * 52).toFixed(2)}deg`);
        romeLayers.forEach((el, i) => {
          el.style.setProperty('--o', (i === 0 ? 1 : clamp((s - (i - 0.35)) / 0.7)).toFixed(3));
          el.style.setProperty('--z', (1.05 + clamp(s - i, -0.35, 1.35) * 0.1).toFixed(3));
        });
        romeItems.forEach(el => {
          const i = Number(el.dataset.i);
          const d = i === 0 && s < 0.5 ? 0 : i === n - 1 && s > n - 0.5 ? 0 : Math.abs(s - (i + 0.5));
          el.style.setProperty('--a', clamp(1 - d * 2.4).toFixed(3));
        });
        if (clockEl) {
          const m = Math.round(CLOCK_FROM + p * (CLOCK_TO - CLOCK_FROM));
          const txt = `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
          if (txt !== lastClock) { clockEl.textContent = txt; lastClock = txt; }
        }
      }
      if (still) return;
      for (const q of drift) if (q) q.el.style.setProperty('--py', `${Math.max(-q.lim, Math.min(q.lim, -q.d * 0.1)).toFixed(1)}px`);
      if (hero) hero.style.setProperty('--hp', Math.max(0, Math.min(1, top / (heroH * 0.75))).toFixed(3));
    };
    let wasScrolled = false;
    const onScroll = () => {
      const now = root.scrollTop > 10;
      if (now !== wasScrolled) { wasScrolled = now; setScrolled(now); }
      if (!raf) raf = requestAnimationFrame(frame);
    };
    root.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    frame();
    // The hero card leans towards the pointer.
    const fine = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
    const tilt = (e: PointerEvent) => {
      if (!hero) return;
      const r = hero.getBoundingClientRect();
      const nx = (e.clientX - r.left) / r.width - 0.5, ny = (e.clientY - r.top) / r.height - 0.5;
      hero.style.setProperty('--ry', `${(nx * 14).toFixed(2)}deg`);
      hero.style.setProperty('--rx', `${(-ny * 10).toFixed(2)}deg`);
    };
    const untilt = () => { hero?.style.setProperty('--ry', '0deg'); hero?.style.setProperty('--rx', '0deg'); };
    if (fine && !still && hero) { hero.addEventListener('pointermove', tilt); hero.addEventListener('pointerleave', untilt); }
    return () => {
      io.disconnect();
      root.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
      if (raf) cancelAnimationFrame(raf);
      hero?.removeEventListener('pointermove', tilt);
      hero?.removeEventListener('pointerleave', untilt);
    };
  }, []);

  useEffect(() => {
    fetch(`/api/marketplace/catalog?per_page=12&slugs=${SHOP_PICKS.join(',')}`)
      .then(r => r.json())
      .then(j => {
        if (!j?.ok) return;
        const got: ShopItem[] = j.data?.items || [];
        setShop(SHOP_PICKS.map(s => got.find(p => p.slug === s)).filter((p): p is ShopItem => Boolean(p && p.image_url)));
      })
      .catch(() => {});
  }, []);

  const cur = FINISHES.find(f => f.id === finish)!;

  const nav: [string, string][] = [['#pay', t('Оплата', 'Pay')], ['#card', t('Картки', 'Cards')], ['#shop', 'Saint Agnes']];
  const langSwitch = (
    <div className="bl-lang" role="group" aria-label={t('Мова', 'Language')}>
      {LANDING_LANGS.map(l => (
        <button key={l.id} type="button" className={lang === l.id ? 'on' : ''} aria-pressed={lang === l.id} onClick={() => setLang(l.id)}>{l.label}</button>
      ))}
    </div>
  );

  return (
    <LandingLangContext.Provider value={lang}>
      <div className="bl" ref={rootRef}>
        <header className={`bl-nav${scrolled ? ' s' : ''}`}>
          <div className="bl-wrap bl-nav-in">
            <a href="#top" className="bl-logo" aria-label="TaxTech"><img src="/icons/mark-white.svg" alt="TaxTech" /></a>
            <nav className="bl-links" aria-label={t('Розділи', 'Sections')}>{nav.map(([h, x]) => <a key={h} href={h}>{x}</a>)}</nav>
            <div className="bl-nav-r">
              {langSwitch}
              <button type="button" className="bl-nav-in-btn" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              <button type="button" className="bl-pill bl-pill-sm" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open account')}</button>
              <button type="button" className={`bl-snd${sound ? ' on' : ''}`} aria-pressed={sound} aria-label={sound ? t('Вимкнути звук', 'Sound off') : t('Увімкнути звук', 'Sound on')} title={sound ? t('Вимкнути звук', 'Sound off') : t('Увімкнути звук', 'Sound on')} onClick={toggleSound}>
                <svg viewBox="0 0 24 24" aria-hidden><path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z" />{sound ? <path d="M15.5 9a4.2 4.2 0 0 1 0 6M18 6.5a7.6 7.6 0 0 1 0 11" /> : <path d="M16 9.5l5 5M21 9.5l-5 5" />}</svg>
              </button>
              <button type="button" className="bl-burger" aria-label={t('Меню', 'Menu')} aria-expanded={menu} onClick={() => setMenu(v => !v)}>
                <svg viewBox="0 0 24 24" aria-hidden>{menu ? <path d="M6 6l12 12M18 6 6 18" /> : <path d="M4 9h16M4 15h16" />}</svg>
              </button>
            </div>
          </div>
        </header>
        {menu && (
          <div className="bl-sheet" role="dialog" aria-modal="true" aria-label={t('Меню', 'Menu')} onClick={() => setMenu(false)}>
            <nav className="bl-wrap bl-sheet-links">
              {nav.map(([h, x], i) => (
                <a key={h} href={h} style={{ ['--i' as string]: i }}>
                  <small>{String(i + 1).padStart(2, '0')}</small><span>{x}</span><i aria-hidden>›</i>
                </a>
              ))}
            </nav>
            <div className="bl-wrap bl-sheet-foot" onClick={e => e.stopPropagation()}>
              <div className="bl-sheet-cta">
                <button type="button" className="bl-pill" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
                <button type="button" className="bl-ghost" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              </div>
              {langSwitch}
            </div>
          </div>
        )}

        {/* ── Hero and the evening in Rome share one night map of Rome: streets from OpenStreetMap, a payment travels along them ── */}
        <div className="bl-cine">
          <div className="bl-cine-bg" aria-hidden><RomeMap /></div>
          <section id="top" className="bl-hero">
            <div className="bl-wrap bl-hero-in">
              <h1>{t('Платіть, як у Римі.', 'Pay like Rome.').split(' ').map((w, i) => <span key={i} className="bl-w" style={{ ['--i' as string]: i }}>{w}</span>)}</h1>
            </div>
            {/* The debit arrives the way a real one does: a banner from the top (top right on a desktop, like macOS) */}
            <div className="bl-hero-push" aria-hidden>
              <div className="bl-toast bl-push bl-toast-loop">{push('Roma · Colosseo', 850, 23150)}</div>
            </div>
            <div className="bl-hero-pay" aria-hidden>
              <div className="bl-hero-card"><Card finish="guilloche" /></div>
            </div>
          </section>

        {/* ── One evening in Rome: the scroll runs the clock, the photographs change, the card pays ── */}
        <section id="pay" className="bl-rome">
          <div className="bl-rome-stage">
            <div className="bl-rome-shade" aria-hidden />
            <div className="bl-wrap bl-rome-in">
              <div className="bl-rome-left">
                <div className="bl-rome-time" aria-hidden>18:30</div>
                <div className="bl-rome-where">
                  {DAY.map((d, i) => (
                    <div key={d.img} data-i={i} className="bl-rome-item" style={{ ['--a' as string]: i === 0 ? 1 : 0 }}>
                      <h2>{t(d.place.uk, d.place.en)}</h2>
                      <p>{t(d.what.uk, d.what.en)}</p>
                    </div>
                  ))}
                </div>
              </div>
              <div className="bl-rome-right">
                <div className="bl-rome-toasts">
                  {DAY.map((d, i) => (
                    <div key={d.img} data-i={i} className="bl-rome-item bl-toast bl-push" style={{ ['--a' as string]: i === 0 ? 1 : 0 }}>
                      {push(`${d.merchant} · ${t(d.what.uk, d.what.en)}`, d.amount, d.bal)}
                    </div>
                  ))}
                </div>
                <div className="bl-rome-card"><Card finish="guilloche" /></div>
              </div>
            </div>
          </div>
        </section>

        </div>

        {/* ── Tap. Paid.: the camera pushes in on the terminal, the tap rings out ── */}
        <TapScene
          src="/landing/pay-tap.webp"
          tapText={t('Дотик.', 'Tap.')}
          paidText={t('Оплачено.', 'Paid.')}
          toast={(
            <div className="bl-toast bl-push bl-toast-pay">{push('Saint Agnes', Number(shop[0]?.price) || 14490, 24000 - (Number(shop[0]?.price) || 14490))}</div>
          )}
        />

        {/* ── Six faces: a 3D cover-flow of the card designs ── */}
        <section id="card" className="bl-sec bl-faces">
          <div className="bl-faces-bg" aria-hidden>
            {FINISHES.map(f => <i key={f.id} className={f.id === finish ? 'on' : ''} style={{ backgroundImage: `url(${f.photo || '/cards/roma-colosseum-night.webp'})` }} />)}
          </div>
          <div className="bl-wrap bl-center">
            <h2 className="bl-h bl-rv">{t('Шість облич.', 'Six faces.')}</h2>
            <div className="bl-rv">
              <FaceFlow count={FINISHES.length} active={FINISHES.findIndex(f => f.id === finish)} onChange={i => setFinish(FINISHES[i].id)}
                renderCard={i => <Card finish={FINISHES[i].id} />} labelPrev={t('Попередня картка', 'Previous card')} labelNext={t('Наступна картка', 'Next card')} />
            </div>
            <div className="bl-thumbs bl-rv" role="radiogroup" aria-label={t('Оздоблення', 'Design')}>
              {FINISHES.map(f => (
                <button key={f.id} type="button" role="radio" aria-checked={finish === f.id} aria-label={t(f.uk, f.en)} className={`bl-thumb${finish === f.id ? ' on' : ''}`} onClick={() => setFinish(f.id)}
                  style={f.photo ? { backgroundImage: `url(${f.photo})` } : undefined}>{!f.photo && <svg viewBox="0 0 100 100" aria-hidden><path d={CARD_ROSETTE} fill="none" stroke="#ffd400" strokeOpacity=".75" strokeWidth=".5" /></svg>}</button>
              ))}
            </div>
            <p className="bl-dot-name" key={finish}>{t(cur.uk, cur.en)}</p>
          </div>
        </section>

        {/* ── Saint Agnes: a cream lookbook page like the shop itself; the shoot on the left, four pieces priced in TAX ── */}
        <section id="shop" className="bl-shopx">
          <div className="bl-wrap">
            <div className="bl-shopx-head bl-rv">
              <p className="bl-shopx-kick">Saint Agnes × TaxTech</p>
              <h2 className="bl-h bl-h-xl">{t('Одягайтесь за TAX.', 'Dress in TAX.')}</h2>
              <p className="bl-shopx-sub">{t('Осінь від Saint Agnes. Ціни в TAX, платите карткою з цієї сторінки.', 'The Saint Agnes autumn edit. Priced in TAX, paid with the card from this page.')}</p>
            </div>
            <div className="bl-shopx-grid">
              <a className="bl-shopx-look bl-rv" href={SHOP_URL} target="_blank" rel="noreferrer" aria-label="Saint Agnes">
                <img src="/shop/hero-autumn.webp" alt="" loading="lazy" decoding="async" />
                <span className="bl-shopx-tag">{t('Осінь · лукбук', 'Autumn · lookbook')}</span>
                <div className="bl-toast bl-push bl-shopx-paid">{push('Saint Agnes', Number(shop[0]?.price) || 14490, 24000 - (Number(shop[0]?.price) || 14490))}</div>
              </a>
              <div className="bl-shopx-list bl-rv">
                {(shop.length ? shop : Array.from({ length: 4 }, (_, i) => ({ id: -i } as ShopItem))).map(p => {
                  const name = p.title ? p.title.replace(/\s*\([^)]*\)\s*$/, '') : '';
                  const brand = name.match(/\s([A-Z0-9][A-Z0-9 .&'-]+)$/)?.[1] || '';
                  return (
                    <a key={p.id} className="bl-shopx-item" href={SHOP_URL} target="_blank" rel="noreferrer">
                      <div className="bl-shopx-img">{p.image_url && <img src={p.image_url} alt="" loading="lazy" decoding="async" />}</div>
                      <small>{brand || '\u00a0'}</small>
                      <span>{(brand ? name.slice(0, -brand.length) : name).trim() || '\u00a0'}</span>
                      <b>{p.price ? <>{fmt(Number(p.price))} <em>TAX</em></> : '\u00a0'}</b>
                    </a>
                  );
                })}
              </div>
            </div>
            <div className="bl-shopx-foot bl-rv"><a className="bl-pill bl-pill-dark" href={SHOP_URL} target="_blank" rel="noreferrer">{t('До магазину', 'Visit the shop')} ›</a></div>
          </div>
        </section>

        {/* ── Final CTA: the Colosseum at blue hour ── */}
        <section className="bl-scene bl-final">
          <FireScene className="bl-photo bl-photo-final" src="/landing/colosseum-sun.webp" ratio={1.504} focusX={0.12} focusY={0.5} spots={SUN_SPOTS} embers={50} />
          <div className="bl-wrap bl-center">
            <h2 className="bl-h bl-h-xl bl-rv">{t('Ваша картка чекає.', 'Your card is waiting.')}</h2>
            <div className="bl-cta bl-rv">
              <button type="button" className="bl-pill" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-ghost" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
            </div>
          </div>
        </section>

        <section className="bl-sec bl-sec-faq">
          <div className="bl-wrap bl-faq-wrap">
            <h2 className="bl-h bl-rv">{t('Питання.', 'Questions.')}</h2>
            <div className="bl-faq bl-rv">
              {FAQ.map(g => (
                <div className="bl-faq-group" key={g.title.en}>
                  <h3>{g.title[lang]}</h3>
                  {g.items.map(it => <details key={it.q.en}><summary>{it.q[lang]}</summary><p>{it.a[lang]}</p></details>)}
                </div>
              ))}
            </div>
          </div>
        </section>

        <footer className="bl-foot">
          <div className="bl-wrap">
            <p className="bl-legal">{t('TaxTech є навчальним банком лабораторії цифрових фінансів. TAX є віртуальним токеном: він не є грошима чи електронними грошима й не обмінюється на гривню чи іншу валюту. Справжніх платежів, карток і рахунків немає; номери карток починаються з 0000. Платформа не сертифікована EMVCo, PCI DSS чи FIDO. Face ID є торговельною маркою Apple Inc.', 'TaxTech is the training bank of a digital-finance lab. TAX is a virtual token: it is not money or e-money and cannot be exchanged for hryvnia or any other currency. There are no real payments, cards or accounts; card numbers start with 0000. The platform is not certified by EMVCo, PCI DSS or FIDO. Face ID is a trademark of Apple Inc.')}</p>
            <p className="bl-credits">{t('Фото', 'Photos')}: <a href="https://commons.wikimedia.org/wiki/File:Early_morning_Colosseo_-_Flickr_-_radkuch.13.jpg" target="_blank" rel="noreferrer">Radek Kucharski</a> (CC BY 2.0) · <a href="https://commons.wikimedia.org/wiki/File:Sunset_trough_the_arches_of_the_Colosseum,_Rome.jpg" target="_blank" rel="noreferrer">Quentin Lowagie</a> (CC BY 4.0) · <a href="https://commons.wikimedia.org/wiki/File:Sunset_over_Roman_Forum_(45485877135).jpg" target="_blank" rel="noreferrer">Sonse</a> (CC BY 2.0) · <a href="https://commons.wikimedia.org/wiki/File:Pantheon_-_Rome_at_night.jpg" target="_blank" rel="noreferrer">DeveshT</a> (CC0) · <a href="https://commons.wikimedia.org/wiki/File:Trevi_Fountain_Long_Exposure.jpg" target="_blank" rel="noreferrer">miketnorton</a> (CC BY 2.0) · <a href="https://unsplash.com/photos/payment-is-being-made-with-a-credit-card-AAYpF9Vx7Ek" target="_blank" rel="noreferrer">SumUp / Unsplash</a> · {t('Карта', 'Map')}: <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">© OpenStreetMap</a></p>
            <div className="bl-foot-row">
              <span>© {new Date().getFullYear()} TaxTech &amp; Munister</span>
              <nav>{nav.map(([h, x]) => <a key={h} href={h}>{x}</a>)}</nav>
              {langSwitch}
            </div>
          </div>
        </footer>
      </div>
    </LandingLangContext.Provider>
  );
}
