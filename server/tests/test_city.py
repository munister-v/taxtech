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
