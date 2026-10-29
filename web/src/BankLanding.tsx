import { useEffect, useMemo, useRef, useState } from 'react';
import { LandingLangContext, initialLandingLang, saveLandingLang, type LandingLang } from './landingLang';
import './bankLanding.css';

// Logged-out landing in the Saint Agnes design language (shop.munister.com.ua): cream paper, Jost capitals with
// wide tracking, square buttons, full-bleed photography. Research lives in docs/RESEARCH.md.
// Photos: drop files into web/public/landing/ (see docs/LANDING-PHOTOS.md). Until a file is there, its slot is a
// colour field (knight blue, honey) with type and the card itself instead of a photo.

const DOCS_URL = 'https://github.com/munister-v/taxtech/blob/main/docs/RESEARCH.md';
const SHOP_URL = 'https://shop.munister.com.ua/';
// Same rates and formula as server/backend/services/deposit_service.py and credit_service.py.
const DEPOSIT_RATES: Record<number, number> = { 1: 8, 3: 10, 6: 12, 12: 14 };
// Hand-picked Saint Agnes pieces, in this order (coat, teddy jacket, tweed cardigan, check jacket).
const SHOP_PICKS = ['munister-81921', 'munister-83171', 'munister-81907', 'munister-83168'];

const SLOTS = ['hero', 'save', 'borrow', 'security'] as const;
type Slot = typeof SLOTS[number];

// Which landing photos exist. A missing file comes back as the SPA's index.html, so Image() fails and the slot stays a colour field.
function usePhotos() {
  const [have, setHave] = useState<Partial<Record<Slot, boolean>>>({});
  useEffect(() => {
    let alive = true;
    SLOTS.forEach(s => {
      const img = new Image();
      img.onload = () => { if (alive && img.naturalWidth > 0) setHave(h => ({ ...h, [s]: true })); };
      img.src = `/landing/${s}.webp`;
    });
    return () => { alive = false; };
  }, []);
  return (s: Slot) => (have[s] ? { backgroundImage: `url(/landing/${s}.webp)` } : undefined);
}

const CARDS = [
  { img: 'roma-colosseum-night', uk: 'Колізей уночі', en: 'Colosseum by Night', n: '6897' },
  { img: 'roma-pantheon', uk: 'Пантеон', en: 'Pantheon', n: '2214' },
  { img: 'roma-forum', uk: 'Форум', en: 'Forum', n: '5530' },
  { img: 'roma-marble', uk: 'Мармур', en: 'Marble', n: '0418' },
  { img: 'roma-aqueduct', uk: 'Акведук', en: 'Aqueduct', n: '7761' },
  { img: 'roma-colosseum', uk: 'Колізей', en: 'Colosseum', n: '3302' },
];

type ShopItem = { id: number; title: string; price: number | string; image_url?: string; slug?: string };

const fmt = (n: number, d = 0) => n.toLocaleString('uk-UA', { minimumFractionDigits: d, maximumFractionDigits: d }).replace(/ /g, ' ');

function Icon({ d }: { d: string }) {
  return <svg className="bl-ic" viewBox="0 0 24 24" aria-hidden><path d={d} /></svg>;
}
const IC = {
  user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM4 21c1.4-3.8 4.4-5.5 8-5.5s6.6 1.7 8 5.5',
  card: 'M3 7.5A1.5 1.5 0 0 1 4.5 6h15A1.5 1.5 0 0 1 21 7.5v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 16.5v-9ZM3 10h18M7 15h4',
  free: 'M12 3v18M16.5 7.5c0-1.7-2-3-4.5-3s-4.5 1.3-4.5 3 2 2.6 4.5 3 4.5 1.4 4.5 3.2-2 3.3-4.5 3.3-4.5-1.4-4.5-3',
  bolt: 'M13 3 5 13.5h6L10 21l8-10.5h-6L13 3Z',
  face: 'M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M9.5 9v1.5M14.5 9v1.5M12 9v4h-1M9.5 15.5s1 1 2.5 1 2.5-1 2.5-1',
  lock: 'M6 11h12v9H6zM8.5 11V8a3.5 3.5 0 0 1 7 0v3',
  menu: 'M4 8h16M4 16h16',
  close: 'M6 6l12 12M18 6 6 18',
  left: 'M15 6l-6 6 6 6',
  right: 'M9 6l6 6-6 6',
};

