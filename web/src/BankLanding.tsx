import { useEffect, useMemo, useRef, useState } from 'react';
import { LandingLangContext, initialLandingLang, saveLandingLang, type LandingLang } from './landingLang';
import './bankLanding.css';

// Logged-out landing. Apple-like restraint on black: big centred type, air, quiet reveals. Card faces are drawn in CSS
// (an original TaxTech check and four plain finishes). Photo slots take dark Rome/Italy shots from web/public/landing/
// (prompts in docs/LANDING-PHOTOS.md); without a file a slot stays a plain dark field. Research lives in docs/RESEARCH.md.

const DOCS_URL = 'https://github.com/munister-v/taxtech/blob/main/docs/RESEARCH.md';
const SHOP_URL = 'https://shop.munister.com.ua/';
// Same rates and formula as server/backend/services/deposit_service.py and credit_service.py.
const DEPOSIT_RATES: Record<number, number> = { 1: 8, 3: 10, 6: 12, 12: 14 };
// Hand-picked Saint Agnes pieces, in this order (coat, teddy jacket, tweed cardigan, check jacket).
const SHOP_PICKS = ['munister-81921', 'munister-83171', 'munister-81907', 'munister-83168'];

const SLOTS = ['hero', 'rome', 'coast', 'night'] as const;
type Slot = typeof SLOTS[number];

// Which landing photos exist. A missing file comes back as the SPA's index.html, so Image() fails and the slot stays dark.
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

type Finish = 'check-honey' | 'check-knight' | 'noir' | 'knight' | 'honey' | 'ivory';
const FINISHES: { id: Finish; uk: string; en: string; dot: string }[] = [
  { id: 'check-honey', uk: 'Клітинка, мед', en: 'Check, honey', dot: '#c7a46f' },
  { id: 'check-knight', uk: 'Клітинка, ніч', en: 'Check, knight', dot: '#1c2740' },
  { id: 'noir', uk: 'Нуар', en: 'Noir', dot: '#1a1a1a' },
  { id: 'knight', uk: 'Найт', en: 'Knight', dot: '#2a3858' },
  { id: 'honey', uk: 'Мед', en: 'Honey', dot: '#d9bd8c' },
  { id: 'ivory', uk: 'Слонова кістка', en: 'Ivory', dot: '#efe8db' },
];

type ShopItem = { id: number; title: string; price: number | string; image_url?: string; slug?: string };

const fmt = (n: number, d = 0) => n.toLocaleString('uk-UA', { minimumFractionDigits: d, maximumFractionDigits: d }).replace(/ /g, ' ');

function Card({ finish, n = '6897' }: { finish: Finish; n?: string }) {
  return (
    <div className={`bl-card bl-card-${finish}`}>
      <span className="bl-card-sheen" aria-hidden />
      <span className="bl-card-brand">TAXTECH</span>
      <svg className="bl-card-nfc" viewBox="0 0 24 24" aria-hidden><path d="M8.5 7.5a6 6 0 0 1 0 9M12 5a9.5 9.5 0 0 1 0 14M15.5 2.5a13 13 0 0 1 0 19" /></svg>
      <span className="bl-card-chip" aria-hidden />
      <span className="bl-card-num">0000 •••• •••• {n}</span>
      <span className="bl-card-name">TAXTECH MEMBER</span>
    </div>
  );
}

