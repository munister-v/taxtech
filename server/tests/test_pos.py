"""Тести POS: еквайринг на навчальному рахунку (авторизація, 3-D Secure, комісія, повернення, відмови)."""
from __future__ import annotations

import random

from backend.routes import pos_routes


def _setup(client, topup=5000):
    uid = ''.join(str(random.randint(0, 9)) for _ in range(7))
    r = client.post('/api/auth/register', json={
        'full_name': f'Pos User {uid}', 'phone': f'+38093{uid}',
        'email': f'pos-{uid}@test.ua', 'password': 'qwerty',
    })
    token = r.get_json()['data']['token']
    h = {'Authorization': f'Bearer {token}'}
    if topup:
        assert client.post('/api/transactions/topup', json={'amount': topup}, headers=h).status_code == 200
    return h


def _balance(client, h):
    return float(client.get('/api/accounts/main', headers=h).get_json()['data']['balance'])


def _pay(client, h, amount, **extra):
    body = {'merchant': 'Café Roma', 'category': 'cafe', 'amount': amount, **extra}
    return client.post('/api/pos/pay', json=body, headers=h)


def _card(client, h):
    r = client.post('/api/cards', json={'card_type': 'virtual', 'design': 'gold'}, headers=h)
    return r.get_json()['data']['id']


def _tds_token(client, h, amount):
    ch = client.post('/api/3ds/challenge', json={'amount': amount, 'recipient': 'Café Roma'}, headers=h).get_json()['data']
    v = client.post('/api/3ds/verify', json={'challenge_id': ch['challenge_id'], 'otp_code': ch['demo_otp']}, headers=h)
    return v.get_json()['data']['session_token']


def test_requires_auth(client):
    assert client.post('/api/pos/pay', json={'merchant': 'X', 'amount': 5}).status_code == 401
    assert client.get('/api/pos/payments').status_code == 401
    assert client.get('/api/pos/merchant').status_code == 401


def test_validation_is_an_error_not_a_decline(client):
    h = _setup(client)
    for body in ({'merchant': '', 'amount': 5}, {'merchant': 'X', 'amount': 0}, {'merchant': 'X', 'amount': 100001}):
        r = client.post('/api/pos/pay', json=body, headers=h)
        assert r.status_code == 400
        assert r.get_json()['ok'] is False


def test_approved_payment_charges_and_takes_mdr(client):
    h = _setup(client)
    r = _pay(client, h, 200)
    d = r.get_json()['data']
    assert r.status_code == 200
    assert d['outcome'] == 'approved' and d['approved'] is True and d['response_code'] == '00'
    assert d['fee'] == 3.0 and d['net'] == 197.0
    assert len(d['auth_code']) == 6 and len(d['rrn']) == 12
    assert [s['stage'] for s in d['stages']] == ['terminal', 'acquirer', 'network', 'issuer']
    assert _balance(client, h) == 4800.0
    assert d['new_balance'] == 4800.0


def test_mdr_rounds_to_cents(client):
    h = _setup(client)
    d = _pay(client, h, 42).get_json()['data']
    assert d['fee'] == 0.63 and d['net'] == 41.37


def test_sca_required_from_threshold(client):
    h = _setup(client)
    below = _pay(client, h, pos_routes.SCA_THRESHOLD - 0.01).get_json()['data']
    assert below['outcome'] == 'approved'
    before = _balance(client, h)
    d = _pay(client, h, pos_routes.SCA_THRESHOLD).get_json()['data']
    assert d['outcome'] == 'sca_required' and d['needs_3ds'] is True and d['response_code'] == '65'
    assert len(d['stages']) == 3
    assert _balance(client, h) == before  # нічого не списано, поки немає підтвердження


def test_sca_payment_with_verified_session(client):
    h = _setup(client)
    token = _tds_token(client, h, 1500)
    d = _pay(client, h, 1500, tds_session=token).get_json()['data']
    assert d['outcome'] == 'approved' and d['three_ds'] is True
    assert d['fee'] == 22.5
    assert _balance(client, h) == 3500.0


def test_sca_session_is_single_use(client):
    h = _setup(client)
    token = _tds_token(client, h, 1500)
    assert _pay(client, h, 1500, tds_session=token).get_json()['data']['outcome'] == 'approved'
    again = _pay(client, h, 1500, tds_session=token).get_json()['data']
    assert again['outcome'] == 'declined' and again['response_code'] == '63'
    assert _balance(client, h) == 3500.0


def test_sca_with_bogus_session_is_security_violation(client):
    h = _setup(client)
    d = _pay(client, h, 1500, tds_session='nope').get_json()['data']
    assert d['outcome'] == 'declined' and d['response_code'] == '63'


