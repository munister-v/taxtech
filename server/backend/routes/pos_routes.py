"""POS: емуляція еквайрингу на навчальному рахунку.

Потік, як у картковій мережі:
  терміналу -> еквайр -> мережа -> емітент (TaxTech) -> відповідь з кодом.
  Суми від SCA_THRESHOLD вимагають 3-D Secure: клієнт отримує код 65, проходить
  /api/3ds/challenge + /verify і повторює платіж із tds_session.
Затверджений платіж одразу списується (capture); еквайр утримує комісію MDR.
Повернення (refund) зараховує повну суму назад.
"""
from __future__ import annotations

import random
import re
import secrets
import zlib
from datetime import date, datetime, timedelta
from typing import Any

from flask import Blueprint, g, jsonify, request

from ..database import get_connection, get_returning_id_suffix, insert_last_id
from ..services.three_ds_service import ThreeDSService
from .helpers import api_error, auth_required, rate_limit

pos_bp = Blueprint('pos', __name__)
_tds = ThreeDSService()

SCA_THRESHOLD = 1000.0
MDR = 0.015
MAX_AMOUNT = 100000.0
_schema_ready = False

MCC = {'cafe': '5814', 'transport': '4121', 'books': '5942', 'fashion': '5651', 'travel': '7011'}

CODES = {
    '00': 'Approved',
    '05': 'Do not honor',
    '51': 'Insufficient funds',
    '54': 'Expired card',
    '63': 'Security violation',
    '65': '3-D Secure required',
}


