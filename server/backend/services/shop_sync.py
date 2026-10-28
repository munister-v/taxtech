"""Інтеграція магазину SAINT AGNES (shop.munister.com.ua) з банком TaxTech.

Обидва напрямки підписані HMAC-SHA256 по спільному секрету SHOP_SYNC_SECRET:
  * замовлення з додатку → магазин (push_order),
  * оплата інвойсу, створеного магазином → магазин (push_paid).
Заголовки: X-TaxTech-Timestamp (unix seconds) і X-TaxTech-Signature
(hex hmac(secret, "<timestamp>.<raw body>")); різниця годин не більше 5 хв.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import logging
import os
import time
import urllib.request
from typing import Any

log = logging.getLogger(__name__)

SHOP_URL = os.environ.get('SHOP_API_URL', 'https://shop.munister.com.ua').rstrip('/')
MAX_SKEW = 300


def _secret() -> bytes:
    return os.environ.get('SHOP_SYNC_SECRET', '').encode()


def enabled() -> bool:
    return bool(_secret())


def sign(body: bytes, ts: str) -> str:
    return hmac.new(_secret(), ts.encode() + b'.' + body, hashlib.sha256).hexdigest()


def verify(body: bytes, ts: str, sig: str) -> bool:
    if not _secret() or not ts or not sig:
        return False
    try:
        if abs(time.time() - int(ts)) > MAX_SKEW:
            return False
    except ValueError:
        return False
    return hmac.compare_digest(sign(body, ts), sig)


def post(path: str, payload: dict[str, Any], timeout: int = 8) -> tuple[bool, dict[str, Any]]:
    if not enabled():
        return False, {'error': 'SHOP_SYNC_SECRET is not configured'}
    body = json.dumps(payload, ensure_ascii=False).encode()
    ts = str(int(time.time()))
    req = urllib.request.Request(
        SHOP_URL + path, data=body, method='POST',
        headers={
            'Content-Type': 'application/json',
            'User-Agent': 'TaxTech-Sync/1.0',
            'X-TaxTech-Timestamp': ts,
            'X-TaxTech-Signature': sign(body, ts),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return True, json.loads(resp.read() or b'{}')
    except Exception as exc:  # мережа/5xx: повторимо з cron
        log.warning('shop sync %s failed: %s', path, exc)
        return False, {'error': str(exc)}


def _shop_product_id(slug: str | None) -> int | None:
    s = str(slug or '')
    if s.startswith('munister-') and s[9:].isdigit():
        return int(s[9:])
    return None


def push_order(conn: Any, order_id: int) -> bool:
    """Передати оплачене замовлення з додатку в магазин (ідемпотентно за external_ref)."""
    order = conn.execute(
        """
        SELECT o.id, o.total_amount, o.status, o.shipping_name, o.shipping_phone, o.shipping_address,
               o.note, o.shop_ref, o.shop_synced, u.full_name, u.email, u.phone
        FROM marketplace_orders o JOIN users u ON u.id = o.user_id WHERE o.id = %s
        """,
        (order_id,),
    ).fetchone()
    if not order or order.get('shop_synced') or order.get('shop_ref') or order.get('status') != 'paid':
        return False
    rows = conn.execute(
        """
        SELECT i.qty, i.price, i.title, p.slug FROM marketplace_order_items i
        LEFT JOIN marketplace_products p ON p.id = i.product_id WHERE i.order_id = %s
        """,
        (order_id,),
    ).fetchall() or []
    items = []
    for r in rows:
        pid = _shop_product_id(r.get('slug'))
        if pid:
            items.append({'product_id': pid, 'qty': int(r['qty']), 'price': float(r['price'])})
    if not items:
        return False  # у замовленні немає товарів магазину
    ok, data = post('/api/integrations/taxtech/orders', {
        'external_ref': f'TT-{order_id}',
        'customer': {
            'name': order.get('shipping_name') or order.get('full_name'),
            'phone': order.get('shipping_phone') or order.get('phone'),
            'email': order.get('email'),
        },
        'address': order.get('shipping_address'),
        'note': order.get('note') or '',
        'items': items,
        'total': float(order['total_amount']),
    })
    if ok and data.get('ok'):
        conn.execute('UPDATE marketplace_orders SET shop_synced = 1 WHERE id = %s', (order_id,))
        return True
    return False


def push_paid(conn: Any, order_id: int, tx_id: int | None = None) -> bool:
    """Повідомити магазин, що інвойс його замовлення оплачено в TaxTech."""
    order = conn.execute(
        'SELECT total_amount, shop_ref, shop_synced FROM marketplace_orders WHERE id = %s', (order_id,),
    ).fetchone()
    if not order or not order.get('shop_ref') or order.get('shop_synced'):
        return False
    ok, data = post('/api/integrations/taxtech/paid', {
        'order_ref': order['shop_ref'], 'amount': float(order['total_amount']),
        'tx_id': tx_id or 0, 'taxtech_order': order_id,
    })
    if ok and data.get('ok'):
        conn.execute('UPDATE marketplace_orders SET shop_synced = 1 WHERE id = %s', (order_id,))
        return True
    return False


def sync_pending(conn: Any) -> int:
    """Повторна відправка тих, що не дійшли (cron)."""
    rows = conn.execute(
        "SELECT id, shop_ref FROM marketplace_orders WHERE status = 'paid' AND shop_synced = 0 ORDER BY id LIMIT 50"
    ).fetchall() or []
    done = 0
    for r in rows:
        if r.get('shop_ref'):
            done += int(push_paid(conn, int(r['id'])))
        else:
            done += int(push_order(conn, int(r['id'])))
    return done
