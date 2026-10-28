import { useLandingT } from './landingLang';

// Academic layer of the research chapter: problem statement, notes under each method slide,
// references, standards and project documents. Every link below was checked to resolve.

type Ref = { id: number; text: string; url: string; label: string };

export const REFS: Ref[] = [
  { id: 1, text: 'Kumar K., Lu Y.-H. Cloud Computing for Mobile Users: Can Offloading Computation Save Energy? // Computer. 2010. Vol. 43, No. 4. P. 51–56.', url: 'https://doi.org/10.1109/MC.2010.98', label: 'doi:10.1109/MC.2010.98' },
  { id: 2, text: 'Cuervo E., Balasubramanian A., Cho D., Wolman A., Saroiu S., Chandra R., Bahl P. MAUI: Making Smartphones Last Longer with Code Offload // Proc. MobiSys 2010. ACM, 2010. P. 49–62.', url: 'https://doi.org/10.1145/1814433.1814441', label: 'doi:10.1145/1814433.1814441' },
  { id: 3, text: 'Huang J., Qian F., Gerber A., Mao Z. M., Sen S., Spatscheck O. A Close Examination of Performance and Power Characteristics of 4G LTE Networks // Proc. MobiSys 2012. ACM, 2012. P. 225–238.', url: 'https://doi.org/10.1145/2307636.2307658', label: 'doi:10.1145/2307636.2307658' },
  { id: 4, text: 'Mao Y., You C., Zhang J., Huang K., Letaief K. B. A Survey on Mobile Edge Computing: The Communication Perspective // IEEE Communications Surveys & Tutorials. 2017. Vol. 19, No. 4. P. 2322–2358.', url: 'https://doi.org/10.1109/COMST.2017.2745201', label: 'doi:10.1109/COMST.2017.2745201' },
  { id: 5, text: 'Kang Y., Hauswald J., Gao C., Rovinski A., Mudge T., Mars J., Tang L. Neurosurgeon: Collaborative Intelligence Between the Cloud and Mobile Edge // Proc. ASPLOS 2017. ACM, 2017. P. 615–629.', url: 'https://doi.org/10.1145/3037697.3037698', label: 'doi:10.1145/3037697.3037698' },
  { id: 6, text: 'Neely M. J. Stochastic Network Optimization with Application to Communication and Queueing Systems. Morgan & Claypool, 2010.', url: 'https://doi.org/10.2200/S00271ED1V01Y201006CNT007', label: 'doi:10.2200/S00271ED1V01Y201006CNT007' },
  { id: 7, text: 'Vovk V., Gammerman A., Shafer G. Algorithmic Learning in a Random World. Springer, 2005.', url: 'https://doi.org/10.1007/b106715', label: 'doi:10.1007/b106715' },
  { id: 8, text: 'Gibbs I., Candès E. Adaptive Conformal Inference Under Distribution Shift // Advances in Neural Information Processing Systems 34 (NeurIPS 2021).', url: 'https://arxiv.org/abs/2106.00170', label: 'arXiv:2106.00170' },
  { id: 9, text: 'Angelopoulos A. N., Bates S. A Gentle Introduction to Conformal Prediction and Distribution-Free Uncertainty Quantification. 2021.', url: 'https://arxiv.org/abs/2107.07511', label: 'arXiv:2107.07511' },
  { id: 10, text: 'Chen L., Zaharia M., Zou J. FrugalGPT: How to Use Large Language Models While Reducing Cost and Improving Performance. 2023.', url: 'https://arxiv.org/abs/2305.05176', label: 'arXiv:2305.05176' },
];

