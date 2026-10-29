import { useEffect, useMemo, useRef, useState } from 'react';
import markSvg from './assets/mark.svg?raw';
import { LandingLangContext, initialLandingLang, saveLandingLang, type LandingLang } from './landingLang';
import './bankLanding.css';

// Logged-out landing. Art direction: travertine paper, ink, one brick-red accent, the Roman arch as the motif.
// The research write-up lives in docs/RESEARCH.md.

const DOCS_URL = 'https://github.com/munister-v/taxtech/blob/main/docs/RESEARCH.md';
// Same rates and formula as server/backend/services/deposit_service.py.
const DEPOSIT_RATES: Record<number, number> = { 1: 8, 3: 10, 6: 12, 12: 14 };

const CARDS = [
  { img: 'roma-colosseum-night', uk: 'Колізей уночі', en: 'Colosseum by night' },
  { img: 'roma-pantheon', uk: 'Пантеон', en: 'Pantheon' },
  { img: 'roma-forum', uk: 'Форум', en: 'Forum' },
  { img: 'roma-marble', uk: 'Мармур', en: 'Marble' },
  { img: 'roma-aqueduct', uk: 'Акведук', en: 'Aqueduct' },
  { img: 'roma-colosseum', uk: 'Колізей', en: 'Colosseum' },
];
const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI'];

const fmt = (n: number, d = 0) => n.toLocaleString('uk-UA', { minimumFractionDigits: d, maximumFractionDigits: d }).replace(/ /g, ' ');

function Mark({ size = 20 }: { size?: number }) {
  return <span className="bl-mark" style={{ width: size, height: size }} aria-hidden dangerouslySetInnerHTML={{ __html: markSvg.replace('<svg ', '<svg style="width:100%;height:100%" ') }} />;
}

async function sha256(s: string): Promise<string> {
  try {
    const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
    return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('');
  } catch {
    return '0'.repeat(64); // crypto.subtle needs a secure context
  }
}

type Entry = { time: string; who: string; what: string; amount: number; hash: string; prev: string };

// A ledger that grows while you watch: each row is chained to the previous one, as integrity_service does on the server.
function useLedger(t: (uk: string, en: string) => string, run: boolean) {
  const pool = useMemo(() => [
    [t('Кав’ярня «Рим»', 'Café Roma'), t('Кава', 'Coffee'), -86],
    [t('Олена К.', 'Olena K.'), t('Переказ', 'Transfer'), 2500],
    ['Saint Agnes', t('Покупки', 'Shopping'), -4290],
    [t('Депозит, 12 міс', 'Deposit, 12 mo'), t('Заощадження', 'Savings'), -9000],
    [t('Андрій М.', 'Andrii M.'), t('Переказ', 'Transfer'), -1200],
    [t('Нарахування відсотків', 'Interest'), t('Депозит', 'Deposit'), 1260],
    [t('Таксі', 'Taxi'), t('Транспорт', 'Transport'), -214],
    [t('Книгарня', 'Bookshop'), t('Покупки', 'Shopping'), -640],
  ] as [string, string, number][], [t]);
  const [rows, setRows] = useState<Entry[]>([]);
  useEffect(() => {
    if (!run) return;
    let alive = true, prev = '0'.repeat(64), i = 0;
    setRows([]);
    const push = async () => {
      const [who, what, amount] = pool[i % pool.length];
      i += 1;
      const time = new Date(Date.now() - Math.max(0, 5 - i) * 97000).toTimeString().slice(0, 5);
      const hash = await sha256(`${i}|${who}|${amount}|${time}|${prev}`);
      if (!alive) return;
      const entry = { time, who, what, amount, hash, prev };
      prev = hash;
      setRows(r => [entry, ...r].slice(0, 6));
    };
    (async () => { for (let k = 0; k < 5; k++) await push(); })();
    const id = window.setInterval(push, 3200);
    return () => { alive = false; window.clearInterval(id); };
  }, [run, pool]);
  return rows;
}

