import { useState } from 'react';
import data from './researchData.json';

// ─── Research chapter of the promo landing ───────────────────────
// Every number here is real: researchData.json is exported from the EdgeRouter Swift sources
// (Policy.decide, EnergyModel, Redactor, the adaptive conformal rule), the labelled research
// dataset in the sandbox database, and the 454 FraudLite parity vectors. Nothing is drawn by hand.

type PlanCode = 'd' | 'c' | 'r' | 'kc' | 'kr';
type Cand = { plan: PlanCode; ms: number; j: number; q: number; obj: number };

const PLAN_NAME: Record<PlanCode, string> = {
  d: 'Телефон', c: 'Сервер', r: 'Сервер з маскою', kc: 'Каскад → сервер', kr: 'Каскад → сервер з маскою',
};
const PLAN_COLOR: Record<PlanCode, string> = { d: '#ffd400', c: '#0a84ff', r: '#8e7cff', kc: '#30d158', kr: '#64d2ff' };
const TASKS = [
  { id: 'fraud', name: 'Перевірка переказу', data: 'відкриті: дані належать банку' },
  { id: 'receipt', name: 'Розбір чека', data: 'особисті: лише з маскою' },
  { id: 'assistant', name: 'Помічник', data: 'особисті: лише з маскою' },
] as const;
type TaskId = typeof TASKS[number]['id'];
const NETS = [{ id: 'wifi', name: 'Wi-Fi' }, { id: 'cellular', name: 'Стільникова' }] as const;
type NetId = typeof NETS[number]['id'];
const STRATS = [
  { id: 'alwaysDevice', name: 'Завжди телефон' }, { id: 'alwaysCloud', name: 'Завжди сервер' },
  { id: 'rules', name: 'Прості правила' }, { id: 'cascade', name: 'Каскад' }, { id: 'adaptive', name: 'EdgeRouter' },
] as const;
const PATTERN_NAME: Record<string, string> = {
  normal: 'Звичайні', money_mule: 'Дроп-рахунок', rapid_succession: 'Серія швидких переказів',
  structuring: 'Дроблення суми', night_batch: 'Нічна пачка', new_recipient_large_amount: 'Велика сума новому отримувачу',
};
const FLAG_NAME: Record<string, string> = {
  suspicious_description: 'Підозрілий опис', structuring: 'Дроблення суми', balance_depletion_critical: 'Критичне спустошення балансу',
  balance_depletion: 'Спустошення балансу', multi_rule_correlation: 'Збіг кількох правил', round_amount: 'Кругла сума',
  threshold_masking: 'Сума трохи нижче порогу',
};
const LEVEL = [['low', 'Низький', '#30d158'], ['medium', 'Середній', '#ffd400'], ['high', 'Високий', '#ff9f0a'], ['critical', 'Критичний', '#ff453a']] as const;
const DAYS = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

const ds = data.dataset;
const pol = data.policy;
const nf = (n: number) => n.toLocaleString('uk-UA');
const fraudTotal = (ds.patterns as [string, number][]).filter(p => p[0] !== 'normal').reduce((a, p) => a + p[1], 0);

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

function Intro() {
  return (
    <section className="rl-intro ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">Наукова лабораторія</p>
        <h2 className="rl-display">Цей банк —<br /><span className="ap-gold">експеримент</span>.</h2>
        <p className="rl-lead">
          TaxTech — віртуальна лабораторія цифрових фінансів. На ній іде наукова робота «Метод інтелектуального вибору
          між локальними та хмарними обчисленнями в мобільних застосунках». Нижче — не ілюстрації, а вивід самого коду
          методу й дані, на яких його перевіряють.
        </p>
        <dl className="rl-stats">
          <div><dt>{nf(ds.total)}</dt><dd>розмічених транзакцій у дослідницькому наборі</dd></div>
          <div><dt>{fraudTotal}</dt><dd>шахрайських, п’ять сценаріїв атак</dd></div>
          <div><dt>{data.parity.n}</dt><dd>еталонних векторів: антифрод телефона ≡ сервера</dd></div>
          <div><dt>3</dt><dd>ІІ-задачі, для яких метод обирає, де рахувати</dd></div>
        </dl>
      </div>
    </section>
  );
}