type Std = { name: string; uk: string; en: string; url: string };
export const STANDARDS: Std[] = [
  { name: 'W3C Web Authentication, Level 2', uk: 'Вхід через passkey без пароля', en: 'Passwordless sign-in with passkeys', url: 'https://www.w3.org/TR/webauthn-2/' },
  { name: 'FIDO2', uk: 'Сімейство протоколів FIDO Alliance, на якому стоїть WebAuthn', en: 'The FIDO Alliance protocol family behind WebAuthn', url: 'https://fidoalliance.org/fido2/' },
  { name: 'EMV® 3-D Secure', uk: 'Підтвердження онлайн-оплат (модель challenge-потоку)', en: 'Online payment authentication (challenge-flow model)', url: 'https://www.emvco.com/emv-technologies/3-d-secure/' },
  { name: 'ISO/IEC 7812-1:2017', uk: 'Нумерація карток (IIN, PAN), контрольна цифра Луна', en: 'Card numbering (IIN, PAN), Luhn check digit', url: 'https://www.iso.org/standard/70484.html' },
  { name: 'ISO 13616-1:2020', uk: 'Структура IBAN: розпізнавання й маскування рахунків', en: 'IBAN structure: account detection and redaction', url: 'https://www.iso.org/standard/81090.html' },
  { name: 'FIPS 180-4 (SHA-256)', uk: 'Хеш-ланцюг цілісності історії транзакцій', en: 'Hash chain for transaction history integrity', url: 'https://csrc.nist.gov/pubs/fips/180-4/upd1/final' },
  { name: 'RFC 7519 (JWT)', uk: 'Токени входу через Apple', en: 'Tokens for Sign in with Apple', url: 'https://www.rfc-editor.org/rfc/rfc7519' },
  { name: 'IETF Idempotency-Key (draft)', uk: 'Повтор запиту не створює подвійного списання', en: 'A repeated request never charges twice', url: 'https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/' },
  { name: 'JSON Lines', uk: 'Формат журналу рішень decisions.jsonl', en: 'Format of the decisions.jsonl log', url: 'https://jsonlines.org/' },
  { name: 'GDPR, ст. 25 / Art. 25', uk: 'Захист даних за задумом: маскування до відправки', en: 'Data protection by design: redaction before sending', url: 'https://eur-lex.europa.eu/eli/reg/2016/679/oj' },
  { name: 'Закон України № 2297-VI', uk: '«Про захист персональних даних»', en: 'Law of Ukraine on Personal Data Protection', url: 'https://zakon.rada.gov.ua/laws/show/2297-17' },
];

const GH = 'https://github.com/munister-v/taxtech/blob/main/';
export const DOCS = [
  { uk: 'Опис проєкту', en: 'Project overview', path: 'README.md' },
  { uk: 'Політика рішень і стратегії', en: 'Decision policy and strategies', path: 'EdgeRouter/Sources/EdgeRouter/Policy.swift' },
  { uk: 'Модель енергії', en: 'Energy model', path: 'EdgeRouter/Sources/EdgeRouter/EnergyModel.swift' },
  { uk: 'Маскування особистих даних', en: 'Personal data redaction', path: 'EdgeRouter/Sources/EdgeRouter/Redactor.swift' },
  { uk: 'Журнал рішень', en: 'Decision log', path: 'EdgeRouter/Sources/EdgeRouter/Telemetry.swift' },
  { uk: 'FraudLite, антифрод на телефоні', en: 'FraudLite, on-device fraud checks', path: 'EdgeRouter/Sources/FraudLite/FraudLite.swift' },
  { uk: 'Тест паритету на 454 векторах', en: 'Parity test on 454 vectors', path: 'EdgeRouter/Tests/FraudLiteTests/FraudLiteParityTests.swift' },
  { uk: 'Серверний антифрод, три шари', en: 'Server fraud engine, three layers', path: 'server/backend/services/fraud_engine.py' },
  { uk: 'Сервер: запуск і API', en: 'Server: setup and API', path: 'server/README.md' },
].map(d => ({ ...d, url: GH + d.path }));

/** Inline citation chips: [2, 3] → links to the reference list. */
export function Cite({ ids }: { ids: number[] }) {
  return <span className="ra-cite">{ids.map(i => <a key={i} href={`#ref-${i}`}>{i}</a>)}</span>;
}

