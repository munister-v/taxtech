"""Тести генератора синтетичних даних scripts/seed_sandbox.py."""
from __future__ import annotations

import os
import sys

_SCRIPTS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'scripts')
if _SCRIPTS not in sys.path:
    sys.path.insert(0, _SCRIPTS)

import seed_sandbox  # noqa: E402

_ARGS = ['--users', '8', '--months', '1', '--seed', '7',
         '--anchor', '2026-10-01T12:00:00Z', '--fraud-users', '5', '--reset']


def _snapshot():
    from backend.database import get_connection
    with get_connection() as conn:
        return conn.execute(
            'SELECT t.tx_type, t.direction, t.amount, t.created_at, l.is_fraud, l.pattern'
            ' FROM transactions t'
            ' JOIN research_labels l ON l.transaction_id = t.id'
            ' JOIN accounts a ON a.id = t.account_id'
            ' JOIN users u ON u.id = a.user_id'
            " WHERE u.email LIKE '%@kopiyka.test'"
            ' ORDER BY t.id'
        ).fetchall()


def test_seed_is_deterministic_and_labelled(app):
    assert seed_sandbox.main(_ARGS) == 0
    first = _snapshot()
    assert seed_sandbox.main(_ARGS) == 0      # --reset прибирає попередній прогін
    second = _snapshot()
    assert first == second
    assert len(first) > 100

    patterns = {row['pattern'] for row in first if row['is_fraud']}
    assert patterns == set(seed_sandbox.FRAUD_PATTERNS)
    assert all(row['pattern'] == 'normal' for row in first if not row['is_fraud'])


def test_seeded_cards_are_clearly_fake(app):
    from backend.database import get_connection
    from backend.services.card_service import _luhn_checksum
    seed_sandbox.main(_ARGS)
    with get_connection() as conn:
        numbers = [r['card_number'].replace(' ', '') for r in conn.execute(
            'SELECT c.card_number FROM cards c JOIN accounts a ON a.id = c.account_id'
            " JOIN users u ON u.id = a.user_id WHERE u.email LIKE '%@kopiyka.test'").fetchall()]
    assert numbers
    for n in numbers:
        assert n.startswith('0000') and len(n) == 16
        assert _luhn_checksum(n) != 0         # навмисно не проходить перевірку Луна


def test_demo_user_can_log_in(client):
    seed_sandbox.main(_ARGS)
    r = client.post('/api/auth/login', json={
        'identity': seed_sandbox.DEFAULT_DEMO_EMAIL,
        'password': seed_sandbox.DEFAULT_DEMO_PASSWORD,
    })
    assert r.status_code == 200
    assert r.get_json()['data']['user']['bank_account_number'].startswith('KP-')
