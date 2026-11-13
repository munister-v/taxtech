import type { ReactNode } from 'react';

// Figures for the engineering article: every number below was counted from the server code and tests.
// Drawn in SVG/CSS on purpose: they stay sharp, follow the page and weigh nothing.

const GOLD = '#b48a1e', INK = '#111', MUT = 'rgba(17,17,17,.5)', LINE = 'rgba(17,17,17,.16)', RED = '#c43d2f', GRN = '#2f7d4f';
const mono = 'Cousine, monospace';

function Fig({ children, cap }: { children: ReactNode; cap: string }) {
  return <figure className="tb-fig tb-wide tb-viz"><div className="tb-viz-in">{children}</div><figcaption>{cap}</figcaption></figure>;
}

const STATS: [string, string][] = [['≈170', 'endpoints'], ['15', 'route modules'], ['20', 'services'], ['25', 'tables'], ['28', 'fraud rules'], ['226', 'tests']];
export function Stats() {
  return <div className="tb-stats">{STATS.map(([n, l]) => <div key={l}><b>{n}</b><span>{l}</span></div>)}</div>;
}

// what the system holds: production counts (13 Nov 2026) and the load run on a throw-away copy
const LIVE: [string, string][] = [['11', 'users in production'], ['64', 'account transactions'], ['212 634', 'simulated city payments']];
const TESTED: [string, string][] = [['670', 'accounts in the load run'], ['3 000', 'transfers attempted'], ['1 553', 'completed in 86 s']];
export function Live() {
  return <div>
    <div className="tb-stats">{LIVE.map(([n, l]) => <div key={l}><b>{n}</b><span>{l}</span></div>)}</div>
    <div className="tb-stats">{TESTED.map(([n, l]) => <div key={l}><b>{n}</b><span>{l}</span></div>)}</div>
    <p className="tb-live-note">Top row: counted on the production database on 13 November 2026, a laboratory with a handful of real people; the large number is the Rome simulation, whose payments run through the same ledger code. Bottom row: a separate load run on a throw-away database, described below.</p>
  </div>;
}

const LOAD: [string, string][] = [['670', 'accounts created'], ['3,000', 'transfer attempts'], ['1,553', 'went through'], ['1,447', 'stopped by fraud rules'], ['35', 'requests a second'], ['447 ms', 'median, p95 543 ms'], ['0', 'server errors'], ['0', 'negative balances'], ['669,000', 'TAX in, 669,000 TAX held']];
export function Load() {
  return <Fig cap="Load run on a throw-away copy of the database: two gunicorn workers on a laptop, 16 clients at once, random pairs of accounts">
    <div className="tb-stats tb-stats-flat">{LOAD.map(([n, l]) => <div key={l}><b>{n}</b><span>{l}</span></div>)}</div>
  </Fig>;
}

// six doors into one room
export function Doors() {
  const doors = ['Card top-up', 'Card number', 'Account transfer', 'POS sale', 'City QR', 'Hosted checkout'];
  return (
    <Fig cap="Six ways in, one way through: every door ends in the same method">
      <svg viewBox="0 0 760 330" role="img" aria-label="Six entry points converge on PaymentCore">
        {doors.map((d, i) => {
          const y = 30 + i * 52;
          return <g key={d}>
            <rect x="0" y={y - 17} width="170" height="34" rx="5" fill="none" stroke={LINE} />
            <text x="14" y={y + 5} fontFamily={mono} fontSize="13" fill={INK}>{d}</text>
            <path d={`M170 ${y} C 260 ${y}, 270 165, 350 165`} fill="none" stroke={GOLD} strokeWidth="1.5" />
          </g>;
        })}
        <rect x="350" y="105" width="190" height="120" rx="8" fill={INK} />
        <text x="445" y="150" textAnchor="middle" fontFamily={mono} fontSize="14" fill="#f3ecdc">PaymentCore</text>
        <text x="445" y="172" textAnchor="middle" fontFamily={mono} fontSize="11" fill="#9d9684">transfer()</text>
        <text x="445" y="196" textAnchor="middle" fontFamily={mono} fontSize="11" fill="#ffd400">moves all the money</text>
        <path d="M540 165 H 600" stroke={GOLD} strokeWidth="1.5" markerEnd="url(#ar)" />
        <defs><marker id="ar" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L8 4 L0 8z" fill={GOLD} /></marker></defs>
        {['1 balance move', '2 ledger lines', '1 chain link', '1 audit line'].map((o, i) => (
          <g key={o}><rect x="600" y={95 + i * 36} width="160" height="28" rx="4" fill="#faf6e8" stroke={LINE} /><text x="612" y={114 + i * 36} fontFamily={mono} fontSize="12" fill={INK}>{o}</text></g>
        ))}
      </svg>
    </Fig>
  );
}

