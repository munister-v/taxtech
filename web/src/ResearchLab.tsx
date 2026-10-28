import { useState } from 'react';
import data from './researchData.json';
import { useLandingT } from './landingLang';

// ─── Research chapter of the promo landing ───────────────────────
// Every number here is real: researchData.json is exported from the EdgeRouter Swift sources
// (Policy.decide, EnergyModel, Redactor, the adaptive conformal rule), the labelled research
// dataset in the sandbox database, and the 454 FraudLite parity vectors. Nothing is drawn by hand.

type PlanCode = 'd' | 'c' | 'r' | 'kc' | 'kr';
type Cand = { plan: PlanCode; ms: number; j: number; q: number; obj: number };
type T = (uk: string, en: string) => string;

const PLAN_COLOR: Record<PlanCode, string> = { d: '#ffd400', c: '#0a84ff', r: '#8e7cff', kc: '#30d158', kr: '#64d2ff' };
const PLANS = Object.keys(PLAN_COLOR) as PlanCode[];
const planName = (t: T, p: PlanCode) => ({
  d: t('Телефон', 'Phone'), c: t('Сервер', 'Server'), r: t('Сервер з маскою', 'Server, redacted'),
  kc: t('Каскад → сервер', 'Cascade → server'), kr: t('Каскад → сервер з маскою', 'Cascade → server, redacted'),
})[p];

const TASK_IDS = ['fraud', 'receipt', 'assistant'] as const;
type TaskId = typeof TASK_IDS[number];
const taskName = (t: T, id: TaskId) => ({ fraud: t('Перевірка переказу', 'Transfer check'), receipt: t('Розбір чека', 'Receipt parsing'), assistant: t('Помічник', 'Assistant') })[id];
const taskData = (t: T, id: TaskId) => (id === 'fraud' ? t('відкриті, належать банку', 'open, owned by the bank') : t('особисті, лише з маскою', 'personal, redacted only'));

const NET_IDS = ['wifi', 'cellular'] as const;
type NetId = typeof NET_IDS[number];
const netName = (t: T, id: NetId) => (id === 'wifi' ? 'Wi-Fi' : t('Стільникова', 'Cellular'));

const STRATS = ['alwaysDevice', 'alwaysCloud', 'rules', 'cascade', 'adaptive'] as const;
const stratName = (t: T, id: typeof STRATS[number]) => ({
  alwaysDevice: t('Завжди телефон', 'Always phone'), alwaysCloud: t('Завжди сервер', 'Always server'),
  rules: t('Прості правила', 'Simple rules'), cascade: t('Каскад', 'Cascade'), adaptive: 'EdgeRouter',
})[id];

const patternName = (t: T, p: string) => ({
  normal: t('Звичайні', 'Normal'), money_mule: t('Дроп-рахунок', 'Money mule'), rapid_succession: t('Серія швидких переказів', 'Rapid succession'),
  structuring: t('Дроблення суми', 'Structuring'), night_batch: t('Нічна пачка', 'Night batch'),
  new_recipient_large_amount: t('Велика сума новому отримувачу', 'Large amount to a new recipient'),
} as Record<string, string>)[p] || p;
const flagName = (t: T, f: string) => ({
  suspicious_description: t('Підозрілий опис', 'Suspicious description'), structuring: t('Дроблення суми', 'Structuring'),
  balance_depletion_critical: t('Критичне спустошення балансу', 'Critical balance depletion'), balance_depletion: t('Спустошення балансу', 'Balance depletion'),
  multi_rule_correlation: t('Збіг кількох правил', 'Several rules at once'), round_amount: t('Кругла сума', 'Round amount'),
  threshold_masking: t('Сума трохи нижче порогу', 'Just below a threshold'),
} as Record<string, string>)[f] || f;
const LEVELS = [['low', '#30d158'], ['medium', '#ffd400'], ['high', '#ff9f0a'], ['critical', '#ff453a']] as const;
const levelName = (t: T, l: string) => ({ low: t('Низький', 'Low'), medium: t('Середній', 'Medium'), high: t('Високий', 'High'), critical: t('Критичний', 'Critical') } as Record<string, string>)[l];
const days = (t: T) => t('Пн Вт Ср Чт Пт Сб Нд', 'Mon Tue Wed Thu Fri Sat Sun').split(' ');

const ds = data.dataset;
const pol = data.policy;
const fraudTotal = (ds.patterns as [string, number][]).filter(p => p[0] !== 'normal').reduce((a, p) => a + p[1], 0);

function useLab() {
  const { lang, t } = useLandingT();
  const nf = (n: number) => n.toLocaleString(lang === 'en' ? 'en-US' : 'uk-UA');
  return { t, nf };
}

export default function ResearchLab() {
  return (
    <div id="lab" className="rl">
      <Intro />
      <Question />
      <Decision />
      <Field />
      <Strategies />
      <Energy />
      <Conformal />
      <Masking />
      <Dataset />
      <Parity />
      <Status />
      <Logged />
    </div>
  );
}

function Tabs<K extends string>({ ids, on, set, label }: { ids: readonly K[]; on: K; set: (k: K) => void; label: (k: K) => string }) {
  return <div className="rl-seg">{ids.map(k => <button key={k} type="button" className={k === on ? 'on' : ''} onClick={() => set(k)}>{label(k)}</button>)}</div>;
}

