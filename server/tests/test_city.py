"""Roma Live: the shared city on the server and paying its places with a real account."""
from __future__ import annotations

import math
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
    assert d['appIDs'] == ['63PXV4HLQZ.com.eprisjournal.kopiyka'] and d['components'][0]['/'] == '/pay/' + '?' * 12


def test_pay_page_serves_web_app_for_qr_codes(client, tmp_path, monkeypatch):
    from backend.routes import taxpay_routes
    index = tmp_path / 'index.html'
    index.write_text('<div id="root"></div>')
    monkeypatch.setattr(taxpay_routes, 'FRONTEND_INDEX', index)
    assert b'id="root"' in client.get('/pay/Cdi9W7Yh3ha5').data
    long = client.get('/pay/' + 'x' * 32).data
    assert b'id="root"' not in long and b'taxpay/sessions' in long


# ── Il tuo locale ──────────────────────────────────────────────────────────────────────────────────────────────

def _busy_spot():
    """A point in the thick of central Rome: next to the busiest cafés"""
    c = cs.city()
    v = c.venues[c.by_cat['cafe'][0]]
    return float(v[0]) + 3, float(v[1]) + 3


def _open(client, h, b, name='Caffè Prova', cat='cafe', price='fair'):
    x, y = _busy_spot()
    return client.post('/api/city/shop', json={'b': b, 'x': x, 'y': y, 'name': name, 'cat': cat, 'price': price, 'rione': 'Monti'}, headers=h)


def test_open_shop_costs_a_licence_and_shows_on_everyones_map(client):
    cs.ensure_schema()
    h = _user(client, topup=5000)
    before = _balance(client, h)
    r = _open(client, h, b=900001)
    d = r.get_json()['data']
    assert r.status_code == 200 and d['name'] == 'Caffè Prova' and d['id'] >= cs.SHOP_BASE
    assert abs(_balance(client, h) - (before - cs.OPEN_FEE)) < 0.01
    shops = client.get('/api/city/shops').get_json()['data']
    assert any(s['id'] == d['id'] and s['b'] == 900001 for s in shops)
    assert client.get(f"/api/city/venue/{d['id']}").get_json()['data']['shop'] is True
    # one place per client, one place per building
    assert _open(client, h, b=900002).status_code == 400
    assert _open(client, _user(client), b=900001).status_code == 400


def test_open_shop_needs_the_fee_and_valid_fields(client):
    poor = _user(client, topup=500)
    assert _open(client, poor, b=900010).status_code == 402
    h = _user(client)
    assert _open(client, h, b=900011, name='x').status_code == 400
    assert _open(client, h, b=900011, cat='stay').status_code == 400
    assert client.post('/api/city/shop', json={'name': 'Bar'}).status_code in (401, 403)


def test_the_city_walks_into_a_new_shop_and_the_owner_cashes_out(client):
    cs.ensure_schema()
    h = _user(client, topup=5000)
    vid = _open(client, h, b=900020, name='Bar Prova', cat='cafe', price='low').get_json()['data']['id']
    cs.shops(fresh=True)
    t0 = time.time() + 30000
    cs.advance(now=t0, rng=random.Random(7))           # the city catches up to the opening
    cs.advance(now=t0 + 6 * 3600, rng=random.Random(8))
    cs._cache.clear()
    me = client.get('/api/city/shop', headers=h).get_json()['data']
    assert me['till_sim'] > 0, 'simulated customers should have paid the new café'
    from backend.database import get_connection
    with get_connection() as conn:
        n = conn.execute('SELECT COUNT(*) AS n FROM city_payments WHERE venue = %s AND ok = 1', (vid,)).fetchone()['n']
    assert n > 0
    assert client.get(f'/api/city/venue/{vid}').get_json()['data']['name'] == 'Bar Prova'
    before = _balance(client, h)
    r = client.post('/api/city/shop/payout', headers=h).get_json()
    assert r['paid'] > 0 and r['paid'] <= cs.SIM_DAILY_CAP + me['till_real'] + 0.01
    assert abs(_balance(client, h) - (before + r['paid'])) < 0.01
    # the simulated part of the till is paid out at most SIM_DAILY_CAP a day
    again = client.post('/api/city/shop/payout', headers=h)
    if r['data']['till_sim'] > 0:
        assert again.status_code == 400 or again.get_json()['paid'] <= 0.01


