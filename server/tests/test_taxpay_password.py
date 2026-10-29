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