function Intro() {
  const { t, nf } = useLab();
  return (
    <section className="rl-intro ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Наукова лабораторія', 'Research lab')}</p>
        <h2 className="rl-display">{t('Метод', 'The method,')}<br /><span className="ap-gold">{t('у дії', 'at work')}</span>.</h2>
        <p className="rl-lead">
          {t('TaxTech є віртуальною лабораторією цифрових фінансів, де виконується наукова робота «Метод інтелектуального вибору між локальними та хмарними обчисленнями в мобільних застосунках». Усе нижче згенеровано вихідним кодом методу та даними, на яких його перевіряють.',
            'TaxTech is a virtual digital-finance lab running the research project “A method for intelligent selection between on-device and cloud computing in mobile applications”. Everything below is generated by the method’s source code and the data it is tested on.')}
        </p>
        <dl className="rl-stats">
          <div><dt>{nf(ds.total)}</dt><dd>{t('розмічених транзакцій у дослідницькому наборі', 'labelled transactions in the research set')}</dd></div>
          <div><dt>{fraudTotal}</dt><dd>{t('шахрайських, п’ять сценаріїв атак', 'fraudulent, across five attack patterns')}</dd></div>
          <div><dt>{data.parity.n}</dt><dd>{t('еталонних векторів: антифрод телефона ≡ сервера', 'reference vectors: phone fraud check ≡ server')}</dd></div>
          <div><dt>3</dt><dd>{t('ІІ-задачі, для яких метод обирає, де рахувати', 'AI tasks where the method chooses where to run')}</dd></div>
        </dl>
      </div>
    </section>
  );
}

function Question() {
  const { t } = useLab();
  return (
    <section className="rl-sec ap-reveal">
      <div className="ap-wrap rl-split">
        <div>
          <p className="rl-kicker">{t('Питання дослідження', 'Research question')}</p>
          <h3 className="rl-h">{t('Де виконувати', 'Where should')}<br />{t('ІІ-задачу?', 'an AI task run?')}</h3>
          <p className="rl-p">
            {t('Сервер точніший, але кожен запит будить радіо й передає дані назовні. Телефон приватний і працює без мережі, але поступається якістю. Метод EdgeRouter для кожної задачі зважує час, енергію й якість, враховуючи заряд, мережу, перегрів і графік відключень світла. Кожне рішення потрапляє в журнал.',
              'The server is more accurate, but every request wakes the radio and sends data off the device. The phone is private and works offline, but its answers are weaker. For every task, EdgeRouter weighs latency, energy and quality against battery, network, thermal state and the power-outage schedule. Every decision is logged.')}
          </p>
        </div>
        <div className="rl-tasks">
          {TASK_IDS.map(id => {
            const c = (pol.candidates as Record<string, Cand[]>)[`${id}|wifi`];
            return (
              <div key={id}>
                <h4>{taskName(t, id)}</h4>
                <p>{t('Дані: ', 'Data: ')}{taskData(t, id)}</p>
                <ul>{c.filter(x => x.plan.length === 1).map(x => <li key={x.plan}><i style={{ background: PLAN_COLOR[x.plan] }} />{planName(t, x.plan)}<span>{Math.round(x.ms)} {t('мс', 'ms')} · {t('якість', 'quality')} {Math.round(x.q * 100)}%</span></li>)}</ul>
              </div>
            );
          })}
          <p className="rl-cap">{t('Апріорні оцінки з профілів задач у застосунку (Wi-Fi). Під час роботи їх уточнюють заміри.', 'Prior estimates from the task profiles in the app (Wi-Fi). Measurements refine them at run time.')}</p>
        </div>
      </div>
    </section>
  );
}

function Decision() {
  const { t } = useLab();
  const [task, setTask] = useState<TaskId>('receipt');
  const [net, setNet] = useState<NetId>('wifi');
  const cands = (pol.candidates as Record<string, Cand[]>)[`${task}|${net}`];
  const best = cands.reduce((a, b) => (b.obj < a.obj ? b : a));
  const maxJ = Math.max(...cands.map(c => c.j));
  const maxMs = Math.max(...cands.map(c => c.ms));
  return (
    <section className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Як ухвалюється рішення', 'How a decision is made')}</p>
        <h3 className="rl-h">{t('Кожен варіант', 'Every option')}<br />{t('має ціну.', 'has a price.')}</h3>
        <p className="rl-p rl-narrow">
          {t('Для кожного дозволеного варіанта метод рахує ціль drift-plus-penalty: ', 'For every allowed option the method computes the drift-plus-penalty objective: ')}
          <code>V·(t/1000 − 4·q) + Z·E</code>
          {t('. Тут t означає час, q якість, E енергію, Z чергу перевитрати. Перемагає найменша. Це точні значення з ', '. Here t is latency, q quality, E energy and Z the overspend queue. The lowest value wins. These are the exact values from ')}
          <code>Policy.decide</code>{t(' для спокійного стану (Z = 0).', ' in a calm state (Z = 0).')}
        </p>
        <div className="rl-panel">
          <div className="rl-ctl">
            <Tabs<TaskId> ids={TASK_IDS} on={task} set={setTask} label={k => taskName(t, k)} />
            <Tabs<NetId> ids={NET_IDS} on={net} set={setNet} label={k => netName(t, k)} />
          </div>
          <div className="rl-cands">
            <div className="rl-cand-h"><span>{t('Варіант', 'Option')}</span><span>{t('Час', 'Latency')}</span><span>{t('Енергія', 'Energy')}</span><span>{t('Якість', 'Quality')}</span><span>{t('Ціль', 'Objective')}</span></div>
            {[...cands].sort((a, b) => a.obj - b.obj).map(c => (
              <div key={c.plan} className={'rl-cand' + (c === best ? ' on' : '')} style={{ ['--c' as string]: PLAN_COLOR[c.plan] }}>
                <span className="rl-cand-n"><i />{planName(t, c.plan)}{c === best && <b>{t('обрано', 'chosen')}</b>}</span>
                <span><em style={{ width: `${(c.ms / maxMs) * 100}%` }} />{c.ms < 1000 ? `${Math.round(c.ms)} ${t('мс', 'ms')}` : `${(c.ms / 1000).toFixed(2)} ${t('с', 's')}`}</span>
                <span><em style={{ width: `${(c.j / maxJ) * 100}%` }} />{c.j < 0.1 ? `${Math.round(c.j * 1000)} ${t('мДж', 'mJ')}` : `${c.j.toFixed(2)} ${t('Дж', 'J')}`}</span>
                <span>{(c.q * 100).toFixed(1)}%</span>
                <span className="rl-num">{c.obj.toFixed(3)}</span>
              </div>
            ))}
          </div>
          {net === 'cellular' && <p className="rl-cap">{t('На стільниковій мережі сервер без замірів вважається у 1,8 раза повільнішим, а радіо після обміну ще 5 с тримає «хвіст» 0,9 Вт. Звідси висока ціна енергії.', 'On cellular, an unmeasured server is assumed 1.8 times slower, and after the exchange the radio holds a 0.9 W tail for another 5 s. That is where the energy cost comes from.')}</p>}
        </div>
      </div>
    </section>
  );
}

