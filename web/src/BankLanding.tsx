import { useEffect, useMemo, useRef, useState } from 'react';
import { LandingLangContext, initialLandingLang, saveLandingLang, type LandingLang } from './landingLang';
import { Arcade, Laurel, ROMAN_YEAR, toRoman } from './roman';
import './bankLanding.css';

// Logged-out landing. It shows the product itself: real iPhone screens of the app (web/public/landing/), the same
// guilloche rosette and engraved medallions as the app, the Rome card photos from web/public/cards/ and live
// Saint Agnes products. Black and signal yellow like the app, a cream section like the shop. Research: docs/RESEARCH.md.

const DOCS_URL = 'https://github.com/munister-v/taxtech/blob/main/docs/RESEARCH.md';
const SHOP_URL = 'https://shop.munister.com.ua/';
// Same rates and formula as server/backend/services/deposit_service.py and credit_service.py.
const DEPOSIT_RATES: Record<number, number> = { 1: 8, 3: 10, 6: 12, 12: 14 };
// Hand-picked Saint Agnes pieces, in this order (coat, teddy jacket, tweed cardigan, check jacket).
const SHOP_PICKS = ['munister-81921', 'munister-83171', 'munister-81907', 'munister-83168'];

// Card designs: the guilloche default plus the Rome photographs the app offers under "Вигляд".
type Finish = 'guilloche' | 'colosseum-night' | 'pantheon' | 'forum' | 'aqueduct' | 'marble';
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
function Eyebrow({ n, children, className = '' }: { n?: number; children: React.ReactNode; className?: string }) {
  return <p className={`bl-eyebrow ${className}`}>{n ? <><b>{toRoman(n)}</b><i aria-hidden /></> : null}{children}</p>;
}

function Card({ finish, n = '6595' }: { finish: Finish; n?: string }) {
  const f = FINISHES.find(x => x.id === finish)!;
  return (
    <div className={`bl-card${f.photo ? ' bl-card-photo' : ' bl-card-guil'}`} style={f.photo ? { backgroundImage: `url(${f.photo})` } : undefined}>
      {!f.photo && <svg className="bl-card-ros" viewBox="0 0 100 100" aria-hidden><path d={CARD_ROSETTE} fill="none" stroke="#fff" strokeOpacity=".55" strokeWidth=".18" /></svg>}
      <span className="bl-card-shade" aria-hidden />
      <span className="bl-card-sheen" aria-hidden />
      <span className="bl-card-brand">TAXTECH</span>
      <svg className="bl-card-nfc" viewBox="0 0 24 24" aria-hidden><path d="M8.5 7.5a6 6 0 0 1 0 9M12 5a9.5 9.5 0 0 1 0 14M15.5 2.5a13 13 0 0 1 0 19" /></svg>
      <span className="bl-card-chip" aria-hidden />
      <span className="bl-card-num">•••• •••• •••• {n}</span>
      <span className="bl-card-name">DEMO USER</span>
      <span className="bl-card-virt">VIRTUAL</span>
    </div>
  );
}

/** Eases a displayed number towards its target, so the deposit gain rolls instead of jumping. */
function useTween(target: number) {
  const [v, setV] = useState(target);
  const from = useRef(target);
  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) { from.current = target; setV(target); return; }
    const a = from.current, t0 = performance.now();
    let raf = 0;
    const step = (now: number) => {
      const k = Math.min(1, (now - t0) / 650);
      const cur = a + (target - a) * (1 - Math.pow(1 - k, 3));
      from.current = cur; setV(cur);
      if (k < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [target]);
  return v;
}