export function States() {
  const node = (x: number, y: number, t: string, fill: string, fg = '#fff') => <g><rect x={x} y={y} width="132" height="44" rx="22" fill={fill} /><text x={x + 66} y={y + 27} textAnchor="middle" fontFamily={mono} fontSize="13" fill={fg}>{t}</text></g>;
  return (
    <Fig cap="A payment order is a state machine. A blocked order never touched a balance.">
      <svg viewBox="0 0 760 250" role="img" aria-label="pending to processing to completed, failed or blocked">
        {node(0, 103, 'pending', INK)}
        {node(220, 103, 'processing', INK)}
        {node(520, 20, 'completed', GRN)}
        {node(520, 103, 'failed', '#8a6d1a')}
        {node(520, 186, 'blocked', RED)}
        <g stroke={GOLD} strokeWidth="1.6" fill="none" markerEnd="url(#ar2)">
          <path d="M132 125 H 218" /><path d="M352 118 C 430 118, 440 42, 518 42" /><path d="M352 125 H 518" />
          <path d="M66 147 C 66 215, 300 208, 518 208" />
        </g>
        <defs><marker id="ar2" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L8 4 L0 8z" fill={GOLD} /></marker></defs>
        <text x="300" y="232" textAnchor="middle" fontFamily={mono} fontSize="11" fill={MUT}>fraud score critical: stop before the money moves</text>
        <text x="418" y="86" textAnchor="middle" fontFamily={mono} fontSize="11" fill={MUT}>funds moved</text>
        <text x="440" y="118" fontFamily={mono} fontSize="11" fill={MUT}>rolled back</text>
      </svg>
    </Fig>
  );
}

const STEPS: [string, string, number][] = [
  ['Headers and size', 'free', 1], ['Authentication', 'free', 1], ['CSRF', 'free', 1], ['Rate limit', 'memory', 1], ['Validation', 'free', 1],
  ['Idempotency', '1 write', 2], ['Ownership & limits', '1–2 reads', 2], ['3-D Secure', '1 read', 2], ['Fraud, 28 rules', 'up to many reads', 4], ['Atomic move', 'transaction', 3], ['Ledger, chain, audit', 'after commit', 3],
];
export function Pipeline() {
  return (
    <Fig cap="Cheap checks first: an unauthenticated caller costs the server almost nothing">
      <ol className="tb-pipe">
        {STEPS.map(([n, c, w], i) => (
          <li key={n}><i>{String(i + 1).padStart(2, '0')}</i><span>{n}</span><em>{c}</em><u style={{ width: `${w * 22}%` }} /></li>
        ))}
      </ol>
    </Fig>
  );
}

export function Race() {
  return (
    <Fig cap="Two payments of 80 against a balance of 100. The condition inside the UPDATE lets exactly one through.">
      <svg viewBox="0 0 760 270" role="img" aria-label="Two parallel debits, only one succeeds">
        <text x="0" y="22" fontFamily={mono} fontSize="12" fill={MUT}>balance</text>
        <text x="0" y="62" fontFamily={mono} fontSize="26" fill={INK}>100</text>
        {[['Payment A', 90, GRN, 'rows updated: 1', 'balance 20'], ['Payment B', 170, RED, 'rows updated: 0', 'insufficient funds']].map(([n, y, c, r, o]) => (
          <g key={n as string}>
            <text x="150" y={(y as number) - 8} fontFamily={mono} fontSize="13" fill={INK}>{n}</text>
            <rect x="150" y={y as number} width="300" height="44" rx="6" fill="none" stroke={c as string} strokeWidth="1.5" />
            <text x="164" y={(y as number) + 19} fontFamily={mono} fontSize="11.5" fill={INK}>WHERE id = :from AND balance &gt;= 80</text>
            <text x="164" y={(y as number) + 35} fontFamily={mono} fontSize="11.5" fill={c as string}>{r as string}</text>
            <path d={`M450 ${(y as number) + 22} H 520`} stroke={c as string} strokeWidth="1.5" />
            <rect x="520" y={y as number} width="230" height="44" rx="6" fill={c as string} />
            <text x="635" y={(y as number) + 27} textAnchor="middle" fontFamily={mono} fontSize="13" fill="#fff">{o as string}</text>
          </g>
        ))}
        <text x="150" y="246" fontFamily={mono} fontSize="11.5" fill={MUT}>no read-then-write gap: the check and the debit are one statement</text>
      </svg>
    </Fig>
  );
}

