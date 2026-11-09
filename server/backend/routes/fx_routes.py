"""Валютні рахунки, обмін і довідки.

  GET  /api/fx/rates                      — курси з bid/ask
  GET  /api/fx/quote?from&to&amount       — розрахунок обміну без виконання
  GET  /api/fx/accounts                   — основний рахунок TAX і валютні гаманці з IBAN
  POST /api/fx/wallets                    — відкрити гаманець {currency}
  POST /api/fx/exchange                   — обмін {from, to, amount}; TAX-сторона йде через основний рахунок
  POST /api/fx/wallets/<id>/topup         — вхідний переказ SWIFT/SEPA (навчальний) {amount}
  POST /api/fx/transfer                   — переказ на IBAN {from_currency, iban, amount, beneficiary}
  GET  /api/fx/wallets/<id>/transactions  — рух коштів гаманця
  POST /api/fx/certificates               — довідка {type: account|balance|turnover|income, currency, from_date, to_date}
  GET  /api/fx/certificates/<code>.pdf    — PDF довідки з QR
"""
from __future__ import annotations

import io
import json
import hashlib
import secrets
from datetime import date, datetime, timezone

from flask import Blueprint, Response, g, jsonify, request

from ..database import get_connection, get_returning_id_suffix, insert_last_id
from ..services import fx_service as fx
from ..services.document_service import DocumentService, KIND_CERT, verify_url
from .helpers import api_error, auth_required, rate_limit

fx_bp = Blueprint('fx', __name__)
_docs = DocumentService()
_ready = False
CERT_TYPES = ('account', 'balance', 'turnover', 'income')


def _ensure() -> None:
    global _ready
    if _ready:
        return
    from ..config import USE_PG
    pk = 'SERIAL PRIMARY KEY' if USE_PG else 'INTEGER PRIMARY KEY'
    with get_connection() as conn:
        conn.execute(
            f"""CREATE TABLE IF NOT EXISTS wallets (
                id {pk}, user_id INTEGER NOT NULL, currency VARCHAR(4) NOT NULL, balance REAL NOT NULL DEFAULT 0,
                iban VARCHAR(34) NOT NULL UNIQUE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (user_id, currency))""")
        conn.execute(
            f"""CREATE TABLE IF NOT EXISTS wallet_tx (
                id {pk}, wallet_id INTEGER NOT NULL, kind VARCHAR(16) NOT NULL, direction VARCHAR(3) NOT NULL,
                amount REAL NOT NULL, description VARCHAR(160) NOT NULL DEFAULT '', counterparty VARCHAR(40),
                rate REAL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)""")
        conn.execute('CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet ON wallet_tx(wallet_id, id)')
    _ready = True


def _num(v, default=0.0) -> float:
    try:
        return round(float(v), 2)
    except (TypeError, ValueError):
        return default


def _main(conn, user_id: int):
    return conn.execute('SELECT id, account_number, balance, status, currency FROM accounts WHERE user_id = %s ORDER BY id LIMIT 1',
                        (user_id,)).fetchone()


def _main_iban(acc, user_id: int) -> str:
    digits = ''.join(ch for ch in str(acc['account_number']) if ch.isdigit()) or str(acc['id'])
    return fx.make_iban('TAX', int(digits[-9:] or 0), user_id)


def _wallet_row(w: dict) -> dict:
    return {'id': int(w['id']), 'currency': w['currency'], 'name': fx.NAMES.get(w['currency'], w['currency']),
            'balance': round(float(w['balance']), 2), 'iban': w['iban'], 'iban_pretty': fx.pretty_iban(w['iban']),
            'created_at': str(w['created_at'] or '')}


def _wallet_tx(conn, wallet_id: int, kind: str, direction: str, amount: float, description: str,
               counterparty: str | None = None, rate: float | None = None) -> None:
    conn.execute(
        'INSERT INTO wallet_tx(wallet_id, kind, direction, amount, description, counterparty, rate) VALUES (%s,%s,%s,%s,%s,%s,%s)',
        (wallet_id, kind, direction, amount, description[:160], counterparty, rate))


