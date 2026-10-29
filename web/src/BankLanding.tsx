import { useEffect, useMemo, useRef, useState } from 'react';
import markSvg from './assets/mark.svg?raw';
import { LandingLangContext, initialLandingLang, saveLandingLang, type LandingLang } from './landingLang';
import './bankLanding.css';

// Logged-out landing: the training bank shown as a premium product. The research write-up lives in docs/RESEARCH.md.

const DOCS_URL = 'https://github.com/munister-v/taxtech/blob/main/docs/RESEARCH.md';
// Same rates and formula as server/backend/services/deposit_service.py and credit_service.py.
const DEPOSIT_RATES: Record<number, number> = { 1: 8, 3: 10, 6: 12, 12: 14 };
const CREDIT_RATES: Record<number, number> = { 3: 18, 6: 20, 12: 22, 24: 24, 36: 26 };

const CARDS = [
  { img: 'roma-colosseum-night', uk: 'Колізей уночі', en: 'Colosseum by night', n: '6897' },
  { img: 'roma-pantheon', uk: 'Пантеон', en: 'Pantheon', n: '2214' },
  { img: 'roma-forum', uk: 'Форум', en: 'Forum', n: '5530' },
  { img: 'roma-marble', uk: 'Мармур', en: 'Marble', n: '0418' },
  { img: 'roma-aqueduct', uk: 'Акведук', en: 'Aqueduct', n: '7761' },
  { img: 'roma-colosseum', uk: 'Колізей', en: 'Colosseum', n: '3302' },
];

const fmt = (n: number, d = 0) => n.toLocaleString('uk-UA', { minimumFractionDigits: d, maximumFractionDigits: d }).replace(/ /g, ' ');

function addMonthsDays(months: number) {
  const a = new Date(); const b = new Date(a); b.setMonth(b.getMonth() + months);
  return Math.round((b.getTime() - a.getTime()) / 86400000);
}

function Mark({ size = 20 }: { size?: number }) {
  return <span className="bl-mark" style={{ width: size, height: size }} aria-hidden dangerouslySetInnerHTML={{ __html: markSvg.replace('<svg ', '<svg style="width:100%;height:100%" ') }} />;
}

function Card({ img, n, label, holder = 'TAXTECH MEMBER' }: { img: string; n: string; label: string; holder?: string }) {
  return (
    <div className="bl-card" style={{ backgroundImage: `url(/cards/${img}.webp)` }}>
      <div className="bl-card-shade" />
      <div className="bl-card-sheen" />
      <div className="bl-card-top">
        <span className="bl-card-brand"><Mark size={16} /> TaxTech</span>
        <svg className="bl-card-nfc" viewBox="0 0 24 24" aria-hidden><path d="M8.5 7.5a6 6 0 0 1 0 9M12 5a9.5 9.5 0 0 1 0 14M15.5 2.5a13 13 0 0 1 0 19" /></svg>
      </div>
      <div className="bl-card-chip" aria-hidden />
      <div className="bl-card-num">0000 •••• •••• {n}</div>
      <div className="bl-card-bot">
        <div><small>{holder}</small><b>{label}</b></div>
        <span className="bl-card-tier">ROMA</span>
      </div>
    </div>
  );
}