const L1 = ['Structuring', 'Round amounts', 'Description anomaly', 'Balance depletion', 'Threshold masking'];
const L2 = ['Velocity', 'Account age', 'High amount', 'Adaptive quartile (IQR)', 'Inactivity burst', 'Time anomaly', 'Pass-through', 'Historical fraud', 'Rapid succession', 'Night batch', 'Card top-up abuse', 'Journal inconsistency'];
const L3 = ['Frequency escalation', 'Duplicate transfer', 'Split transaction', 'Amount progression', 'New recipient', 'New recipient, large', 'Counterparty concentration', 'Transfer graph', 'Behavioural entropy', 'Money mule', 'Recipient risk propagation'];
export function Rules() {
  const col = (t: string, sub: string, rs: string[], c: string) => (
    <div className="tb-rules-col"><h4 style={{ borderColor: c }}>{t}<small>{sub}</small></h4><ul>{rs.map(r => <li key={r}>{r}</li>)}</ul></div>
  );
  return (
    <Fig cap="All 28 rules, by what they cost: 5 need only the request, 12 read the sender’s history, 11 read the pair and the graph">
      <div className="tb-rules">
        {col('Layer 1 · 5', 'no database', L1, '#2f7d4f')}
        {col('Layer 2 · 12', '1–2 queries, sender', L2, GOLD)}
        {col('Layer 3 · 11', 'heavy: pair, graph, entropy', L3, RED)}
      </div>
    </Fig>
  );
}

export function Noisy() {
  const ps = [0.35, 0.3, 0.25];
  const s = 1 - ps.reduce((a, p) => a * (1 - p), 1);
  const bands: [string, number, string][] = [['low', 25, '#2f7d4f'], ['medium', 25, '#b48a1e'], ['high', 25, '#d97a1f'], ['critical', 25, RED]];
  return (
    <Fig cap="Three weak signals of 35%, 30% and 25% combine to 1 − 0.65 × 0.70 × 0.75 = 66%: a high-risk transfer, though no rule alone was sure">
      <div className="tb-noisy">
        <div className="tb-noisy-bar">
          {bands.map(([n, w, c]) => <span key={n} style={{ flex: w, background: c }}>{n}</span>)}
          <i style={{ left: `${Math.round(s * 100)}%` }}><b>{Math.round(s * 100)}</b></i>
        </div>
        <div className="tb-noisy-ax"><span>0</span><span>25</span><span>50</span><span>75</span><span>100</span></div>
      </div>
    </Fig>
  );
}

export function Sessions() {
  const rows: [string, string, string][] = [
    ['Browser', 'Server', 'POST /login  →  Set-Cookie: __Host-kp_session (HttpOnly, Secure, Path=/)  +  kp_csrf (readable)'],
    ['Browser', 'Server', 'POST /transfer  +  Cookie  +  X-CSRF-Token: <kp_csrf>'],
    ['Server', 'Server', 'hmac.compare_digest(cookie csrf, header csrf)  →  constant time'],
    ['Server', 'Browser', '403 if different; otherwise the request goes on'],
  ];
  return (
    <Fig cap="Cookie sessions for browsers: the session cookie cannot be read by script, and a forged cross-site request cannot copy the header">
      <ul className="tb-seq">{rows.map(([a, b, t], i) => <li key={i}><b>{a}{a === b ? '' : ' → ' + b}</b><code>{t}</code></li>)}</ul>
    </Fig>
  );
}

export function Chain() {
  const hs = ['9f3a…c1', 'b27e…04', '51dd…9a', 'e8c0…7b'];
  return (
    <Fig cap="Each link hashes the transaction plus the previous hash. Edit one row and every later link stops matching.">
      <div className="tb-chain">
        {hs.map((h, i) => (
          <div key={h} className={`tb-link${i === 1 ? ' bad' : ''}${i > 1 ? ' after' : ''}`}>
            <small>tx {1040 + i}</small>
            <code>{h}</code>
            <span>{i === 0 ? 'prev: genesis' : `prev: ${hs[i - 1]}`}</span>
            {i === 1 && <em>amount edited</em>}
            {i > 1 && <em>no longer matches</em>}
          </div>
        ))}
      </div>
    </Fig>
  );
}

