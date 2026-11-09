"""Attack experiments against a local Kopiyka app on a scratch SQLite copy.

E2 retries / double spend through the real HTTP routes (Flask test client, threads)
E3 tampering with the transaction history (hash chain)
E4 password guessing (rate limiter)

Usage (cwd = kopiyka/server, env KOPIYKA_DATABASE_PATH=<scratch db>):
    .venv/bin/python -I <this file> <out.json>
"""
from __future__ import annotations

import json
import random
import sqlite3
import statistics
import sys
import threading
import time
import uuid
from pathlib import Path

sys.path.insert(0, str(Path.cwd()))

from backend.app import create_app  # noqa: E402
from backend.config import DATABASE_PATH  # noqa: E402
from backend.services import payment_core as pc  # noqa: E402
from backend.services.auth_service import AuthService  # noqa: E402
from backend.services.fraud_engine import RiskResult  # noqa: E402
from backend.services.integrity_service import IntegrityService, _hash_tx  # noqa: E402

OUT: dict = {}
app = create_app()
app.testing = False
auth = AuthService()


def db():
    c = sqlite3.connect(str(DATABASE_PATH), timeout=30)
    c.row_factory = sqlite3.Row
    return c


def new_user(tag: str, balance: float) -> tuple[str, dict]:
    phone = f'+38067{random.randint(1000000, 9999999)}'
    s = auth.register({'full_name': f'Тест {tag}', 'phone': phone,
                       'email': f'{tag}-{uuid.uuid4().hex[:6]}@kopiyka.test', 'password': 'Sandbox-pass-12345'})
    token = s['token']
    acc = auth.ensure_user_bank_account(s['user']['id'])[0]
    with db() as c:
        c.execute('UPDATE accounts SET balance = ? WHERE id = ?', (balance, acc['id']))
    return token, dict(acc)


def fire(n: int, make_req) -> list[int]:
    codes = [0] * n
    barrier = threading.Barrier(n)

    def run(i):
        client = app.test_client()
        barrier.wait()
        codes[i] = make_req(client, i).status_code

    th = [threading.Thread(target=run, args=(i,)) for i in range(n)]
    [t.start() for t in th]
    [t.join() for t in th]
    return codes


def out_count(acc_id: int) -> int:
    with db() as c:
        return c.execute("SELECT COUNT(*) FROM transactions WHERE account_id=? AND direction='out'",
                         (acc_id,)).fetchone()[0]


def balance(acc_id: int) -> float:
    with db() as c:
        return float(c.execute('SELECT balance FROM accounts WHERE id=?', (acc_id,)).fetchone()[0])


def counts(codes):
    d = {}
    for x in codes:
        d[str(x)] = d.get(str(x), 0) + 1
    return d


# ── E2a: the same request retried 50 times at once (one Idempotency-Key) ─────
def e2a(n=50):
    tok, acc = new_user('dup', 1000)
    _, rcv = new_user('dup-rcv', 0)
    key = uuid.uuid4().hex
    body = {'amount': 10, 'recipient_account_number': rcv['account_number'], 'description': 'Оплата'}
    codes = fire(n, lambda c, i: c.post('/api/transactions/transfer', json=body,
                                        headers={'Authorization': f'Bearer {tok}', 'Idempotency-Key': key}))
    seq = [app.test_client().post('/api/transactions/transfer', json=body,
                                  headers={'Authorization': f'Bearer {tok}', 'Idempotency-Key': key}).status_code
           for _ in range(20)]
    OUT['e2a'] = {'parallel': n, 'codes': counts(codes), 'sequential_retries': 20, 'seq_codes': counts(seq),
                  'debits': out_count(acc['id']), 'balance_after': balance(acc['id'])}


# ── E2b: race for the last money (distinct keys), anti-fraud off and on ───────
def e2b(n=50, amount=100.0, start=1000.0, fraud_on=False):
    tok, acc = new_user('race', start)
    rcvs = [new_user(f'race-rcv{i}', 0)[1] for i in range(5)]
    orig = pc.FraudEngine.assess
    if not fraud_on:
        pc.FraudEngine.assess = lambda self, *a, **k: (lambda r: (r.finalize(), r)[1])(RiskResult())
    try:
        codes = fire(n, lambda c, i: c.post(
            '/api/transactions/transfer',
            json={'amount': amount, 'recipient_account_number': rcvs[i % 5]['account_number'],
                  'description': 'Переказ'},
            headers={'Authorization': f'Bearer {tok}', 'Idempotency-Key': uuid.uuid4().hex}))
    finally:
        pc.FraudEngine.assess = orig
    with db() as c:
        blocked = c.execute("SELECT COUNT(*) FROM payment_orders WHERE sender_account_id=? AND status='blocked'",
                            (acc['id'],)).fetchone()[0]
        got = c.execute('SELECT COALESCE(SUM(balance),0) FROM accounts WHERE id IN (%s)'
                        % ','.join(str(r['id']) for r in rcvs)).fetchone()[0]
    OUT['e2b_fraud_on' if fraud_on else 'e2b'] = {
        'parallel': n, 'amount': amount, 'start_balance': start, 'codes': counts(codes),
        'debits': out_count(acc['id']), 'blocked_orders': blocked, 'balance_after': balance(acc['id']),
        'received_total': float(got), 'money_conserved': abs(start - balance(acc['id']) - float(got)) < 1e-6}