def _open_wallet(conn, user_id: int, currency: str) -> dict:
    row = conn.execute('SELECT * FROM wallets WHERE user_id = %s AND currency = %s', (user_id, currency)).fetchone()
    if row:
        return row
    n = conn.execute('SELECT COUNT(*) AS n FROM wallets WHERE user_id = %s', (user_id,)).fetchone()['n']
    iban = fx.make_iban(currency, int(n) + 1, user_id)
    conn.execute('INSERT INTO wallets(user_id, currency, balance, iban) VALUES (%s,%s,0,%s)', (user_id, currency, iban))
    return conn.execute('SELECT * FROM wallets WHERE user_id = %s AND currency = %s', (user_id, currency)).fetchone()


def _tax_tx(conn, account_id: int, direction: str, amount: float, description: str, related: str) -> None:
    conn.execute(
        'INSERT INTO transactions(account_id, tx_type, direction, amount, description, related_account) VALUES (%s,%s,%s,%s,%s,%s)',
        (account_id, 'exchange', direction, amount, description, related))


@fx_bp.get('/fx/rates')
@auth_required
def fx_rates():
    return jsonify({'ok': True, 'data': {'base': 'TAX', 'spread': fx.SPREAD, 'rates': fx.rates(),
                                         'updated_at': datetime.now(timezone.utc).strftime('%Y-%m-%d %H:00 UTC')}})


@fx_bp.get('/fx/quote')
@auth_required
def fx_quote():
    frm, to = str(request.args.get('from', '')).upper(), str(request.args.get('to', '')).upper()
    amount = _num(request.args.get('amount'))
    if amount <= 0 or amount > fx.MAX_AMOUNT:
        return api_error('Сума від 0.01 до 1000000.')
    try:
        return jsonify({'ok': True, 'data': fx.convert(frm, to, amount)})
    except ValueError as exc:
        return api_error(str(exc))


@fx_bp.get('/fx/accounts')
@auth_required
def fx_accounts():
    _ensure()
    uid = int(g.current_user['id'])
    with get_connection() as conn:
        acc = _main(conn, uid)
        if not acc:
            return api_error('Рахунок не знайдено.', 404)
        wallets = conn.execute('SELECT * FROM wallets WHERE user_id = %s ORDER BY id', (uid,)).fetchall()
    q = {r['currency']: r for r in fx.rates()}
    main = {'id': 0, 'currency': 'TAX', 'name': fx.NAMES['TAX'], 'balance': round(float(acc['balance']), 2),
            'iban': _main_iban(acc, uid), 'iban_pretty': fx.pretty_iban(_main_iban(acc, uid)), 'created_at': ''}
    rows = [main] + [_wallet_row(w) for w in wallets]
    total = sum(r['balance'] if r['currency'] == 'TAX' else r['balance'] * q[r['currency']]['mid'] for r in rows)
    return jsonify({'ok': True, 'data': {'accounts': rows, 'total_tax': round(total, 2), 'available': [c for c in fx.SUPPORTED
                    if c not in {w['currency'] for w in wallets}]}})


@fx_bp.post('/fx/wallets')
@auth_required
@rate_limit(20, 600, key_func=lambda: f"fx-open:{g.current_user['id']}")
def fx_open():
    _ensure()
    cur = str((request.get_json(silent=True) or {}).get('currency') or '').upper()
    if cur not in fx.SUPPORTED:
        return api_error('Невідома валюта.')
    with get_connection() as conn:
        w = _open_wallet(conn, int(g.current_user['id']), cur)
    return jsonify({'ok': True, 'data': _wallet_row(w)})


