"""TaxPay: a signed-in session alone must not spend money, the password is required."""
from __future__ import annotations

import hashlib
import hmac
import json
import random
import time


def _session(client, monkeypatch, ref):
    monkeypatch.setenv('SHOP_SYNC_SECRET', 'test-sync')
    body = json.dumps({'order_ref': ref, 'amount': 100, 'items': []}).encode()
    ts = str(int(time.time()))
    sig = hmac.new(b'test-sync', ts.encode() + b'.' + body, hashlib.sha256).hexdigest()
    r = client.post('/api/taxpay/merchant/sessions', data=body,
                    headers={'Content-Type': 'application/json', 'X-TaxTech-Timestamp': ts, 'X-TaxTech-Signature': sig})
    assert r.status_code == 200, r.get_json()
    return r.get_json()['token']


def test_pay_needs_the_password(client, monkeypatch):
    from backend.database import get_connection
    uid = ''.join(str(random.randint(0, 9)) for _ in range(7))
    reg = client.post('/api/auth/register', json={
        'full_name': 'Покупець', 'phone': f'+38094{uid}', 'email': f'tp-{uid}@test.ua', 'password': 'qwerty',
    }).get_json()
    assert reg.get('ok'), reg
    headers = {'Authorization': f"Bearer {reg['data']['token']}"}
    with get_connection() as conn:
        conn.execute('UPDATE accounts SET balance = 1000 WHERE user_id = %s', (reg['data']['user']['id'],))
    token = _session(client, monkeypatch, f'T{uid}')
    url = f'/api/taxpay/sessions/{token}/pay'

    assert client.post(url, json={}, headers=headers).status_code == 400
    assert client.post(url, json={'password': 'wrong'}, headers=headers).status_code == 403
    ok = client.post(url, json={'password': 'qwerty'}, headers=headers)
    assert ok.status_code == 200 and ok.get_json()['status'] == 'paid', ok.get_json()


def _sign(token):
    ts = str(int(time.time()))
    return {'X-TaxTech-Timestamp': ts, 'X-TaxTech-Signature': hmac.new(b'test-sync', ts.encode() + b'.' + token.encode(), hashlib.sha256).hexdigest()}


def _paid_session(client, monkeypatch):
    from backend.database import get_connection
    uid = ''.join(str(random.randint(0, 9)) for _ in range(7))
    reg = client.post('/api/auth/register', json={
        'full_name': 'Покупець', 'phone': f'+38095{uid}', 'email': f'rf-{uid}@test.ua', 'password': 'qwerty',
    }).get_json()
    headers = {'Authorization': f"Bearer {reg['data']['token']}"}
    user_id = reg['data']['user']['id']
    with get_connection() as conn:
        conn.execute('UPDATE accounts SET balance = 1000 WHERE user_id = %s', (user_id,))
    token = _session(client, monkeypatch, f'R{uid}')
    assert client.post(f'/api/taxpay/sessions/{token}/pay', json={'password': 'qwerty'}, headers=headers).status_code == 200
    return token, user_id


def _balance(user_id):
    from backend.database import get_connection
    with get_connection() as conn:
        return float(conn.execute('SELECT balance FROM accounts WHERE user_id = %s', (user_id,)).fetchone()['balance'])


def test_refund_returns_the_money_once(client, monkeypatch):
    token, user_id = _paid_session(client, monkeypatch)
    assert _balance(user_id) == 900
    url = f'/api/taxpay/merchant/sessions/{token}/refund'
    assert client.post(url).status_code == 401  # unsigned
    first = client.post(url, headers=_sign(token))
    assert first.status_code == 200 and first.get_json()['status'] == 'refunded'
    assert _balance(user_id) == 1000
    again = client.post(url, headers=_sign(token))
    assert again.status_code == 200 and _balance(user_id) == 1000  # not paid back twice


def test_unpaid_session_cannot_be_refunded(client, monkeypatch):
    token = _session(client, monkeypatch, f'U{random.randint(10**6, 10**7)}')
    assert client.post(f'/api/taxpay/merchant/sessions/{token}/refund', headers=_sign(token)).status_code == 409


def test_stuck_processing_session_opens_again(client, monkeypatch):
    from backend.database import get_connection
    token = _session(client, monkeypatch, f'P{random.randint(10**6, 10**7)}')
    with get_connection() as conn:
        conn.execute("UPDATE taxpay_sessions SET status = 'processing', processing_ts = %s WHERE token = %s", (int(time.time()) - 600, token))
    assert client.get(f'/api/taxpay/sessions/{token}').get_json()['data']['status'] == 'open'
