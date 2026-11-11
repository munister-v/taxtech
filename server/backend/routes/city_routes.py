"""Roma Live API: the shared city (services/city_service.py) and paying its places with a real TaxTech account.

GET  /api/city/live?since=<id>   city clock, today's totals, payments after <id> (the last ~45 s when since=0)
GET  /api/city/venues            today's turnover per place: {venue id: [TAX, payments]}
GET  /api/city/venue/<id>        one place: hours, payer mix, rank among its kind, last payments
GET  /api/city/me                (signed in) balance, card and today's own payments in the city
POST /api/city/pay               (signed in) {venue, amount, tds_session?, card_id?}: goes through the POS pipeline
                                 (authorisation, 3-D Secure from 1000 TAX, MDR, ISO 8583), is debited from the main
                                 account, appears in the statement as "POS · Roma · <place>" and on everyone's map.
"""
from __future__ import annotations

import time

from flask import Blueprint, g, jsonify, request

from ..database import get_connection
from ..services import city_service as cs
from .helpers import api_error, auth_required, rate_limit
from .pos_routes import _authorize

city_bp = Blueprint('city', __name__)

# the POS category (MCC) of each kind of place
POS_CAT = {'cafe': 'cafe', 'food': 'restaurant', 'bar': 'bar', 'shop': 'shop', 'stay': 'hotel',
           'culture': 'museum', 'money': 'cash', 'health': 'pharmacy'}
REASON_BY_CODE = {'51': 'funds', '05': 'limit', '54': 'limit', '63': 'limit'}


def _who(user_id: int) -> str:
    return f'TaxTech •• {(user_id * 7919) % 10000:04d}'


@city_bp.get('/city/live')
@rate_limit(120, 60, key_func=lambda: f"city-live:{request.remote_addr}")
def city_live():
    try:
        since = int(request.args.get('since') or 0)
    except ValueError:
        since = 0
    cs.advance()
    st = cs.stats()
    now = time.time()
    d = cs.rome_now(now)
    pays = cs.payments_since(since)
    return jsonify({'ok': True, 'data': {
        'now': round(now, 2), 'rome': d.strftime('%H:%M'), 'hour': d.hour + d.minute / 60, 'day': st['day'],
        'busy': round(cs.busy(d.hour + d.minute / 60), 3),
        'stats': {k: st[k] for k in ('vol', 'n', 'declined', 'by_cat', 'hours', 'reasons')},
        'payments': pays, 'last_id': pays[-1]['id'] if pays else since,
    }})


@city_bp.get('/city/venues')
def city_venues():
    cs.advance()
    return jsonify({'ok': True, 'data': {'day': cs.today(), 'rev': cs.stats()['rev']}})


@city_bp.get('/city/venue/<int:vid>')
def city_venue(vid: int):
    if vid < 0 or vid >= len(cs.city().venues):
        return api_error('Not found', 404)
    cs.ensure_schema()
    return jsonify({'ok': True, 'data': cs.venue_detail(vid)})


@city_bp.get('/city/me')
@auth_required
def city_me():
    cs.ensure_schema()
    uid = int(g.current_user['id'])
    with get_connection() as conn:
        acc = conn.execute('SELECT id, balance, account_number FROM accounts WHERE user_id = %s ORDER BY id LIMIT 1', (uid,)).fetchone()
        card = conn.execute("SELECT id, card_number FROM cards WHERE account_id = %s AND status = 'active' ORDER BY id LIMIT 1", (int(acc['id']),)).fetchone() if acc else None
        rows = conn.execute('SELECT * FROM city_payments WHERE user_id = %s AND day = %s ORDER BY id DESC LIMIT 20', (uid, cs.today())).fetchall()
    name = str(g.current_user.get('full_name') or '').split(' ')[0]
    return jsonify({'ok': True, 'data': {
        'name': name, 'who': _who(uid), 'balance': round(float(acc['balance']), 2) if acc else 0,
        'card_id': int(card['id']) if card else None, 'card_last4': str(card['card_number'])[-4:] if card else None,
        'payments': [cs._pay_row(r) for r in rows], 'sca_threshold': 1000,
    }})


@city_bp.post('/city/pay')
@auth_required
@rate_limit(30, 600, key_func=lambda: f"pos-pay:{g.current_user['id']}")
def city_pay():
    cs.ensure_schema()
    data = request.get_json(silent=True) or {}
    try:
        vid = int(data.get('venue'))
        amount = round(float(data.get('amount') or 0), 2)
    except (TypeError, ValueError):
        return api_error('venue and amount are required')
    venues = cs.city().venues
    if vid < 0 or vid >= len(venues) or amount <= 0 or amount > 30000:
        return api_error('venue and amount from 0.01 to 30000 are required')
    v = venues[vid]
    body = {'merchant': f'Roma · {v[3]}'[:80], 'category': POS_CAT.get(v[2], 'shop'), 'amount': amount,
            'tds_session': data.get('tds_session') or '', 'card_id': data.get('card_id') or 0}
    resp = _authorize(False, body)
    if isinstance(resp, tuple):           # a validation error from the POS layer
        return resp
    out = resp.get_json() or {}
    d = out.get('data') or {}
    if d.get('outcome') in ('approved', 'declined'):
        uid = int(g.current_user['id'])
        at = data.get('from')
        at = (float(at[0]), float(at[1])) if isinstance(at, list) and len(at) == 2 else None
        with get_connection() as conn:
            cs.record_user(conn, uid, vid, amount, d.get('outcome') == 'approved',
                           None if d.get('outcome') == 'approved' else REASON_BY_CODE.get(str(d.get('response_code')), 'limit'),
                           _who(uid), d.get('id'), at)
        cs._cache.clear()
    return jsonify(out)