@fx_bp.post('/fx/exchange')
@auth_required
@rate_limit(40, 600, key_func=lambda: f"fx-ex:{g.current_user['id']}")
def fx_exchange():
    _ensure()
    data = request.get_json(silent=True) or {}
    frm, to = str(data.get('from') or '').upper(), str(data.get('to') or '').upper()
    amount = _num(data.get('amount'))
    if amount <= 0 or amount > fx.MAX_AMOUNT:
        return api_error('Сума від 0.01 до 1000000.')
    try:
        q = fx.convert(frm, to, amount)
    except ValueError as exc:
        return api_error(str(exc))
    if q['to_amount'] <= 0:
        return api_error('Сума після обміну замала.')
    uid = int(g.current_user['id'])
    label = f'FX {frm}→{to}'
    with get_connection() as conn:
        acc = _main(conn, uid)
        if not acc or str(acc['status']) != 'active':
            return api_error('Рахунок недоступний.', 404)
        # списання
        if frm == 'TAX':
            res = conn.execute("UPDATE accounts SET balance = balance - %s WHERE id = %s AND balance >= %s", (amount, int(acc['id']), amount))
            if getattr(res, 'rowcount', 0) == 0:
                return api_error('Недостатньо коштів.', 409)
            _tax_tx(conn, int(acc['id']), 'out', amount, label, f'FX-{to}')
        else:
            w = conn.execute('SELECT * FROM wallets WHERE user_id = %s AND currency = %s', (uid, frm)).fetchone()
            if not w:
                return api_error('Спочатку відкрийте гаманець.', 404)
            res = conn.execute('UPDATE wallets SET balance = balance - %s WHERE id = %s AND balance >= %s', (amount, int(w['id']), amount))
            if getattr(res, 'rowcount', 0) == 0:
                return api_error('Недостатньо коштів.', 409)
            _wallet_tx(conn, int(w['id']), 'exchange', 'out', amount, label, to, q['rate'])
        # зарахування
        if to == 'TAX':
            conn.execute('UPDATE accounts SET balance = balance + %s WHERE id = %s', (q['to_amount'], int(acc['id'])))
            _tax_tx(conn, int(acc['id']), 'in', q['to_amount'], label, f'FX-{frm}')
        else:
            w2 = _open_wallet(conn, uid, to)
            conn.execute('UPDATE wallets SET balance = balance + %s WHERE id = %s', (q['to_amount'], int(w2['id'])))
            _wallet_tx(conn, int(w2['id']), 'exchange', 'in', q['to_amount'], label, frm, q['rate'])
    return jsonify({'ok': True, 'data': {**q, 'rrn': ''.join(secrets.choice('0123456789') for _ in range(12))}})


@fx_bp.post('/fx/wallets/<int:wallet_id>/topup')
@auth_required
@rate_limit(20, 600, key_func=lambda: f"fx-top:{g.current_user['id']}")
def fx_topup(wallet_id: int):
    _ensure()
    amount = _num((request.get_json(silent=True) or {}).get('amount'))
    if amount <= 0 or amount > 100000:
        return api_error('Сума від 0.01 до 100000.')
    with get_connection() as conn:
        w = conn.execute('SELECT * FROM wallets WHERE id = %s AND user_id = %s', (wallet_id, int(g.current_user['id']))).fetchone()
        if not w:
            return api_error('Гаманець не знайдено.', 404)
        conn.execute('UPDATE wallets SET balance = balance + %s WHERE id = %s', (amount, wallet_id))
        rail = 'SEPA' if w['currency'] == 'EUR' else 'SWIFT'
        _wallet_tx(conn, wallet_id, 'incoming', 'in', amount, f'{rail} incoming (training)', rail)
        w = conn.execute('SELECT * FROM wallets WHERE id = %s', (wallet_id,)).fetchone()
    return jsonify({'ok': True, 'data': _wallet_row(w)})