export function Ledger() {
  return (
    <Fig cap="Every transfer writes two lines. At the end of the day the two columns must be equal; the reconcile job also reports orphans and unsettled lines.">
      <table className="tb-ledger"><thead><tr><th>Account</th><th>Debit</th><th>Credit</th></tr></thead>
        <tbody><tr><td>Sender</td><td>120.00</td><td /></tr><tr><td>Recipient</td><td /><td>120.00</td></tr></tbody>
        <tfoot><tr><td>Σ</td><td>120.00</td><td>120.00</td></tr></tfoot></table>
    </Fig>
  );
}

const TESTS: [string, number][] = [['POS terminal', 38], ['Features', 35], ['City', 23], ['Account transfers', 22], ['Research', 19], ['Validators', 11], ['Apple sign-in', 9], ['Auth', 8], ['i18n', 8], ['Cards', 7], ['API hardening', 6], ['Access control', 5], ['FX', 5], ['Marketplace', 5]];
export function Tests() {
  const max = 38;
  return (
    <Fig cap="226 tests across 22 files; the largest suites guard the terminal and money movement. The other 25 tests, in 8 smaller files, are not drawn.">
      <ul className="tb-bars">{TESTS.map(([n, v]) => <li key={n}><span>{n}</span><u style={{ width: `${(v / max) * 100}%` }} /><b>{v}</b></li>)}</ul>
    </Fig>
  );
}

const MODS: [string, number, string][] = [['marketplace', 3260, 'catalogue, orders, sizes'], ['account', 601, 'balances, transfers, history'], ['feature', 569, 'budgets, goals, templates, recurring'], ['pos', 544, 'sale, preauth, capture, void, refund, dispute'], ['fx', 427, 'currency wallets and exchange'], ['taxpay', 412, 'hosted checkout for merchants'], ['city', 398, 'Roma Live, QR invoices, shops'], ['auth', 352, 'register, login, reset, sessions'], ['passkey', 240, 'WebAuthn'], ['credit', 197, 'credits and debts'], ['card', 180, 'cards and top-ups'], ['research', 129, 'labels and datasets'], ['deposit', 97, 'term deposits'], ['three_ds', 78, 'challenge and verify'], ['document', 65, 'statements and receipts']];
export function Modules() {
  return (
    <Fig cap="The fifteen route modules by size (lines of code). Routes stay thin; the rules live in twenty services, the largest being the fraud engine (1,364 lines) and statements (1,343).">
      <ul className="tb-bars tb-mods">{MODS.map(([n, v, d]) => <li key={n}><span>{n}</span><u style={{ width: `${Math.max(2, (v / 3260) * 100)}%` }} /><b>{v}</b><em>{d}</em></li>)}</ul>
    </Fig>
  );
}

const TABLES: [string, string[]][] = [
  ['Identity', ['users', 'sessions', 'passkeys', 'audit_logs']],
  ['Money', ['accounts', 'transactions', 'payment_orders', 'payment_order_events', 'account_holds', 'payouts']],
  ['Proof', ['journal_entries', 'integrity_hashes', 'api_idempotency']],
  ['Risk', ['risk_events', 'fraud_velocity_cache']],
  ['Product', ['cards', 'payment_templates', 'recurring_transactions', 'budget_limits', 'savings_goals', 'debts', 'family_contacts', 'donations', 'notifications', 'research_labels']],
];
export function Schema() {
  return (
    <Fig cap="The 25 tables of the schema, grouped by job. Everything that moves money is separate from everything that merely describes it.">
      <div className="tb-schema">{TABLES.map(([g, ts]) => <div key={g}><h4>{g}</h4><ul>{ts.map(t => <li key={t}>{t}</li>)}</ul></div>)}</div>
    </Fig>
  );
}

export const VIZ: Record<string, () => ReactNode> = { stats: Stats, load: Load, live: Live, doors: Doors, states: States, pipeline: Pipeline, race: Race, rules: Rules, noisy: Noisy, sessions: Sessions, chain: Chain, ledger: Ledger, tests: Tests, modules: Modules, schema: Schema };