function Field() {
  const { t } = useLab();
  const [task, setTask] = useState<TaskId>('fraud');
  const [net, setNet] = useState<NetId>('cellular');
  const f = pol.field;
  const rows = (f.cells as Record<string, PlanCode[][]>)[`${task}|${net}`];
  const cw = 26, ch = 18, W = f.z.length * cw, H = rows.length * ch;
  const flat = rows.flat();
  const used = Array.from(new Set(flat));
  const share = (p: PlanCode) => Math.round(flat.filter(x => x === p).length / flat.length * 100);
  return (
    <section className="rl-sec ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Теплова карта рішень', 'Decision heatmap')}</p>
        <h3 className="rl-h">{t('Де метод', 'Where the method')}<br />{t('змінює рішення.', 'changes its mind.')}</h3>
        <p className="rl-p rl-narrow">
          {f.z.length * f.outage.length}{t(' викликів ', ' calls to ')}<code>Policy.decide</code>{t(' на кожну карту. Горизонтальна вісь показує чергу енергії Z, тобто скільки джоулів телефон уже витратив понад бюджет. Вертикальна вісь показує імовірність відключення світла за графіком, коли сервер може не відповісти. Колір позначає вибір методу.',
            ' per map. The horizontal axis is the energy queue Z: how many joules the phone has already spent over budget. The vertical axis is the probability of a scheduled power outage, when the server may not answer. Colour shows what the method chose.')}
        </p>
        <div className="rl-ctl rl-ctl-c">
          <Tabs<TaskId> ids={TASK_IDS} on={task} set={setTask} label={k => taskName(t, k)} />
          <Tabs<NetId> ids={NET_IDS} on={net} set={setNet} label={k => netName(t, k)} />
        </div>
        <figure className="rl-fig">
          <svg viewBox={`-56 -8 ${W + 70} ${H + 58}`} className="rl-field" role="img" aria-label={t('Карта рішень EdgeRouter', 'EdgeRouter decision map')}>
            {rows.map((r, i) => r.map((p, j) => (
              <rect key={i + '-' + j} x={j * cw} y={(rows.length - 1 - i) * ch} width={cw - 1} height={ch - 1} rx="2" fill={PLAN_COLOR[p]}>
                <title>{`Z = ${f.z[j].toFixed(2)} ${t('Дж', 'J')}, ${t('відключення', 'outage')} ${Math.round(f.outage[i] * 100)}% → ${planName(t, p)}`}</title>
              </rect>
            )))}
            {[0, 5, 10, 15, 20].map(i => <text key={i} x={-10} y={(rows.length - 1 - i) * ch + ch / 2 + 4} textAnchor="end" className="rl-svg-s">{Math.round(f.outage[i] * 100)}%</text>)}
            {[0, 5, 10, 15, 20, 25, 30].map(j => <text key={j} x={j * cw + cw / 2} y={H + 20} textAnchor="middle" className="rl-svg-s">{f.z[j].toFixed(1)}</text>)}
            <text x={W / 2} y={H + 44} textAnchor="middle" className="rl-svg-s">{t('черга енергії Z, Дж', 'energy queue Z, J')}</text>
          </svg>
          <figcaption className="rl-legend">{used.map(p => <span key={p}><i style={{ background: PLAN_COLOR[p] }} />{planName(t, p)} <b>{share(p)}%</b></span>)}</figcaption>
        </figure>
        <p className="rl-cap rl-narrow">{t('Заряд 60%, без перегріву, апріорні оцінки. Для чека й помічника на стільниковій мережі метод завжди лишається на телефоні: передача з «хвостом» радіо коштує дорожче, ніж виграш у якості.', 'Battery 60%, no throttling, prior estimates. For receipts and the assistant on cellular the method always stays on the phone: sending data with the radio tail costs more than the quality gain.')}</p>
      </div>
    </section>
  );
}

