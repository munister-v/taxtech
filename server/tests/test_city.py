"""Roma Live: the shared city on the server and paying its places with a real account."""
from __future__ import annotations

import random
import time

from backend.services import city_service as cs


def _user(client, topup=5000):
    uid = ''.join(str(random.randint(0, 9)) for _ in range(7))
    r = client.post('/api/auth/register', json={'full_name': f'Roma User {uid}', 'phone': f'+38095{uid}',
                                                 'email': f'roma-{uid}@test.ua', 'password': 'qwerty'})
    h = {'Authorization': f"Bearer {r.get_json()['data']['token']}"}
    if topup:
        assert client.post('/api/transactions/topup', json={'amount': topup}, headers=h).status_code == 200
    return h


def _balance(client, h):
    return float(client.get('/api/accounts/main', headers=h).get_json()['data']['balance'])


def test_city_generates_on_rome_clock(client):
    cs.ensure_schema()
    r = client.get('/api/city/live')
    d = r.get_json()['data']
    assert r.status_code == 200
    assert {'now', 'rome', 'stats', 'payments', 'last_id'} <= set(d)
    # ten minutes of city later there are payments, each pointing at a real place
    n = cs.advance(now=time.time() + 600, rng=random.Random(1))
    assert n > 50
    rows = cs.payments_since(d['last_id'])
    assert rows and all(0 <= p['v'] < len(cs.city().venues) for p in rows)
    assert all(p['a'] > 0 for p in rows)


def test_advance_is_claimed_once(client):
    cs.ensure_schema()
    t = time.time() + 2000
    first = cs.advance(now=t, rng=random.Random(2))
    again = cs.advance(now=t, rng=random.Random(2))
    assert first > 0 and again == 0


def test_venues_and_detail(client):
    cs.ensure_schema()
    cs.advance(now=time.time() + 2600, rng=random.Random(3))
    cs._cache.clear()
    rev = client.get('/api/city/venues').get_json()['data']['rev']
    assert rev
    vid = int(next(iter(rev)))
    d = client.get(f'/api/city/venue/{vid}').get_json()['data']
    assert d['id'] == vid and len(d['hours']) == 24 and d['name']
    assert client.get('/api/city/venue/999999').status_code == 404


def test_pay_requires_auth(client):
    assert client.post('/api/city/pay', json={'venue': 1, 'amount': 50}).status_code == 401
    assert client.get('/api/city/me').status_code == 401


def test_real_payment_debits_and_shows_on_the_map(client):
    h = _user(client)
    before = _balance(client, h)
    vid = cs.city().by_cat['cafe'][0]
    r = client.post('/api/city/pay', json={'venue': vid, 'amount': 90}, headers=h)
    d = r.get_json()['data']
    assert r.status_code == 200 and d['approved'] is True
    assert d['merchant'].startswith('Roma · ')
    assert abs(_balance(client, h) - (before - 90)) < 0.01
    me = client.get('/api/city/me', headers=h).get_json()['data']
    assert me['payments'][0]['v'] == vid and me['payments'][0]['k'] == 'user' and me['payments'][0]['ok'] is True
    live = client.get('/api/city/live?since=0').get_json()['data']['payments']
    assert any(p['k'] == 'user' and p['v'] == vid for p in live)


def test_big_payment_needs_3ds_then_passes(client):
    h = _user(client, topup=9000)
    vid = cs.city().by_cat['stay'][0]
    d = client.post('/api/city/pay', json={'venue': vid, 'amount': 3800}, headers=h).get_json()['data']
    assert d['outcome'] == 'sca_required'
    ch = client.post('/api/3ds/challenge', json={'amount': 3800, 'recipient': 'Roma'}, headers=h).get_json()['data']
    tok = client.post('/api/3ds/verify', json={'challenge_id': ch['challenge_id'], 'otp_code': ch['demo_otp']}, headers=h).get_json()['data']['session_token']
    d = client.post('/api/city/pay', json={'venue': vid, 'amount': 3800, 'tds_session': tok}, headers=h).get_json()['data']
    assert d['approved'] is True and d['three_ds'] is True


