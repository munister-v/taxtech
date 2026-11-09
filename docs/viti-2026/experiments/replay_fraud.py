"""Replay evaluation of the Kopiyka fraud engine on the labeled sandbox set.

Every outgoing transfer is scored against the database exactly as it was at the
moment of the transfer: rows are processed newest-first, and before scoring
transfer k every row with id >= k is deleted; the engine's clock is frozen at
the transfer's timestamp. Each transfer is scored three times: l1 (device
layer), l1+l2, l1+l2+l3 (full server cascade, the production default).

Usage (cwd = kopiyka/server, env KOPIYKA_DATABASE_PATH=<copy of seeded db>):
    .venv/bin/python <this file> <out.json>
"""
from __future__ import annotations

import json
import sqlite3
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path.cwd()))

from backend.config import DATABASE_PATH  # noqa: E402
from backend.services import fraud_engine as fe  # noqa: E402

_FROZEN = [datetime.now(timezone.utc)]


class Frozen(datetime):
    @classmethod
    def now(cls, tz=None):  # noqa: D401
        return _FROZEN[0] if tz else _FROZEN[0].replace(tzinfo=None)


fe.datetime = Frozen

CONFIGS = {'l1': ['l1'], 'l12': ['l1', 'l2'], 'l123': None}


def main(out_path: str) -> None:
    db = sqlite3.connect(str(DATABASE_PATH))
    db.row_factory = sqlite3.Row
    rows = db.execute(
        'SELECT t.id, t.account_id, t.tx_type, t.direction, t.amount, t.description, '
        't.related_account, t.created_at, rl.is_fraud, rl.pattern '
        'FROM transactions t JOIN research_labels rl ON rl.transaction_id = t.id ORDER BY t.id'
    ).fetchall()
    acc_by_number = {r['account_number']: r['id'] for r in db.execute('SELECT id, account_number FROM accounts')}

    running = defaultdict(float)
    targets = []
    for r in rows:
        bal_before = running[r['account_id']]
        sign = 1 if r['direction'] == 'in' else -1
        running[r['account_id']] += sign * float(r['amount'])
        if r['direction'] == 'out' and r['tx_type'] == 'transfer':
            targets.append({
                'id': r['id'], 'account_id': r['account_id'], 'amount': float(r['amount']),
                'description': r['description'], 'recipient': r['related_account'],
                'recipient_id': acc_by_number.get(r['related_account']),
                'balance': round(bal_before, 2), 'created_at': r['created_at'],
                'is_fraud': int(r['is_fraud']), 'pattern': r['pattern'],
            })

    engine = fe.FraudEngine()
    results = []
    t_start = time.perf_counter()
    for i, t in enumerate(reversed(targets)):
        db.execute('DELETE FROM transactions WHERE id >= ?', (t['id'],))
        db.commit()
        _FROZEN[0] = datetime.strptime(t['created_at'], '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc)
        rec = dict(t)
        for name, layers in CONFIGS.items():
            t0 = time.perf_counter()
            res = engine.assess(t['account_id'], t['recipient'], t['amount'], balance=t['balance'],
                                description=t['description'], recipient_account_id=t['recipient_id'],
                                layers=layers)
            rec[name] = {'score': res.score, 'level': res.level, 'flags': list(res.flags),
                         'layers_run': list(res.layers_run), 'ms': (time.perf_counter() - t0) * 1000}
        results.append(rec)
        if i % 500 == 0:
            print(f'{i}/{len(targets)} {time.perf_counter() - t_start:.0f}s', flush=True)
    Path(out_path).write_text(json.dumps(results, ensure_ascii=False))
    print('done', len(results), f'{time.perf_counter() - t_start:.0f}s')


if __name__ == '__main__':
    main(sys.argv[1])