export default function BankLanding({ onAuth }: { onAuth: (m: 'login' | 'register') => void }) {
  const rootRef = useRef<HTMLDivElement | null>(null);
  const [lang, setLang] = useState<LandingLang>(initialLandingLang);
  const [scrolled, setScrolled] = useState(false);
  const [menu, setMenu] = useState(false);
  const [finish, setFinish] = useState<Finish>('check-honey');
  const [term, setTerm] = useState(12);
  const [amount, setAmount] = useState(50000);
  const [shop, setShop] = useState<ShopItem[]>([]);
  const photo = usePhotos();
  const t = (uk: string, en: string) => (lang === 'en' ? en : uk);

  useEffect(() => {
    const id = window.setTimeout(() => { document.documentElement.lang = lang; }, 0);
    saveLandingLang(lang);
    document.title = lang === 'en' ? 'TaxTech · the card, reimagined' : 'TaxTech · картка нового рівня';
    return () => { window.clearTimeout(id); document.documentElement.lang = 'uk'; };
  }, [lang]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    root.classList.add('bl-js');
    const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { root, threshold: 0.14 });
    root.querySelectorAll('.bl-rv').forEach(el => io.observe(el));
    const onScroll = () => setScrolled(root.scrollTop > 10);
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
  const cur = FINISHES.find(f => f.id === finish)!;

  const nav: [string, string][] = [['#card', t('Картка', 'Card')], ['#everyday', t('Можливості', 'Features')], ['#save', t('Депозит', 'Deposit')], ['#security', t('Безпека', 'Security')], ['#shop', 'Saint Agnes']];
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

        {/* ── Hero ── */}
        <section id="top" className="bl-hero">
          <div className="bl-photo" style={photo('hero')} aria-hidden />
          <div className="bl-wrap bl-hero-in">
            <p className="bl-eyebrow">TaxTech Card</p>
            <h1>{t('Створена в дусі', 'Made in the spirit')}<br />{t('Риму.', 'of Rome.')}</h1>
            <p className="bl-sub">{t('Безкоштовний рахунок, картка за хвилину, вхід за Face ID.', 'A free account, a card in a minute, Face ID sign-in.')}</p>
            <div className="bl-cta">
              <button type="button" className="bl-pill" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-more" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')} ›</button>
            </div>
            <div className="bl-hero-card"><Card finish="check-honey" /></div>
          </div>
        </section>

        {/* ── Card finishes ── */}
        <section id="card" className="bl-sec">
          <div className="bl-wrap bl-center">
            <h2 className="bl-h bl-rv">{t('Шість оздоблень.', 'Six finishes.')}<br /><span className="bl-dim">{t('Одна картка.', 'One card.')}</span></h2>
            <div className="bl-stage bl-rv">
              <div className="bl-stage-card" key={finish}><Card finish={finish} /></div>
            </div>
            <div className="bl-dots bl-rv" role="radiogroup" aria-label={t('Оздоблення', 'Finish')}>
              {FINISHES.map(f => (
                <button key={f.id} type="button" role="radio" aria-checked={finish === f.id} aria-label={t(f.uk, f.en)} className={`bl-dot${finish === f.id ? ' on' : ''}${f.id.startsWith('check') ? ' check' : ''}`} style={{ ['--c' as string]: f.dot }} onClick={() => setFinish(f.id)} />
              ))}
            </div>
            <p className="bl-dot-name">{t(cur.uk, cur.en)}</p>
          </div>
        </section>

        {/* ── Photo break ── */}
        <section className="bl-break">
          <div className="bl-photo" style={photo('rome')} aria-hidden />
          <div className="bl-wrap bl-break-in bl-rv">
            <h2 className="bl-h">{t('Платіть одним поглядом.', 'Pay with a glance.')}</h2>
            <p className="bl-sub">{t('Face ID і passkey замість паролів. Ключ ніколи не залишає ваш пристрій.', 'Face ID and passkeys instead of passwords. The key never leaves your device.')}</p>
          </div>
        </section>

        {/* ── Everyday tiles ── */}
        <section id="everyday" className="bl-sec">
          <div className="bl-wrap">
            <h2 className="bl-h bl-center bl-rv">{t('Усе для щоденних фінансів.', 'Everything for everyday money.')}</h2>
            <div className="bl-tiles">
              {[
                ['0 TAX', t('Рахунок, картка й перекази', 'Account, card and transfers'), t('Без комісій за обслуговування й перекази між рахунками TaxTech.', 'No fees for upkeep or transfers between TaxTech accounts.')],
                ['14%', t('Депозит на рік', 'A year on deposit'), t('Строки 1, 3, 6 і 12 місяців, відсотки щодня.', 'Terms of 1, 3, 6 and 12 months, interest daily.')],
                ['36', t('Місяців кредиту', 'Months of credit'), t('Рівні платежі від 18% річних, графік наперед.', 'Equal payments from 18% a year, schedule upfront.')],
                ['PDF', t('Виписки за секунду', 'Statements in a second'), t('З хешем кожного запису.', 'With the hash of every entry.')],
              ].map(([a, b, c], i) => (
                <div key={b} className="bl-tile bl-rv" style={{ ['--d' as string]: `${i * 60}ms` }}><b>{a}</b><h3>{b}</h3><p>{c}</p></div>
              ))}
            </div>
          </div>
        </section>

        {/* ── Deposit ── */}
        <section id="save" className="bl-sec bl-sec-alt">
          <div className="bl-wrap bl-center">
            <h2 className="bl-h bl-rv">{t('Гроші, що працюють.', 'Money that works.')}</h2>
            <p className="bl-sub bl-rv">{t('Та сама формула, що й у банку: сума × ставка × дні / 365.', 'The same formula the bank uses: amount × rate × days / 365.')}</p>
            <div className="bl-calc bl-rv">
              <div className="bl-seg" role="group" aria-label={t('Строк', 'Term')}>
                {Object.keys(DEPOSIT_RATES).map(Number).map(m => (
                  <button key={m} type="button" className={m === term ? 'on' : ''} aria-pressed={m === term} onClick={() => setTerm(m)}>{m} {t('міс', 'mo')} · {DEPOSIT_RATES[m]}%</button>
                ))}
              </div>
              <div className="bl-calc-big"><span>+{fmt(gain, 2)}</span><small>TAX {t('за', 'over')} {days} {t('дн.', 'days')}</small></div>
              <label className="bl-range">
                <input type="range" min={1000} max={500000} step={1000} value={amount} aria-label={t('Сума', 'Amount')} style={{ ['--p' as string]: `${((amount - 1000) / 499000) * 100}%` }} onChange={e => setAmount(+e.target.value)} />
                <span>{t('Сума', 'Amount')} <b>{fmt(amount)} TAX</b> · {t('наприкінці', 'at maturity')} <b>{fmt(amount + gain, 2)}</b></span>
              </label>
              <button type="button" className="bl-pill" onClick={() => onAuth('register')}>{t('Відкрити депозит', 'Open a deposit')}</button>
            </div>
          </div>
        </section>

        {/* ── Security ── */}
        <section id="security" className="bl-break bl-break-tall">
          <div className="bl-photo" style={photo('night')} aria-hidden />
          <div className="bl-wrap bl-center bl-rv">
            <p className="bl-eyebrow">{t('Безпека', 'Security')}</p>
            <h2 className="bl-h">{t('Переказ зупиняється', 'A transfer stops')}<br />{t('раніше, ніж гроші рушать.', 'before the money moves.')}</h2>
            <div className="bl-layers">
              {[[t('Операція', 'The transaction'), '5'], [t('Ваша історія', 'Your history'), '12'], [t('Граф переказів', 'Transfer graph'), '11']].map(([a, b], i) => (
                <div key={a}><small>{t('Шар', 'Layer')} {i + 1}</small><b>{a}</b><span>{b} {t('правил', 'rules')}</span></div>
              ))}
            </div>
            <p className="bl-sub">{t('Онлайн-оплату підтверджує 3-D Secure, а повторний запит ніколи не спише двічі.', 'Online payments are confirmed with 3-D Secure, and a retried request never charges twice.')}</p>
          </div>
        </section>

        {/* ── Saint Agnes ── */}
        <section id="shop" className="bl-sec">
          <div className="bl-wrap">
            <div className="bl-center bl-rv">
              <p className="bl-eyebrow">Saint Agnes × TaxTech</p>
              <h2 className="bl-h">{t('Оплата в один дотик.', 'One tap at checkout.')}</h2>
              <a className="bl-more" href={SHOP_URL} target="_blank" rel="noreferrer">{t('До магазину', 'Visit Saint Agnes')} ›</a>
            </div>
            <div className="bl-shop bl-rv">
              {(shop.length ? shop : Array.from({ length: 4 }, (_, i) => ({ id: -i } as ShopItem))).map(p => (
                <a key={p.id} className="bl-prod" href={SHOP_URL} target="_blank" rel="noreferrer">
                  <div className="bl-prod-img" style={p.image_url ? { backgroundImage: `url(${p.image_url})` } : undefined} />
                  <span>{p.title ? p.title.replace(/\s*\([^)]*\)\s*$/, '') : ' '}</span>
                  <b>{p.price ? `${fmt(Number(p.price))} TAX` : ' '}</b>
                </a>
              ))}
            </div>
          </div>
        </section>

        {/* ── Coast + final CTA ── */}
        <section className="bl-break bl-break-tall">
          <div className="bl-photo" style={photo('coast')} aria-hidden />
          <div className="bl-wrap bl-center bl-rv">
            <h2 className="bl-h bl-h-xl">{t('Ваша картка чекає.', 'Your card is waiting.')}</h2>
            <div className="bl-cta">
              <button type="button" className="bl-pill" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-more" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')} ›</button>
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
          <div className="bl-wrap">
            <p className="bl-legal">{t('TaxTech є навчальним банком лабораторії цифрових фінансів. TAX є віртуальним токеном: він не є грошима чи електронними грошима й не обмінюється на гривню чи іншу валюту. Справжніх платежів, карток і рахунків немає; номери карток починаються з 0000. Платформа не сертифікована EMVCo, PCI DSS чи FIDO. Face ID є торговельною маркою Apple Inc.', 'TaxTech is the training bank of a digital-finance lab. TAX is a virtual token: it is not money or e-money and cannot be exchanged for hryvnia or any other currency. There are no real payments, cards or accounts; card numbers start with 0000. The platform is not certified by EMVCo, PCI DSS or FIDO. Face ID is a trademark of Apple Inc.')}</p>
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
