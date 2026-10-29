"""TaxPay: сторінка оплати TaxTech для зовнішніх магазинів (SAINT AGNES).

Потік:
  1. Магазин (server-to-server, HMAC як у shop_sync) створює сесію
     POST /api/taxpay/merchant/sessions -> {token, pay_url}.
  2. Покупця переводять на https://bank.../pay/<token>. Сторінка показує кошик,
     суму й баланс, просить увійти, якщо треба, і списує кошти одним натиском.
  3. Після оплати банк сам повідомляє магазин (shop_sync.push_paid) і повертає
     покупця на return_url. Магазин додатково звіряє статус підписаним
     GET /api/taxpay/merchant/sessions/<token> - вебхук може не дійти.
Сесія живе 30 хвилин; магазин тримає резерв товару рівно стільки ж.
"""
from __future__ import annotations

import json
import secrets
import time
from pathlib import Path
from typing import Any

from flask import Blueprint, g, jsonify, request, send_file

from ..database import get_connection, get_returning_id_suffix, insert_last_id
from ..services import shop_sync
from .helpers import api_error, auth_required, auth_service, rate_limit
from ..utils.security import verify_password
from .marketplace_routes import (
    _authorize_and_capture_payment,
    _due_at_sql,
    _ensure_schema as _ensure_market_schema,
    _generate_unique_invoice_number,
    _now_sql,
)

taxpay_bp = Blueprint('taxpay', __name__)

SESSION_TTL = 30 * 60
PAGE = Path(__file__).resolve().parent.parent / 'assets' / 'taxpay.html'
_schema_ready = False