function Question() {
  return (
    <section className="rl-sec ap-reveal">
      <div className="ap-wrap rl-split">
        <div>
          <p className="rl-kicker">Питання дослідження</p>
          <h3 className="rl-h">Де думати:<br />у кишені чи в хмарі?</h3>
          <p className="rl-p">
            Сервер точніший, але кожен запит будить радіо й передає дані назовні. Телефон приватний і працює без мережі,
            але поступається якістю. Метод EdgeRouter для кожної задачі зважує час, енергію й якість, враховуючи заряд,
            мережу, перегрів і навіть графік відключень світла — і пише кожне рішення в журнал.
          </p>
        </div>
        <div className="rl-tasks">
          {TASKS.map(t => {
            const c = (pol.candidates as Record<string, Cand[]>)[`${t.id}|wifi`];
            return (
              <div key={t.id}>
                <h4>{t.name}</h4>
                <p>Дані: {t.data}</p>
                <ul>{c.filter(x => x.plan.length === 1).map(x => <li key={x.plan}><i style={{ background: PLAN_COLOR[x.plan] }} />{PLAN_NAME[x.plan]}<span>{Math.round(x.ms)} мс · якість {Math.round(x.q * 100)}%</span></li>)}</ul>
              </div>
            );
          })}
          <p className="rl-cap">Апріорні оцінки з профілів задач у застосунку (Wi-Fi). Під час роботи їх уточнюють заміри.</p>
        </div>
      </div>
    </section>
  );
}

function Decision() {
  const [task, setTask] = useState<TaskId>('receipt');
  const [net, setNet] = useState<NetId>('wifi');
  const cands = (pol.candidates as Record<string, Cand[]>)[`${task}|${net}`];
  const best = cands.reduce((a, b) => (b.obj < a.obj ? b : a));
  const maxJ = Math.max(...cands.map(c => c.j));
  const maxMs = Math.max(...cands.map(c => c.ms));
  return (
    <section className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">Як ухвалюється рішення</p>
        <h3 className="rl-h">Кожен варіант<br />отримує ціну.</h3>
        <p className="rl-p rl-narrow">
          Для кожного дозволеного варіанта метод рахує ціль drift-plus-penalty:
          <code> V·(t/1000 − 4·q) + Z·E</code>, де t — час, q — якість, E — енергія, Z — черга перевитрати.
          Перемагає найменша. Це точні значення з <code>Policy.decide</code> для спокійного стану (Z = 0).
        </p>
        <div className="rl-panel">
          <div className="rl-ctl">
            <div className="rl-seg">{TASKS.map(t => <button key={t.id} type="button" className={t.id === task ? 'on' : ''} onClick={() => setTask(t.id)}>{t.name}</button>)}</div>
            <div className="rl-seg">{NETS.map(n => <button key={n.id} type="button" className={n.id === net ? 'on' : ''} onClick={() => setNet(n.id)}>{n.name}</button>)}</div>
          </div>
          <div className="rl-cands">
            <div className="rl-cand-h"><span>Варіант</span><span>Час</span><span>Енергія</span><span>Якість</span><span>Ціль</span></div>
            {[...cands].sort((a, b) => a.obj - b.obj).map(c => (
              <div key={c.plan} className={'rl-cand' + (c === best ? ' on' : '')} style={{ ['--c' as string]: PLAN_COLOR[c.plan] }}>
                <span className="rl-cand-n"><i />{PLAN_NAME[c.plan]}{c === best && <b>обрано</b>}</span>
                <span><em style={{ width: `${(c.ms / maxMs) * 100}%` }} />{c.ms < 1000 ? `${Math.round(c.ms)} мс` : `${(c.ms / 1000).toFixed(2)} с`}</span>
                <span><em style={{ width: `${(c.j / maxJ) * 100}%` }} />{c.j < 0.1 ? `${Math.round(c.j * 1000)} мДж` : `${c.j.toFixed(2)} Дж`}</span>
                <span>{(c.q * 100).toFixed(1)}%</span>
                <span className="rl-num">{c.obj.toFixed(3)}</span>
              </div>
            ))}
          </div>
          {net === 'cellular' && <p className="rl-cap">На стільниковій мережі сервер без замірів вважається у 1,8 раза повільнішим, а радіо після обміну ще 5 с тримає «хвіст» 0,9 Вт — звідси ціна енергії.</p>}
        </div>
      </div>
    </section>
  );
}