function Strategies() {
  const { t } = useLab();
  const S = pol.strategies as Record<string, Record<string, Record<string, number>>>;
  return (
    <section className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Порівняння', 'Comparison')}</p>
        <h3 className="rl-h">{t('П’ять стратегій.', 'Five strategies.')}<br />{t('48 однакових ситуацій.', '48 identical situations.')}</h3>
        <p className="rl-p rl-narrow">
          {t('Wi-Fi, стільникова й офлайн × заряд 10, 30, 60, 90% × з відключенням і без × з перевитратою енергії і без. Кожна смуга показує, як стратегія розподілила рішення для задачі. Фіксовані стратегії реагують однаково на будь-яку ситуацію, EdgeRouter змінює вибір.',
            'Wi-Fi, cellular and offline × battery at 10, 30, 60 and 90% × with and without an outage × with and without energy overspend. Each bar shows how a strategy split its decisions for a task. Fixed strategies respond the same way to everything; EdgeRouter adapts.')}
        </p>
        <figure className="rl-fig">
          <div className="rl-st">
            <span />
            {TASK_IDS.map(id => <span key={id} className="rl-st-h">{taskName(t, id)}</span>)}
            {STRATS.map(s => (
              <Row key={s} label={stratName(t, s)} on={s === 'adaptive'}>
                {TASK_IDS.map(id => {
                  const c = S[s][id];
                  const tot = Object.values(c).reduce((a, b) => a + b, 0);
                  return (
                    <span key={id} className="rl-st-bar">
                      {PLANS.filter(p => c[p]).map(p => (
                        <i key={p} style={{ width: `${(c[p] / tot) * 100}%`, background: PLAN_COLOR[p] }} title={`${planName(t, p)}: ${c[p]} ${t('з', 'of')} ${tot}`} />
                      ))}
                    </span>
                  );
                })}
              </Row>
            ))}
          </div>
          <figcaption className="rl-legend">{PLANS.map(p => <span key={p}><i style={{ background: PLAN_COLOR[p] }} />{planName(t, p)}</span>)}</figcaption>
        </figure>
        <p className="rl-cap rl-narrow">{t('Офлайн усі стратегії змушені рахувати на телефоні. Яка з них краща за якістю й енергією, покаже журнал зі справжніх iPhone на наступному етапі.', 'Offline, every strategy has to run on the phone. Which one wins on quality and energy will be shown by logs from real iPhones in the next stage.')}</p>
      </div>
    </section>
  );
}

function Row({ label, on, children }: { label: string; on?: boolean; children: React.ReactNode }) {
  return <><span className={'rl-st-l' + (on ? ' on' : '')}>{label}</span>{children}</>;
}

function Energy() {
  const { t } = useLab();
  const e = pol.energyModel;
  const W = 900, H = 200, sx = W / 6;
  // Radio power for a 0.25 s exchange, then the tail.
  const curve = (radio: number, tailS: number, tailW: number) => {
    const t0 = 0.25;
    const pts = [[0, 0], [0, radio], [t0, radio], [t0, tailW], [t0 + tailS, tailW], [t0 + tailS, 0], [6, 0]];
    return pts.map(([x, y], i) => `${i ? 'L' : 'M'}${(x * sx).toFixed(1)} ${(H - (y / 2) * H).toFixed(1)}`).join(' ');
  };
  const W_ = t('Вт', 'W'), S_ = t('с', 's');
  return (
    <section className="rl-sec ap-reveal">
      <div className="ap-wrap rl-split rl-split-wide">
        <div>
          <p className="rl-kicker">{t('Модель енергії', 'Energy model')}</p>
          <h3 className="rl-h">{t('Дорогий не запит.', 'The request is cheap.')}<br />{t('Дорогий «хвіст».', 'The tail is not.')}</h3>
          <p className="rl-p">
            {t(`iOS не дає застосунку миттєвої потужності, тож енергію метод рахує з часу й коефіцієнтів. Після відповіді стільниковий модем ще ${e.tailS.cellular} с не засинає й тягне ${e.tailW.cellular} Вт. Тому навіть крихітний запит коштує близько ${(e.tailS.cellular * e.tailW.cellular).toFixed(1)} Дж, у сотні разів більше за правило антифроду на телефоні.`,
              `iOS does not expose instantaneous power to apps, so the method estimates energy from time and coefficients. After a reply, the cellular modem stays awake for ${e.tailS.cellular} s drawing ${e.tailW.cellular} W. Even a tiny request therefore costs about ${(e.tailS.cellular * e.tailW.cellular).toFixed(1)} J, hundreds of times more than an on-device fraud rule.`)}
          </p>
          <div className="rl-kv">
            <div><span>{t('Обчислення на телефоні', 'On-device compute')}</span><b>{e.computeW} {W_}</b></div>
            <div><span>{t('Радіо Wi-Fi / стільникове', 'Radio, Wi-Fi / cellular')}</span><b>{e.radioW.wifi} / {e.radioW.cellular} {W_}</b></div>
            <div><span>{t('«Хвіст» Wi-Fi', 'Wi-Fi tail')}</span><b>{e.tailS.wifi} {S_} × {e.tailW.wifi} {W_}</b></div>
            <div><span>{t('«Хвіст» стільникового', 'Cellular tail')}</span><b>{e.tailS.cellular} {S_} × {e.tailW.cellular} {W_}</b></div>
          </div>
          <p className="rl-cap">{t('Стартові коефіцієнти з літератури (MAUI, заміри «хвоста» LTE). Наступний крок: калібрування Power Profiler на власних iPhone.', 'Starting coefficients come from the literature (MAUI, LTE tail measurements). Next step: calibration with Power Profiler on our own iPhones.')}</p>
        </div>
        <figure className="rl-fig rl-fig-flat">
          <svg viewBox={`-40 -14 ${W + 50} ${H + 54}`} className="rl-chart" role="img" aria-label={t('Потужність радіо після запиту', 'Radio power after a request')}>
            {[0.5, 1, 1.5].map(w => <g key={w}><line x1="0" x2={W} y1={H - (w / 2) * H} y2={H - (w / 2) * H} stroke="#2c2c2e" /><text x="-8" y={H - (w / 2) * H + 4} textAnchor="end" className="rl-svg-s">{w}</text></g>)}
            <path d={curve(e.radioW.cellular, e.tailS.cellular, e.tailW.cellular)} fill="rgba(255,69,58,.14)" stroke="#ff453a" strokeWidth="2.5" />
            <path d={curve(e.radioW.wifi, e.tailS.wifi, e.tailW.wifi)} fill="rgba(10,132,255,.18)" stroke="#0a84ff" strokeWidth="2.5" />
            <line x1="0" x2={W} y1={H} y2={H} stroke="#48484a" />
            {[0, 1, 2, 3, 4, 5, 6].map(s => <text key={s} x={s * sx} y={H + 22} textAnchor="middle" className="rl-svg-s">{s} {S_}</text>)}
            <text x="-8" y="0" textAnchor="end" className="rl-svg-s">{W_}</text>
          </svg>
          <figcaption className="rl-legend"><span><i style={{ background: '#ff453a' }} />{t('стільникове', 'cellular')}</span><span><i style={{ background: '#0a84ff' }} />Wi-Fi</span><span>{t('обмін 0,25 с, далі «хвіст»', 'a 0.25 s exchange, then the tail')}</span></figcaption>
        </figure>
      </div>
    </section>
  );
}