function Card({ img, n, label }: { img: string; n: string; label: string }) {
  return (
    <div className="bl-card" style={{ backgroundImage: `url(/cards/${img}.webp)` }}>
      <span className="bl-card-brand">TAXTECH</span>
      <span className="bl-card-chip" aria-hidden />
      <span className="bl-card-num">0000 •••• {n}</span>
      <span className="bl-card-name">{label}</span>
    </div>
  );
}

export default function BankLanding({ onAuth }: { onAuth: (m: 'login' | 'register') => void }) {
  const rootRef = useRef<HTMLDivElement | null>(null);
  const railRef = useRef<HTMLDivElement | null>(null);
  const [lang, setLang] = useState<LandingLang>(initialLandingLang);
  const [scrolled, setScrolled] = useState(false);
  const [menu, setMenu] = useState(false);
  const [term, setTerm] = useState(12);
  const [amount, setAmount] = useState(50000);
  const [shop, setShop] = useState<ShopItem[]>([]);
  const t = (uk: string, en: string) => (lang === 'en' ? en : uk);
  const photo = usePhotos();

  useEffect(() => {
    const id = window.setTimeout(() => { document.documentElement.lang = lang; }, 0);
    saveLandingLang(lang);
    document.title = lang === 'en' ? 'TaxTech · the bank of Saint Agnes' : 'TaxTech · банк Saint Agnes';
    return () => { window.clearTimeout(id); document.documentElement.lang = 'uk'; };
  }, [lang]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    root.classList.add('bl-js');
    const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { root, threshold: 0.12 });
    root.querySelectorAll('.bl-rv').forEach(el => io.observe(el));
    const onScroll = () => setScrolled(root.scrollTop > 36);
    root.addEventListener('scroll', onScroll, { passive: true });
    return () => { io.disconnect(); root.removeEventListener('scroll', onScroll); };
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
  const scrollRail = (dir: number) => { const r = railRef.current; if (r) r.scrollBy({ left: dir * r.clientWidth * 0.8, behavior: 'smooth' }); };

  const nav: [string, string, string?][] = [
    ['#cards', t('Картки', 'Cards')], ['#save', t('Депозити', 'Deposits')], ['#borrow', t('Кредит', 'Credit')],
    ['#security', t('Безпека', 'Security')], ['#shop', 'Saint Agnes', 'accent'],
  ];
  const faq: [string, string][] = [
    [t('Що таке TaxTech?', 'What is TaxTech?'), t('Навчальний цифровий банк лабораторії цифрових фінансів і платіжний партнер Saint Agnes. Рахунок, картки, перекази, депозити, кредит і антифрод працюють як у справжньому банку, але на віртуальних грошах.', 'The training digital bank of a digital-finance lab and the payment partner of Saint Agnes. Accounts, cards, transfers, deposits, credit and fraud checks work as in a real bank, but with virtual money.')],
    [t('Що таке TAX?', 'What is TAX?'), t('Віртуальний токен банку. Він не є грошима чи електронними грошима й не обмінюється на гривню. Справжні картки й рахунки не прив’язуються, тож втратити реальні гроші неможливо.', 'The bank’s virtual token. It is not money or e-money and cannot be exchanged for hryvnia. No real cards or accounts are linked, so there is no way to lose real money.')],
    [t('Як відкрити рахунок?', 'How do I open an account?'), t('Вкажіть телефон або email і пароль. Рахунок і перша картка з’являються одразу; потім можна додати passkey і входити за Face ID.', 'Enter a phone number or email and a password. The account and your first card appear at once; then add a passkey and sign in with Face ID.')],
    [t('Як працює захист від шахрайства?', 'How does fraud protection work?'), t('Кожен переказ ще до списання проходить 28 правил у трьох шарах: сама операція, ваша історія і граф переказів між клієнтами. Онлайн-оплату підтверджує код 3-D Secure.', 'Before any money moves, every transfer passes 28 rules in three layers: the transaction itself, your history and the transfer graph between customers. Online payments are confirmed with a 3-D Secure code.')],
  ];
  const langSwitch = (cls = '') => (
    <div className={`bl-lang ${cls}`} role="group" aria-label={t('Мова', 'Language')}>
      <button type="button" className={lang === 'en' ? 'on' : ''} aria-pressed={lang === 'en'} onClick={() => setLang('en')}>EN</button>
      <button type="button" className={lang === 'uk' ? 'on' : ''} aria-pressed={lang === 'uk'} onClick={() => setLang('uk')}>UA</button>
    </div>
  );

  return (
    <LandingLangContext.Provider value={lang}>
      <div className="bl" ref={rootRef}>
        <div className="bl-bar">{t('Рахунок і картка за хвилину · 0 TAX за обслуговування', 'Account and card in a minute · Zero fees')}</div>

        <header className={`bl-head${scrolled ? ' s' : ''}`}>
          <div className="bl-wrap bl-head-in">
            <div className="bl-head-l">
              <button type="button" className="bl-burger" aria-label={t('Меню', 'Menu')} onClick={() => setMenu(true)}><Icon d={IC.menu} /></button>
              {langSwitch('bl-lang-head')}
            </div>
            <a href="#top" className="bl-logo">TAXTECH</a>
            <div className="bl-head-r">
              <button type="button" className="bl-iconbtn" aria-label={t('Увійти', 'Sign in')} onClick={() => onAuth('login')}><Icon d={IC.user} /><span>{t('Увійти', 'Sign in')}</span></button>
              <button type="button" className="bl-iconbtn" aria-label={t('Відкрити рахунок', 'Open an account')} onClick={() => onAuth('register')}><Icon d={IC.card} /></button>
            </div>
          </div>
          <nav className="bl-nav" aria-label={t('Розділи', 'Sections')}>
            {nav.map(([h, x, c]) => <a key={h} href={h} className={c}>{x}</a>)}
          </nav>
        </header>

        {menu && (
          <div className="bl-drawer" role="dialog" aria-modal="true" onClick={() => setMenu(false)}>
            <div className="bl-drawer-in" onClick={e => e.stopPropagation()}>
              <div className="bl-drawer-top"><span className="bl-logo">TAXTECH</span><button type="button" className="bl-iconbtn" aria-label={t('Закрити', 'Close')} onClick={() => setMenu(false)}><Icon d={IC.close} /></button></div>
              {nav.map(([h, x, c]) => <a key={h} href={h} className={c} onClick={() => setMenu(false)}>{x}</a>)}
              <button type="button" className="bl-btn bl-btn-dark" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-btn bl-btn-line-dark" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              {langSwitch()}
            </div>
          </div>
        )}

        {/* ── Hero ── */}
        <section id="top" className={`bl-hero${photo('hero') ? ' bl-hero-photo' : ' bl-field'}`}>
          {photo('hero') ? <div className="bl-hero-img" style={photo('hero')} /> : (
            <div className="bl-hero-cards" aria-hidden>
              <div className="bl-hc bl-hc-back"><Card img="roma-pantheon" n="2214" label={t('Пантеон', 'Pantheon')} /></div>
              <div className="bl-hc bl-hc-front"><Card img="roma-colosseum-night" n="6897" label={t('Колізей уночі', 'Colosseum by Night')} /></div>
            </div>
          )}
          <div className="bl-wrap bl-hero-in">
            <h1><span>{t('Нова колекція', 'The new')}</span><span className="bl-copper">{t('карток Roma', 'Roma cards')}</span></h1>
            <p>{t('Шість дизайнів, натхненних Вічним містом. Безкоштовний рахунок, віртуальна картка одразу, вхід за Face ID і оплата в Saint Agnes в один дотик.', 'Six designs inspired by the Eternal City. A free account, a virtual card at once, Face ID sign-in and one-tap checkout at Saint Agnes.')}</p>
            <div className="bl-hero-cta">
              <button type="button" className="bl-btn bl-btn-cream" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <a className="bl-btn bl-btn-line" href="#cards">{t('Дивитися картки', 'See the cards')}</a>
            </div>
          </div>
        </section>

        <div className="bl-perks">
          <div className="bl-wrap bl-perks-in">
            {[
              [IC.free, t('Обслуговування 0 TAX', 'Zero fees'), t('рахунок, картка й перекази', 'account, card and transfers')],
              [IC.bolt, t('Картка одразу', 'Instant card'), t('віртуальна, після реєстрації', 'virtual, on sign-up')],
              [IC.face, t('Face ID і passkey', 'Face ID & passkeys'), t('вхід без пароля', 'no passwords')],
              [IC.lock, '3-D Secure', t('кожна онлайн-оплата', 'on every online payment')],
            ].map(([d, a, b]) => <div key={a}><Icon d={d} /><span><b>{a}</b><small>{b}</small></span></div>)}
          </div>
        </div>

        {/* ── Cards as a product grid ── */}
        <section id="cards" className="bl-sec">
          <div className="bl-wrap">
            <div className="bl-sec-head bl-rv">
              <h2>{t('Картки', 'Cards')}</h2>
              <button type="button" className="bl-more" onClick={() => onAuth('register')}>{t('Обрати свою', 'Choose yours')} →</button>
            </div>
            <div className="bl-grid bl-rv">
              {CARDS.map((c, i) => (
                <button type="button" key={c.img} className="bl-tile-card" onClick={() => onAuth('register')}>
                  <div className="bl-tile-card-img">
                    {i === 0 && <span className="bl-badge">{t('Новинка', 'New')}</span>}
                    <Card img={c.img} n={c.n} label={t(c.uk, c.en)} />
                  </div>
                  <span className="bl-tile-card-t">{t('Картка', 'Card')} TaxTech Roma · {t(c.uk, c.en)}</span>
                  <span className="bl-tile-card-p">0 TAX</span>
                </button>
              ))}
            </div>
          </div>
        </section>

        {/* ── Save / Borrow ── */}
        <section className="bl-sec bl-sec-tight">
          <div className="bl-wrap bl-duo">
            <a id="save" href="#calc" className={`bl-duo-tile bl-rv${photo('save') ? '' : ' bl-duo-honey'}`} style={photo('save')}>
              {!photo('save') && <span className="bl-duo-num" aria-hidden>14<small>%</small></span>}
              <div>
                <h2>{t('Депозити', 'Deposits')}</h2>
                <p>{t('1 · 3 · 6 · 12 місяців · до 14% річних', '1 · 3 · 6 · 12 months · up to 14% a year')}</p>
                <span className="bl-btn bl-btn-line bl-btn-sm">{t('Розрахувати', 'Calculate')}</span>
              </div>
            </a>
            <button id="borrow" type="button" className={`bl-duo-tile bl-rv${photo('borrow') ? '' : ' bl-duo-knight'}`} style={photo('borrow')} onClick={() => onAuth('register')}>
              {!photo('borrow') && <span className="bl-duo-num" aria-hidden>36<small>{t('міс', 'mo')}</small></span>}
              <div>
                <h2>{t('Кредит', 'Credit')}</h2>
                <p>{t('3–36 місяців · рівні платежі · 18–26% річних', '3–36 months · equal payments · 18–26% a year')}</p>
                <span className="bl-btn bl-btn-line bl-btn-sm">{t('Оформити', 'Apply')}</span>
              </div>
            </button>
          </div>
        </section>

        {/* ── Saint Agnes ── */}
        <section id="shop" className="bl-sec">
          <div className="bl-wrap">
            <div className="bl-sec-head bl-rv">
              <div>
                <span className="bl-eyebrow">Saint Agnes × TaxTech</span>
                <h2>{t('Оплачуйте картою', 'Pay with your card')}</h2>
              </div>
              <div className="bl-sec-head-r">
                <a className="bl-more" href={SHOP_URL} target="_blank" rel="noreferrer">{t('До магазину', 'Visit the shop')} →</a>
                <button type="button" className="bl-arrow" aria-label={t('Назад', 'Previous')} onClick={() => scrollRail(-1)}><Icon d={IC.left} /></button>
                <button type="button" className="bl-arrow" aria-label={t('Далі', 'Next')} onClick={() => scrollRail(1)}><Icon d={IC.right} /></button>
              </div>
            </div>
            <div className="bl-rail bl-rv" ref={railRef}>
              {(shop.length ? shop : Array.from({ length: 4 }, (_, i) => ({ id: -i } as ShopItem))).map(p => (
                <a key={p.id} className="bl-prod" href={SHOP_URL} target="_blank" rel="noreferrer">
                  <div className="bl-prod-img" style={p.image_url ? { backgroundImage: `url(${p.image_url})` } : undefined}>
                    <span className="bl-badge bl-badge-dark">{t('Оплата TaxTech', 'Pay with TaxTech')}</span>
                  </div>
                  <span className="bl-tile-card-t">{p.title ? p.title.replace(/\s*\([^)]*\)\s*$/, '') : ' '}</span>
                  <span className="bl-tile-card-p">{p.price ? `${fmt(Number(p.price))} TAX` : ' '}</span>
                </a>
              ))}
            </div>
          </div>
        </section>

        {/* ── Deposit calculator ── */}
        <section id="calc" className="bl-sec bl-sand">
          <div className="bl-wrap bl-calc">
            <div className="bl-rv">
              <span className="bl-eyebrow">{t('Депозит', 'Deposit')}</span>
              <h2 className="bl-h2">{t('Калькулятор', 'Calculator')}</h2>
              <p className="bl-muted">{t('Та сама формула, що й у банку: сума × ставка × дні / 365. Відсотки нараховуються щодня.', 'The same formula the bank uses: amount × rate × days / 365. Interest accrues daily.')}</p>
            </div>
            <div className="bl-calc-box bl-rv">
              <div className="bl-seg" role="group" aria-label={t('Строк', 'Term')}>
                {Object.keys(DEPOSIT_RATES).map(Number).map(m => (
                  <button key={m} type="button" className={m === term ? 'on' : ''} aria-pressed={m === term} onClick={() => setTerm(m)}>{m} {t('міс', 'mo')}<small>{DEPOSIT_RATES[m]}%</small></button>
                ))}
              </div>
              <label className="bl-range">
                <span>{t('Сума', 'Amount')}<b>{fmt(amount)} TAX</b></span>
                <input type="range" min={1000} max={500000} step={1000} value={amount} style={{ ['--p' as string]: `${((amount - 1000) / 499000) * 100}%` }} onChange={e => setAmount(+e.target.value)} />
              </label>
              <div className="bl-calc-out">
                <div><small>{t('Дохід', 'Interest')} · {days} {t('дн.', 'days')}</small><b className="bl-copper-d">+{fmt(gain, 2)}</b></div>
                <div><small>{t('Наприкінці строку', 'At maturity')}</small><b>{fmt(amount + gain, 2)}</b></div>
              </div>
              <button type="button" className="bl-btn bl-btn-dark bl-btn-full" onClick={() => onAuth('register')}>{t('Відкрити депозит', 'Open a deposit')}</button>
            </div>
          </div>
        </section>

        {/* ── Security banner ── */}
        <section id="security" className="bl-sec">
          <div className="bl-wrap">
            <div className={`bl-banner bl-rv${photo('security') ? '' : ' bl-banner-field'}`} style={photo('security')}>
              {!photo('security') && <span className="bl-banner-num" aria-hidden>28</span>}
              <div>
                <span className="bl-eyebrow bl-eyebrow-light">{t('Безпека', 'Security')}</span>
                <h2>{t('Захищено', 'Protected')}<br />{t('на кожному кроці', 'at every step')}</h2>
                <p>{t('Підозрілий переказ зупиняється ще до списання: 28 правил у трьох шарах перевіряють суму, вашу історію і граф переказів між клієнтами.', 'A suspicious transfer stops before any money moves: 28 rules in three layers check the amount, your history and the transfer graph between customers.')}</p>
                <button type="button" className="bl-btn bl-btn-line" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              </div>
            </div>
          </div>
        </section>

        <section className="bl-points">
          <div className="bl-wrap bl-points-in">
            {[
              [t('Антифрод', 'Fraud checks'), t('Переказ перевіряють до списання, а не після', 'Transfers are checked before money moves, not after')],
              [t('Цілісна історія', 'Sealed history'), t('Кожен запис зшитий з попереднім ланцюгом SHA-256', 'Every entry is chained to the last with SHA-256')],
              [t('Без подвійних списань', 'No double charges'), t('Повторний запит не спише гроші вдруге', 'A retried request never charges twice')],
              [t('Виписки в PDF', 'PDF statements'), t('З хешем кожного запису, за секунду', 'With the hash of every entry, in a second')],
            ].map(([a, b], i) => <div key={a} className="bl-rv"><h3><span>0{i + 1}</span>{a}</h3><p>{b}</p></div>)}
          </div>
        </section>

        <section className="bl-sec">
          <div className="bl-wrap bl-faq-wrap">
            <h2 className="bl-h2 bl-rv">{t('Питання', 'Questions')}</h2>
            <div className="bl-faq bl-rv">
              {faq.map(([q, a]) => <details key={q}><summary>{q}</summary><p>{a}</p></details>)}
              <a className="bl-research" href={DOCS_URL} target="_blank" rel="noreferrer">{t('Дослідження TaxTech: телефон чи хмара для ІІ-задач', 'TaxTech research: phone or cloud for AI tasks')} →</a>
            </div>
          </div>
        </section>

        <section className="bl-dark">
          <div className="bl-wrap bl-dark-in">
            <h2 className="bl-rv">{t('Ваша картка Roma', 'Your Roma card')}<br />{t('чекає на вас', 'is waiting')}</h2>
            <div className="bl-dark-r bl-rv">
              <p>{t('Відкрийте рахунок за хвилину: без паперів, без комісій, без реальних грошей.', 'Open an account in a minute: no paperwork, no fees, no real money.')}</p>
              <div className="bl-hero-cta">
                <button type="button" className="bl-btn bl-btn-cream" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
                <button type="button" className="bl-btn bl-btn-line" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              </div>
            </div>
          </div>
        </section>

        <footer className="bl-foot">
          <div className="bl-wrap">
            <div className="bl-foot-cols">
              <div><span className="bl-logo bl-logo-light">TAXTECH</span><p>{t('Цифровий банк лабораторії цифрових фінансів', 'The digital bank of a digital-finance lab')}</p></div>
              <div><h4>{t('Продукти', 'Products')}</h4><a href="#cards">{t('Картки', 'Cards')}</a><a href="#save">{t('Депозити', 'Deposits')}</a><a href="#borrow">{t('Кредит', 'Credit')}</a></div>
              <div><h4>{t('Партнери', 'Partners')}</h4><a href={SHOP_URL} target="_blank" rel="noreferrer">Saint Agnes</a><a href={DOCS_URL} target="_blank" rel="noreferrer">{t('Дослідження', 'Research')}</a><a href="https://github.com/munister-v/taxtech" target="_blank" rel="noreferrer">GitHub</a></div>
              <div><h4>{t('Акаунт', 'Account')}</h4><button type="button" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button><button type="button" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>{langSwitch('bl-lang-foot')}</div>
            </div>
            <p className="bl-legal">{t('TaxTech є навчальним банком лабораторії цифрових фінансів. TAX є віртуальним токеном: він не є грошима чи електронними грошима й не обмінюється на гривню чи іншу валюту. Справжніх платежів, карток і рахунків немає; номери карток починаються з 0000. Платформа не сертифікована EMVCo, PCI DSS чи FIDO. Face ID є торговельною маркою Apple Inc.', 'TaxTech is the training bank of a digital-finance lab. TAX is a virtual token: it is not money or e-money and cannot be exchanged for hryvnia or any other currency. There are no real payments, cards or accounts; card numbers start with 0000. The platform is not certified by EMVCo, PCI DSS or FIDO. Face ID is a trademark of Apple Inc.')}</p>
            <p className="bl-copy">© {new Date().getFullYear()} TaxTech &amp; Munister</p>
          </div>
        </footer>
      </div>
    </LandingLangContext.Provider>
  );
}