function Field() {
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
        <p className="rl-kicker">Теплова карта рішень</p>
        <h3 className="rl-h">Межа, яку<br />проводить метод.</h3>
        <p className="rl-p rl-narrow">
          {f.z.length * f.outage.length} викликів <code>Policy.decide</code> на кожну карту. По горизонталі — черга енергії Z:
          скільки джоулів телефон уже перевитратив понад бюджет. По вертикалі — імовірність відключення світла з графіка:
          тоді сервер може не відповісти. Колір — що обрав метод.
        </p>
        <div className="rl-ctl rl-ctl-c">
          <div className="rl-seg">{TASKS.map(t => <button key={t.id} type="button" className={t.id === task ? 'on' : ''} onClick={() => setTask(t.id)}>{t.name}</button>)}</div>
          <div className="rl-seg">{NETS.map(n => <button key={n.id} type="button" className={n.id === net ? 'on' : ''} onClick={() => setNet(n.id)}>{n.name}</button>)}</div>
        </div>
        <figure className="rl-fig">
          <svg viewBox={`-56 -8 ${W + 70} ${H + 58}`} className="rl-field" role="img" aria-label="Карта рішень EdgeRouter">
            {rows.map((r, i) => r.map((p, j) => (
              <rect key={i + '-' + j} x={j * cw} y={(rows.length - 1 - i) * ch} width={cw - 1} height={ch - 1} rx="2" fill={PLAN_COLOR[p]}>
                <title>{`Z = ${f.z[j].toFixed(2)} Дж, відключення ${Math.round(f.outage[i] * 100)}% → ${PLAN_NAME[p]}`}</title>
              </rect>
            )))}
            {[0, 5, 10, 15, 20].map(i => <text key={i} x={-10} y={(rows.length - 1 - i) * ch + ch / 2 + 4} textAnchor="end" className="rl-svg-s">{Math.round(f.outage[i] * 100)}%</text>)}
            {[0, 5, 10, 15, 20, 25, 30].map(j => <text key={j} x={j * cw + cw / 2} y={H + 20} textAnchor="middle" className="rl-svg-s">{f.z[j].toFixed(1)}</text>)}
            <text x={W / 2} y={H + 44} textAnchor="middle" className="rl-svg-s">черга енергії Z, Дж</text>
          </svg>
          <figcaption className="rl-legend">{used.map(p => <span key={p}><i style={{ background: PLAN_COLOR[p] }} />{PLAN_NAME[p]} <b>{share(p)}%</b></span>)}</figcaption>
        </figure>
        <p className="rl-cap rl-narrow">Заряд 60%, без перегріву, апріорні оцінки. Для чека й помічника на стільниковій мережі метод завжди лишається на телефоні: передача з «хвостом» радіо коштує дорожче, ніж виграш у якості.</p>
      </div>
    </section>
  );
}

function Strategies() {
  const S = pol.strategies as Record<string, Record<string, Record<string, number>>>;
  return (
    <section className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">Порівняння</p>
        <h3 className="rl-h">П’ять стратегій.<br />48 однакових ситуацій.</h3>
        <p className="rl-p rl-narrow">
          Wi-Fi, стільникова й офлайн × заряд 10, 30, 60, 90% × з відключенням і без × з перевитратою енергії і без.
          Кожна смуга — частка рішень стратегії для задачі. Фіксовані стратегії відповідають однаково на все; EdgeRouter — по-різному.
        </p>
        <figure className="rl-fig">
          <div className="rl-st">
            <span />
            {TASKS.map(t => <span key={t.id} className="rl-st-h">{t.name}</span>)}
            {STRATS.map(s => (
              <Row key={s.id} label={s.name} on={s.id === 'adaptive'}>
                {TASKS.map(t => {
                  const c = S[s.id][t.id];
                  const tot = Object.values(c).reduce((a, b) => a + b, 0);
                  return (
                    <span key={t.id} className="rl-st-bar">
                      {(Object.keys(PLAN_NAME) as PlanCode[]).filter(p => c[p]).map(p => (
                        <i key={p} style={{ width: `${(c[p] / tot) * 100}%`, background: PLAN_COLOR[p] }} title={`${PLAN_NAME[p]}: ${c[p]} з ${tot}`} />
                      ))}
                    </span>
                  );
                })}
              </Row>
            ))}
          </div>
          <figcaption className="rl-legend">{(Object.keys(PLAN_NAME) as PlanCode[]).map(p => <span key={p}><i style={{ background: PLAN_COLOR[p] }} />{PLAN_NAME[p]}</span>)}</figcaption>
        </figure>
        <p className="rl-cap rl-narrow">Офлайн усі стратегії змушені рахувати на телефоні. Яка з них краща за якістю й енергією, покаже журнал на справжніх iPhone — це наступний етап.</p>
      </div>
    </section>
  );
}