def _ensure_schema() -> None:
    global _schema_ready
    if _schema_ready:
        return
    _ensure_market_schema()
    from ..config import USE_PG
    pk = 'SERIAL PRIMARY KEY' if USE_PG else 'INTEGER PRIMARY KEY'
    with get_connection() as conn:
        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS taxpay_sessions (
                id {pk},
                token VARCHAR(64) NOT NULL UNIQUE,
                merchant_ref VARCHAR(40) NOT NULL,
                merchant_name VARCHAR(80) NOT NULL DEFAULT 'SAINT AGNES',
                amount REAL NOT NULL,
                currency VARCHAR(8) NOT NULL DEFAULT 'TAX',
                items TEXT NOT NULL DEFAULT '[]',
                customer_name VARCHAR(120) NOT NULL DEFAULT '',
                shipping TEXT NOT NULL DEFAULT '',
                phone VARCHAR(40) NOT NULL DEFAULT '',
                return_url TEXT NOT NULL DEFAULT '',
                cancel_url TEXT NOT NULL DEFAULT '',
                status VARCHAR(20) NOT NULL DEFAULT 'open',
                user_id INTEGER,
                order_id INTEGER,
                invoice_number VARCHAR(40),
                payment_tx_id INTEGER,
                created_ts INTEGER NOT NULL,
                expires_ts INTEGER NOT NULL,
                paid_ts INTEGER
            )
            """
        )
        conn.execute('CREATE INDEX IF NOT EXISTS idx_taxpay_sessions_ref ON taxpay_sessions(merchant_ref)')
    _schema_ready = True


def _shop_url(url: str) -> str:
    """Повертати покупця можна лише в магазин - інакше це відкритий редирект."""
    u = str(url or '').strip()
    return u if u.startswith(shop_sync.SHOP_URL + '/') else ''


def _load(conn: Any, token: str) -> dict[str, Any] | None:
    row = conn.execute('SELECT * FROM taxpay_sessions WHERE token = %s', (token,)).fetchone()
    if not row:
        return None
    s = dict(row)
    if s['status'] == 'open' and int(s['expires_ts']) < time.time():
        conn.execute("UPDATE taxpay_sessions SET status = 'expired' WHERE id = %s AND status = 'open'", (s['id'],))
        s['status'] = 'expired'
    return s


def _optional_user() -> dict[str, Any] | None:
    header = request.headers.get('Authorization', '')
    token = header[7:].strip() if header.startswith('Bearer ') else ''
    token = token or (request.cookies.get('__Host-kp_session') or request.cookies.get('kp_session') or '').strip()
    return auth_service.get_user_by_token(token) if token else None


def _public(s: dict[str, Any], user: dict[str, Any] | None) -> dict[str, Any]:
    try:
        items = json.loads(s.get('items') or '[]')
    except ValueError:
        items = []
    out: dict[str, Any] = {
        'merchant': s['merchant_name'],
        'reference': s['merchant_ref'],
        'amount': round(float(s['amount']), 2),
        'currency': s['currency'],
        'items': items,
        'status': s['status'],
        'expires_in': max(0, int(s['expires_ts']) - int(time.time())),
        'return_url': s['return_url'],
        'cancel_url': s['cancel_url'],
        'shipping': s['shipping'],
    }
    if user:
        with get_connection() as conn:
            acc = conn.execute(
                'SELECT account_number, balance, currency FROM accounts WHERE user_id = %s ORDER BY id LIMIT 1',
                (int(user['id']),),
            ).fetchone()
        number = str((acc or {}).get('account_number') or '')
        out['me'] = {
            'name': user.get('full_name') or '',
            'balance': round(float((acc or {}).get('balance') or 0), 2),
            'account': ('•• ' + number[-4:]) if number else '',
        }
    return out


# ── Merchant API (HMAC) ──────────────────────────────────────────────────────

@taxpay_bp.post('/api/taxpay/merchant/sessions')
def merchant_create_session():
    raw = request.get_data()
    if not shop_sync.verify(raw, request.headers.get('X-TaxTech-Timestamp', ''), request.headers.get('X-TaxTech-Signature', '')):
        return api_error('Підпис недійсний.', 401)
    _ensure_schema()
    data = json.loads(raw or b'{}')
    ref = str(data.get('order_ref') or '').strip()[:40]
    try:
        amount = round(float(data.get('amount') or 0), 2)
    except (TypeError, ValueError):
        amount = 0
    if not ref or amount <= 0:
        return api_error('Потрібні order_ref і amount.')
    items = []
    for it in (data.get('items') or [])[:50]:
        items.append({
            'title': str(it.get('title') or '')[:160],
            'brand': str(it.get('brand') or '')[:80],
            'size': str(it.get('size') or '')[:20],
            'qty': int(it.get('qty') or 1),
            'price': round(float(it.get('price') or 0), 2),
            'image': str(it.get('image') or '')[:400] if str(it.get('image') or '').startswith('https://') else '',
        })
    now = int(time.time())
    with get_connection() as conn:
        live = conn.execute(
            "SELECT token, expires_ts FROM taxpay_sessions WHERE merchant_ref = %s AND status = 'open' ORDER BY id DESC LIMIT 1",
            (ref,),
        ).fetchone()
        if live and int(live['expires_ts']) > now:
            token = live['token']
        else:
            token = secrets.token_urlsafe(24)
            conn.execute(
                """
                INSERT INTO taxpay_sessions (token, merchant_ref, merchant_name, amount, currency, items, customer_name,
                    shipping, phone, return_url, cancel_url, status, created_ts, expires_ts)
                VALUES (%s, %s, %s, %s, 'TAX', %s, %s, %s, %s, %s, %s, 'open', %s, %s)
                """,
                (token, ref, str(data.get('merchant') or 'SAINT AGNES')[:80], amount,
                 json.dumps(items, ensure_ascii=False), str(data.get('customer_name') or '')[:120],
                 str(data.get('shipping') or '')[:300], str(data.get('phone') or '')[:40],
                 _shop_url(data.get('return_url')), _shop_url(data.get('cancel_url')), now, now + SESSION_TTL),
            )
    base = request.host_url.rstrip('/')
    if request.headers.get('X-Forwarded-Proto', '').startswith('https'):
        base = base.replace('http://', 'https://', 1)
    return jsonify({'ok': True, 'token': token, 'pay_url': f'{base}/pay/{token}', 'expires_in': SESSION_TTL})


@taxpay_bp.get('/api/taxpay/merchant/sessions/<token>')
def merchant_session_status(token: str):
    if not shop_sync.verify(token.encode(), request.headers.get('X-TaxTech-Timestamp', ''), request.headers.get('X-TaxTech-Signature', '')):
        return api_error('Підпис недійсний.', 401)
    _ensure_schema()
    with get_connection() as conn:
        s = _load(conn, token)
    if not s:
        return api_error('Сесію не знайдено.', 404)
    return jsonify({'ok': True, 'status': s['status'], 'order_ref': s['merchant_ref'], 'amount': float(s['amount']),
                    'taxtech_order': int(s.get('order_id') or 0), 'tx_id': int(s.get('payment_tx_id') or 0)})


# ── Buyer side ───────────────────────────────────────────────────────────────

@taxpay_bp.get('/pay/<token>')
def pay_page(token: str):
    resp = send_file(PAGE, mimetype='text/html')
    resp.headers['Cache-Control'] = 'no-store'
    return resp


@taxpay_bp.get('/api/taxpay/sessions/<token>')
def session_view(token: str):
    _ensure_schema()
    with get_connection() as conn:
        s = _load(conn, token)
    if not s:
        return api_error('Платіж не знайдено.', 404)
    resp = jsonify({'ok': True, 'data': _public(s, _optional_user())})
    resp.headers['Cache-Control'] = 'no-store'
    return resp


@taxpay_bp.post('/api/taxpay/sessions/<token>/cancel')
def session_cancel(token: str):
    _ensure_schema()
    with get_connection() as conn:
        s = _load(conn, token)
        if not s:
            return api_error('Платіж не знайдено.', 404)
        if s['status'] == 'open':
            conn.execute("UPDATE taxpay_sessions SET status = 'cancelled' WHERE id = %s AND status = 'open'", (s['id'],))
            s['status'] = 'cancelled'
    return jsonify({'ok': True, 'status': s['status'], 'redirect': s['cancel_url'] or s['return_url']})


@taxpay_bp.post('/api/taxpay/sessions/<token>/pay')
@auth_required
@rate_limit(8, 900, key_func=lambda: f"taxpay-pay:{g.current_user['id']}")
def session_pay(token: str):
    _ensure_schema()
    user_id = int(g.current_user['id'])
    # A signed-in browser session is not consent to spend: every payment needs
    # the account password typed now (the cookie may be on a shared or borrowed
    # device, or left logged in for weeks). Wrong tries count against the limit.
    data = request.get_json(silent=True) or {}
    password = str(data.get('password') or '')
    with get_connection() as conn:
        row = conn.execute('SELECT password_hash FROM users WHERE id = %s', (user_id,)).fetchone()
    if not password:
        return api_error('Введіть пароль, щоб підтвердити платіж.', 400)
    if not row or not verify_password(password, str(row['password_hash'] or '')):
        return api_error('Невірний пароль. Гроші не списано.', 403)
    with get_connection() as conn:
        s = _load(conn, token)
        if not s:
            return api_error('Платіж не знайдено.', 404)
        if s['status'] == 'paid':
            if int(s.get('user_id') or 0) == user_id:
                return jsonify({'ok': True, 'status': 'paid', 'redirect': s['return_url']})
            return api_error('Цей рахунок уже оплачено.', 409)
        if s['status'] != 'open':
            return api_error('Час на оплату минув. Поверніться в магазин і оформіть замовлення ще раз.'
                             if s['status'] == 'expired' else 'Платіж скасовано.', 409)
        # Захоплюємо сесію: другий паралельний натиск отримає rowcount 0.
        cur = conn.execute("UPDATE taxpay_sessions SET status = 'processing' WHERE id = %s AND status = 'open'", (s['id'],))
        if getattr(cur, 'rowcount', 0) == 0:
            return api_error('Платіж уже обробляється.', 409)

    amount = round(float(s['amount']), 2)
    ref = s['merchant_ref']
    order_id = 0
    payment_tx_id = 0
    error: tuple[str, int] | None = None
    try:
        with get_connection() as conn:
            account = conn.execute(
                "SELECT id, account_number, balance, currency FROM accounts WHERE user_id = %s ORDER BY id LIMIT 1",
                (user_id,),
            ).fetchone()
            if not account:
                raise LookupError('Рахунок не знайдено.')
            invoice_number = _generate_unique_invoice_number(conn)
            payment = _authorize_and_capture_payment(
                conn,
                user_id=user_id,
                account=dict(account),
                amount=amount,
                invoice_number=invoice_number,
                tx_type='marketplace_invoice',
                description=f"TaxPay · {s['merchant_name']} {ref}",
                payment_network='TAX_PAY',
            )
            if not payment.get('approved'):
                error = (payment.get('error') or 'Платіж відхилено.', int(payment.get('status_code') or 409))
                conn.execute("UPDATE taxpay_sessions SET status = 'open' WHERE id = %s", (s['id'],))
            else:
                payment_tx_id = int(payment.get('payment_tx_id') or 0)
                auth_id = int((payment.get('authorization') or {}).get('id') or 0)
                currency = str(account.get('currency') or 'TAX')
                suffix = get_returning_id_suffix()
                cur = conn.execute(
                    """
                    INSERT INTO marketplace_orders
                    (user_id, account_id, total_amount, currency, status, payment_mode, invoice_number, invoice_status,
                     invoice_due_at, shipping_name, shipping_phone, shipping_address, note, shop_ref, payment_tx_id, payment_auth_id)
                    VALUES (%s, %s, %s, %s, 'paid', 'taxpay', %s, 'paid', """ + _due_at_sql(0) + """, %s, %s, %s, %s, %s, %s, %s)"""
                    + suffix,
                    (user_id, account['id'], amount, currency, invoice_number, s['customer_name'], s['phone'],
                     s['shipping'], f"{s['merchant_name']} {ref}", ref, payment_tx_id, auth_id),
                )
                order_id = int(insert_last_id(cur) or 0)
                try:
                    items = json.loads(s.get('items') or '[]')
                except ValueError:
                    items = []
                for it in items or [{'title': f"{s['merchant_name']} {ref}", 'qty': 1, 'price': amount}]:
                    title = ' · '.join(x for x in (it.get('brand'), it.get('title'), it.get('size')) if x)[:200]
                    qty = int(it.get('qty') or 1)
                    price = float(it.get('price') or 0)
                    conn.execute(
                        'INSERT INTO marketplace_order_items(order_id, product_id, title, price, qty, line_total) VALUES (%s, NULL, %s, %s, %s, %s)',
                        (order_id, title or 'Товар', price, qty, round(price * qty, 2)),
                    )
                conn.execute(
                    """
                    INSERT INTO marketplace_invoices
                    (invoice_number, order_id, user_id, account_id, amount, currency, status, due_at, paid_at, payment_tx_id, payment_auth_id)
                    VALUES (%s, %s, %s, %s, %s, %s, 'paid', """ + _now_sql() + ", " + _now_sql() + """, %s, %s)""",
                    (invoice_number, order_id, user_id, account['id'], amount, currency, payment_tx_id, auth_id),
                )
                conn.execute('UPDATE marketplace_payment_authorizations SET order_id = %s WHERE id = %s', (order_id, auth_id))
                conn.execute(
                    "UPDATE taxpay_sessions SET status = 'paid', user_id = %s, order_id = %s, invoice_number = %s, "
                    "payment_tx_id = %s, paid_ts = %s WHERE id = %s",
                    (user_id, order_id, invoice_number, payment_tx_id, int(time.time()), s['id']),
                )
    except LookupError as exc:
        error = (str(exc), 404)
    except Exception:
        error = ('Банк тимчасово недоступний. Гроші не списано, спробуйте ще раз.', 500)

    if error:
        with get_connection() as conn:
            conn.execute("UPDATE taxpay_sessions SET status = 'open' WHERE id = %s AND status = 'processing'", (s['id'],))
        return api_error(*error)

    # Магазин дізнається одразу; якщо не відповів - його return-сторінка звірить статус сама.
    try:
        with get_connection() as sconn:
            shop_sync.push_paid(sconn, order_id, payment_tx_id)
    except Exception:
        pass
    return jsonify({'ok': True, 'status': 'paid', 'redirect': s['return_url'], 'order_id': order_id})