def _ensure_schema() -> None:
    global _schema_ready
    if _schema_ready:
        return
    from ..config import USE_PG
    pk = 'SERIAL PRIMARY KEY' if USE_PG else 'INTEGER PRIMARY KEY'
    with get_connection() as conn:
        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS pos_payments (
                id {pk},
                user_id INTEGER NOT NULL,
                account_id INTEGER NOT NULL,
                merchant VARCHAR(80) NOT NULL,
                category VARCHAR(40) NOT NULL DEFAULT '',
                amount REAL NOT NULL,
                fee REAL NOT NULL DEFAULT 0,
                status VARCHAR(20) NOT NULL,
                response_code VARCHAR(4) NOT NULL,
                auth_code VARCHAR(12),
                rrn VARCHAR(16),
                card_last4 VARCHAR(4),
                three_ds INTEGER NOT NULL DEFAULT 0,
                latency_ms INTEGER NOT NULL DEFAULT 0,
                tx_id INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute('CREATE INDEX IF NOT EXISTS idx_pos_payments_user ON pos_payments(user_id)')
    _schema_ready = True


def _stages() -> list[dict[str, Any]]:
    """Навчальні затримки етапів: термінал, еквайр, мережа, емітент."""
    return [
        {'stage': 'terminal', 'ms': random.randint(18, 40)},
        {'stage': 'acquirer', 'ms': random.randint(35, 80)},
        {'stage': 'network', 'ms': random.randint(25, 70)},
        {'stage': 'issuer', 'ms': random.randint(30, 90)},
    ]


def _created(p: dict[str, Any]) -> datetime:
    raw = str(p['created_at'] or '')[:19].replace('T', ' ')
    try:
        return datetime.strptime(raw, '%Y-%m-%d %H:%M:%S')
    except ValueError:
        return datetime.utcnow()


def _payout_date(d: date) -> date:
    """Розрахунок з мерчантом наступного робочого дня (T+1)."""
    d += timedelta(days=1)
    while d.weekday() >= 5:
        d += timedelta(days=1)
    return d


def _iso(p: dict[str, Any]) -> list[dict[str, str]]:
    """Відповідь авторизації як повідомлення ISO 8583 (0110): поля, які бачить мережа."""
    ts = _created(p)
    seed = zlib.crc32(str(p['merchant']).encode('utf-8'))
    last4 = str(p['card_last4'] or '0000')
    fields = [
        ('MTI', 'Message type', '0110'),
        ('DE2', 'Primary account number', f'**** **** **** {last4}'),
        ('DE3', 'Processing code', '000000'),
        ('DE4', 'Amount, minor units', f"{int(round(float(p['amount']) * 100)):012d}"),
        ('DE7', 'Transmission date and time', ts.strftime('%m%d%H%M%S')),
        ('DE11', 'System trace number', f"{int(p['id']) % 1000000:06d}"),
        ('DE18', 'Merchant category code', MCC.get(str(p['category']), '5999')),
        ('DE37', 'Retrieval reference number', str(p['rrn'] or '')),
        ('DE38', 'Authorization code', str(p['auth_code'] or '')),
        ('DE39', 'Response code', str(p['response_code'])),
        ('DE41', 'Terminal ID', f'TT{seed % 1000000:06d}'),
        ('DE42', 'Merchant ID', f'TAXMERCH{seed % 10000000:07d}'),
        ('DE49', 'Currency code', '999'),
    ]
    return [{'field': f, 'name': n, 'value': v} for f, n, v in fields if v != '' or f not in ('DE37', 'DE38')]


def _settlement(p: dict[str, Any]) -> dict[str, Any]:
    ts = _created(p)
    amount = round(float(p['amount']), 2)
    fee = round(float(p['fee'] or 0), 2)
    pay = _payout_date(ts.date())
    return {
        'clearing_date': ts.date().isoformat(), 'payout_date': pay.isoformat(),
        'paid_out': pay <= date.today(), 'gross': amount, 'mdr': MDR, 'fee': fee, 'net': round(amount - fee, 2),
    }


def _row(p: dict[str, Any]) -> dict[str, Any]:
    fee = round(float(p['fee'] or 0), 2)
    amount = round(float(p['amount']), 2)
    return {
        'id': int(p['id']), 'merchant': p['merchant'], 'category': p['category'], 'amount': amount, 'fee': fee,
        'net': round(amount - fee, 2), 'status': p['status'], 'response_code': p['response_code'],
        'message': CODES.get(p['response_code'], ''), 'auth_code': p['auth_code'], 'rrn': p['rrn'],
        'card_last4': p['card_last4'], 'three_ds': bool(p['three_ds']), 'latency_ms': int(p['latency_ms'] or 0),
        'created_at': str(p['created_at'] or ''),
        'iso': _iso(p), 'settlement': _settlement(p) if p['status'] in ('captured', 'refunded') else None,
    }


@pos_bp.post('/pos/pay')
@auth_required
@rate_limit(30, 600, key_func=lambda: f"pos-pay:{g.current_user['id']}")
def pos_pay():
    _ensure_schema()
    data = request.get_json(silent=True) or {}
    user_id = int(g.current_user['id'])
    merchant = re.sub(r'\s+', ' ', str(data.get('merchant') or '').strip())[:80]
    category = str(data.get('category') or '').strip()[:40]
    try:
        amount = round(float(data.get('amount') or 0), 2)
    except (TypeError, ValueError):
        amount = 0
    if not merchant or amount <= 0 or amount > MAX_AMOUNT:
        return api_error('Потрібні merchant і amount від 0.01 до 100000.')
    card_id = int(data.get('card_id') or 0)
    tds = str(data.get('tds_session') or '').strip()
    stages = _stages()
    latency = sum(s['ms'] for s in stages)

    with get_connection() as conn:
        acc = conn.execute('SELECT id, balance, status FROM accounts WHERE user_id = %s ORDER BY id LIMIT 1', (user_id,)).fetchone()
        if not acc:
            return api_error('Рахунок не знайдено.', 404)
        card = None
        if card_id:
            card = conn.execute('SELECT * FROM cards WHERE id = %s AND account_id = %s', (card_id, int(acc['id']))).fetchone()
            if not card:
                return api_error('Картку не знайдено.', 404)
        last4 = str((card or {}).get('card_number') or '')[-4:]

        def decline(code: str, three_ds: bool = False):
            cur = conn.execute(
                'INSERT INTO pos_payments(user_id, account_id, merchant, category, amount, fee, status, response_code, card_last4, three_ds, latency_ms) '
                "VALUES (%s, %s, %s, %s, %s, 0, 'declined', %s, %s, %s, %s)" + get_returning_id_suffix(),
                (user_id, int(acc['id']), merchant, category, amount, code, last4, 1 if three_ds else 0, latency),
            )
            pid = int(insert_last_id(cur) or 0)
            p = conn.execute('SELECT * FROM pos_payments WHERE id = %s', (pid,)).fetchone()
            return jsonify({'ok': True, 'data': {**_row(p), 'outcome': 'declined', 'approved': False, 'needs_3ds': False, 'stages': stages}})

        if card and str(card.get('status') or 'active') != 'active':
            return decline('05')
        if card:
            exp = str(card.get('expires_at') or '')[:10]
            from datetime import date
            if exp and exp < date.today().isoformat():
                return decline('54')
        needs_3ds = amount >= SCA_THRESHOLD
        if needs_3ds and not tds:
            return jsonify({'ok': True, 'data': {
                'outcome': 'sca_required', 'approved': False, 'needs_3ds': True, 'response_code': '65', 'message': CODES['65'],
                'amount': amount, 'merchant': merchant, 'stages': stages[:3],
            }})
        if needs_3ds:
            try:
                _tds.consume_session(user_id, tds)
            except ValueError:
                return decline('63')
        if float(acc['balance'] or 0) < amount or str(acc['status']) != 'active':
            return decline('51', needs_3ds)

        debit = conn.execute(
            "UPDATE accounts SET balance = balance - %s WHERE id = %s AND user_id = %s AND status = 'active' AND balance >= %s",
            (amount, int(acc['id']), user_id, amount),
        )
        if getattr(debit, 'rowcount', 0) == 0:
            return decline('51', needs_3ds)
        slug = re.sub(r'[^A-Z0-9]+', '-', merchant.upper()).strip('-')[:24] or 'MERCHANT'
        tx = conn.execute(
            'INSERT INTO transactions(account_id, tx_type, direction, amount, description, related_account) VALUES (%s, %s, %s, %s, %s, %s)'
            + get_returning_id_suffix(),
            (int(acc['id']), 'payment', 'out', amount, f'POS · {merchant}', f'POS-{slug}'),
        )
        tx_id = int(insert_last_id(tx) or 0)
        fee = round(amount * MDR, 2)
        auth_code = ''.join(secrets.choice('0123456789') for _ in range(6))
        rrn = ''.join(secrets.choice('0123456789') for _ in range(12))
        cur = conn.execute(
            'INSERT INTO pos_payments(user_id, account_id, merchant, category, amount, fee, status, response_code, auth_code, rrn, card_last4, three_ds, latency_ms, tx_id) '
            "VALUES (%s, %s, %s, %s, %s, %s, 'captured', '00', %s, %s, %s, %s, %s, %s)" + get_returning_id_suffix(),
            (user_id, int(acc['id']), merchant, category, amount, fee, auth_code, rrn, last4, 1 if needs_3ds else 0, latency, tx_id),
        )
        pid = int(insert_last_id(cur) or 0)
        p = conn.execute('SELECT * FROM pos_payments WHERE id = %s', (pid,)).fetchone()
        bal = conn.execute('SELECT balance FROM accounts WHERE id = %s', (int(acc['id']),)).fetchone()
    return jsonify({'ok': True, 'data': {**_row(p), 'outcome': 'approved', 'approved': True, 'needs_3ds': False, 'stages': stages,
                                         'new_balance': round(float(bal['balance']), 2)}})


@pos_bp.get('/pos/payments')
@auth_required
def pos_list():
    _ensure_schema()
    with get_connection() as conn:
        rows = conn.execute('SELECT * FROM pos_payments WHERE user_id = %s ORDER BY id DESC LIMIT 100', (int(g.current_user['id']),)).fetchall()
    return jsonify({'ok': True, 'data': [_row(r) for r in rows]})


@pos_bp.post('/pos/payments/<int:payment_id>/refund')
@auth_required
def pos_refund(payment_id: int):
    _ensure_schema()
    user_id = int(g.current_user['id'])
    with get_connection() as conn:
        p = conn.execute('SELECT * FROM pos_payments WHERE id = %s AND user_id = %s', (payment_id, user_id)).fetchone()
        if not p:
            return api_error('Платіж не знайдено.', 404)
        if p['status'] != 'captured':
            return api_error('Повертати нічого.', 409)
        claim = conn.execute("UPDATE pos_payments SET status = 'refunded' WHERE id = %s AND status = 'captured'", (payment_id,))
        if getattr(claim, 'rowcount', 0) == 0:
            return api_error('Повертати нічого.', 409)
        amount = round(float(p['amount']), 2)
        conn.execute('UPDATE accounts SET balance = balance + %s WHERE id = %s', (amount, int(p['account_id'])))
        conn.execute(
            'INSERT INTO transactions(account_id, tx_type, direction, amount, description, related_account) VALUES (%s, %s, %s, %s, %s, %s)',
            (int(p['account_id']), 'refund', 'in', amount, f"POS refund · {p['merchant']}", 'POS-REFUND'),
        )
        bal = conn.execute('SELECT balance FROM accounts WHERE id = %s', (int(p['account_id']),)).fetchone()
        p = conn.execute('SELECT * FROM pos_payments WHERE id = %s', (payment_id,)).fetchone()
    return jsonify({'ok': True, 'data': {**_row(p), 'new_balance': round(float(bal['balance']), 2)}})


@pos_bp.get('/pos/merchant')
@auth_required
def pos_merchant():
    """Мерчантський кабінет: оборот, комісії, виплати за днями й розбивка за магазинами."""
    _ensure_schema()
    with get_connection() as conn:
        rows = conn.execute('SELECT * FROM pos_payments WHERE user_id = %s ORDER BY id DESC LIMIT 500', (int(g.current_user['id']),)).fetchall()
    gross = fee = refunded = 0.0
    approved = declined = 0
    shops: dict[str, dict[str, Any]] = {}
    days: dict[str, dict[str, Any]] = {}
    for p in rows:
        amount = float(p['amount'])
        if p['status'] == 'declined':
            declined += 1
            continue
        approved += 1
        if p['status'] == 'refunded':
            refunded += amount
            continue
        f = float(p['fee'] or 0)
        gross += amount
        fee += f
        shop = shops.setdefault(p['merchant'], {'merchant': p['merchant'], 'gross': 0.0, 'fee': 0.0, 'count': 0})
        shop['gross'] += amount
        shop['fee'] += f
        shop['count'] += 1
        pay = _payout_date(_created(p).date())
        day = days.setdefault(pay.isoformat(), {'date': pay.isoformat(), 'gross': 0.0, 'fee': 0.0, 'count': 0, 'paid_out': pay <= date.today()})
        day['gross'] += amount
        day['fee'] += f
        day['count'] += 1

    def fin(d: dict[str, Any]) -> dict[str, Any]:
        d['gross'] = round(d['gross'], 2)
        d['fee'] = round(d['fee'], 2)
        d['net'] = round(d['gross'] - d['fee'], 2)
        return d

    total = approved + declined
    return jsonify({'ok': True, 'data': {
        'totals': fin({'gross': gross, 'fee': fee, 'count': sum(s['count'] for s in shops.values())}) | {
            'refunded': round(refunded, 2), 'declined': declined,
            'approval_rate': round(approved / total, 3) if total else 0.0, 'mdr': MDR,
        },
        'merchants': sorted((fin(s) for s in shops.values()), key=lambda x: -x['gross']),
        'payouts': sorted((fin(d) for d in days.values()), key=lambda x: x['date'], reverse=True),
    }})