/** Academic note under a method slide. */
export function Note({ term, children, refs, code }: { term: string; children: React.ReactNode; refs?: number[]; code?: { path: string; label: string } }) {
  const { t } = useLandingT();
  return (
    <aside className="ra-note">
      <span className="ra-note-k">{term}</span>
      <div className="ra-note-b">{children}</div>
      <div className="ra-note-f">
        {refs && refs.length > 0 && <span>{t('Джерела', 'Sources')} <Cite ids={refs} /></span>}
        {code && <a href={GH + code.path} target="_blank" rel="noreferrer">{t('Код', 'Code')}: {code.label} ↗</a>}
      </div>
    </aside>
  );
}

export function Problem() {
  const { t } = useLandingT();
  const blocks: [string, React.ReactNode][] = [
    [t('Актуальність', 'Relevance'), <>{t('Мобільні застосунки дедалі частіше виконують ІІ-задачі: розбір документів, антифрод, діалогові помічники. Кожну з них можна виконати на пристрої або на сервері, і цей вибір одночасно визначає затримку, витрату заряду, якість відповіді й те, чи залишають особисті дані телефон. Класичні роботи з винесення обчислень', 'Mobile apps increasingly run AI tasks: document parsing, fraud checks, conversational assistants. Each can run on the device or on a server, and that choice sets latency, battery drain, answer quality and whether personal data leaves the phone, all at once. Classic work on computation offloading')} <Cite ids={[1, 2, 4, 5]} /> {t('оптимізує переважно час та енергію і не розглядає чутливість даних як жорстке обмеження.', 'optimises mainly for time and energy and does not treat data sensitivity as a hard constraint.')}</>],
    [t('Проблема', 'Problem'), t('Фіксовані стратегії («завжди сервер», «завжди телефон», прості правила) не враховують стан пристрою, що змінюється: заряд, тип мережі, перегрів, загрозу відключення електроенергії. Вони або марнують енергію через «хвіст» радіо, або втрачають якість, або надсилають особисті дані на сервер. Бракує методу, який ухвалює рішення для кожного запиту з гарантіями щодо бюджету енергії, частки помилок і приватності.', 'Fixed strategies (always server, always phone, simple rules) ignore the changing state of the device: battery, network type, thermal state, the risk of a power outage. They either waste energy on the radio tail, lose quality, or send personal data to the server. What is missing is a per-request method with guarantees on the energy budget, the error rate and privacy.')],
    [t('Мета', 'Aim'), t('Розробити та експериментально перевірити метод інтелектуального вибору між локальними та хмарними обчисленнями в мобільних застосунках, що мінімізує затримку й енергоспоживання за заданих обмежень на якість і приватність.', 'To develop and experimentally validate a method for intelligent selection between on-device and cloud computing in mobile applications that minimises latency and energy use under given constraints on quality and privacy.')],
    [t('Завдання', 'Objectives'), <ol>
      <li>{t('Проаналізувати підходи до винесення обчислень і каскадного виводу.', 'Review approaches to computation offloading and cascaded inference.')} <Cite ids={[1, 2, 4, 5, 10]} /></li>
      <li>{t('Побудувати модель контексту пристрою, часу, якості й енергії з урахуванням «хвоста» радіо.', 'Build a model of device context, latency, quality and energy that accounts for the radio tail.')} <Cite ids={[2, 3]} /></li>
      <li>{t('Сформулювати політику вибору на основі оптимізації Ляпунова з віртуальною чергою енергії.', 'Formulate a selection policy based on Lyapunov optimisation with a virtual energy queue.')} <Cite ids={[6]} /></li>
      <li>{t('Додати каскад з адаптивним конформним порогом, що контролює частку помилок.', 'Add a cascade with an adaptive conformal threshold that controls the error rate.')} <Cite ids={[7, 8, 9]} /></li>
      <li>{t('Задати чутливість даних як жорстке обмеження та маскування особистих даних.', 'Encode data sensitivity as a hard constraint, with redaction of personal data.')}</li>
      <li>{t('Реалізувати метод і полігон (навчальний банк, розмічений набір) та порівняти п’ять стратегій.', 'Implement the method and a testbed (training bank, labelled dataset) and compare five strategies.')}</li>
    </ol>],
    [t('Об’єкт', 'Object'), t('Процес виконання ІІ-задач у мобільних застосунках з даними різної чутливості.', 'The execution of AI tasks in mobile applications whose data differ in sensitivity.')],
    [t('Предмет', 'Subject'), t('Методи й моделі вибору виконавця (пристрій, сервер, сервер після маскування, каскад) для кожного запиту.', 'Methods and models for choosing an executor (device, server, server after redaction, cascade) for each request.')],
    [t('Методи дослідження', 'Research methods'), <>{t('Стохастична оптимізація Ляпунова', 'Lyapunov stochastic optimisation')} <Cite ids={[6]} />{t(', конформне прогнозування', ', conformal prediction')} <Cite ids={[7, 8]} />{t(', байєсове оцінювання якості (Beta-розподіл), експоненційне згладжування затримок, енергетичне моделювання', ', Bayesian quality estimation (Beta distribution), exponential smoothing of latency, energy modelling')} <Cite ids={[2, 3]} />{t(', порівняльний експеримент на розміченому наборі.', ', and a comparative experiment on a labelled dataset.')}</>],
    [t('Наукова новизна', 'Novelty'), t('Поєднання в одній політиці трьох механізмів: черги енергії Ляпунова, адаптивного конформного порогу каскаду та жорстких обмежень приватності з маскуванням; урахування імовірності відключення електроенергії як фактору відмови сервера.', 'Combining three mechanisms in one policy: a Lyapunov energy queue, an adaptive conformal cascade threshold, and hard privacy constraints with redaction; and treating the probability of a power outage as a server-failure factor.')],
    [t('Практичне значення', 'Practical value'), t('Відкрита реалізація у вигляді Swift-пакета, перенесений антифрод для телефона з перевіреним паритетом, журнал рішень для відтворюваного аналізу.', 'An open implementation as a Swift package, an on-device port of fraud detection with verified parity, and a decision log for reproducible analysis.')],
  ];
  return (
    <section id="problem" className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <h3 className="rl-h">{t('Що досліджуємо', 'What we study')}<br />{t('і навіщо.', 'and why.')}</h3>
        <dl className="ra-prob">
          {blocks.map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v}</dd></div>)}
        </dl>
      </div>
    </section>
  );
}