@fx_bp.post('/fx/transfer')
@auth_required
@rate_limit(30, 600, key_func=lambda: f"fx-tr:{g.current_user['id']}")
def fx_transfer():
    """Переказ на IBAN. Одержувач у системі з тією ж валютою отримує кошти одразу, інакше це зовнішній SWIFT/SEPA з комісією."""
    _ensure()
    data = request.get_json(silent=True) or {}
    cur = str(data.get('from_currency') or 'TAX').upper()
    iban = fx.clean_iban(data.get('iban'))
    amount = _num(data.get('amount'))
    name = str(data.get('beneficiary') or '').strip()[:60]
    purpose = str(data.get('purpose') or '').strip()[:80]
    if cur not in fx.NUMERIC:
        return api_error('Невідома валюта.')
    if amount <= 0 or amount > fx.MAX_AMOUNT:
        return api_error('Сума від 0.01 до 1000000.')
    if not fx.valid_iban(iban):
        return api_error('IBAN не пройшов перевірку контрольних цифр.')
    if not name:
        return api_error('Вкажіть одержувача.')
    uid = int(g.current_user['id'])
    with get_connection() as conn:
        acc = _main(conn, uid)
        own_iban = _main_iban(acc, uid) if cur == 'TAX' else None
        src = None
        if cur != 'TAX':
            src = conn.execute('SELECT * FROM wallets WHERE user_id = %s AND currency = %s', (uid, cur)).fetchone()
            if not src:
                return api_error('Гаманець не знайдено.', 404)
            own_iban = src['iban']
        if iban == own_iban:
            return api_error('Це ваш власний IBAN.')
        target = conn.execute('SELECT * FROM wallets WHERE iban = %s', (iban,)).fetchone()
        internal = bool(target and target['currency'] == cur)
        if target and not internal:
            return api_error('Валюта рахунку одержувача інша: спершу зробіть обмін.', 409)
        fee = 0.0 if internal else round(max(1.0, amount * 0.005), 2)
        total = round(amount + fee, 2)
        if cur == 'TAX':
            res = conn.execute('UPDATE accounts SET balance = balance - %s WHERE id = %s AND balance >= %s', (total, int(acc['id']), total))
            if getattr(res, 'rowcount', 0) == 0:
                return api_error('Недостатньо коштів.', 409)
            _tax_tx(conn, int(acc['id']), 'out', total, f'IBAN → {fx.pretty_iban(iban)[:24]} · {name}', iban[-8:])
        else:
            res = conn.execute('UPDATE wallets SET balance = balance - %s WHERE id = %s AND balance >= %s', (total, int(src['id']), total))
            if getattr(res, 'rowcount', 0) == 0:
                return api_error('Недостатньо коштів.', 409)
            _wallet_tx(conn, int(src['id']), 'transfer', 'out', total, f'{"SEPA" if cur == "EUR" else "SWIFT"} → {name} {purpose}'.strip(), iban[-8:])
        if internal:
            conn.execute('UPDATE wallets SET balance = balance + %s WHERE id = %s', (amount, int(target['id'])))
            _wallet_tx(conn, int(target['id']), 'incoming', 'in', amount, f'IBAN from {own_iban[-8:]}', own_iban[-8:])
    return jsonify({'ok': True, 'data': {'amount': amount, 'fee': fee, 'total': total, 'currency': cur, 'internal': internal,
                                         'rail': 'internal' if internal else ('SEPA' if cur == 'EUR' else 'SWIFT'),
                                         'reference': ''.join(secrets.choice('0123456789') for _ in range(12))}})


@fx_bp.get('/fx/wallets/<int:wallet_id>/transactions')
@auth_required
def fx_wallet_tx(wallet_id: int):
    _ensure()
    uid = int(g.current_user['id'])
    with get_connection() as conn:
        w = conn.execute('SELECT * FROM wallets WHERE id = %s AND user_id = %s', (wallet_id, uid)).fetchone()
        if not w:
            return api_error('Гаманець не знайдено.', 404)
        rows = conn.execute('SELECT * FROM wallet_tx WHERE wallet_id = %s ORDER BY id DESC LIMIT 100', (wallet_id,)).fetchall()
    return jsonify({'ok': True, 'data': [{
        'id': int(r['id']), 'kind': r['kind'], 'direction': r['direction'], 'amount': round(float(r['amount']), 2),
        'description': r['description'], 'counterparty': r['counterparty'], 'rate': r['rate'], 'created_at': str(r['created_at'] or '')}
        for r in rows]})