function Conformal() {
  const { t } = useLab();
  const p = pol.conformal as number[];
  const W = 900, H = 220;
  const lo = Math.min(...p) - 0.05, hi = Math.max(...p) + 0.05;
  const y = (v: number) => H - ((v - lo) / (hi - lo)) * H;
  const line = p.map((v, i) => `${i ? 'L' : 'M'}${((i / (p.length - 1)) * W).toFixed(1)} ${y(v).toFixed(1)}`).join(' ');
  return (
    <section className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Каскад', 'Cascade')}</p>
        <h3 className="rl-h">{t('Поріг, який', 'A threshold that')}<br />{t('вчиться на помилках.', 'learns from mistakes.')}</h3>
        <p className="rl-p rl-narrow">
          {t('У каскаді телефон відповідає першим, і відповідь приймається, якщо невпевненість нижча за поріг λ. Поріг оновлюється після кожного зворотного зв’язку за правилом адаптивного конформного виводу (Gibbs & Candès, 2021): ',
            'In the cascade the phone answers first, and the answer is accepted when its uncertainty is below the threshold λ. After every piece of feedback the threshold is updated by the adaptive conformal inference rule (Gibbs & Candès, 2021): ')}
          <code>λ ← λ + η(α − err)</code>
          {t(', α = 5%, η = 0,05. Помилка звужує поріг, правильна відповідь розширює.', ', α = 5%, η = 0.05. An error tightens the threshold; a correct answer relaxes it.')}
        </p>
        <figure className="rl-fig">
          <svg viewBox={`-40 -10 ${W + 50} ${H + 50}`} className="rl-chart" role="img" aria-label={t('Траєкторія порогу λ', 'Trajectory of the threshold λ')}>
            <rect x={W / 2} y="0" width={W / 2} height={H} fill="rgba(255,69,58,.06)" />
            <line x1={W / 2} x2={W / 2} y1="0" y2={H} stroke="#48484a" strokeDasharray="4 5" />
            <text x={W / 2 - 10} y="16" textAnchor="end" className="rl-svg-s">{t('телефон помиляється у 3%', 'phone is wrong 3% of the time')}</text>
            <text x={W / 2 + 10} y="16" className="rl-svg-s">{t('зсув: помилок 15%', 'shift: 15% errors')}</text>
            {[lo + 0.05, (lo + hi) / 2, hi - 0.05].map(v => <text key={v} x="-8" y={y(v) + 4} textAnchor="end" className="rl-svg-s">{v.toFixed(2)}</text>)}
            <path d={line} fill="none" stroke="#ffd400" strokeWidth="2" />
            <line x1="0" x2={W} y1={H} y2={H} stroke="#48484a" />
            <text x="0" y={H + 22} className="rl-svg-s">{t('відповідь 1', 'answer 1')}</text>
            <text x={W} y={H + 22} textAnchor="end" className="rl-svg-s">{t('відповідь', 'answer')} {p.length}</text>
          </svg>
          <figcaption className="rl-cap">{t('Справжнє правило ', 'The actual rule ')}<code>PolicyState.updateThreshold</code>{t(' на тестовому потоці: 200 відповідей з 3% помилок, далі 200 з 15%. Після зсуву поріг стискається сам, і більше задач іде на сервер.', ' on a test stream: 200 answers with 3% errors, then 200 with 15%. After the shift the threshold tightens on its own, and more tasks go to the server.')}</figcaption>
        </figure>
      </div>
    </section>
  );
}