export default function BankLanding({ onAuth }: { onAuth: (m: 'login' | 'register') => void }) {
  const rootRef = useRef<HTMLDivElement | null>(null);
  const ledgerRef = useRef<HTMLDivElement | null>(null);
  const [lang, setLang] = useState<LandingLang>(initialLandingLang);
  const [scrolled, setScrolled] = useState(false);
  const [menu, setMenu] = useState(false);
  const [ready, setReady] = useState(false);
  const [ledgerOn, setLedgerOn] = useState(false);
  const [term, setTerm] = useState(12);
  const [amount, setAmount] = useState(50000);
  const t = useMemo(() => (uk: string, en: string) => (lang === 'en' ? en : uk), [lang]);
  const rows = useLedger(t, ledgerOn);

  useEffect(() => {
    const id = window.setTimeout(() => { document.documentElement.lang = lang; }, 0);
    saveLandingLang(lang);
    document.title = lang === 'en' ? 'TaxTech · money, kept in order' : 'TaxTech · гроші в порядку';
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
      if (e.target === ledgerRef.current) setLedgerOn(true);
    }), { root, threshold: 0.15 });
    root.querySelectorAll('.bl-rv').forEach(el => io.observe(el));
    if (ledgerRef.current) io.observe(ledgerRef.current);
    const onScroll = () => {
      setScrolled(root.scrollTop > 8);
      root.style.setProperty('--sy', String(Math.min(root.scrollTop, 1200)));
    };
    root.addEventListener('scroll', onScroll, { passive: true });
    return () => { cancelAnimationFrame(r); io.disconnect(); root.removeEventListener('scroll', onScroll); };
  }, []);

  const days = useMemo(() => { const a = new Date(); const b = new Date(a); b.setMonth(b.getMonth() + term); return Math.round((b.getTime() - a.getTime()) / 86400000); }, [term]);
  const gain = Math.round(amount * DEPOSIT_RATES[term] / 100 * days / 365 * 100) / 100;

  const nav: [string, string][] = [['#cards', t('Картки', 'Cards')], ['#ledger', t('Облік', 'Ledger')], ['#tariffs', t('Тарифи', 'Tariffs')], ['#security', t('Безпека', 'Security')], ['#faq', t('Питання', 'Questions')]];
  const tariffs: [string, string, string][] = [
    [t('Рахунок', 'Account'), t('Відкриття й обслуговування', 'Opening and upkeep'), '0 TAX'],
    [t('Картка', 'Card'), t('Віртуальна, випуск одразу після реєстрації', 'Virtual, issued the moment you sign up'), '0 TAX'],
    [t('Перекази', 'Transfers'), t('За номером картки, рахунку чи телефону', 'By card, account or phone number'), '0 TAX'],
    [t('Депозит', 'Deposit'), t('1, 3, 6 або 12 місяців', '1, 3, 6 or 12 months'), t('8–14% річних', '8–14% a year')],
    [t('Кредит', 'Credit'), t('Від 3 до 36 місяців, рівні платежі', '3 to 36 months, equal payments'), t('18–26% річних', '18–26% a year')],
    [t('Виписка', 'Statement'), t('PDF з хешем кожного запису', 'PDF with the hash of every entry'), t('Включено', 'Included')],
  ];
  const faq: [string, string][] = [
    [t('Що таке TaxTech?', 'What is TaxTech?'),
      t('Навчальний цифровий банк лабораторії цифрових фінансів. Рахунок, картки, перекази, депозити, кредит і антифрод працюють як у справжньому банку, але на віртуальних грошах.', 'The training digital bank of a digital-finance lab. Accounts, cards, transfers, deposits, credit and fraud checks work as in a real bank, but with virtual money.')],
    [t('Що таке TAX?', 'What is TAX?'),
      t('Віртуальний токен банку. Він не є грошима чи електронними грошима й не обмінюється на гривню. Справжні картки й рахунки не прив’язуються, тож втратити реальні гроші неможливо.', 'The bank’s virtual token. It is not money or e-money and cannot be exchanged for hryvnia. No real cards or accounts are linked, so there is no way to lose real money.')],
    [t('Як відкрити рахунок?', 'How do I open an account?'),
      t('Вкажіть телефон або email і пароль. Рахунок і перша картка з’являються одразу; потім можна додати passkey і входити за Face ID.', 'Enter a phone number or email and a password. The account and your first card appear at once; then add a passkey and sign in with Face ID.')],
    [t('Які дані збираються?', 'What data is collected?'),
      t('Лише потрібне для рахунку і технічний журнал рішень застосунку без текстів, фото й відповідей. Фото чека розпізнається на телефоні.', 'Only what the account needs, and a technical log of the app’s decisions without text, photos or answers. Receipt photos are read on the phone.')],
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
        <header className={`bl-nav${scrolled ? ' bl-nav-s' : ''}`}>
          <div className="bl-wrap bl-nav-in">
            <a href="#top" className="bl-logo"><Mark size={20} /><span>TaxTech</span></a>
            <nav className="bl-links" aria-label={t('Розділи', 'Sections')}>
              {nav.map(([h, x]) => <a key={h} href={h}>{x}</a>)}
            </nav>
            <div className="bl-nav-r">
              {langSwitch}
              <button type="button" className="bl-link" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              <button type="button" className="bl-btn bl-btn-sm" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-burger" aria-label={t('Меню', 'Menu')} aria-expanded={menu} onClick={() => setMenu(v => !v)}>
                <svg viewBox="0 0 24 24" aria-hidden>{menu ? <path d="M6 6l12 12M18 6L6 18" /> : <path d="M4 9h16M4 15h16" />}</svg>
              </button>
            </div>
          </div>
        </header>
        {menu && (
          <div className="bl-sheet" onClick={() => setMenu(false)}>
            <nav className="bl-wrap" aria-label={t('Меню', 'Menu')}>
              {nav.map(([h, x], i) => <a key={h} href={h}><span>{ROMAN[i]}</span>{x}</a>)}
              <button type="button" className="bl-btn" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-link" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              {langSwitch}
            </nav>
          </div>
        )}

        {/* ── Hero ── */}
        <section id="top" className={`bl-hero${ready ? ' on' : ''}`}>
          <div className="bl-wrap bl-hero-in">
            <div className="bl-hero-copy">
              <p className="bl-over">TaxTech · {t('цифровий банк', 'digital bank')}</p>
              <h1>{t('Гроші', 'Money,')}<br />{t('в порядку.', 'kept in order.')}</h1>
              <p className="bl-lead">{t('Рахунок, картки, перекази й депозити. Кожну операцію перевіряють до того, як вона відбудеться, і підписують після.', 'Accounts, cards, transfers and deposits. Every operation is checked before it happens and signed after.')}</p>
              <div className="bl-cta">
                <button type="button" className="bl-btn" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
                <button type="button" className="bl-link bl-link-u" onClick={() => onAuth('login')}>{t('Увійти', 'Sign in')}</button>
              </div>
            </div>
            <figure className="bl-arch bl-hero-arch">
              <div className="bl-arch-img" style={{ backgroundImage: 'url(/cards/roma-colosseum-night.webp)' }} />
              <figcaption>{t('Картка «Колізей уночі», колекція Roma', 'The Colosseum by Night card, Roma collection')}</figcaption>
            </figure>
          </div>
          <div className="bl-wrap">
            <dl className="bl-facts">
              <div><dt>28</dt><dd>{t('правил антифроду перевіряють переказ до списання', 'fraud rules check a transfer before money moves')}</dd></div>
              <div><dt>SHA-256</dt><dd>{t('зшиває кожен запис історії з попереднім', 'chains every history entry to the one before')}</dd></div>
              <div><dt>0 TAX</dt><dd>{t('за рахунок, картку й перекази', 'for the account, card and transfers')}</dd></div>
            </dl>
          </div>
        </section>

        {/* ── Colonnade ── */}
        <section id="cards" className="bl-sec">
          <div className="bl-wrap">
            <div className="bl-sec-head bl-rv">
              <h2>{t('Шість карток.', 'Six cards.')}<br />{t('Одне місто.', 'One city.')}</h2>
              <p>{t('Колекція Roma: камінь, світло й арки Вічного міста. Віртуальна картка готова одразу після реєстрації, блокується одним дотиком, а дизайн можна змінити без перевипуску.', 'The Roma collection: the stone, light and arches of the Eternal City. Your virtual card is ready as soon as you sign up, freezes with one tap, and its design changes without a reissue.')}</p>
            </div>
          </div>
          <div className="bl-colonnade bl-rv">
            {CARDS.map((c, i) => (
              <figure key={c.img} className="bl-arch" style={{ ['--i' as string]: i }}>
                <div className="bl-arch-img" style={{ backgroundImage: `url(/cards/${c.img}.webp)` }} />
                <figcaption><span>{ROMAN[i]}</span>{t(c.uk, c.en)}</figcaption>
              </figure>
            ))}
          </div>
        </section>

        {/* ── Ledger ── */}
        <section id="ledger" className="bl-sec bl-ink">
          <div className="bl-wrap">
            <div className="bl-sec-head bl-rv">
              <h2>{t('Кожен запис', 'Every entry,')}<br />{t('підписано.', 'signed.')}</h2>
              <p>{t('Банк зшиває транзакції ланцюгом SHA-256: хеш кожного запису містить хеш попереднього. Змініть один рядок у минулому, і зламаються всі наступні. Повторний запит має ключ ідемпотентності, тож двічі не спише нічого.', 'The bank chains transactions with SHA-256: each entry’s hash contains the hash of the one before. Change one line in the past and every line after it breaks. A retried request carries an idempotency key, so nothing is ever charged twice.')}</p>
            </div>
            <div className="bl-ledger bl-rv" ref={ledgerRef} aria-label={t('Приклад журналу операцій', 'Example ledger')}>
              <div className="bl-lg-h"><span>{t('Час', 'Time')}</span><span>{t('Операція', 'Entry')}</span><span>{t('Сума, TAX', 'Amount, TAX')}</span><span>{t('Хеш', 'Hash')}</span></div>
              {rows.map(r => (
                <div className="bl-lg-r" key={r.hash}>
                  <span className="bl-lg-t">{r.time}</span>
                  <span className="bl-lg-w"><b>{r.who}</b><small>{r.what}</small></span>
                  <span className={`bl-lg-a${r.amount > 0 ? ' pos' : ''}`}>{r.amount > 0 ? '+' : '−'}{fmt(Math.abs(r.amount), 2)}</span>
                  <span className="bl-lg-x"><i>{r.hash.slice(0, 10)}</i><small>← {r.prev.slice(0, 6)}</small></span>
                </div>
              ))}
              <p className="bl-lg-note">{t('Хеші обчислено у вашому браузері тим самим SHA-256. Операції ілюстративні.', 'Hashes are computed in your browser with the same SHA-256. The entries are illustrative.')}</p>
            </div>
          </div>
        </section>

        {/* ── Tariffs ── */}
        <section id="tariffs" className="bl-sec">
          <div className="bl-wrap">
            <div className="bl-sec-head bl-rv">
              <h2>{t('Тарифи.', 'Tariffs.')}</h2>
              <p>{t('Повний перелік на одному екрані.', 'The complete list, on one screen.')}</p>
            </div>
            <div className="bl-table bl-rv" role="table">
              {tariffs.map(([a, b, c], i) => (
                <div className="bl-tr" role="row" key={a}>
                  <span className="bl-tr-n" role="cell">{ROMAN[i]}</span>
                  <span className="bl-tr-a" role="cell">{a}</span>
                  <span className="bl-tr-b" role="cell">{b}</span>
                  <span className="bl-tr-c" role="cell">{c}</span>
                </div>
              ))}
            </div>

            <div className="bl-calc bl-rv">
              <div className="bl-calc-l">
                <h3>{t('Розрахунок депозиту', 'Deposit estimate')}</h3>
                <p>{t('Та сама формула, що й у банку: сума × ставка × дні / 365.', 'The same formula the bank uses: amount × rate × days / 365.')}</p>
              </div>
              <div className="bl-calc-r">
                <div className="bl-seg" role="group" aria-label={t('Строк', 'Term')}>
                  {Object.keys(DEPOSIT_RATES).map(Number).map(m => (
                    <button key={m} type="button" className={m === term ? 'on' : ''} aria-pressed={m === term} onClick={() => setTerm(m)}>
                      {m} {t('міс', 'mo')} · {DEPOSIT_RATES[m]}%
                    </button>
                  ))}
                </div>
                <label className="bl-range">
                  <span>{t('Сума', 'Amount')}</span>
                  <input type="range" min={1000} max={500000} step={1000} value={amount} style={{ ['--p' as string]: `${((amount - 1000) / 499000) * 100}%` }} onChange={e => setAmount(+e.target.value)} />
                  <b>{fmt(amount)} TAX</b>
                </label>
                <div className="bl-calc-out">
                  <div><small>{t('Дохід за', 'Interest over')} {days} {t('дн.', 'days')}</small><b className="bl-red">+{fmt(gain, 2)}</b></div>
                  <div><small>{t('Наприкінці строку', 'At maturity')}</small><b>{fmt(amount + gain, 2)}</b></div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ── Security ── */}
        <section id="security" className="bl-sec bl-stone">
          <div className="bl-wrap">
            <div className="bl-sec-head bl-rv">
              <h2>{t('Три перевірки,', 'Three checks')}<br />{t('поки гроші на місці.', 'before money moves.')}</h2>
              <p>{t('Переказ на 9 900 TAX з описом «терміново» на новий рахунок. Ось що з ним відбувається.', 'A 9,900 TAX transfer marked “urgent” to a new account. Here is what happens to it.')}</p>
            </div>
            <ol className="bl-steps bl-rv">
              <li><span>I</span><h3>{t('Сама операція', 'The transaction')}</h3><p>{t('Сума трохи нижча за поріг 10 000, підозрілий опис. 5 правил.', 'Just under the 10,000 threshold, a suspicious description. 5 rules.')}</p></li>
              <li><span>II</span><h3>{t('Ваша історія', 'Your history')}</h3><p>{t('Частота, звичні суми, нічна активність, вік рахунку. 12 правил.', 'Frequency, usual amounts, night activity, account age. 12 rules.')}</p></li>
              <li><span>III</span><h3>{t('Граф переказів', 'The transfer graph')}</h3><p>{t('Новий отримувач, дроп-рахунки, цикли між клієнтами. 11 правил.', 'New recipient, money mules, cycles between customers. 11 rules.')}</p></li>
              <li className="bl-verdict"><span>✕</span><h3>{t('Зупинено', 'Stopped')}</h3><p>{t('Ризик середній: дроблення суми. Гроші не списано.', 'Medium risk: structuring. No money has moved.')}</p></li>
            </ol>
            <div className="bl-sec-list bl-rv">
              {[
                ['Passkey · Face ID', t('Вхід без пароля, ключ лишається на пристрої.', 'Sign in without a password; the key stays on your device.')],
                ['3-D Secure', t('Онлайн-оплату підтверджує одноразовий код.', 'An online payment is confirmed with a one-time code.')],
                [t('Ідемпотентність', 'Idempotency'), t('Повтор запиту не створює другого списання.', 'A retried request never creates a second charge.')],
              ].map(([a, b]) => <div key={a}><b>{a}</b><span>{b}</span></div>)}
            </div>
          </div>
        </section>

        {/* ── Questions + research ── */}
        <section id="faq" className="bl-sec">
          <div className="bl-wrap bl-two">
            <div className="bl-rv">
              <h2 className="bl-h3">{t('Питання', 'Questions')}</h2>
              <div className="bl-faq">
                {faq.map(([q, a]) => <details key={q}><summary>{q}</summary><p>{a}</p></details>)}
              </div>
            </div>
            <a className="bl-research bl-rv" href={DOCS_URL} target="_blank" rel="noreferrer">
              <span className="bl-over">{t('Дослідження', 'Research')}</span>
              <h3>{t('Телефон чи хмара?', 'Phone or cloud?')}</h3>
              <p>{t('Для кожної ІІ-задачі застосунок сам вирішує, де її виконати: на iPhone, на сервері чи на сервері після маскування особистих даних. Метод, формули й дані відкриті.', 'For every AI task the app decides where it runs: on the iPhone, on the server, or on the server after personal data is redacted. The method, formulas and data are open.')}</p>
              <span className="bl-link-u">{t('Читати на GitHub', 'Read on GitHub')} ↗</span>
            </a>
          </div>
        </section>

        <section className="bl-final">
          <div className="bl-wrap bl-final-in">
            <h2 className="bl-rv">{t('Відкрийте рахунок.', 'Open an account.')}</h2>
            <div className="bl-cta bl-rv">
              <button type="button" className="bl-btn bl-btn-inv" onClick={() => onAuth('register')}>{t('Відкрити рахунок', 'Open an account')}</button>
              <button type="button" className="bl-link bl-link-u" onClick={() => onAuth('login')}>{t('У мене вже є акаунт', 'I already have one')}</button>
            </div>
          </div>
        </section>

        <footer className="bl-foot">
          <div className="bl-wrap">
            <div className="bl-foot-top">
              <a href="#top" className="bl-logo"><Mark size={20} /><span>TaxTech</span></a>
              <nav>{nav.map(([h, x]) => <a key={h} href={h}>{x}</a>)}<a href={DOCS_URL} target="_blank" rel="noreferrer">{t('Дослідження', 'Research')}</a><a href="https://github.com/munister-v/taxtech" target="_blank" rel="noreferrer">GitHub</a></nav>
              {langSwitch}
            </div>
            <p className="bl-legal">{t('TaxTech є навчальним банком лабораторії цифрових фінансів. TAX є віртуальним токеном: він не є грошима чи електронними грошима й не обмінюється на гривню чи іншу валюту. Справжніх платежів, карток і рахунків немає; номери карток починаються з 0000. Платформа не сертифікована EMVCo, PCI DSS чи FIDO. Face ID є торговельною маркою Apple Inc.', 'TaxTech is the training bank of a digital-finance lab. TAX is a virtual token: it is not money or e-money and cannot be exchanged for hryvnia or any other currency. There are no real payments, cards or accounts; card numbers start with 0000. The platform is not certified by EMVCo, PCI DSS or FIDO. Face ID is a trademark of Apple Inc.')}</p>
            <p className="bl-copy">© {new Date().getFullYear()} TaxTech &amp; Munister</p>
          </div>
        </footer>
      </div>
    </LandingLangContext.Provider>
  );
}