# ── Довідки ───────────────────────────────────────────────────────────────────
def cert_digest(meta: dict) -> str:
    return hashlib.sha256(json.dumps(meta, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def _turnover(conn, account_ids: list[int], wallet_id: int | None, d_from: str, d_to: str) -> tuple[float, float]:
    inn = out = 0.0
    if wallet_id is None:
        for r in conn.execute(
                'SELECT direction, SUM(amount) AS s FROM transactions WHERE account_id = %s AND created_at >= %s AND created_at <= %s '
                'GROUP BY direction', (account_ids[0], f'{d_from} 00:00:00', f'{d_to} 23:59:59')).fetchall():
            if r['direction'] == 'in':
                inn = float(r['s'] or 0)
            else:
                out = float(r['s'] or 0)
    else:
        for r in conn.execute(
                'SELECT direction, SUM(amount) AS s FROM wallet_tx WHERE wallet_id = %s AND created_at >= %s AND created_at <= %s '
                'GROUP BY direction', (wallet_id, f'{d_from} 00:00:00', f'{d_to} 23:59:59')).fetchall():
            if r['direction'] == 'in':
                inn = float(r['s'] or 0)
            else:
                out = float(r['s'] or 0)
    return round(inn, 2), round(out, 2)


@fx_bp.post('/fx/certificates')
@auth_required
@rate_limit(20, 600, key_func=lambda: f"fx-cert:{g.current_user['id']}")
def fx_certificate():
    _ensure()
    data = request.get_json(silent=True) or {}
    kind = str(data.get('type') or '').lower()
    cur = str(data.get('currency') or 'TAX').upper()
    if kind not in CERT_TYPES or cur not in fx.NUMERIC:
        return api_error('Невірний вид довідки або валюта.')
    today = date.today().isoformat()
    d_from = str(data.get('from_date') or today[:8] + '01')[:10]
    d_to = str(data.get('to_date') or today)[:10]
    if d_from > d_to:
        return api_error('Початок періоду пізніше за кінець.')
    uid = int(g.current_user['id'])
    with get_connection() as conn:
        acc = _main(conn, uid)
        user = conn.execute('SELECT full_name FROM users WHERE id = %s', (uid,)).fetchone()
        wallet = None
        if cur == 'TAX':
            iban, balance = _main_iban(acc, uid), round(float(acc['balance']), 2)
        else:
            wallet = conn.execute('SELECT * FROM wallets WHERE user_id = %s AND currency = %s', (uid, cur)).fetchone()
            if not wallet:
                return api_error('Гаманця в цій валюті немає.', 404)
            iban, balance = wallet['iban'], round(float(wallet['balance']), 2)
        meta: dict = {'cert': kind, 'currency': cur, 'iban': iban, 'holder': user['full_name'], 'issued_on': today}
        if kind == 'account':
            meta['opened'] = str((wallet['created_at'] if wallet else acc.get('created_at')) or '')[:10] if wallet or 'created_at' in acc else ''
        elif kind == 'balance':
            meta['as_of'] = today
            meta['balance'] = balance
        else:
            inn, out = _turnover(conn, [int(acc['id'])], int(wallet['id']) if wallet else None, d_from, d_to)
            meta.update({'from_date': d_from, 'to_date': d_to, 'credit': inn, 'debit': out})
            if kind == 'income':
                meta['income'] = inn
    title = {'account': 'Довідка про відкриття рахунку', 'balance': 'Довідка про залишок на рахунку',
             'turnover': 'Довідка про обороти за рахунком', 'income': 'Довідка про надходження коштів'}[kind]
    ref = f"{kind}|{cur}|{meta.get('from_date', '')}|{meta.get('to_date', '')}|{today}"
    doc = _docs.issue(uid, KIND_CERT, ref, f'{title} · {cur}', cert_digest(meta),
                      amount=meta.get('balance', meta.get('income', meta.get('credit'))), meta=meta)
    return jsonify({'ok': True, 'data': _docs.present(doc, request.url_root)})


@fx_bp.get('/fx/certificates/<code>.pdf')
@auth_required
def fx_certificate_pdf(code: str):
    doc = _docs.by_code(code)
    if not doc or doc['kind'] != KIND_CERT or int(doc['user_id']) != int(g.current_user['id']):
        return api_error('Довідку не знайдено.', 404)
    return Response(_render_pdf(doc, request.url_root), mimetype='application/pdf',
                    headers={'Content-Disposition': f'inline; filename="{doc["code"]}.pdf"'})


def _render_pdf(doc: dict, root: str) -> bytes:
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import mm
    from reportlab.pdfgen import canvas
    from reportlab.graphics import renderPDF
    from ..services.document_service import qr_drawing
    from ..services.statement_service import _ensure_fonts, _f
    _ensure_fonts()
    m = doc['meta']
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    w, h = A4
    c.setFont(_f(True), 20)
    c.drawString(20 * mm, h - 28 * mm, 'TaxTech')
    c.setFont(_f(), 9)
    c.drawRightString(w - 20 * mm, h - 28 * mm, f"№ {doc['code']}")
    c.setLineWidth(0.6)
    c.line(20 * mm, h - 33 * mm, w - 20 * mm, h - 33 * mm)
    c.setFont(_f(True), 16)
    c.drawString(20 * mm, h - 48 * mm, str(doc['title']).split(' · ')[0])
    rows = [('Клієнт', m.get('holder', '')), ('IBAN', fx.pretty_iban(m.get('iban', ''))), ('Валюта', m.get('currency', '')),
            ('Дата видачі', m.get('issued_on', ''))]
    if m.get('cert') == 'account':
        rows.append(('Рахунок відкрито', m.get('opened', '') or '—'))
    if m.get('cert') == 'balance':
        rows.append(('Залишок на дату', f"{m.get('balance', 0):,.2f} {m.get('currency', '')}".replace(',', ' ')))
    if m.get('cert') in ('turnover', 'income'):
        rows.append(('Період', f"{m.get('from_date', '')} – {m.get('to_date', '')}"))
        rows.append(('Надходження', f"{m.get('credit', 0):,.2f} {m.get('currency', '')}".replace(',', ' ')))
        if m.get('cert') == 'turnover':
            rows.append(('Списання', f"{m.get('debit', 0):,.2f} {m.get('currency', '')}".replace(',', ' ')))
    y = h - 66 * mm
    for k, v in rows:
        c.setFont(_f(), 9)
        c.setFillGray(0.45)
        c.drawString(20 * mm, y, k)
        c.setFillGray(0)
        c.setFont(_f(True), 11)
        c.drawString(70 * mm, y, str(v))
        y -= 9 * mm
    d = qr_drawing(verify_url(doc['code'], root), 30 * mm)
    renderPDF.draw(d, c, 20 * mm, 30 * mm)
    c.setFont(_f(), 8)
    c.setFillGray(0.4)
    c.drawString(56 * mm, 44 * mm, 'Перевірка: скануйте QR або відкрийте посилання на сторінці перевірки.')
    c.drawString(56 * mm, 39 * mm, verify_url(doc['code'], root))
    c.drawString(56 * mm, 34 * mm, 'Навчальний документ. Суми в віртуальних токенах, не є банківською довідкою.')
    c.showPage()
    c.save()
    return buf.getvalue()