function useCount(target: number, run: boolean, ms = 1600) {
  const [v, setV] = useState(0);
  useEffect(() => {
    if (!run) return;
    let raf = 0; const t0 = performance.now();
    const tick = (t: number) => {
      const p = Math.min(1, (t - t0) / ms);
      setV(target * (1 - Math.pow(1 - p, 4)));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, run, ms]);
  return v;
}

function DepositCalc({ t }: { t: (uk: string, en: string) => string }) {
  const [term, setTerm] = useState(12);
  const [amount, setAmount] = useState(50000);
  const rate = DEPOSIT_RATES[term];
  const days = useMemo(() => addMonthsDays(term), [term]);
  const gain = Math.round(amount * rate / 100 * days / 365 * 100) / 100;
  const pts = Array.from({ length: 13 }, (_, i) => {
    const x = (i / 12) * 300;
    const y = 92 - Math.pow(i / 12, 1.6) * (rate / 14) * 80;
    return `${x.toFixed(1)},${Math.max(6, y).toFixed(1)}`;
  });
  return (
    <div className="bl-calc">
      <div className="bl-seg" role="group" aria-label={t('Строк', 'Term')}>
        {Object.keys(DEPOSIT_RATES).map(Number).map(m => (
          <button key={m} type="button" className={m === term ? 'on' : ''} aria-pressed={m === term} onClick={() => setTerm(m)}>
            {m} {t('міс', 'mo')}<span>{DEPOSIT_RATES[m]}%</span>
          </button>
        ))}
      </div>
      <label className="bl-range">
        <span>{t('Сума', 'Amount')}<b>{fmt(amount)} TAX</b></span>
        <input type="range" min={1000} max={500000} step={1000} value={amount} style={{ ['--p' as string]: `${((amount - 1000) / 499000) * 100}%` }} onChange={e => setAmount(+e.target.value)} />
      </label>
      <svg className="bl-calc-chart" viewBox="0 0 300 100" preserveAspectRatio="none" aria-hidden>
        <defs><linearGradient id="blg" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stopColor="#e6d3a8" stopOpacity=".22" /><stop offset="1" stopColor="#f4d58d" stopOpacity="0" /></linearGradient></defs>
        <polygon points={`0,100 ${pts.join(' ')} 300,100`} fill="url(#blg)" />
        <polyline points={pts.join(' ')} fill="none" stroke="#e6d3a8" strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
      </svg>
      <div className="bl-calc-out">
        <div><small>{t('Дохід', 'You earn')}</small><b className="bl-gold">+{fmt(gain, 2)}</b></div>
        <div><small>{t('Наприкінці', 'At maturity')}</small><b>{fmt(amount + gain, 2)}</b></div>
      </div>
    </div>
  );
}

export default function BankLanding({ onAuth }: { onAuth: (m: 'login' | 'register') => void }) {
  const rootRef = useRef<HTMLDivElement | null>(null);
  const sceneRef = useRef<HTMLDivElement | null>(null);
  const [lang, setLang] = useState<LandingLang>(initialLandingLang);
  const [scrolled, setScrolled] = useState(false);
  const [menu, setMenu] = useState(false);
  const [ready, setReady] = useState(false);
  const [statsOn, setStatsOn] = useState(false);
  const statsRef = useRef<HTMLDivElement | null>(null);
  const t = (uk: string, en: string) => (lang === 'en' ? en : uk);

  useEffect(() => {
    const id = window.setTimeout(() => { document.documentElement.lang = lang; }, 0);
    saveLandingLang(lang);
    document.title = lang === 'en' ? 'TaxTech · private banking, reimagined' : 'TaxTech · банкінг нового рівня';
    return () => { window.clearTimeout(id); document.documentElement.lang = 'uk'; };
  }, [lang]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    root.classList.add('bl-js');
    const r = requestAnimationFrame(() => setReady(true));
    const io = new IntersectionObserver(es => es.forEach(e => {
      if (!e.isIntersecting) return;
      e.target.classList.add('in'); io.unobserve(e.target);
      if (e.target === statsRef.current) setStatsOn(true);
    }), { root, threshold: 0.16 });
    root.querySelectorAll('.bl-rv').forEach(el => io.observe(el));
    if (statsRef.current) io.observe(statsRef.current);
    const onScroll = () => {
      setScrolled(root.scrollTop > 12);
      root.style.setProperty('--sy', String(root.scrollTop));
    };
    root.addEventListener('scroll', onScroll, { passive: true });
    return () => { cancelAnimationFrame(r); io.disconnect(); root.removeEventListener('scroll', onScroll); };
  }, []);

  // Hero scene follows the pointer (desktop only; no-op on touch).
  const onMove = (e: React.PointerEvent) => {
    const s = sceneRef.current;
    if (!s || e.pointerType !== 'mouse') return;
    const b = s.getBoundingClientRect();
    const x = (e.clientX - b.left) / b.width - 0.5, y = (e.clientY - b.top) / b.height - 0.5;
    s.style.setProperty('--rx', `${(-y * 10).toFixed(2)}deg`);
    s.style.setProperty('--ry', `${(x * 14).toFixed(2)}deg`);
    s.style.setProperty('--mx', `${((x + 0.5) * 100).toFixed(1)}%`);
    s.style.setProperty('--my', `${((y + 0.5) * 100).toFixed(1)}%`);
  };
  const onLeave = () => { const s = sceneRef.current; if (s) { s.style.setProperty('--rx', '0deg'); s.style.setProperty('--ry', '0deg'); } };

  const balance = useCount(167504.68, ready, 2200);
  const s1 = useCount(28, statsOn), s2 = useCount(454, statsOn), s3 = useCount(14, statsOn), s4 = useCount(6, statsOn);

  const nav: [string, string][] = [['#cards', t('Картки', 'Cards')], ['#everyday', t('Щодня', 'Everyday')], ['#grow', t('Заощадження', 'Savings')], ['#security', t('Безпека', 'Security')], ['#faq', t('Питання', 'FAQ')]];
  const tx = [
    { i: 'CR', n: 'Café Roma', s: t('Кава', 'Coffee'), a: '−86,00' },
    { i: t('ОК', 'OK'), n: t('Олена К.', 'Olena K.'), s: t('Переказ', 'Transfer'), a: '+2 500,00', pos: true },
    { i: 'SA', n: 'Saint Agnes', s: t('Покупки', 'Shopping'), a: '−4 290,00' },
  ];
  const faq: [string, string][] = [
    [t('Що таке TaxTech?', 'What is TaxTech?'),
      t('Навчальний цифровий банк: рахунок, картки, перекази, депозити, кредити, виписки й захист від шахрайства працюють як у справжньому банку, але на віртуальних грошах. На ньому тестується наукова робота про вибір між телефоном і хмарою для ІІ-задач.', 'A training digital bank: accounts, cards, transfers, deposits, loans, statements and fraud protection work as in a real bank, but with virtual money. It is also the testbed for a research project on choosing between the phone and the cloud for AI tasks.')],
    [t('Що таке TAX і чи є ризик?', 'What is TAX, and is there any risk?'),
      t('TAX є віртуальним токеном навчального банку. Він не є грошима чи електронними грошима, не обмінюється на гривню, справжні картки й рахунки не прив’язуються. Втратити реальні гроші неможливо.', 'TAX is the virtual token of the training bank. It is not money or e-money, cannot be exchanged for hryvnia, and no real cards or accounts are linked. There is no way to lose real money.')],
    [t('Як відкрити рахунок?', 'How do I open an account?'),
      t('Натисніть «Відкрити рахунок», вкажіть телефон або email і пароль. Рахунок у TAX і перша картка з’являються одразу. Потім можна додати passkey і входити за Face ID.', 'Tap Open an account and enter a phone number or email and a password. Your TAX account and first card appear at once. Then add a passkey and sign in with Face ID.')],
    [t('Як працює захист від шахрайства?', 'How does fraud protection work?'),
      t('Кожен переказ ще до списання проходить 28 правил у трьох шарах: сама операція, ваша історія і граф переказів між клієнтами. Підозрілий переказ зупиняється, а оплати підтверджуються кодом 3-D Secure.', 'Before any money moves, every transfer passes 28 rules in three layers: the transaction itself, your history and the transfer graph between customers. A suspicious transfer is stopped, and payments are confirmed with a 3-D Secure code.')],
    [t('Які дані про мене збираються?', 'What data is collected about me?'),
      t('Тільки те, що потрібно для рахунку, і журнал технічних рішень застосунку без текстів запитів, фото й відповідей. Фото чека розпізнається лише на телефоні, а особисті дані маскуються до відправки на сервер.', 'Only what the account needs, plus a log of the app’s technical decisions without request text, photos or answers. Receipt photos are read on the phone only, and personal data is redacted before anything reaches the server.')],
  ];
  const langSwitch = (
    <div className="bl-lang" role="group" aria-label={t('Мова', 'Language')}>
      <button type="button" className={lang === 'en' ? 'on' : ''} aria-pressed={lang === 'en'} onClick={() => setLang('en')}>EN</button>
      <button type="button" className={lang === 'uk' ? 'on' : ''} aria-pressed={lang === 'uk'} onClick={() => setLang('uk')}>UA</button>
    </div>
  );
  const marquee = [t('Face ID і passkey', 'Face ID & passkeys'), '3-D Secure', t('28 правил антифроду', '28 fraud rules'), t('Перекази за секунду', 'Instant transfers'), t('Депозит до 14%', 'Deposits up to 14%'), t('PDF-виписки', 'PDF statements'), t('Чеки розпізнаються на телефоні', 'Receipts read on-device'), t('Колекція карток Roma', 'Roma card collection'), t('Оплата в один дотик', 'One-tap payments')];

  return (
    <LandingLangContext.Provider value={lang}>
      <div className="bl" ref={rootRef}>
        <div className="bl-aurora" aria-hidden><i /><i /><i /></div>
        <div className="bl-grain" aria-hidden />

        <header className={`bl-nav${scrolled ? ' bl-nav-s' : ''}`}>
          <div className="bl-wrap bl-nav-in">
            <a href="#top" className="bl-logo"><Mark size={22} /><span>Tax<em>Tech</em></span></a>
            <nav className="bl-links" aria-label={t('Розділи', 'Sections')}>
              {nav.map(([h, x]) => <a key={h} href={h}>{x}</a>)}
            </nav>
            <div className="bl-nav-r">
              {langSwitch}
              <button type="button" className="bl-ghost" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              <button type="button" className="bl-btn bl-btn-sm" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open account')}</button>
              <button type="button" className="bl-burger" aria-label={t('Меню', 'Menu')} aria-expanded={menu} onClick={() => setMenu(v => !v)}>
                <svg viewBox="0 0 24 24" aria-hidden>{menu ? <path d="M6 6l12 12M18 6L6 18" /> : <path d="M4 9h16M4 15h16" />}</svg>
              </button>
            </div>
          </div>
        </header>
        {menu && (
          <div className="bl-sheet" onClick={() => setMenu(false)}>
            <nav className="bl-wrap" aria-label={t('Меню', 'Menu')}>
              {nav.map(([h, x], i) => <a key={h} href={h} style={{ ['--i' as string]: i }}>{x}</a>)}
              <button type="button" className="bl-btn" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-ghost" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              {langSwitch}
            </nav>
          </div>
        )}

        {/* ── Hero ── */}
        <section id="top" className={`bl-hero${ready ? ' on' : ''}`} onPointerMove={onMove} onPointerLeave={onLeave}>
          <div className="bl-wrap bl-hero-in">
            <div className="bl-hero-copy">
              <a className="bl-chip" href="#cards"><span className="bl-chip-dot" />{t('Нове: колекція карток Roma', 'New: the Roma card collection')}<span aria-hidden>→</span></a>
              <h1>
                <span className="bl-l">{t('Банкінг,', 'Banking,')}</span>
                <span className="bl-l">{t('який', 'beautifully')}</span>
                <span className="bl-l bl-gold">{t('вражає.', 'engineered.')}</span>
              </h1>
              <p className="bl-lead">{t('Рахунок, картки, перекази й депозити в одному застосунку, де кожен рух грошей захищено Face ID, 3-D Secure і розумним антифродом.', 'Accounts, cards, transfers and deposits in one app, with every move of money guarded by Face ID, 3-D Secure and intelligent fraud detection.')}</p>
              <div className="bl-cta">
                <button type="button" className="bl-btn bl-btn-lg" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}<span aria-hidden>→</span></button>
                <button type="button" className="bl-ghost bl-ghost-lg" onClick={() => onAuth('login')}>{t('У мене вже є акаунт', 'I have an account')}</button>
              </div>
              <ul className="bl-trust">
                <li><svg viewBox="0 0 24 24" aria-hidden><path d="M12 3l7 3v5c0 5-3 8.5-7 10-4-1.5-7-5-7-10V6l7-3Z" /><path d="M9 12l2 2 4-4" /></svg>{t('Антифрод до списання', 'Fraud checks before money moves')}</li>
                <li><svg viewBox="0 0 24 24" aria-hidden><rect x="5" y="10" width="14" height="10" rx="2.5" /><path d="M8 10V8a4 4 0 0 1 8 0v2" /></svg>3-D Secure</li>
                <li><svg viewBox="0 0 24 24" aria-hidden><path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M9.5 9v1.5M14.5 9v1.5M12 9v4h-1M9.5 15.5s1 1 2.5 1 2.5-1 2.5-1" /></svg>Face ID</li>
              </ul>
            </div>

            <div className="bl-scene" ref={sceneRef}>
              <div className="bl-scene-glow" />
              <div className="bl-tilt">
                <div className="bl-phone">
                  <div className="bl-phone-scr">
                    <div className="bl-ph-bar"><span>9:41</span><i /><span className="bl-ph-sig">●●●</span></div>
                    <div className="bl-ph-hi">{t('Доброго ранку, Олено', 'Good morning, Olena')}</div>
                    <div className="bl-ph-lbl">{t('Загальний баланс', 'Total balance')}</div>
                    <div className="bl-ph-bal">{fmt(Math.floor(balance))}<small>,{String(Math.round((balance % 1) * 100)).padStart(2, '0')}</small> <span>TAX</span></div>
                    <div className="bl-ph-delta">▲ +12,4% {t('за місяць', 'this month')}</div>
                    <svg className="bl-ph-spark" viewBox="0 0 200 50" preserveAspectRatio="none" aria-hidden>
                      <defs><linearGradient id="bls" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stopColor="#e6d3a8" stopOpacity=".18" /><stop offset="1" stopColor="#f4d58d" stopOpacity="0" /></linearGradient></defs>
                      <path d="M0 40 C 20 38, 30 30, 50 32 S 80 22, 100 24 S 130 12, 150 16 S 180 6, 200 4 L200 50 L0 50Z" fill="url(#bls)" />
                      <path className="bl-ph-line" d="M0 40 C 20 38, 30 30, 50 32 S 80 22, 100 24 S 130 12, 150 16 S 180 6, 200 4" fill="none" stroke="#e6d3a8" strokeWidth="1.5" />
                    </svg>
                    <div className="bl-ph-acts">
                      {[[t('Переказ', 'Send'), 'M7 17L17 7M9 7h8v8'], [t('Поповнити', 'Top up'), 'M12 5v14M5 12h14'], [t('Депозит', 'Save'), 'M4 19h16M6 16V10M10 16V7M14 16v-5M18 16V5'], [t('Ще', 'More'), 'M6 12h.01M12 12h.01M18 12h.01']].map(([l, d]) => <div key={l}><span><svg viewBox="0 0 24 24" aria-hidden><path d={d} /></svg></span>{l}</div>)}
                    </div>
                    <div className="bl-ph-list">
                      {tx.map(r => (
                        <div key={r.n} className="bl-ph-row"><span className="bl-ph-ic">{r.i}</span><div><b>{r.n}</b><small>{r.s}</small></div><em className={r.pos ? 'pos' : ''}>{r.a}</em></div>
                      ))}
                    </div>
                  </div>
                </div>
                <div className="bl-hero-card"><Card img="roma-colosseum-night" n="6897" label={t('Колізей уночі', 'Colosseum by night')} /></div>
                <div className="bl-toast bl-toast-1"><span className="bl-toast-ic ok"><svg viewBox="0 0 24 24" aria-hidden><path d="M5 12.5l4.5 4.5L19 7.5" /></svg></span><div><b>{t('Оплату підтверджено', 'Payment confirmed')}</b><small>3-D Secure · Saint Agnes</small></div></div>
                <div className="bl-toast bl-toast-2"><span className="bl-toast-ic warn"><svg viewBox="0 0 24 24" aria-hidden><path d="M12 7v6M12 17h.01" /></svg></span><div><b>{t('Переказ зупинено', 'Transfer stopped')}</b><small>{t('Антифрод: дроблення суми', 'Fraud check: structuring')}</small></div></div>
              </div>
            </div>
          </div>
        </section>

        <div className="bl-marquee" aria-hidden>
          <div>{[...marquee, ...marquee].map((m, i) => <span key={i}>{m}<i /></span>)}</div>
        </div>

        {/* ── Cards ── */}
        <section id="cards" className="bl-sec bl-cards">
          <div className="bl-wrap">
            <div className="bl-head bl-rv">
              <span className="bl-kick"><i>01</i>Roma Collection</span>
              <h2>{t('Картка, яку хочеться', 'A card you’ll want')}<br /><span className="bl-gold">{t('діставати.', 'to take out.')}</span></h2>
              <p>{t('Шість дизайнів, натхненних Вічним містом. Віртуальна картка з’являється в ту ж секунду, як ви відкриваєте рахунок, і миттєво блокується одним дотиком.', 'Six designs inspired by the Eternal City. Your virtual card appears the second you open an account and freezes with a single tap.')}</p>
            </div>
          </div>
          <div className="bl-fan bl-rv">
            {CARDS.map((c, i) => (
              <figure key={c.img} style={{ ['--i' as string]: i - (CARDS.length - 1) / 2 }}>
                <Card img={c.img} n={c.n} label={t(c.uk, c.en)} />
              </figure>
            ))}
          </div>
          <div className="bl-wrap">
            <div className="bl-feats bl-rv">
              {[
                [t('Миттєвий випуск', 'Instant issue'), t('Картка готова до оплати одразу після реєстрації.', 'Ready to pay the moment you sign up.')],
                [t('Заморозка в один дотик', 'One-tap freeze'), t('Загубили телефон? Картка блокується за секунду.', 'Lost your phone? Freeze the card in a second.')],
                [t('Дизайн на настрій', 'A design for every mood'), t('Змінюйте дизайн картки будь-коли, без перевипуску.', 'Switch your card design any time, no reissue.')],
              ].map(([h, p]) => <div key={h}><h3>{h}</h3><p>{p}</p></div>)}
            </div>
          </div>
        </section>

        {/* ── Everyday bento ── */}
        <section id="everyday" className="bl-sec">
          <div className="bl-wrap">
            <div className="bl-head bl-rv">
              <span className="bl-kick"><i>02</i>{t('Щоденний банкінг', 'Everyday banking')}</span>
              <h2>{t('Усе, що потрібно.', 'Everything you need.')}<br /><span className="bl-mut">{t('Нічого зайвого.', 'Nothing you don’t.')}</span></h2>
            </div>
            <div className="bl-bento">
              <article className="bl-tile bl-t-wide bl-rv">
                <div className="bl-tile-copy">
                  <span className="bl-kick">{t('Перекази', 'Transfers')}</span>
                  <h3>{t('Гроші доходять раніше, ніж ви встигнете прибрати телефон.', 'Money lands before you’ve put your phone away.')}</h3>
                  <p>{t('За номером картки, рахунку чи телефону. Повтор запиту ніколи не спише двічі.', 'By card, account or phone number. A repeated request never charges twice.')}</p>
                </div>
                <div className="bl-notifs">
                  {[[t('Надіслано', 'Sent'), t('Андрію М. · щойно', 'Andrii M. · now'), '−1 200 TAX'], [t('Отримано', 'Received'), t('Олена К. · 2 хв', 'Olena K. · 2m'), '+2 500 TAX'], [t('Депозит', 'Deposit'), t('12 міс · 14% · вчора', '12 mo · 14% · yesterday'), '−9 000 TAX']].map(([a, b, c], i) => (
                    <div key={a} className="bl-notif" style={{ ['--i' as string]: i }}>
                      <span className="bl-notif-ic"><Mark size={14} /></span>
                      <div><b>{a}</b><small>{b}</small></div><em>{c}</em>
                    </div>
                  ))}
                </div>
              </article>

              <article className="bl-tile bl-rv">
                <span className="bl-kick">{t('Аналітика', 'Insights')}</span>
                <h3>{t('Куди йдуть гроші — з першого погляду.', 'See where your money goes, at a glance.')}</h3>
                <div className="bl-ring">
                  <svg viewBox="0 0 120 120" aria-hidden>
                    {[[0, 38, '#e6d3a8'], [38, 24, '#a8977a'], [62, 20, '#6f6556'], [82, 18, '#3e3a33']].map(([o, l, c]) => (
                      <circle key={String(c)} cx="60" cy="60" r="46" fill="none" stroke={String(c)} strokeWidth="12" pathLength={100} strokeDasharray={`${Number(l) - 1.5} ${101.5 - Number(l)}`} strokeDashoffset={-Number(o)} strokeLinecap="round" />
                    ))}
                  </svg>
                  <div><b>24 380</b><small>TAX · {t('жовтень', 'October')}</small></div>
                </div>
                <ul className="bl-legend">
                  {[[t('Покупки', 'Shopping'), '38%', '#e6d3a8'], [t('Їжа', 'Food'), '24%', '#a8977a'], [t('Транспорт', 'Transport'), '20%', '#6f6556'], [t('Інше', 'Other'), '18%', '#3e3a33']].map(([a, b, c]) => <li key={a}><i style={{ background: c }} />{a}<b>{b}</b></li>)}
                </ul>
              </article>

              <article className="bl-tile bl-rv">
                <span className="bl-kick">{t('Чеки', 'Receipts')}</span>
                <h3>{t('Сфотографуйте чек. Решту зробить телефон.', 'Snap a receipt. Your phone does the rest.')}</h3>
                <div className="bl-receipt">
                  <div className="bl-receipt-p">
                    <b>CAFÉ ROMA</b>
                    {[['Cappuccino', '62,00'], ['Cornetto', '48,00'], ['Acqua', '24,00']].map(([a, b]) => <span key={a}><i>{a}</i><i>{b}</i></span>)}
                    <span className="tot"><i>TOTAL</i><i>134,00</i></span>
                  </div>
                  <div className="bl-scan" />
                </div>
                <p>{t('Фото не залишає телефон: текст розпізнається на пристрої.', 'The photo never leaves your phone: text is read on the device.')}</p>
              </article>

              <article className="bl-tile bl-rv">
                <span className="bl-kick">{t('Кредит', 'Credit')}</span>
                <h3>{t('Кредит із чесним графіком.', 'Credit with an honest schedule.')}</h3>
                <div className="bl-rates">
                  {Object.entries(CREDIT_RATES).map(([m, r]) => <div key={m}><b>{r}%</b><small>{m} {t('міс', 'mo')}</small></div>)}
                </div>
                <p>{t('Ануїтетний платіж, видно наперед до копійки.', 'Equal monthly payments, known to the cent upfront.')}</p>
              </article>

              <article className="bl-tile bl-rv">
                <span className="bl-kick">{t('Виписки', 'Statements')}</span>
                <h3>{t('PDF-виписка й квитанція за секунду.', 'PDF statements and receipts in a second.')}</h3>
                <div className="bl-doc" aria-hidden>
                  <div><Mark size={14} /><b>TaxTech</b><small>{t('Виписка · жовтень', 'Statement · October')}</small></div>
                  {[70, 52, 84, 40, 62].map((w, i) => <i key={i} style={{ width: `${w}%` }} />)}
                  <span>PDF</span>
                </div>
              </article>
            </div>
          </div>
        </section>

        {/* ── Savings ── */}
        <section id="grow" className="bl-sec">
          <div className="bl-wrap bl-split">
            <div className="bl-head bl-rv" style={{ textAlign: 'left', margin: 0 }}>
              <span className="bl-kick"><i>03</i>{t('Депозити', 'Deposits')}</span>
              <h2>{t('Нехай гроші', 'Let your money')}<br /><span className="bl-gold">{t('працюють.', 'work for you.')}</span></h2>
              <p>{t('Від 8% на місяць до 14% на рік. Оберіть строк і суму: калькулятор рахує за тією ж формулою, що й банк.', 'From 8% for a month to 14% for a year. Pick a term and an amount: the calculator uses the same formula as the bank.')}</p>
            </div>
            <div className="bl-rv"><DepositCalc t={t} /></div>
          </div>
        </section>

        {/* ── Security ── */}
        <section id="security" className="bl-sec bl-sec-dark">
          <div className="bl-wrap">
            <div className="bl-head bl-rv">
              <span className="bl-kick"><i>04</i>{t('Безпека', 'Security')}</span>
              <h2>{t('Захист, який', 'Protection that')}<br /><span className="bl-gold">{t('не спить.', 'never sleeps.')}</span></h2>
              <p>{t('Кожен переказ проходить три шари перевірки ще до того, як гроші зрушать з місця.', 'Every transfer passes three layers of checks before any money moves.')}</p>
            </div>
            <div className="bl-shield bl-rv">
              <div className="bl-flow">
                <div className="bl-flow-in"><small>{t('Переказ', 'Transfer')}</small><b>9 900 TAX</b><span>«{t('терміново', 'urgent')}»</span></div>
                {[[t('Шар 1', 'Layer 1'), t('Сама операція', 'The transaction'), '5'], [t('Шар 2', 'Layer 2'), t('Ваша історія', 'Your history'), '12'], [t('Шар 3', 'Layer 3'), t('Граф переказів', 'Transfer graph'), '11']].map(([a, b, c], i) => (
                  <div key={a} className="bl-layer" style={{ ['--i' as string]: i }}><small>{a}</small><b>{b}</b><span>{c} {t('правил', 'rules')}</span></div>
                ))}
                <div className="bl-flow-out"><span><svg viewBox="0 0 24 24" aria-hidden><path d="M12 7v6M12 17h.01" /></svg></span><b>{t('Зупинено', 'Stopped')}</b><small>{t('ризик: середній · дроблення суми', 'risk: medium · structuring')}</small></div>
              </div>
            </div>
            <div className="bl-sec-grid">
              {[
                ['M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M9.5 9v1.5M14.5 9v1.5M12 9v4h-1M9.5 15.5s1 1 2.5 1 2.5-1 2.5-1', t('Face ID і passkey', 'Face ID & passkeys'), t('Вхід без пароля. Ключ ніколи не залишає ваш пристрій.', 'Sign in without a password. The key never leaves your device.')],
                ['M5 12h14M5 12a7 7 0 0 1 14 0M5 12a7 7 0 0 0 14 0M12 5v14', '3-D Secure', t('Кожну онлайн-оплату підтверджує одноразовий код.', 'Every online payment is confirmed with a one-time code.')],
                ['M4 7h16M4 12h10M4 17h7M17 15l2 2 3-4', t('Без подвійних списань', 'No double charges'), t('Ключ ідемпотентності: повтор запиту не списує двічі.', 'Idempotency keys: a retried request never charges twice.')],
                ['M8 4h8l4 4v8l-4 4H8l-4-4V8l4-4ZM12 9v4M12 16h.01', t('Цілісна історія', 'Tamper-evident history'), t('Транзакції зшиті хеш-ланцюгом SHA-256.', 'Transactions are chained with SHA-256 hashes.')],
              ].map(([d, h, p]) => (
                <div key={h} className="bl-rv"><svg viewBox="0 0 24 24" aria-hidden><path d={d} /></svg><h3>{h}</h3><p>{p}</p></div>
              ))}
            </div>
          </div>
        </section>

        {/* ── Numbers ── */}
        <section className="bl-sec bl-nums-sec">
          <div className="bl-wrap">
            <div className="bl-nums" ref={statsRef}>
              <div><b>{Math.round(s1)}</b><span>{t('правил антифроду у трьох шарах', 'fraud rules in three layers')}</span></div>
              <div><b>{Math.round(s2)}<em>/454</em></b><span>{t('перевірок: антифрод на телефоні ≡ серверу', 'checks: on-phone fraud engine ≡ server')}</span></div>
              <div><b>{Math.round(s3)}<em>%</em></b><span>{t('річних на депозит на 12 місяців', 'a year on a 12-month deposit')}</span></div>
              <div><b>{Math.round(s4)}</b><span>{t('дизайнів карток у колекції Roma', 'card designs in the Roma collection')}</span></div>
            </div>
          </div>
        </section>

        {/* ── Research teaser ── */}
        <section className="bl-sec">
          <div className="bl-wrap">
            <a className="bl-research bl-rv" href={DOCS_URL} target="_blank" rel="noreferrer">
              <div>
                <span className="bl-kick"><i>05</i>{t('Під капотом', 'Under the hood')}</span>
                <h2>{t('Телефон чи хмара?', 'Phone or cloud?')}<br /><span className="bl-mut">{t('Вирішує метод.', 'The method decides.')}</span></h2>
                <p>{t('Для кожної ІІ-задачі застосунок сам обирає, де її виконати: на iPhone, на сервері чи на сервері після маскування особистих даних. Це наукова робота TaxTech; повний опис методу, формули й дані відкриті.', 'For every AI task the app decides where to run it: on the iPhone, on the server, or on the server after redacting personal data. This is TaxTech’s research project; the full method, formulas and data are open.')}</p>
                <span className="bl-arrow">{t('Читати дослідження', 'Read the research')} <span aria-hidden>↗</span></span>
              </div>
              <div className="bl-route" aria-hidden>
                {[['iPhone', '2 ms', 'on'], [t('Сервер', 'Server'), '250 ms', ''], [t('Сервер з маскою', 'Redacted server'), '1.5 s', '']].map(([a, b, c]) => (
                  <div key={a} className={c}><b>{a}</b><small>{b}</small></div>
                ))}
              </div>
            </a>
          </div>
        </section>

        {/* ── FAQ ── */}
        <section id="faq" className="bl-sec">
          <div className="bl-wrap bl-faq-wrap">
            <div className="bl-head bl-rv" style={{ textAlign: 'left', margin: 0 }}>
              <span className="bl-kick"><i>06</i>{t('Питання', 'FAQ')}</span>
              <h2>{t('Відповіді', 'Answers,')}<br /><span className="bl-mut">{t('без дрібного шрифту.', 'no fine print.')}</span></h2>
            </div>
            <div className="bl-faq bl-rv">
              {faq.map(([q, a]) => <details key={q}><summary>{q}<i aria-hidden /></summary><p>{a}</p></details>)}
            </div>
          </div>
        </section>

        {/* ── Final CTA ── */}
        <section className="bl-sec">
          <div className="bl-wrap">
            <div className="bl-final bl-rv">
              <div className="bl-final-cards" aria-hidden>
                <div><Card img="roma-pantheon" n="2214" label={t('Пантеон', 'Pantheon')} /></div>
                <div><Card img="roma-marble" n="0418" label={t('Мармур', 'Marble')} /></div>
              </div>
              <h2>{t('Ваш новий банк', 'Your new bank')}<br /><span className="bl-gold">{t('за хвилину.', 'in a minute.')}</span></h2>
              <p>{t('Безкоштовно. Без паперів. Без реальних грошей.', 'Free. No paperwork. No real money.')}</p>
              <div className="bl-cta" style={{ justifyContent: 'center' }}>
                <button type="button" className="bl-btn bl-btn-lg" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}<span aria-hidden>→</span></button>
                <button type="button" className="bl-ghost bl-ghost-lg" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              </div>
            </div>
          </div>
        </section>

        <footer className="bl-foot">
          <div className="bl-wrap">
            <div className="bl-foot-top">
              <a href="#top" className="bl-logo"><Mark size={22} /><span>Tax<em>Tech</em></span></a>
              <div className="bl-foot-cols">
                <div><h4>{t('Продукти', 'Products')}</h4><a href="#cards">{t('Картки', 'Cards')}</a><a href="#everyday">{t('Перекази', 'Transfers')}</a><a href="#grow">{t('Депозити', 'Deposits')}</a><a href="#everyday">{t('Кредит', 'Credit')}</a></div>
                <div><h4>{t('Безпека', 'Security')}</h4><a href="#security">Face ID</a><a href="#security">3-D Secure</a><a href="#security">{t('Антифрод', 'Fraud detection')}</a></div>
                <div><h4>TaxTech</h4><a href={DOCS_URL} target="_blank" rel="noreferrer">{t('Дослідження', 'Research')}</a><a href="https://github.com/munister-v/taxtech" target="_blank" rel="noreferrer">GitHub</a><a href="#faq">{t('Питання', 'FAQ')}</a></div>
                <div><h4>{t('Акаунт', 'Account')}</h4><button type="button" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button><button type="button" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button></div>
              </div>
            </div>
            <p className="bl-legal">{t('TaxTech є навчальним банком лабораторії цифрових фінансів. TAX є віртуальним токеном: він не є грошима чи електронними грошима й не обмінюється на гривню чи іншу валюту. Справжніх платежів, карток і рахунків немає; номери карток починаються з 0000. Платформа не сертифікована EMVCo, PCI DSS чи FIDO. Face ID є торговельною маркою Apple Inc.', 'TaxTech is the training bank of a digital-finance lab. TAX is a virtual token: it is not money or e-money and cannot be exchanged for hryvnia or any other currency. There are no real payments, cards or accounts; card numbers start with 0000. The platform is not certified by EMVCo, PCI DSS or FIDO. Face ID is a trademark of Apple Inc.')}</p>
            <div className="bl-foot-bot"><span>© {new Date().getFullYear()} TaxTech &amp; Munister</span>{langSwitch}</div>
          </div>
        </footer>
      </div>
    </LandingLangContext.Provider>
  );
}