function Row({ label, on, children }: { label: string; on?: boolean; children: React.ReactNode }) {
  return <><span className={'rl-st-l' + (on ? ' on' : '')}>{label}</span>{children}</>;
}

function Energy() {
  const e = pol.energyModel;
  const W = 900, H = 200, sx = W / 6;
  // Radio power for a 0.25 s exchange, then the tail.
  const curve = (radio: number, tailS: number, tailW: number) => {
    const t0 = 0.25;
    const pts = [[0, 0], [0, radio], [t0, radio], [t0, tailW], [t0 + tailS, tailW], [t0 + tailS, 0], [6, 0]];
    return pts.map(([x, y], i) => `${i ? 'L' : 'M'}${(x * sx).toFixed(1)} ${(H - (y / 2) * H).toFixed(1)}`).join(' ');
  };
  return (
    <section className="rl-sec ap-reveal">
      <div className="ap-wrap rl-split rl-split-wide">
        <div>
          <p className="rl-kicker">Модель енергії</p>
          <h3 className="rl-h">Дорогий не запит.<br />Дорогий «хвіст».</h3>
          <p className="rl-p">
            iOS не дає застосунку миттєвої потужності, тож енергію метод рахує з часу й коефіцієнтів. Після відповіді
            стільниковий модем ще {e.tailS.cellular} с не засинає й тягне {e.tailW.cellular} Вт. Тому навіть крихітний запит
            коштує близько {(e.tailS.cellular * e.tailW.cellular).toFixed(1)} Дж — у сотні разів більше, ніж правило антифроду на телефоні.
          </p>
          <div className="rl-kv">
            <div><span>Обчислення на телефоні</span><b>{e.computeW} Вт</b></div>
            <div><span>Радіо Wi-Fi / стільникове</span><b>{e.radioW.wifi} / {e.radioW.cellular} Вт</b></div>
            <div><span>«Хвіст» Wi-Fi</span><b>{e.tailS.wifi} с × {e.tailW.wifi} Вт</b></div>
            <div><span>«Хвіст» стільникового</span><b>{e.tailS.cellular} с × {e.tailW.cellular} Вт</b></div>
          </div>
          <p className="rl-cap">Стартові коефіцієнти з літератури (MAUI, заміри «хвоста» LTE). Наступний етап — калібрування Power Profiler на власних iPhone.</p>
        </div>
        <figure className="rl-fig rl-fig-flat">
          <svg viewBox={`-40 -14 ${W + 50} ${H + 54}`} className="rl-chart" role="img" aria-label="Потужність радіо після запиту">
            {[0.5, 1, 1.5].map(w => <g key={w}><line x1="0" x2={W} y1={H - (w / 2) * H} y2={H - (w / 2) * H} stroke="#2c2c2e" /><text x="-8" y={H - (w / 2) * H + 4} textAnchor="end" className="rl-svg-s">{w}</text></g>)}
            <path d={curve(e.radioW.cellular, e.tailS.cellular, e.tailW.cellular)} fill="rgba(255,69,58,.14)" stroke="#ff453a" strokeWidth="2.5" />
            <path d={curve(e.radioW.wifi, e.tailS.wifi, e.tailW.wifi)} fill="rgba(10,132,255,.18)" stroke="#0a84ff" strokeWidth="2.5" />
            <line x1="0" x2={W} y1={H} y2={H} stroke="#48484a" />
            {[0, 1, 2, 3, 4, 5, 6].map(s => <text key={s} x={s * sx} y={H + 22} textAnchor="middle" className="rl-svg-s">{s} с</text>)}
            <text x="-8" y="0" textAnchor="end" className="rl-svg-s">Вт</text>
          </svg>
          <figcaption className="rl-legend"><span><i style={{ background: '#ff453a' }} />стільникове</span><span><i style={{ background: '#0a84ff' }} />Wi-Fi</span><span>обмін 0,25 с, далі «хвіст»</span></figcaption>
        </figure>
      </div>
    </section>
  );
}