def test_insufficient_funds_declines(client):
    h = _setup(client, topup=100)
    d = _pay(client, h, 150).get_json()['data']
    assert d['outcome'] == 'declined' and d['response_code'] == '51' and d['approved'] is False
    assert d['fee'] == 0
    assert _balance(client, h) == 100.0


def test_blocked_card_declines(client):
    h = _setup(client)
    card_id = _card(client, h)
    assert _pay(client, h, 10, card_id=card_id).get_json()['data']['outcome'] == 'approved'
    assert client.patch(f'/api/cards/{card_id}/block', headers=h).status_code == 200
    d = _pay(client, h, 10, card_id=card_id).get_json()['data']
    assert d['outcome'] == 'declined' and d['response_code'] == '05'


def test_unknown_card_is_an_error(client):
    h = _setup(client)
    r = _pay(client, h, 10, card_id=999999)
    assert r.status_code == 404 and r.get_json()['ok'] is False


def test_refund_returns_full_amount_once(client):
    h = _setup(client)
    pid = _pay(client, h, 300).get_json()['data']['id']
    assert _balance(client, h) == 4700.0
    r = client.post(f'/api/pos/payments/{pid}/refund', headers=h)
    d = r.get_json()['data']
    assert r.status_code == 200 and d['status'] == 'refunded' and d['new_balance'] == 5000.0
    again = client.post(f'/api/pos/payments/{pid}/refund', headers=h)
    assert again.status_code == 409
    assert _balance(client, h) == 5000.0


def test_cannot_refund_declined_or_foreign_payment(client):
    h = _setup(client, topup=10)
    declined = _pay(client, h, 50).get_json()['data']['id']
    assert client.post(f'/api/pos/payments/{declined}/refund', headers=h).status_code == 409
    other = _setup(client)
    pid = _pay(client, other, 20).get_json()['data']['id']
    assert client.post(f'/api/pos/payments/{pid}/refund', headers=h).status_code == 404


def test_history_lists_own_payments_newest_first(client):
    h = _setup(client)
    _pay(client, h, 10)
    _pay(client, h, 20)
    rows = client.get('/api/pos/payments', headers=h).get_json()['data']
    assert [r['amount'] for r in rows] == [20, 10]
    other = _setup(client)
    assert client.get('/api/pos/payments', headers=other).get_json()['data'] == []


def test_iso_message_and_settlement(client):
    h = _setup(client)
    d = _pay(client, h, 12.5, category='transport').get_json()['data']
    iso = {f['field']: f['value'] for f in d['iso']}
    assert iso['MTI'] == '0110' and iso['DE3'] == '000000'
    assert iso['DE4'] == '000000001250'
    assert iso['DE18'] == '4121' and iso['DE39'] == '00'
    assert iso['DE37'] == d['rrn'] and iso['DE38'] == d['auth_code']
    s = d['settlement']
    assert s['gross'] == 12.5 and s['fee'] == 0.19 and s['net'] == 12.31 and s['mdr'] == 0.015
    assert s['payout_date'] > s['clearing_date']


def test_payout_date_skips_weekends():
    from datetime import date
    assert pos_routes._payout_date(date(2026, 11, 6)).isoformat() == '2026-11-09'  # пʼятниця -> понеділок
    assert pos_routes._payout_date(date(2026, 11, 4)).isoformat() == '2026-11-05'


def test_merchant_summary(client):
    h = _setup(client)
    _pay(client, h, 100)
    _pay(client, h, 200, merchant='Metro Taxi', category='transport')
    refunded = _pay(client, h, 50).get_json()['data']['id']
    client.post(f'/api/pos/payments/{refunded}/refund', headers=h)
    _pay(client, h, 99999)  # sca_required: у підсумки не входить
    h2 = _setup(client, topup=1)
    _pay(client, h2, 500)  # відмова: другий користувач, але перевіримо відмову в нього
    m = client.get('/api/pos/merchant', headers=h).get_json()['data']
    t = m['totals']
    assert t['gross'] == 300.0 and t['fee'] == 4.5 and t['net'] == 295.5
    assert t['count'] == 2 and t['refunded'] == 50.0 and t['declined'] == 0 and t['approval_rate'] == 1.0
    assert [s['merchant'] for s in m['merchants']] == ['Metro Taxi', 'Café Roma']
    assert sum(p['count'] for p in m['payouts']) == 2
    assert round(sum(p['net'] for p in m['payouts']), 2) == 295.5
    m2 = client.get('/api/pos/merchant', headers=h2).get_json()['data']
    assert m2['totals']['declined'] == 1 and m2['totals']['approval_rate'] == 0.0