export default function BankLanding({ onAuth }: { onAuth: (m: 'login' | 'register') => void }) {
  const rootRef = useRef<HTMLDivElement | null>(null);
  const [lang, setLang] = useState<LandingLang>(initialLandingLang);
  const [scrolled, setScrolled] = useState(false);
  const [menu, setMenu] = useState(false);
  const [finish, setFinish] = useState<Finish>('guilloche');
  const [term, setTerm] = useState(12);
  const [amount, setAmount] = useState(50000);
  const [shop, setShop] = useState<ShopItem[]>([]);
  const t = (uk: string, en: string) => (lang === 'en' ? en : uk);

  useEffect(() => {
    const id = window.setTimeout(() => { document.documentElement.lang = lang; }, 0);
    saveLandingLang(lang);
    document.title = lang === 'en' ? 'TaxTech · card, account and shop in one app' : 'TaxTech · картка, рахунок і магазин в одному застосунку';
    return () => { window.clearTimeout(id); document.documentElement.lang = 'uk'; };
  }, [lang]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    root.classList.add('bl-js');
    const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { root, threshold: 0.12 });
    root.querySelectorAll('.bl-rv').forEach(el => io.observe(el));
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const photos = Array.from(root.querySelectorAll<HTMLElement>('.bl-photo, .bl-paystage-photo, .bl-hero-photo'));
    const hero = root.querySelector<HTMLElement>('.bl-hero');
    let raf = 0;
    // Photos drift slower than the page (parallax), the hero lets go as you leave it, a gold hairline tracks progress.
    const frame = () => {
      raf = 0;
      const box = root.getBoundingClientRect();
      const max = root.scrollHeight - root.clientHeight;
      root.style.setProperty('--sp', (max > 0 ? root.scrollTop / max : 0).toFixed(4));
      if (still) return;
      for (const el of photos) {
        const sec = el.parentElement;
        if (!sec) continue;
        const r = sec.getBoundingClientRect();
        if (r.bottom < box.top - 150 || r.top > box.bottom + 150) continue;
        const lim = el.offsetHeight * (el.classList.contains('bl-hero-photo') ? 0.04 : 0.08);
        const d = (r.top + r.height / 2) - (box.top + box.height / 2);
        el.style.setProperty('--py', `${Math.max(-lim, Math.min(lim, -d * 0.1)).toFixed(1)}px`);
      }
      if (hero) hero.style.setProperty('--hp', Math.max(0, Math.min(1, root.scrollTop / (hero.offsetHeight * 0.75))).toFixed(3));
    };
    const onScroll = () => { setScrolled(root.scrollTop > 10); if (!raf) raf = requestAnimationFrame(frame); };
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

  const days = useMemo(() => { const a = new Date(); const b = new Date(a); b.setMonth(b.getMonth() + term); return Math.round((b.getTime() - a.getTime()) / 86400000); }, [term]);
  const gain = Math.round(amount * DEPOSIT_RATES[term] / 100 * days / 365 * 100) / 100;
  const shownGain = useTween(gain);
  const cur = FINISHES.find(f => f.id === finish)!;

  const nav: [string, string][] = [['#pay', t('Оплата', 'Pay')], ['#card', t('Картки', 'Cards')], ['#save', t('Депозит', 'Deposit')], ['#security', t('Безпека', 'Security')], ['#shop', 'Saint Agnes']];
  const faq: [string, string][] = [
    [t('Що таке TaxTech?', 'What is TaxTech?'), t('Навчальний цифровий банк лабораторії цифрових фінансів і платіжний партнер Saint Agnes. Рахунок, картки, перекази, депозити, кредит і антифрод працюють як у справжньому банку, але на віртуальних грошах.', 'The training digital bank of a digital-finance lab and the payment partner of Saint Agnes. Accounts, cards, transfers, deposits, credit and fraud checks work as in a real bank, but with virtual money.')],
    [t('Що таке TAX?', 'What is TAX?'), t('Віртуальний токен банку. Він не є грошима чи електронними грошима й не обмінюється на гривню. Справжні картки й рахунки не прив’язуються, тож втратити реальні гроші неможливо.', 'The bank’s virtual token. It is not money or e-money and cannot be exchanged for hryvnia. No real cards or accounts are linked, so there is no way to lose real money.')],
    [t('Як відкрити рахунок?', 'How do I open an account?'), t('Вкажіть телефон або email і пароль. Рахунок і перша картка з’являються одразу; потім можна додати passkey і входити за Face ID.', 'Enter a phone number or email and a password. The account and your first card appear at once; then add a passkey and sign in with Face ID.')],
    [t('Як працює захист від шахрайства?', 'How does fraud protection work?'), t('Кожен переказ ще до списання проходить 28 правил у трьох шарах: сама операція, ваша історія і граф переказів між клієнтами. Онлайн-оплату підтверджує код 3-D Secure.', 'Before any money moves, every transfer passes 28 rules in three layers: the transaction itself, your history and the transfer graph between customers. Online payments are confirmed with a 3-D Secure code.')],
  ];
  const langSwitch = (
    <div className="bl-lang" role="group" aria-label={t('Мова', 'Language')}>
      <button type="button" className={lang === 'en' ? 'on' : ''} aria-pressed={lang === 'en'} onClick={() => setLang('en')}>EN</button>
      <button type="button" className={lang === 'uk' ? 'on' : ''} aria-pressed={lang === 'uk'} onClick={() => setLang('uk')}>UA</button>
    </div>
  );

  return (
    <LandingLangContext.Provider value={lang}>
      <div className="bl" ref={rootRef}>
        <div className="bl-progress" aria-hidden />
        <header className={`bl-nav${scrolled ? ' s' : ''}`}>
          <div className="bl-wrap bl-nav-in">
            <a href="#top" className="bl-logo">TAXTECH</a>
            <nav className="bl-links" aria-label={t('Розділи', 'Sections')}>{nav.map(([h, x]) => <a key={h} href={h}>{x}</a>)}</nav>
            <div className="bl-nav-r">
              {langSwitch}
              <button type="button" className="bl-nav-in-btn" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              <button type="button" className="bl-pill bl-pill-sm" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open account')}</button>
              <button type="button" className="bl-burger" aria-label={t('Меню', 'Menu')} aria-expanded={menu} onClick={() => setMenu(v => !v)}>
                <svg viewBox="0 0 24 24" aria-hidden>{menu ? <path d="M6 6l12 12M18 6 6 18" /> : <path d="M4 9h16M4 15h16" />}</svg>
              </button>
            </div>
          </div>
        </header>
        {menu && (
          <div className="bl-sheet" onClick={() => setMenu(false)}>
            <nav className="bl-wrap">
              {nav.map(([h, x], i) => <a key={h} href={h} style={{ ['--i' as string]: i }}>{x}</a>)}
              <button type="button" className="bl-pill" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-more" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')} ›</button>
              {langSwitch}
            </nav>
          </div>
        )}

        {/* ── Hero: a real photograph of Rome at dusk ── */}
        <section id="top" className="bl-hero">
          <div className="bl-hero-photo" style={{ backgroundImage: 'url(/landing/rome-colosseum-night.webp)' }} aria-hidden />
          <div className="bl-wrap bl-hero-in">
            <p className="bl-eyebrow bl-eyebrow-hero"><Laurel size={34} />Roma · {ROMAN_YEAR}</p>
            <h1>{t('Платіть, як у Римі.', 'Pay like Rome.')}</h1>
            <div className="bl-cta">
              <button type="button" className="bl-pill" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-ghost" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
            </div>
          </div>
          <div className="bl-hero-pay" aria-hidden>
            <div className="bl-toast bl-toast-loop">
              <Medallion tint="#4fd18b">{IC.check}</Medallion>
              <div><b>Roma · Colosseo</b><span>{t('Оплачено', 'Paid')}</span></div>
              <strong>−850 <small>TAX</small></strong>
            </div>
            <div className="bl-hero-card"><Card finish="guilloche" /></div>
          </div>
        </section>

        {/* ── Pay scene: a Saint Agnes shoot with the checkout over it ── */}
        <section id="pay" className="bl-sec bl-pay">
          <div className="bl-wrap bl-center">
            <Eyebrow n={1} className="bl-rv">{t('Оплата', 'Pay')}</Eyebrow>
            <h2 className="bl-h bl-rv">{t('Дотик. Оплачено.', 'Tap. Paid.')}</h2>
          </div>
          <div className="bl-wrap">
            <div className="bl-paystage bl-rv">
              <div className="bl-paystage-photo" style={{ backgroundImage: 'url(/landing/pay-tap.webp)' }} aria-hidden />
              <div className="bl-toast bl-toast-loop bl-toast-pay">
                <Medallion tint="#4fd18b">{IC.check}</Medallion>
                <div><b>Saint Agnes</b><span>{t('Оплачено', 'Paid')}</span></div>
                <strong>−{shop[0]?.price ? fmt(Number(shop[0].price)) : '14 490'} <small>TAX</small></strong>
              </div>
            </div>
          </div>
        </section>

        {/* ── Card designs ── */}
        <section id="card" className="bl-sec bl-sec-photo" style={{ ['--bg-photo' as string]: `url(${cur.photo || '/cards/roma-colosseum-night.webp'})` }}>
          <div className="bl-wrap bl-center">
            <Eyebrow n={2} className="bl-rv">{t('Картки', 'Cards')}</Eyebrow>
            <h2 className="bl-h bl-rv">{t('Шість облич.', 'Six faces.')}</h2>
            <div className="bl-stage bl-rv">
              <div className="bl-stage-card" key={finish}><Card finish={finish} /></div>
            </div>
            <div className="bl-thumbs bl-rv" role="radiogroup" aria-label={t('Оздоблення', 'Design')}>
              {FINISHES.map(f => (
                <button key={f.id} type="button" role="radio" aria-checked={finish === f.id} aria-label={t(f.uk, f.en)} className={`bl-thumb${finish === f.id ? ' on' : ''}`} onClick={() => setFinish(f.id)}
                  style={f.photo ? { backgroundImage: `url(${f.photo})` } : undefined}>{!f.photo && <svg viewBox="0 0 100 100" aria-hidden><path d={CARD_ROSETTE} fill="none" stroke="#fff" strokeOpacity=".7" strokeWidth=".5" /></svg>}</button>
              ))}
            </div>
            <p className="bl-dot-name">{t(cur.uk, cur.en)}</p>
          </div>
        </section>

        {/* ── Deposit: sunset over the Forum ── */}
        <section id="save" className="bl-scene bl-save">
          <div className="bl-photo bl-photo-warm" style={{ backgroundImage: 'url(/landing/rome-forum-sunset.webp)' }} aria-hidden />
          <div className="bl-wrap bl-center">
            <Eyebrow n={3} className="bl-rv">{t('Депозит', 'Deposit')}</Eyebrow>
            <div className="bl-calc-big bl-rv"><span>+{fmt(shownGain, 0)}<em>TAX</em></span><small>{t('за', 'in')} {term} {t('міс', 'months')} · {DEPOSIT_RATES[term]}%</small></div>
            <div className="bl-calc bl-rv">
              <div className="bl-seg" role="group" aria-label={t('Строк', 'Term')}>
                {Object.keys(DEPOSIT_RATES).map(Number).map(m => (
                  <button key={m} type="button" className={m === term ? 'on' : ''} aria-pressed={m === term} onClick={() => setTerm(m)}>{m} {t('міс', 'mo')}</button>
                ))}
              </div>
              <label className="bl-range">
                <input type="range" min={1000} max={500000} step={1000} value={amount} aria-label={t('Сума', 'Amount')} style={{ ['--p' as string]: `${((amount - 1000) / 499000) * 100}%` }} onChange={e => setAmount(+e.target.value)} />
                <span><b>{fmt(amount)} TAX</b></span>
              </label>
              <button type="button" className="bl-pill" onClick={() => onAuth('register')}>{t('Відкрити депозит', 'Open a deposit')}</button>
            </div>
          </div>
        </section>

        {/* ── Security: the Pantheon at night ── */}
        <section id="security" className="bl-scene bl-secure">
          <div className="bl-photo" style={{ backgroundImage: 'url(/landing/rome-pantheon-night.webp)' }} aria-hidden />
          <div className="bl-wrap bl-center">
            <Eyebrow n={4} className="bl-rv">{t('Безпека', 'Security')}</Eyebrow>
            <h2 className="bl-h bl-h-xl bl-rv">{t('28 замків.', '28 locks.')}</h2>
            <div className="bl-layers bl-rv">
              {[[t('Операція', 'The transaction'), '5'], [t('Ваша історія', 'Your history'), '12'], [t('Граф переказів', 'Transfer graph'), '11']].map(([a, b]) => (
                <div key={a}><b>{b}</b><span>{a}</span></div>
              ))}
            </div>
          </div>
        </section>

        {/* ── Saint Agnes: the shoot, the pieces ── */}
        <section id="shop" className="bl-scene bl-shopscene">
          <div className="bl-photo bl-photo-shop" style={{ backgroundImage: 'url(/shop/hero-autumn.webp)' }} aria-hidden />
          <div className="bl-wrap bl-center">
            <Eyebrow n={5} className="bl-rv">Saint Agnes × TaxTech</Eyebrow>
            <h2 className="bl-h bl-h-xl bl-rv">{t('Одягайтесь за TAX.', 'Dress in TAX.')}</h2>
            <div className="bl-shop bl-rv">
              {(shop.length ? shop : Array.from({ length: 4 }, (_, i) => ({ id: -i } as ShopItem))).map(p => (
                <a key={p.id} className="bl-prod" href={SHOP_URL} target="_blank" rel="noreferrer">
                  <div className="bl-prod-img" style={p.image_url ? { backgroundImage: `url(${p.image_url})` } : undefined} />
                  <span>{p.title ? p.title.replace(/\s*\([^)]*\)\s*$/, '') : ' '}</span>
                  <b>{p.price ? `${fmt(Number(p.price))} TAX` : ' '}</b>
                </a>
              ))}
            </div>
            <div className="bl-cta bl-rv"><a className="bl-pill" href={SHOP_URL} target="_blank" rel="noreferrer">{t('До магазину', 'Visit the shop')}</a></div>
          </div>
        </section>

        {/* ── Final CTA: the Colosseum at blue hour ── */}
        <section className="bl-scene bl-final">
          <div className="bl-photo bl-photo-final" style={{ backgroundImage: 'url(/landing/rome-colosseum-day.webp)' }} aria-hidden />
          <div className="bl-wrap bl-center">
            <Laurel size={88} className="bl-cta-laurel" />
            <p className="bl-inscr bl-inscr-top">Fides · Prvdentia · Libertas</p>
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
              {faq.map(([q, a]) => <details key={q}><summary>{q}</summary><p>{a}</p></details>)}
              <a className="bl-more" href={DOCS_URL} target="_blank" rel="noreferrer">{t('Дослідження TaxTech: телефон чи хмара для ІІ-задач', 'TaxTech research: phone or cloud for AI tasks')} ›</a>
            </div>
          </div>
        </section>

        <footer className="bl-foot">
          <Arcade className="bl-arcade" opacity={0.5} />
          <div className="bl-wrap">
            <p className="bl-inscr bl-inscr-foot">TaxTech · Argentaria Virtvalis · Anno {ROMAN_YEAR}</p>
            <p className="bl-legal">{t('TaxTech є навчальним банком лабораторії цифрових фінансів. TAX є віртуальним токеном: він не є грошима чи електронними грошима й не обмінюється на гривню чи іншу валюту. Справжніх платежів, карток і рахунків немає; номери карток починаються з 0000. Платформа не сертифікована EMVCo, PCI DSS чи FIDO. Face ID є торговельною маркою Apple Inc.', 'TaxTech is the training bank of a digital-finance lab. TAX is a virtual token: it is not money or e-money and cannot be exchanged for hryvnia or any other currency. There are no real payments, cards or accounts; card numbers start with 0000. The platform is not certified by EMVCo, PCI DSS or FIDO. Face ID is a trademark of Apple Inc.')}</p>
            <p className="bl-credits">{t('Фото', 'Photos')}: <a href="https://commons.wikimedia.org/wiki/File:Colosseum_at_night_01.jpg" target="_blank" rel="noreferrer">John Samuel</a> (CC BY-SA 4.0) · <a href="https://commons.wikimedia.org/wiki/File:Pantheon_-_Rome_at_night.jpg" target="_blank" rel="noreferrer">DeveshT</a> (CC0) · <a href="https://commons.wikimedia.org/wiki/File:Sunset_over_Roman_Forum_(45485877135).jpg" target="_blank" rel="noreferrer">Sonse</a> (CC BY 2.0) · <a href="https://commons.wikimedia.org/wiki/File:Colosseum_in_Rome,_Italy_-_April_2007.jpg" target="_blank" rel="noreferrer">Diliff</a> (CC BY-SA 2.5) · <a href="https://unsplash.com/photos/payment-is-being-made-with-a-credit-card-AAYpF9Vx7Ek" target="_blank" rel="noreferrer">SumUp / Unsplash</a></p>
            <div className="bl-foot-row">
              <span>© {new Date().getFullYear()} TaxTech &amp; Munister</span>
              <nav>{nav.map(([h, x]) => <a key={h} href={h}>{x}</a>)}<a href={DOCS_URL} target="_blank" rel="noreferrer">{t('Дослідження', 'Research')}</a><a href="https://github.com/munister-v/taxtech" target="_blank" rel="noreferrer">GitHub</a></nav>
              {langSwitch}
            </div>
          </div>
        </footer>
      </div>
    </LandingLangContext.Provider>
  );
}