function Conformal() {
  const p = pol.conformal as number[];
  const W = 900, H = 220;
  const lo = Math.min(...p) - 0.05, hi = Math.max(...p) + 0.05;
  const y = (v: number) => H - ((v - lo) / (hi - lo)) * H;
  const line = p.map((v, i) => `${i ? 'L' : 'M'}${((i / (p.length - 1)) * W).toFixed(1)} ${y(v).toFixed(1)}`).join(' ');
  return (
    <section className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">Каскад</p>
        <h3 className="rl-h">Поріг, який<br />вчиться на помилках.</h3>
        <p className="rl-p rl-narrow">
          У каскаді телефон відповідає першим, і відповідь приймається, якщо невпевненість нижча за поріг λ.
          Поріг оновлюється після кожного зворотного зв’язку за правилом адаптивного конформного виводу
          (Gibbs &amp; Candès, 2021): <code>λ ← λ + η(α − err)</code>, α = 5%, η = 0,05. Помилка звужує поріг, правильна відповідь — розширює.
        </p>
        <figure className="rl-fig">
          <svg viewBox={`-40 -10 ${W + 50} ${H + 50}`} className="rl-chart" role="img" aria-label="Траєкторія порогу λ">
            <rect x={W / 2} y="0" width={W / 2} height={H} fill="rgba(255,69,58,.06)" />
            <line x1={W / 2} x2={W / 2} y1="0" y2={H} stroke="#48484a" strokeDasharray="4 5" />
            <text x={W / 2 - 10} y="16" textAnchor="end" className="rl-svg-s">телефон помиляється у 3%</text>
            <text x={W / 2 + 10} y="16" className="rl-svg-s">зсув: помилок 15%</text>
            {[lo + 0.05, (lo + hi) / 2, hi - 0.05].map(v => <text key={v} x="-8" y={y(v) + 4} textAnchor="end" className="rl-svg-s">{v.toFixed(2)}</text>)}
            <path d={line} fill="none" stroke="#ffd400" strokeWidth="2" />
            <line x1="0" x2={W} y1={H} y2={H} stroke="#48484a" />
            <text x="0" y={H + 22} className="rl-svg-s">відповідь 1</text>
            <text x={W} y={H + 22} textAnchor="end" className="rl-svg-s">відповідь {p.length}</text>
          </svg>
          <figcaption className="rl-cap">Справжнє правило <code>PolicyState.updateThreshold</code> на тестовому потоці: 200 відповідей з 3% помилок, далі 200 з 15%. Після зсуву поріг сам стискається — більше задач іде на сервер.</figcaption>
        </figure>
      </div>
    </section>
  );
}

function Masking() {
  const r = data.redaction;
  const parts = r.output.split(/(\[[^\]]+\])/);
  return (
    <section className="rl-sec ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">Приватність</p>
        <h3 className="rl-h">Що бачить сервер.</h3>
        <p className="rl-p rl-narrow">
          Чек і помічник працюють з особистими даними, тож на сервер вони йдуть лише через <code>Redactor</code>.
          Він замінює IBAN, номери карток, телефони, пошту, ІПН і номери паспортів. Суми й назви магазинів лишаються —
          без них сервер не розбере чек. Фото чека з телефона не виходить ніколи: розпізнається Vision локально.
        </p>
        <div className="rl-mask">
          <div className="rl-mask-col"><span className="rl-mask-t">На iPhone</span><p>{r.input}</p></div>
          <svg viewBox="0 0 80 40" className="rl-mask-arr" aria-hidden><path d="M4 20H70M58 8l12 12-12 12" /></svg>
          <div className="rl-mask-col rl-mask-srv">
            <span className="rl-mask-t">На сервер · замін: {r.count}</span>
            <p>{parts.map((s, i) => (/^\[.+\]$/.test(s) ? <mark key={i} className="rl-tok">{s}</mark> : <span key={i}>{s}</span>))}</p>
          </div>
        </div>
        <p className="rl-cap">Вивід справжньої функції <code>Redactor.redact</code> на цьому реченні. Імена вона не маскує — це відоме обмеження поточної версії.</p>
      </div>
    </section>
  );
}