def test_a_real_client_pays_a_shop_and_the_owner_cannot_pay_his_own(client):
    owner = _user(client, topup=5000)
    vid = _open(client, owner, b=900030, name='Trattoria Prova', cat='food').get_json()['data']['id']
    assert client.post('/api/city/pay', json={'venue': vid, 'amount': 300}, headers=owner).status_code == 400
    guest = _user(client, topup=3000)
    d = client.post('/api/city/pay', json={'venue': vid, 'amount': 300}, headers=guest).get_json()['data']
    assert d['approved'] is True and d['merchant'] == 'Roma · Trattoria Prova'
    me = client.get('/api/city/shop', headers=owner).get_json()['data']
    assert abs(me['till_real'] - 300 * (1 - cs.SHOP_MDR)) < 0.01
    # QR for the shop works too
    q = client.post('/api/city/qr', json={'venue': vid, 'amount': 120}).get_json()['data']
    assert q['name'] == 'Trattoria Prova'
    assert client.post(f"/api/city/qr/{q['code']}/confirm", json={}, headers=owner).status_code == 400
    assert client.post(f"/api/city/qr/{q['code']}/confirm", json={}, headers=guest).get_json()['data']['status'] == 'paid'
    # closing pays out what it may
    before = _balance(client, owner)
    c = client.post('/api/city/shop/close', headers=owner).get_json()
    assert c['paid'] >= 300 * (1 - cs.SHOP_MDR) and _balance(client, owner) > before
    assert client.get('/api/city/shop', headers=owner).get_json()['data'] is None
    assert all(s['id'] != vid for s in client.get('/api/city/shops').get_json()['data'])


# ── Weather and events ─────────────────────────────────────────────────────────────────────────────────────────

def _rome_ts(s):
    from datetime import datetime
    return datetime.strptime(s, '%Y-%m-%d %H:%M').replace(tzinfo=cs.ROME).timestamp()


def test_events_follow_romes_week():
    on = lambda s: {e['id'] for e in cs.events_at(_rome_ts(s)) if e['on']}
    assert on('2026-11-15 12:00') == {'angelus'}                          # Sunday noon
    assert {'udienza', 'campo', 'testaccio'} <= on('2026-11-18 10:00')     # Wednesday morning
    assert {'circo', 'trastevere', 'sanlorenzo'} <= on('2026-11-14 22:30')  # Saturday night
    assert on('2026-11-15 00:30') == {'trastevere', 'sanlorenzo'}          # past midnight, still Saturday's evening
    ahead = cs.events_at(_rome_ts('2026-11-16 03:00'), ahead=6 * 3600)
    assert {e['id'] for e in ahead if not e['on']} == {'campo', 'testaccio'}


def test_an_event_fills_the_places_around_it(monkeypatch):
    cs.ensure_schema()
    monkeypatch.setattr(cs, 'weather', lambda: {'t': 18, 'rain': False, 'code': 0})
    c = cs.city()
    near = lambda vid, ev: math.hypot(c.venues[vid][0] - ev['x'], c.venues[vid][1] - ev['y']) < 600 if vid < len(c.venues) else False
    angelus = next(e for e in cs.events_at(_rome_ts('2026-11-15 12:00')) if e['id'] == 'angelus')
    # an hour of the same Sunday with and without the Angelus
    def share(monkey_events):
        monkeypatch.setattr(cs, 'events_at', monkey_events)
        rows = []
        monkeypatch.setattr(cs, '_bulk', lambda conn, r: rows.extend(r))
        from backend.database import get_connection
        with get_connection() as conn:
            conn.execute('UPDATE city_state SET last_ts = %s WHERE id = 1', (_rome_ts('2026-11-15 11:30'),))
        cs.advance(now=_rome_ts('2026-11-15 12:30'), rng=random.Random(4))
        return sum(1 for r in rows if near(r[3], angelus)) / max(1, len(rows)), len(rows)
    real = cs.events_at
    with_ev, n_ev = share(lambda ts, ahead=0.0: [e for e in real(ts, ahead) if e['id'] == 'angelus'])
    without, n_plain = share(lambda ts, ahead=0.0: [])
    assert n_ev > n_plain and with_ev > without * 1.5


def test_rain_moves_people_indoors():
    tilt, pace = cs.weather_effect({'t': 14, 'rain': True})
    assert tilt['cafe'] > 1 and tilt['culture'] > 1 and tilt['bar'] < 1 and pace < 1
    hot, _ = cs.weather_effect({'t': 33, 'rain': False})
    assert hot['cafe'] > 1


def test_live_reports_weather_and_events(client):
    d = client.get('/api/city/live?since=999999999').get_json()['data']
    assert {'t', 'rain', 'code'} <= set(d['weather'])
    assert isinstance(d['events'], list)