export function Sources() {
  const { t } = useLandingT();
  return (
    <section id="sources" className="rl-sec ap-reveal">
      <div className="ap-wrap">
        <h3 className="rl-h">{t('Література,', 'Literature,')}<br />{t('стандарти, код.', 'standards, code.')}</h3>

        <h4 className="ra-h">{t('Список літератури', 'References')}</h4>
        <ol className="ra-refs">
          {REFS.map(r => (
            <li key={r.id} id={`ref-${r.id}`}>
              <span>{r.text}</span>
              <a href={r.url} target="_blank" rel="noreferrer">{r.label} ↗</a>
            </li>
          ))}
        </ol>

        <h4 className="ra-h">{t('Стандарти й нормативні документи', 'Standards and regulations')}</h4>
        <div className="ra-std">
          {STANDARDS.map(s => (
            <a key={s.name} href={s.url} target="_blank" rel="noreferrer">
              <b>{s.name}</b><span>{t(s.uk, s.en)}</span><i aria-hidden>↗</i>
            </a>
          ))}
        </div>
        <p className="rl-cap">{t('Протоколи реалізовано в навчальному контурі. Платформа не проходила сертифікацію EMVCo, PCI DSS чи FIDO і не обробляє справжніх платежів.', 'These protocols are implemented in a training environment. The platform is not certified by EMVCo, PCI DSS or FIDO and processes no real payments.')}</p>

        <h4 className="ra-h">{t('Документи й вихідний код', 'Documents and source code')}</h4>
        <div className="ra-docs">
          {DOCS.map(d => (
            <a key={d.path} href={d.url} target="_blank" rel="noreferrer">
              <b>{t(d.uk, d.en)}</b><code>{d.path}</code>
            </a>
          ))}
        </div>
        <p className="rl-cap">{t('Репозиторій відкритий: ', 'The repository is public: ')}<a className="ra-link" href="https://github.com/munister-v/taxtech" target="_blank" rel="noreferrer">github.com/munister-v/taxtech ↗</a></p>
      </div>
    </section>
  );
}