function Dataset() {
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
        <p className="rl-kicker">Дані для антифроду</p>
        <h3 className="rl-h">{nf(ds.total)} транзакцій.<br />Кожна з відповіддю.</h3>
        <p className="rl-p rl-narrow">
          Щоб виміряти якість, потрібна правильна відповідь. Тому в банку є розмічений набір: {ds.accounts} рахунків,
          шість місяців операцій ({ds.from_.slice(0, 10)} — {ds.to.slice(0, 10)}), серед них {fraudTotal} шахрайських
          за п’ятьма сценаріями атак. Набір синтетичний і генерується сервером — реальних клієнтів у ньому немає.
        </p>

        <div className="rl-pats">
          {(ds.patterns as [string, number][]).filter(p => p[0] !== 'normal').map(([p, c]) => (
            <div key={p}><b>{c}</b><span>{PATTERN_NAME[p] || p}</span><i style={{ width: `${(c / fraudTotal) * 100}%` }} /></div>
          ))}
        </div>

        <figure className="rl-fig">
          <figcaption className="rl-fig-h"><h4>Коли відбуваються операції</h4><span>кількість за днем тижня й годиною</span></figcaption>
          <Week rows={week} color={v => yel(v / maxW)} title={(d, h, v) => `${DAYS[d]} ${h}:00 — ${nf(v)} операцій`} />
          <div className="rl-scale"><span>0</span><i style={{ background: `linear-gradient(90deg, ${yel(0)}, ${yel(1)})` }} /><span>{nf(maxW)}</span></div>
        </figure>

        <figure className="rl-fig">
          <figcaption className="rl-fig-h"><h4>Де ховається шахрайство</h4><span>частка шахрайських операцій у кожній клітинці</span></figcaption>
          <Week rows={rate} color={v => red(v / maxR)} title={(d, h, v) => `${DAYS[d]} ${h}:00 — ${(v * 100).toFixed(2)}% шахрайських`} />
          <div className="rl-scale"><span>0%</span><i style={{ background: `linear-gradient(90deg, ${red(0)}, ${red(1)})` }} /><span>{(maxR * 100).toFixed(1)}%</span></div>
        </figure>

        <figure className="rl-fig">
          <figcaption className="rl-fig-h"><h4>Почерк кожної атаки</h4><span>шахрайські операції за сценарієм і годиною</span></figcaption>
          <div className="rl-week rl-week-p">
            <span />
            {Array.from({ length: 24 }, (_, h) => <span key={h} className="rl-wk-h">{h % 3 === 0 ? h : ''}</span>)}
            {pats.map(p => (
              <Row key={p} label={PATTERN_NAME[p] || p}>
                {ph[p].map((v, h) => <span key={h} className="rl-wk-c rl-wk-flat" style={{ background: red(v / maxP) }} title={`${PATTERN_NAME[p]} · ${h}:00 — ${v}`} />)}
              </Row>
            ))}
          </div>
        </figure>

        <figure className="rl-fig">
          <figcaption className="rl-fig-h"><h4>Суми</h4><span>розподіл за сумою в TAX, логарифмічна шкала, частка в групі</span></figcaption>
          <svg viewBox="-10 -10 920 250" className="rl-chart" role="img" aria-label="Розподіл сум звичайних і шахрайських операцій">
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
          <div className="rl-legend"><span><i style={{ background: '#ffd400' }} />звичайні</span><span><i style={{ background: '#ff453a' }} />шахрайські</span></div>
        </figure>
      </div>
    </section>
  );
}

function Week({ rows, color, title }: { rows: number[][]; color: (v: number) => string; title: (d: number, h: number, v: number) => string }) {
  return (
    <div className="rl-week">
      <span />
      {Array.from({ length: 24 }, (_, h) => <span key={h} className="rl-wk-h">{h % 3 === 0 ? h : ''}</span>)}
      {rows.map((r, d) => (
        <Row key={d} label={DAYS[d]}>
          {r.map((v, h) => <span key={h} className="rl-wk-c" style={{ background: color(v) }} title={title(d, h, v)} />)}
        </Row>
      ))}
    </div>
  );
}