function Masking() {
  const { t } = useLab();
  const r = data.redaction;
  const parts = r.output.split(/(\[[^\]]+\])/);
  return (
    <section className="rl-sec ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Приватність', 'Privacy')}</p>
        <h3 className="rl-h">{t('Що бачить сервер.', 'What the server sees.')}</h3>
        <p className="rl-p rl-narrow">
          {t('Чек і помічник працюють з особистими даними, тож на сервер вони йдуть лише через ', 'Receipts and the assistant handle personal data, so they reach the server only through ')}
          <code>Redactor</code>
          {t('. Він замінює IBAN, номери карток, телефони, пошту, ІПН і номери паспортів. Суми й назви магазинів лишаються, бо без них сервер не розбере чек. Фото чека з телефона не виходить ніколи: розпізнається Vision локально.',
            '. It replaces IBANs, card numbers, phone numbers, email addresses, tax IDs and passport numbers. Amounts and shop names stay, because the server cannot parse a receipt without them. A receipt photo never leaves the phone: Vision reads it locally.')}
        </p>
        <div className="rl-mask">
          <div className="rl-mask-col"><span className="rl-mask-t">{t('На iPhone', 'On the iPhone')}</span><p>{r.input}</p></div>
          <svg viewBox="0 0 80 40" className="rl-mask-arr" aria-hidden><path d="M4 20H70M58 8l12 12-12 12" /></svg>
          <div className="rl-mask-col rl-mask-srv">
            <span className="rl-mask-t">{t('На сервер · замін: ', 'To the server · replacements: ')}{r.count}</span>
            <p>{parts.map((s, i) => (/^\[.+\]$/.test(s) ? <mark key={i} className="rl-tok">{s}</mark> : <span key={i}>{s}</span>))}</p>
          </div>
        </div>
        <p className="rl-cap">{t('Вивід справжньої функції ', 'Output of the actual ')}<code>Redactor.redact</code>{t(' на цьому реченні. Імена поточна версія не маскує, це відоме обмеження.', ' function on this sentence (in Ukrainian, as the app uses it). The current version does not redact names; this is a known limitation.')}</p>
      </div>
    </section>
  );
}