def test_no_funds_is_a_recorded_decline(client):
    h = _user(client, topup=50)
    vid = cs.city().by_cat['food'][0]
    d = client.post('/api/city/pay', json={'venue': vid, 'amount': 400}, headers=h).get_json()['data']
    assert d['approved'] is False and d['response_code'] == '51'
    me = client.get('/api/city/me', headers=h).get_json()['data']
    assert me['payments'][0]['ok'] is False and me['payments'][0]['r'] == 'funds'


def test_bad_input(client):
    h = _user(client)
    for body in ({'venue': -1, 'amount': 5}, {'venue': 1, 'amount': 0}, {'venue': 'x', 'amount': 5}, {'venue': 1, 'amount': 50000}):
        assert client.post('/api/city/pay', json=body, headers=h).status_code == 400


def _qr(client, amount=90, cat='cafe'):
    vid = cs.city().by_cat[cat][1]
    r = client.post('/api/city/qr', json={'venue': vid, 'amount': amount})
    assert r.status_code == 200
    return r.get_json()['data']


def test_qr_create_and_read_without_auth(client):
    q = _qr(client)
    assert q['status'] == 'pending' and q['expires_in'] > 200 and q['name']
    g = client.get(f"/api/city/qr/{q['code']}").get_json()['data']
    assert g['code'] == q['code'] and g['amount'] == 90
    assert client.get('/api/city/qr/nope').status_code == 404


def test_qr_confirm_pays_once(client):
    h = _user(client)
    before = _balance(client, h)
    q = _qr(client)
    assert client.post(f"/api/city/qr/{q['code']}/confirm").status_code in (401, 403)   # 403: cookie session without CSRF header
    d = client.post(f"/api/city/qr/{q['code']}/confirm", json={}, headers=h).get_json()['data']
    assert d['outcome'] == 'approved' and d['status'] == 'paid' and d['auth_code']
    assert abs(_balance(client, h) - (before - 90)) < 0.01
    # the screen that showed the code sees it paid; a second confirm does nothing
    assert client.get(f"/api/city/qr/{q['code']}").get_json()['data']['status'] == 'paid'
    again = client.post(f"/api/city/qr/{q['code']}/confirm", json={}, headers=h).get_json()['data']
    assert again['outcome'] == 'closed'
    assert abs(_balance(client, h) - (before - 90)) < 0.01


def test_qr_big_amount_needs_3ds(client):
    h = _user(client, topup=9000)
    q = _qr(client, 3800, 'stay')
    d = client.post(f"/api/city/qr/{q['code']}/confirm", json={}, headers=h).get_json()['data']
    assert d['outcome'] == 'sca_required' and d['status'] == 'pending'
    ch = client.post('/api/3ds/challenge', json={'amount': 3800, 'recipient': 'Roma'}, headers=h).get_json()['data']
    tok = client.post('/api/3ds/verify', json={'challenge_id': ch['challenge_id'], 'otp_code': ch['demo_otp']}, headers=h).get_json()['data']['session_token']
    d = client.post(f"/api/city/qr/{q['code']}/confirm", json={'tds_session': tok}, headers=h).get_json()['data']
    assert d['status'] == 'paid' and d['three_ds'] is True


def test_qr_expired_and_cancelled(client):
    h = _user(client)
    q = _qr(client)
    client.post(f"/api/city/qr/{q['code']}/cancel")
    d = client.post(f"/api/city/qr/{q['code']}/confirm", json={}, headers=h).get_json()['data']
    assert d['outcome'] == 'closed' and d['status'] == 'cancelled'
    q2 = _qr(client)
    from backend.database import get_connection
    with get_connection() as conn:
        conn.execute('UPDATE city_qr SET expires_ts = %s WHERE code = %s', (time.time() - 1, q2['code']))
    assert client.get(f"/api/city/qr/{q2['code']}").get_json()['data']['status'] == 'expired'


def test_qr_no_funds_declines(client):
    h = _user(client, topup=20)
    q = _qr(client, 400, 'food')
    d = client.post(f"/api/city/qr/{q['code']}/confirm", json={}, headers=h).get_json()['data']
    assert d['status'] == 'declined' and d['response_code'] == '51'


def test_apple_app_site_association(client):
    r = client.get('/.well-known/apple-app-site-association')
    assert r.status_code == 200 and r.mimetype == 'application/json'
    d = r.get_json()['applinks']['details'][0]
    assert d['appIDs'] == ['63PXV4HLQZ.com.eprisjournal.kopiyka'] and d['components'][0]['/'] == '/pay/*'
