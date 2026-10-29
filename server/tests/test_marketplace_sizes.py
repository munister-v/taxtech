"""In-app shop: shop products need a size, and the size travels to the shop order."""
from __future__ import annotations

import random

from backend.services import shop_sync


def _buyer(client):
    from backend.database import get_connection
    uid = ''.join(str(random.randint(0, 9)) for _ in range(7))
    reg = client.post('/api/auth/register', json={
        'full_name': 'Покупець', 'phone': f'+38096{uid}', 'email': f'sz-{uid}@test.ua', 'password': 'qwerty',
    }).get_json()
    assert reg.get('ok'), reg
    with get_connection() as conn:
        conn.execute('UPDATE accounts SET balance = 100000 WHERE user_id = %s', (reg['data']['user']['id'],))
    return {'Authorization': f"Bearer {reg['data']['token']}"}


def _product(slug):
    from backend.database import get_connection
    from backend.routes.marketplace_routes import _ensure_schema
    _ensure_schema()
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO marketplace_products (slug, title, price, stock, is_active, image_url) "
            "VALUES (%s, 'Shirt TEST', 1000, 9, TRUE, '/x.jpg')", (slug,))
        return conn.execute('SELECT id FROM marketplace_products WHERE slug = %s', (slug,)).fetchone()['id']


def _body(pid, size=''):
    return {
        'items': [{'product_id': pid, 'qty': 2, 'size': size}],
        'shipping_name': 'Anna Koval', 'shipping_phone': '+380501234567', 'shipping_address': 'Kyiv, Khreshchatyk 1',
        'payment_mode': 'pay_now',
    }


def _stub_shop(monkeypatch, sizes, live=None, pushed=None):
    monkeypatch.setattr(shop_sync, 'check_stock', lambda items: {i['product_id']: 9 for i in items})
    monkeypatch.setattr(shop_sync, 'shop_sizes', lambda ids: {i: sizes for i in ids})
    monkeypatch.setattr(shop_sync, 'check_size_stock',
                        lambda lines: {(l['product_id'], l['variation']): (live or {}).get(l['variation'], 9) for l in lines})
    if pushed is not None:
        monkeypatch.setattr(shop_sync, 'push_order', lambda conn, order_id: pushed.append(order_id) or True)


def test_sizes_endpoint_reports_the_shops_sizes(client, monkeypatch):
    pid = _product(f'munister-{random.randint(10**5, 10**6)}')
    _stub_shop(monkeypatch, [{'size': '40', 'available': 3}, {'size': '41', 'available': 0}])
    r = client.get(f'/api/marketplace/catalog/{pid}/sizes')
    assert r.status_code == 200 and r.get_json()['data']['sizes'][0] == {'size': '40', 'available': 3}


def test_checkout_wants_a_size_when_the_shop_has_sizes(client, monkeypatch):
    pid = _product(f'munister-{random.randint(10**5, 10**6)}')
    _stub_shop(monkeypatch, [{'size': '40', 'available': 3}])
    r = client.post('/api/marketplace/checkout', json=_body(pid, ''), headers={**_buyer(client), 'Idempotency-Key': 'sz-1'})
    assert r.status_code == 409 and 'розмір' in r.get_json()['error'].lower()


def test_checkout_refuses_a_missing_size_and_a_short_shelf(client, monkeypatch):
    pid = _product(f'munister-{random.randint(10**5, 10**6)}')
    _stub_shop(monkeypatch, [{'size': '40', 'available': 3}, {'size': '41', 'available': 1}], live={'41': 1})
    h = _buyer(client)
    bad = client.post('/api/marketplace/checkout', json=_body(pid, '99'), headers={**h, 'Idempotency-Key': 'sz-2'})
    assert bad.status_code == 409 and '99' in bad.get_json()['error']
    short = client.post('/api/marketplace/checkout', json=_body(pid, '41'), headers={**h, 'Idempotency-Key': 'sz-3'})
    assert short.status_code == 409 and 'лишилось 1' in short.get_json()['error']


def test_checkout_with_a_size_stores_it_and_sends_it_to_the_shop(client, monkeypatch):
    from backend.database import get_connection
    pid = _product(f'munister-{random.randint(10**5, 10**6)}')
    pushed: list[int] = []
    _stub_shop(monkeypatch, [{'size': '40', 'available': 3}], pushed=pushed)
    r = client.post('/api/marketplace/checkout', json=_body(pid, '40'), headers={**_buyer(client), 'Idempotency-Key': 'sz-4'})
    assert r.status_code == 200, r.get_json()
    with get_connection() as conn:
        item = conn.execute('SELECT size, qty, title FROM marketplace_order_items WHERE product_id = %s', (pid,)).fetchone()
    assert item['size'] == '40' and item['qty'] == 2 and item['title'].endswith('· 40')
    assert pushed == [r.get_json()['data']['order_id']]


def test_one_size_product_needs_no_size(client, monkeypatch):
    pid = _product(f'munister-{random.randint(10**5, 10**6)}')
    _stub_shop(monkeypatch, [])
    r = client.post('/api/marketplace/checkout', json=_body(pid, 'ignored'), headers={**_buyer(client), 'Idempotency-Key': 'sz-5'})
    assert r.status_code == 200, r.get_json()