function Dataset() {
  const { t, nf } = useLab();
  const D = days(t);
  const week = ds.weekHour as number[][];
  const fw = ds.fraudWeekHour as number[][];
  const maxW = Math.max(...week.flat());
  const rate = week.map((r, d) => r.map((c, h) => (c ? fw[d][h] / c : 0)));
  const maxR = Math.max(...rate.flat());
  const ph = ds.patternHour as Record<string, number[]>;
  const pats = Object.keys(ph).sort((a, b) => ph[b].reduce((x, y) => x + y, 0) - ph[a].reduce((x, y) => x + y, 0));
  const maxP = Math.max(...pats.flatMap(p => ph[p]));
  const an = ds.amountNormal as number[], af = ds.amountFraud as number[];
  const sn = an.reduce((a, b) => a + b, 0), sf = af.reduce((a, b) => a + b, 0);
  const maxA = Math.max(...an.map(v => v / sn), ...af.map(v => v / sf));
  const yel = (v: number) => `rgba(255, 212, 0, ${0.06 + 0.94 * v})`;
  const red = (v: number) => `rgba(255, 69, 58, ${0.06 + 0.94 * v})`;
  return (
    <section className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Дані для антифроду', 'Fraud data')}</p>
        <h3 className="rl-h">{nf(ds.total)} {t('транзакцій.', 'transactions.')}<br />{t('Усі розмічені.', 'All labelled.')}</h3>
        <p className="rl-p rl-narrow">
          {t(`Щоб виміряти якість, потрібна правильна відповідь. Тому в банку є розмічений набір: ${ds.accounts} рахунків, шість місяців операцій (з ${ds.from_.slice(0, 10)} по ${ds.to.slice(0, 10)}), серед них ${fraudTotal} шахрайських за п’ятьма сценаріями атак. Набір синтетичний, його генерує сервер, реальних клієнтів у ньому немає.`,
            `Measuring quality needs a known right answer. So the bank holds a labelled set: ${ds.accounts} accounts, six months of activity (${ds.from_.slice(0, 10)} to ${ds.to.slice(0, 10)}), including ${fraudTotal} fraudulent transactions across five attack patterns. The set is synthetic and generated by the server; it contains no real customers.`)}
        </p>

        <div className="rl-pats">
          {(ds.patterns as [string, number][]).filter(p => p[0] !== 'normal').map(([p, c]) => (
            <div key={p}><b>{c}</b><span>{patternName(t, p)}</span><i style={{ width: `${(c / fraudTotal) * 100}%` }} /></div>
          ))}
        </div>

        <figure className="rl-fig">
          <figcaption className="rl-fig-h"><h4>{t('Коли відбуваються операції', 'When transactions happen')}</h4><span>{t('кількість за днем тижня й годиною', 'count by weekday and hour')}</span></figcaption>
          <Week days={D} rows={week} color={v => yel(v / maxW)} title={(d, h, v) => `${D[d]} ${h}:00, ${t('операцій', 'transactions')}: ${nf(v)}`} />
          <div className="rl-scale"><span>0</span><i style={{ background: `linear-gradient(90deg, ${yel(0)}, ${yel(1)})` }} /><span>{nf(maxW)}</span></div>
        </figure>

        <figure className="rl-fig">
          <figcaption className="rl-fig-h"><h4>{t('Де ховається шахрайство', 'Where fraud hides')}</h4><span>{t('частка шахрайських операцій у кожній клітинці', 'share of fraudulent transactions in each cell')}</span></figcaption>
          <Week days={D} rows={rate} color={v => red(v / maxR)} title={(d, h, v) => `${D[d]} ${h}:00, ${t('шахрайських', 'fraudulent')}: ${(v * 100).toFixed(2)}%`} />
          <div className="rl-scale"><span>0%</span><i style={{ background: `linear-gradient(90deg, ${red(0)}, ${red(1)})` }} /><span>{(maxR * 100).toFixed(1)}%</span></div>
        </figure>

        <figure className="rl-fig">
          <figcaption className="rl-fig-h"><h4>{t('Почерк кожної атаки', 'The signature of each attack')}</h4><span>{t('шахрайські операції за сценарієм і годиною', 'fraudulent transactions by pattern and hour')}</span></figcaption>
          <div className="rl-week rl-week-p">
            <span />
            {Array.from({ length: 24 }, (_, h) => <span key={h} className="rl-wk-h">{h % 3 === 0 ? h : ''}</span>)}
            {pats.map(p => (
              <Row key={p} label={patternName(t, p)}>
                {ph[p].map((v, h) => <span key={h} className="rl-wk-c rl-wk-flat" style={{ background: red(v / maxP) }} title={`${patternName(t, p)} · ${h}:00, ${t('операцій', 'transactions')}: ${v}`} />)}
              </Row>
            ))}
          </div>
        </figure>

        <figure className="rl-fig">
          <figcaption className="rl-fig-h"><h4>{t('Суми', 'Amounts')}</h4><span>{t('розподіл за сумою в TAX, логарифмічна шкала, частка в групі', 'distribution by amount in TAX, log scale, share within each group')}</span></figcaption>
          <svg viewBox="-10 -10 920 250" className="rl-chart" role="img" aria-label={t('Розподіл сум звичайних і шахрайських операцій', 'Amount distribution of normal and fraudulent transactions')}>
            {an.map((v, i) => {
              const w = 900 / an.length;
              const hn = (v / sn / maxA) * 200, hf = (af[i] / sf / maxA) * 200;
              return (
                <g key={i}>
                  <rect x={i * w + 2} y={200 - hn} width={w / 2 - 3} height={hn} rx="2" fill="#ffd400" />
                  <rect x={i * w + w / 2} y={200 - hf} width={w / 2 - 3} height={hf} rx="2" fill="#ff453a" />
                </g>
              );
            })}
            <line x1="0" x2="900" y1="200" y2="200" stroke="#48484a" />
            {[0, 4, 8, 12, 16, 20].map(i => <text key={i} x={(i / an.length) * 900} y="226" textAnchor="middle" className="rl-svg-s">{nf(Math.round(ds.amountBins[i]))}</text>)}
          </svg>
          <div className="rl-legend"><span><i style={{ background: '#ffd400' }} />{t('звичайні', 'normal')}</span><span><i style={{ background: '#ff453a' }} />{t('шахрайські', 'fraudulent')}</span></div>
        </figure>
      </div>
    </section>
  );
}

function Week({ days: D, rows, color, title }: { days: string[]; rows: number[][]; color: (v: number) => string; title: (d: number, h: number, v: number) => string }) {
  return (
    <div className="rl-week">
      <span />
      {Array.from({ length: 24 }, (_, h) => <span key={h} className="rl-wk-h">{h % 3 === 0 ? h : ''}</span>)}
      {rows.map((r, d) => (
        <Row key={d} label={D[d]}>
          {r.map((v, h) => <span key={h} className="rl-wk-c" style={{ background: color(v) }} title={title(d, h, v)} />)}
        </Row>
      ))}
    </div>
  );
}

function Parity() {
  const { t } = useLab();
  const p = data.parity;
  const lv = p.levels as Record<string, number>;
  const flags = p.flags as [string, number][];
  const maxF = Math.max(...flags.map(f => f[1]));
  const sh = p.scoreHist as number[];
  const maxS = Math.max(...sh);
  return (
    <section className="rl-sec ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Перенесення антифроду', 'Porting fraud detection')}</p>
        <h3 className="rl-h">{p.n} {t('з', 'of')} {p.n}.<br />{t('Збіг до бала.', 'Identical to the point.')}</h3>
        <p className="rl-p rl-narrow">
          {t('Щоб чесно порівнювати телефон і сервер, перший шар антифроду перенесено з Python у Swift (', 'To compare phone and server fairly, the first fraud layer was ported from Python to Swift (')}
          <code>FraudLite</code>
          {t(`) один до одного. Сервер згенерував ${p.n} еталонних векторів (суми, баланси, описи) з бальною оцінкою, рівнем ризику й прапорами. Тест вимагає точного збігу кожного.`,
            `) line for line. The server generated ${p.n} reference vectors (amounts, balances, descriptions) with a score, a risk level and flags. The test requires every one of them to match exactly.`)}
        </p>
        <div className="rl-par">
          <figure className="rl-fig">
            <figcaption className="rl-fig-h"><h4>{t('Рівні ризику', 'Risk levels')}</h4></figcaption>
            <div className="rl-stack">{LEVELS.map(([k, c]) => <i key={k} style={{ flex: lv[k] || 0, background: c }} />)}</div>
            <div className="rl-legend">{LEVELS.map(([k, c]) => <span key={k}><i style={{ background: c }} />{levelName(t, k)} <b>{lv[k] || 0}</b></span>)}</div>
            <figcaption className="rl-fig-h rl-mt"><h4>{t('Бали', 'Scores')}</h4><span>{t('0–100, кроком 10', '0–100, in steps of 10')}</span></figcaption>
            <div className="rl-hist">{sh.map((v, i) => <i key={i} style={{ height: `${(v / maxS) * 100}%` }} title={`${i * 10}–${i * 10 + 9}: ${v}`} />)}</div>
          </figure>
          <figure className="rl-fig">
            <figcaption className="rl-fig-h"><h4>{t('Що спрацьовує', 'What fires')}</h4><span>{t('прапори на векторах', 'flags across the vectors')}</span></figcaption>
            <div className="rl-bars">
              {flags.map(([f, c]) => <div key={f}><span>{flagName(t, f)}</span><i style={{ width: `${(c / maxF) * 100}%` }} /><b>{c}</b></div>)}
            </div>
          </figure>
        </div>
      </div>
    </section>
  );
}