# ── E3: tampering with history ───────────────────────────────────────────────
def e3(trials=1000):
    integ = IntegrityService()
    with db() as c:
        txs = c.execute('SELECT id, account_id, amount, direction, created_at FROM transactions ORDER BY id').fetchall()
    t0 = time.perf_counter()
    for t in txs:  # chain every seeded row exactly as payment_core does
        integ.record(t['id'], t['account_id'], float(t['amount']), t['direction'], str(t['created_at']))
    chain_build_s = time.perf_counter() - t0

    t0 = time.perf_counter()
    base = integ.verify_all_accounts()
    verify_all_s = time.perf_counter() - t0
    assert base['all_ok'], 'chain broken before tampering'

    by_acc: dict[int, list] = {}
    for t in txs:
        by_acc.setdefault(t['account_id'], []).append(t)
    rng = random.Random(7)
    kinds = ['amount_cent', 'direction', 'timestamp_1s', 'delete_row', 'swap_amounts']
    res = {k: {'trials': 0, 'detected': 0, 'located': 0} for k in kinds}
    verify_ms = []
    for i in range(trials):
        kind = kinds[i % len(kinds)]
        acc_id = rng.choice([a for a in by_acc if len(by_acc[a]) > 2])
        rows = by_acc[acc_id]
        t = rng.choice(rows[:-1])
        c = db()
        snap = [dict(r) for r in c.execute('SELECT * FROM transactions WHERE account_id=?', (acc_id,))]
        expected_first = t['id']
        if kind == 'amount_cent':
            c.execute('UPDATE transactions SET amount = amount + 0.01 WHERE id=?', (t['id'],))
        elif kind == 'direction':
            c.execute("UPDATE transactions SET direction = CASE direction WHEN 'in' THEN 'out' ELSE 'in' END WHERE id=?",
                      (t['id'],))
        elif kind == 'timestamp_1s':
            c.execute("UPDATE transactions SET created_at = datetime(created_at, '+1 second') WHERE id=?", (t['id'],))
        elif kind == 'delete_row':
            c.execute('DELETE FROM transactions WHERE id=?', (t['id'],))
            nxt = [r for r in rows if r['id'] > t['id']]
            expected_first = nxt[0]['id']
        elif kind == 'swap_amounts':
            u = rows[rows.index(t) + 1]
            c.execute('UPDATE transactions SET amount = ? WHERE id=?', (float(u['amount']), t['id']))
            c.execute('UPDATE transactions SET amount = ? WHERE id=?', (float(t['amount']), u['id']))
            if float(u['amount']) == float(t['amount']):
                c.rollback(); c.close(); continue
        c.commit()
        t0 = time.perf_counter()
        v = integ.verify_account(acc_id)
        verify_ms.append((time.perf_counter() - t0) * 1000)
        res[kind]['trials'] += 1
        res[kind]['detected'] += int(not v['ok'])
        res[kind]['located'] += int(v.get('broken_at') == expected_first)
        # restore
        c.execute('DELETE FROM transactions WHERE account_id=?', (acc_id,))
        for r in snap:
            cols = ','.join(r.keys())
            c.execute(f'INSERT INTO transactions({cols}) VALUES({",".join("?" * len(r))})', tuple(r.values()))
        c.commit()
        c.close()
        assert integ.verify_account(acc_id)['ok']
    # control: untouched accounts never raise a false alarm
    OUT['e3'] = {'rows_chained': len(txs), 'accounts': len(by_acc), 'chain_build_s': chain_build_s,
                 'verify_all_s': verify_all_s, 'verify_account_ms_median': statistics.median(verify_ms),
                 'verify_account_ms_p95': sorted(verify_ms)[int(0.95 * len(verify_ms))],
                 'by_kind': res, 'false_alarms_on_clean_db': int(not base['all_ok'])}


# ── E4: password guessing ────────────────────────────────────────────────────
def e4(n=40):
    tok, acc = new_user('victim', 0)
    with db() as c:
        phone = c.execute('SELECT phone FROM users WHERE id=(SELECT user_id FROM accounts WHERE id=?)',
                          (acc['id'],)).fetchone()[0]
    client = app.test_client()
    codes, times = [], []
    for i in range(n):
        t0 = time.perf_counter()
        r = client.post('/api/auth/login', json={'identity': phone, 'password': f'guess-{i:04d}'})
        times.append((time.perf_counter() - t0) * 1000)
        codes.append(r.status_code)
    first_429 = codes.index(429) + 1 if 429 in codes else None
    bcrypt_ms = statistics.median(times[:10])
    OUT['e4'] = {'attempts': n, 'codes': counts(codes), 'first_429_at': first_429,
                 'retry_after': client.post('/api/auth/login', json={'identity': phone, 'password': 'x'}).headers.get('Retry-After'),
                 'wrong_password_ms_median': bcrypt_ms}


def live_chain():
    res = IntegrityService().verify_all_accounts()
    OUT['live_chain'] = {'accounts': res['total_accounts'], 'broken_accounts': res['broken_accounts'],
                         'records': sum(v['total'] for v in res['per_account'].values()),
                         'failing_records': sum(len(v['errors']) for v in res['per_account'].values())}


if __name__ == '__main__':
    random.seed(1)
    if sys.argv[2] == 'api':
        e2a()
        e2b(fraud_on=False)
        e2b(fraud_on=True)
        e4()
        live_chain()
    else:
        e3()
    Path(sys.argv[1]).write_text(json.dumps(OUT, ensure_ascii=False, indent=1))
    print(json.dumps(OUT, ensure_ascii=False, indent=1))