function Parity() {
  const p = data.parity;
  const lv = p.levels as Record<string, number>;
  const flags = p.flags as [string, number][];
  const maxF = Math.max(...flags.map(f => f[1]));
  const sh = p.scoreHist as number[];
  const maxS = Math.max(...sh);
  return (
    <section className="rl-sec ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">Перенесення антифроду</p>
        <h3 className="rl-h">{p.n} з {p.n}.<br />Збіг до бала.</h3>
        <p className="rl-p rl-narrow">
          Щоб чесно порівнювати телефон і сервер, перший шар антифроду перенесено з Python у Swift (<code>FraudLite</code>)
          один до одного. Сервер згенерував {p.n} еталонних векторів — суми, баланси, описи — з бальною оцінкою, рівнем
          ризику й прапорами. Тест вимагає точного збігу кожного.
        </p>
        <div className="rl-par">
          <figure className="rl-fig">
            <figcaption className="rl-fig-h"><h4>Рівні ризику</h4></figcaption>
            <div className="rl-stack">{LEVEL.map(([k, , c]) => <i key={k} style={{ flex: lv[k] || 0, background: c }} />)}</div>
            <div className="rl-legend">{LEVEL.map(([k, n, c]) => <span key={k}><i style={{ background: c }} />{n} <b>{lv[k] || 0}</b></span>)}</div>
            <figcaption className="rl-fig-h rl-mt"><h4>Бали</h4><span>0–100, кроком 10</span></figcaption>
            <div className="rl-hist">{sh.map((v, i) => <i key={i} style={{ height: `${(v / maxS) * 100}%` }} title={`${i * 10}–${i * 10 + 9}: ${v}`} />)}</div>
          </figure>
          <figure className="rl-fig">
            <figcaption className="rl-fig-h"><h4>Що спрацьовує</h4><span>прапори на векторах</span></figcaption>
            <div className="rl-bars">
              {flags.map(([f, c]) => <div key={f}><span>{FLAG_NAME[f] || f}</span><i style={{ width: `${(c / maxF) * 100}%` }} /><b>{c}</b></div>)}
            </div>
          </figure>
        </div>
      </div>
    </section>
  );
}

function Status() {
  const steps: [string, string, boolean][] = [
    ['Метод EdgeRouter', 'Оцінки, модель енергії, політика з чергою Ляпунова, каскад з конформним порогом, маскування, журнал. Swift-пакет з тестами.', true],
    ['FraudLite на телефоні', `Перший шар антифроду в Swift, збіг із сервером на ${data.parity.n} векторах.`, true],
    ['Навчальний банк і набір даних', `Цей банк і ${nf(ds.total)} розмічених транзакцій.`, true],
    ['Калібрування енергії', 'Коефіцієнти поки з літератури. Потрібні заміри Power Profiler на кількох iPhone.', false],
    ['Невпевненість антифроду', 'На телефоні поки евристика. Її треба навчити на розміченому наборі.', false],
    ['Локальна мовна модель', 'Foundation Models не підтримує українську — для помічника на телефоні потрібна своя модель.', false],
  ];
  return (
    <section className="rl-sec rl-dark ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">Стан роботи</p>
        <h3 className="rl-h">Що готово.<br />Що ще ні.</h3>
        <ol className="rl-tl">
          {steps.map(([h, p, done]) => <li key={h} className={done ? 'done' : ''}><span>{done ? 'Готово' : 'Попереду'}</span><h4>{h}</h4><p>{p}</p></li>)}
        </ol>
      </div>
    </section>
  );
}

function Logged() {
  const fields = [
    ['Задача й стратегія', 'яку задачу і за якою стратегією вирішували'],
    ['Стан телефона', 'мережа, заряд, енергозбереження, перегрів, імовірність відключення'],
    ['Усі кандидати', 'час, енергія, якість і ціль для кожного варіанта'],
    ['Рішення', 'обраний план, де фактично виконано, чи була ескалація чи відкат'],
    ['Каскад і бюджет', 'невпевненість, поріг λ, черга енергії Z'],
    ['Результат', 'фактичний час і енергія, кількість замін маскування, причина'],
  ];
  return (
    <section className="rl-sec rl-ethics ap-reveal">
      <div className="ap-wrap">
        <p className="rl-kicker">Журнал рішень</p>
        <h3 className="rl-h">Що записується.<br />І що ні.</h3>
        <div className="rl-table">{fields.map(([a, b]) => <div key={a}><b>{a}</b><span>{b}</span></div>)}</div>
        <p className="rl-p rl-narrow rl-mt">
          Тексти запитів, фото й відповіді в журнал <code>decisions.jsonl</code> не потрапляють. Стратегії, параметри α, V,
          бюджет енергії й експорт журналу — у розділі «Лабораторія» застосунку для iPhone.
        </p>
      </div>
    </section>
  );
}