function Status() {
  const { t, nf } = useLab();
  const steps: [string, string, boolean][] = [
    [t('Метод EdgeRouter', 'The EdgeRouter method'), t('Оцінки, модель енергії, політика з чергою Ляпунова, каскад з конформним порогом, маскування, журнал. Swift-пакет з тестами.', 'Estimators, energy model, a policy with a Lyapunov queue, a cascade with a conformal threshold, redaction, logging. A Swift package with tests.'), true],
    [t('FraudLite на телефоні', 'FraudLite on the phone'), t(`Перший шар антифроду в Swift, збіг із сервером на ${data.parity.n} векторах.`, `The first fraud layer in Swift, matching the server on ${data.parity.n} vectors.`), true],
    [t('Навчальний банк і набір даних', 'Training bank and dataset'), t(`Цей банк і ${nf(ds.total)} розмічених транзакцій.`, `This bank and ${nf(ds.total)} labelled transactions.`), true],
    [t('Калібрування енергії', 'Energy calibration'), t('Коефіцієнти поки з літератури. Потрібні заміри Power Profiler на кількох iPhone.', 'Coefficients still come from the literature. Power Profiler measurements on several iPhones are needed.'), false],
    [t('Невпевненість антифроду', 'Fraud uncertainty'), t('На телефоні поки евристика. Її треба навчити на розміченому наборі.', 'Still a heuristic on the phone. It needs to be trained on the labelled set.'), false],
    [t('Локальна мовна модель', 'On-device language model'), t('Foundation Models не підтримує українську, тож помічнику на телефоні потрібна власна модель.', 'Foundation Models does not support Ukrainian, so the on-device assistant needs its own model.'), false],
  ];
  return (
    <section className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Стан роботи', 'Progress')}</p>
        <h3 className="rl-h">{t('Зроблено', 'Done')}<br />{t('й заплановано.', 'and planned.')}</h3>
        <ol className="rl-tl">
          {steps.map(([h, p, done]) => <li key={h} className={done ? 'done' : ''}><span>{done ? t('Готово', 'Done') : t('Попереду', 'Next')}</span><h4>{h}</h4><p>{p}</p></li>)}
        </ol>
      </div>
    </section>
  );
}

function Logged() {
  const { t } = useLab();
  const fields = [
    [t('Задача й стратегія', 'Task and strategy'), t('яку задачу і за якою стратегією вирішували', 'which task was solved and under which strategy')],
    [t('Стан телефона', 'Phone state'), t('мережа, заряд, енергозбереження, перегрів, імовірність відключення', 'network, battery, Low Power Mode, thermal state, outage probability')],
    [t('Усі кандидати', 'All candidates'), t('час, енергія, якість і ціль для кожного варіанта', 'latency, energy, quality and objective for every option')],
    [t('Рішення', 'Decision'), t('обраний план, де фактично виконано, чи була ескалація чи відкат', 'the chosen plan, where it actually ran, any escalation or fallback')],
    [t('Каскад і бюджет', 'Cascade and budget'), t('невпевненість, поріг λ, черга енергії Z', 'uncertainty, the threshold λ, the energy queue Z')],
    [t('Результат', 'Outcome'), t('фактичний час і енергія, кількість замін маскування, причина', 'actual latency and energy, number of redactions, the reason')],
  ];
  return (
    <section className="rl-sec rl-ethics ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">{t('Журнал рішень', 'Decision log')}</p>
        <h3 className="rl-h">{t('Що потрапляє', 'What goes')}<br />{t('в журнал.', 'into the log.')}</h3>
        <div className="rl-table">{fields.map(([a, b]) => <div key={a}><b>{a}</b><span>{b}</span></div>)}</div>
        <p className="rl-p rl-narrow rl-mt">
          {t('Тексти запитів, фото й відповіді в журнал ', 'Request text, photos and answers never enter ')}
          <code>decisions.jsonl</code>
          {t(' не потрапляють. Стратегії, параметри α, V, бюджет енергії й експорт журналу доступні в розділі «Лабораторія» застосунку для iPhone.', '. Strategies, the α and V parameters, the energy budget and log export are in the Lab screen of the iPhone app.')}
        </p>
      </div>
    </section>
  );
}
