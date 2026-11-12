"""Roma Live: one shared city on the server.

The places are the 4 551 shops, cafés, restaurants, hotels and museums of central Rome from OpenStreetMap
(assets/rome_city.json, built by web/scripts/build-city-server.py; a venue id is its index there and on the map).
The city runs on Rome's real clock. Synthetic card holders (residents, tourists, commuters) pay those places at the
rate a Roman day has at that hour; every payment is a row in city_payments, so every visitor sees the same city.
Real TaxTech clients pay the same places through the POS pipeline (routes/city_routes.py) and land in the same table.

There is no background worker: the first request after a pause catches the city up to now (at most 15 minutes back).
A compare-and-set on city_state.last_ts makes sure only one request generates a given stretch of time, so several
gunicorn workers never write the same payments twice.
"""
from __future__ import annotations

import json
import math
import random
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

from ..database import get_connection

ROME = ZoneInfo('Europe/Rome')
CATS = ('cafe', 'food', 'bar', 'shop', 'stay', 'culture', 'money', 'health')
KINDS = ('res', 'tou', 'com')
# average ticket in TAX and its spread
TICKET = {'cafe': (55, .6), 'food': (780, .55), 'bar': (290, .5), 'shop': (1600, .9), 'stay': (5200, .5),
          'culture': (640, .4), 'money': (1400, .5), 'health': (260, .7)}
WEIGHT = {'cafe': 1.5, 'food': 1.3, 'bar': .8, 'shop': 1.0, 'stay': .2, 'culture': .45, 'money': .1, 'health': .3}
PEAKS = {'cafe': ((8, 1), (11, .5), (16, .45)), 'food': ((13.3, 1), (20.6, 1.15)), 'bar': ((19, .6), (22.5, 1), (.5, .7)),
         'shop': ((11.5, .8), (17.5, 1)), 'stay': ((10.5, .7), (15, 1)), 'culture': ((10, .8), (14.5, 1)),
         'money': ((9.5, .6), (13, .5), (18, .6)), 'health': ((10, .7), (17.5, .7))}
ACCOUNTS = 9000
MAX_CATCHUP = 24 * 3600    # seconds of city generated on one request, at most (a cold start backfills from midnight)
CHUNK = 400                # rows per multi-row INSERT
KEEP_DAYS = 2

# Your own place ("Il tuo locale"): a client opens a café, trattoria, bar or shop in an empty building. It is a venue like
# the others (id SHOP_BASE + its row id), the synthetic city walks in by the same gravity model, and the takings land in
# the shop's till; the owner moves them to the account. Simulated takings are paid out up to SIM_DAILY_CAP a day, money
# from real clients in full: the city cannot print TAX faster than that.
SHOP_BASE = 100000
SHOP_CATS = ('cafe', 'food', 'bar', 'shop')
PRICE = {'low': .8, 'fair': 1.0, 'high': 1.35}
OPEN_FEE = 2000.0
SIM_DAILY_CAP = 3000.0
SHOP_MDR = 0.015
SHOP_DRAW = 2.0          # a new place is talked about: it is considered twice as often as an average one

# ── Rome's weather and events move the city ─────────────────────────────────────────────────────────────────
# Weather: Open-Meteo (free, no key) for the centre of Rome, refreshed in the background every 10 minutes; rain sends
# people into cafés and museums and off the bar terraces, heat sells coffee granita and evening drinks.
# Events: the real rhythm of Rome (the Angelus on Sunday, the Pope's audience on Wednesday, the markets, the evenings in
# Trastevere and San Lorenzo) and a concert at the Circus Maximus on Friday and Saturday nights. While one is on, a share
# of the city's payers stands there and pays the places around it.
LAT0, LON0 = 41.8985, 12.4765
KX, KY = 111320 * math.cos(math.radians(LAT0)), 110540


def _xy(lat: float, lon: float) -> tuple[float, float]:
    return (lon - LON0) * KX, (lat - LAT0) * KY


# id, name, lat, lon, weekdays (0 = Monday), start hour, end hour (may pass midnight), kinds of places, crowd, radius m
EVENTS = [
    ('angelus', 'Angelus a San Pietro', 41.9022, 12.4568, {6}, 11.0, 13.5, ('cafe', 'food', 'shop', 'culture'), .55, 450),
    ('udienza', 'Udienza del Papa', 41.9022, 12.4568, {2}, 8.5, 12.5, ('cafe', 'shop', 'culture', 'food'), .45, 450),
    ('campo', "Mercato di Campo de' Fiori", 41.8956, 12.4722, {0, 1, 2, 3, 4, 5}, 7.5, 14.0, ('food', 'shop', 'cafe'), .22, 260),
    ('testaccio', 'Mercato di Testaccio', 41.8774, 12.4752, {0, 1, 2, 3, 4, 5}, 7.5, 15.0, ('food', 'cafe', 'shop'), .14, 300),
    ('trastevere', 'Sera a Trastevere', 41.8894, 12.4700, {3, 4, 5}, 21.0, 26.0, ('bar', 'food'), .38, 420),
    ('sanlorenzo', 'Sera a San Lorenzo', 41.8975, 12.5150, {3, 4, 5}, 21.5, 26.5, ('bar', 'food'), .3, 380),
    ('circo', 'Concerto al Circo Massimo', 41.8861, 12.4851, {4, 5}, 20.5, 23.75, ('bar', 'food', 'cafe'), .5, 520),
]


def _event_row(e, start_ts: float, end_ts: float, now: float) -> dict[str, Any]:
    x, y = _xy(e[2], e[3])
    return {'id': e[0], 'name': e[1], 'x': round(x), 'y': round(y), 'r': e[9], 'cats': list(e[7]), 'crowd': e[8],
            'start': round(start_ts), 'end': round(end_ts), 'on': start_ts <= now < end_ts}


def events_at(ts: float, ahead: float = 0.0) -> list[dict[str, Any]]:
    """Events on at `ts`, plus those starting within `ahead` seconds"""
    out = []
    d = rome_now(ts)
    for offset in (-1, 0, 1):
        day = (d.replace(hour=0, minute=0, second=0, microsecond=0)).timestamp() + offset * 86400
        wd = rome_now(day + 3600).weekday()
        for e in EVENTS:
            if wd not in e[4]:
                continue
            a, b = day + e[5] * 3600, day + e[6] * 3600
            if a <= ts < b or (ahead and ts <= a < ts + ahead):
                out.append(_event_row(e, a, b, ts))
    out.sort(key=lambda r: (not r['on'], r['start']))
    return out


_weather: dict[str, Any] = {'t': None, 'rain': False, 'code': 0, 'at': 0.0, 'busy': False}
WEATHER_URL = ('https://api.open-meteo.com/v1/forecast?latitude=41.8985&longitude=12.4765'
               '&current=temperature_2m,precipitation,weather_code&timezone=Europe%2FRome')


def _fetch_weather() -> None:
    import urllib.request
    try:
        with urllib.request.urlopen(urllib.request.Request(WEATHER_URL, headers={'User-Agent': 'TaxTech-RomaLive/1.0'}), timeout=6) as r:
            cur = json.loads(r.read().decode()).get('current') or {}
        code = int(cur.get('weather_code') or 0)
        rain = float(cur.get('precipitation') or 0) > 0.1 or code in (51, 53, 55, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99)
        _weather.update({'t': cur.get('temperature_2m'), 'rain': rain, 'code': code, 'at': time.time()})
    except Exception:
        _weather['at'] = time.time() - 480        # try again in two minutes
    finally:
        _weather['busy'] = False


def weather() -> dict[str, Any]:
    """Rome's weather now (never blocks: a stale value starts a refresh in the background)"""
    if WEATHER_URL and not _weather['busy'] and time.time() - _weather['at'] > 600:
        _weather['busy'] = True
        threading.Thread(target=_fetch_weather, daemon=True).start()
    return {k: _weather[k] for k in ('t', 'rain', 'code')}


def weather_effect(w: dict[str, Any]) -> tuple[dict[str, float], float]:
    """How the weather tilts the kinds of places, and the city's overall pace"""
    m = {c: 1.0 for c in CATS}
    pace = 1.0
    t = w.get('t')
    if w.get('rain'):
        m.update({'cafe': 1.3, 'culture': 1.35, 'shop': 1.1, 'bar': .75, 'food': .95})
        pace = .88
    if t is not None:
        if t >= 30:
            m['cafe'] *= 1.2; m['bar'] *= 1.15; m['culture'] *= .9
        elif t <= 8:
            m['cafe'] *= 1.15; m['bar'] *= .9
    return m, pace


_lock = threading.Lock()
_schema_ready = False
_cache: dict[str, tuple[float, Any]] = {}


def _profile(cat: str, h: float) -> float:
    v = 0.0
    for c, w in PEAKS[cat]:
        d = min(abs(h - c), 24 - abs(h - c))
        v += w * math.exp(-(d * d) / 3.2)
    return v


def busy(h: float) -> float:
    return sum(WEIGHT[c] * _profile(c, h) for c in CATS) / 2.4


class _City:
    def __init__(self) -> None:
        raw = json.loads((Path(__file__).resolve().parent.parent / 'assets' / 'rome_city.json').read_text('utf-8'))
        self.venues: list[list[Any]] = raw['venues']          # [x, y, cat, name, rione]
        self.homes: list[list[int]] = raw['homes']
        self.bounds = raw['bounds']
        self.by_cat: dict[str, list[int]] = {c: [] for c in CATS}
        for i, v in enumerate(self.venues):
            self.by_cat[v[2]].append(i)
        r = random.Random(20261111)
        self.pop = [math.exp((r.random() + r.random() + r.random() - 1.5) * 1.3) for _ in self.venues]
        hotels = self.by_cat['stay']
        self.accounts: list[tuple[str, float, float, str]] = []
        bx1, by0, by1 = self.bounds[2], self.bounds[1], self.bounds[3]
        for i in range(ACCOUNTS):
            k = r.random()
            if k < .55:
                hx, hy = self.homes[r.randrange(len(self.homes))]; kind = 'res'
            elif k < .85:
                v = self.venues[hotels[r.randrange(len(hotels))]]; hx, hy = v[0], v[1]; kind = 'tou'
            else:
                hx, hy = bx1 - r.random() * 200, by0 + (by1 - by0) * (.45 + r.random() * .35); kind = 'com'
            label = f'TT{r.randint(10, 99)} •••• {r.randint(1000, 9999)}'
            self.accounts.append((kind, float(hx), float(hy), label))

    def pick_cat(self, r: random.Random, h: float, tilt: dict[str, float] | None = None) -> str:
        w = [WEIGHT[c] * _profile(c, h) * (tilt[c] if tilt else 1.0) for c in CATS]
        x = r.random() * sum(w)
        for c, wi in zip(CATS, w):
            x -= wi
            if x <= 0:
                return c
        return 'cafe'

    def pick_venue(self, r: random.Random, x: float, y: float, cat: str, tourist: bool, with_weight: bool = False):
        lst = self.by_cat[cat]
        walk = 520 if tourist else 340
        best, bw = lst[0], -1.0
        for _ in range(18):
            i = lst[r.randrange(len(lst))]
            v = self.venues[i]
            w = self.pop[i] * math.exp(-math.hypot(v[0] - x, v[1] - y) / walk) * (.5 + r.random())
            if w > bw:
                best, bw = i, w
        return (best, bw) if with_weight else best

    @staticmethod
    def amount(r: random.Random, cat: str) -> float:
        m, sd = TICKET[cat]
        g = (r.random() + r.random() + r.random() + r.random() - 2) * 1.2
        return float(max(5, round(m * math.exp(g * sd) / 5) * 5))


_city: _City | None = None


def city() -> _City:
    global _city
    if _city is None:
        with _lock:
            if _city is None:
                _city = _City()
    return _city


def ensure_schema() -> None:
    global _schema_ready
    if _schema_ready:
        return
    from ..config import USE_PG
    pk = 'BIGSERIAL PRIMARY KEY' if USE_PG else 'INTEGER PRIMARY KEY'
    with get_connection() as conn:
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS city_payments (
                id {pk},
                ts DOUBLE PRECISION NOT NULL,
                day VARCHAR(10) NOT NULL,
                hour INTEGER NOT NULL,
                venue INTEGER NOT NULL,
                amount REAL NOT NULL,
                ok INTEGER NOT NULL,
                reason VARCHAR(10),
                kind VARCHAR(4) NOT NULL,
                who VARCHAR(24) NOT NULL,
                fx REAL NOT NULL,
                fy REAL NOT NULL,
                user_id INTEGER,
                pos_id INTEGER
            )""")
        conn.execute('CREATE INDEX IF NOT EXISTS idx_city_day ON city_payments(day)')
        conn.execute('CREATE INDEX IF NOT EXISTS idx_city_venue_day ON city_payments(venue, day)')
        conn.execute('CREATE INDEX IF NOT EXISTS idx_city_ts ON city_payments(ts)')
        conn.execute('CREATE TABLE IF NOT EXISTS city_state (id INTEGER PRIMARY KEY, last_ts DOUBLE PRECISION NOT NULL)')
        # QR invoices: the map shows a code for a place and an amount, a phone confirms it
        conn.execute("""
            CREATE TABLE IF NOT EXISTS city_qr (
                code VARCHAR(24) PRIMARY KEY,
                venue INTEGER NOT NULL,
                amount REAL NOT NULL,
                status VARCHAR(12) NOT NULL,
                created_ts DOUBLE PRECISION NOT NULL,
                expires_ts DOUBLE PRECISION NOT NULL,
                payer_user_id INTEGER,
                pos_id INTEGER,
                response_code VARCHAR(4),
                auth_code VARCHAR(12),
                rrn VARCHAR(16),
                who VARCHAR(24),
                three_ds INTEGER NOT NULL DEFAULT 0,
                paid_ts DOUBLE PRECISION
            )""")
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS city_shops (
                id {pk},
                user_id INTEGER NOT NULL,
                name VARCHAR(40) NOT NULL,
                cat VARCHAR(8) NOT NULL,
                price VARCHAR(4) NOT NULL,
                b INTEGER NOT NULL,
                x REAL NOT NULL,
                y REAL NOT NULL,
                rione VARCHAR(40) NOT NULL DEFAULT '',
                status VARCHAR(8) NOT NULL DEFAULT 'open',
                created_ts DOUBLE PRECISION NOT NULL,
                bal_real REAL NOT NULL DEFAULT 0,
                bal_sim REAL NOT NULL DEFAULT 0,
                paid_sim_day VARCHAR(10) NOT NULL DEFAULT '',
                paid_sim REAL NOT NULL DEFAULT 0,
                paid_total REAL NOT NULL DEFAULT 0
            )""")
        conn.execute('CREATE INDEX IF NOT EXISTS idx_city_shops_user ON city_shops(user_id, status)')
    _schema_ready = True


# ── Places: an OpenStreetMap venue or a client's own shop ──────────────────────────────────────────────────────

def is_shop(vid: int) -> bool:
    return vid >= SHOP_BASE


def shops(fresh: bool = False) -> dict[int, dict[str, Any]]:
    """Open shops by venue id. Cached for a few seconds: the generator asks on every request."""
    def load():
        ensure_schema()
        with get_connection() as conn:
            rows = conn.execute("SELECT * FROM city_shops WHERE status = 'open' ORDER BY id").fetchall()
        return {SHOP_BASE + int(r['id']): dict(r) for r in rows}
    if fresh:
        _cache.pop('shops', None)
    return _cached('shops', 5.0, load)


def place(vid: int) -> tuple[float, float, str, str, str] | None:
    """x, y, category, name, rione of any place on the map"""
    if is_shop(vid):
        r = shops().get(vid)
        return (float(r['x']), float(r['y']), r['cat'], r['name'], r['rione']) if r else None
    v = city().venues
    if 0 <= vid < len(v):
        x, y, cat, name, rione = v[vid][:5]
        return float(x), float(y), cat, name, rione
    return None


def credit_shop(conn, vid: int, amount: float, real: bool) -> None:
    """A payment to a client's shop goes into its till, less the acquirer's fee"""
    net = round(amount * (1 - SHOP_MDR), 2)
    col = 'bal_real' if real else 'bal_sim'
    conn.execute(f'UPDATE city_shops SET {col} = {col} + %s WHERE id = %s', (net, vid - SHOP_BASE))


def payable(r: dict[str, Any], day: str | None = None) -> tuple[float, float]:
    """What the owner can move to the account now: (from real clients, from the simulated city)"""
    day = day or today()
    left = SIM_DAILY_CAP - (float(r['paid_sim']) if r['paid_sim_day'] == day else 0.0)
    return round(float(r['bal_real']), 2), round(max(0.0, min(float(r['bal_sim']), left)), 2)


def rome_now(ts: float | None = None) -> datetime:
    return datetime.fromtimestamp(ts if ts is not None else time.time(), ROME)


_COLS = 'INSERT INTO city_payments(ts, day, hour, venue, amount, ok, reason, kind, who, fx, fy, user_id, pos_id) VALUES '
_ONE = '(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)'


def _tuple(ts: float, venue: int, amount: float, ok: bool, reason: str | None, kind: str, who: str,
           fx: float, fy: float, user_id: int | None = None, pos_id: int | None = None) -> tuple:
    d = rome_now(ts)
    return (ts, d.strftime('%Y-%m-%d'), d.hour, venue, amount, 1 if ok else 0, reason, kind, who, round(fx, 1), round(fy, 1), user_id, pos_id)


def _insert(conn, *a, **kw) -> None:
    conn.execute(_COLS + _ONE, _tuple(*a, **kw))


def _bulk(conn, rows: list[tuple]) -> None:
    for i in range(0, len(rows), CHUNK):
        part = rows[i:i + CHUNK]
        conn.execute(_COLS + ', '.join([_ONE] * len(part)), tuple(x for r in part for x in r))


def advance(now: float | None = None, rng: random.Random | None = None) -> int:
    """Generate the city's payments up to `now`. Returns how many were written by this call."""
    ensure_schema()
    now = time.time() if now is None else now
    c = city()
    own = list(shops().items())
    with get_connection() as conn:
        row = conn.execute('SELECT last_ts FROM city_state WHERE id = 1').fetchone()
        if not row:
            # first start: the city has been open since midnight in Rome
            midnight = rome_now(now).replace(hour=0, minute=0, second=0, microsecond=0).timestamp()
            conn.execute('INSERT INTO city_state(id, last_ts) VALUES (1, %s) ON CONFLICT (id) DO NOTHING', (midnight,))
            row = conn.execute('SELECT last_ts FROM city_state WHERE id = 1').fetchone()
        old = float(row['last_ts'])
        if now - old < 1.0:
            return 0
        claim = conn.execute('UPDATE city_state SET last_ts = %s WHERE id = 1 AND last_ts = %s', (now, old))
        if getattr(claim, 'rowcount', 1) == 0:
            return 0
        start = max(old, now - MAX_CATCHUP)
        r = rng or random.Random()
        rows: list[tuple] = []
        till: dict[int, float] = {}
        tilt, pace = weather_effect(weather())
        ev_min, ev_on = -1, []
        t = start
        # a Poisson process whose rate follows the Roman day, the weather and what is on in town
        while True:
            m = int(t // 60)
            if m != ev_min:
                ev_min, ev_on = m, [e for e in events_at(t) if e['on']]
            crowd = sum(e['crowd'] for e in ev_on)
            h = rome_now(t).hour + rome_now(t).minute / 60
            rate = (.15 + 1.6 * busy(h)) * pace * (1 + crowd)
            t += r.expovariate(rate)
            if t >= now:
                break
            h = rome_now(t).hour + rome_now(t).minute / 60
            ai = r.randrange(ACCOUNTS)
            kind, hx, hy, who = c.accounts[ai]
            if r.random() < .012:
                rows += _fraud(r, min(t, now - 60), ai)
                continue
            if ev_on and r.random() < crowd / (1 + crowd):
                # this payer is at an event: they pay one of the places around it
                x = r.random() * crowd
                ev = ev_on[-1]
                for e in ev_on:
                    x -= e['crowd']
                    if x <= 0:
                        ev = e
                        break
                hx, hy = ev['x'] + r.gauss(0, ev['r'] / 2), ev['y'] + r.gauss(0, ev['r'] / 2)
                kind = 'tou' if r.random() < .6 else kind
                cat = ev['cats'][min(len(ev['cats']) - 1, int(r.random() ** 1.6 * len(ev['cats'])))]
            else:
                cat = c.pick_cat(r, h, tilt)
            vi, bw = c.pick_venue(r, hx, hy, cat, kind == 'tou', with_weight=True)
            pf = 1.0
            if own:
                # a client's place is one more candidate, drawn about as often as SHOP_DRAW ordinary places
                walk = 520 if kind == 'tou' else 340
                p_in = min(1.0, 18 * SHOP_DRAW / max(1, len(c.by_cat[cat])))
                for sid, sh in own:
                    if sh['cat'] != cat or r.random() > p_in:
                        continue
                    f = PRICE.get(sh['price'], 1.0)
                    w = (f ** -2.2) * math.exp(-math.hypot(float(sh['x']) - hx, float(sh['y']) - hy) / walk) * (.5 + r.random())
                    if w > bw:
                        vi, bw, pf = sid, w, f
            amt = float(max(5, round(c.amount(r, cat) * pf / 5) * 5))
            ok, reason = True, None
            if r.random() < .004:
                ok, reason = False, 'funds'
            if ok and vi >= SHOP_BASE:
                till[vi] = till.get(vi, 0.0) + amt
            rows.append(_tuple(t, vi, amt, ok, reason, kind, who, hx + r.uniform(-25, 25), hy + r.uniform(-25, 25)))
        rows.sort(key=lambda x: x[0])
        _bulk(conn, rows)
        for vid, amt in till.items():
            credit_shop(conn, vid, amt, real=False)
        n = len(rows)
        if r.random() < .02:
            conn.execute('DELETE FROM city_payments WHERE ts < %s', (now - KEEP_DAYS * 86400,))
    return n


def _fraud(r: random.Random, t: float, ai: int) -> list[tuple]:
    """Card testing (a burst of tiny payments: the velocity check stops it) or a cloned card (impossible travel)."""
    c = city()
    kind, hx, hy, who = c.accounts[ai]
    if r.random() < .5:
        vi = c.pick_venue(r, hx, hy, 'shop' if r.random() < .5 else 'food', False)
        return [_tuple(t + k * 2.5, vi, 5.0 + r.randint(0, 3) * 5, k < 3, None if k < 3 else 'velocity', kind, who, hx, hy) for k in range(6)]
    a = c.venues[r.randrange(len(c.venues))]
    b = max((c.venues[r.randrange(len(c.venues))] for _ in range(6)), key=lambda v: math.hypot(v[0] - a[0], v[1] - a[1]))
    ia, ib = c.venues.index(a), c.venues.index(b)
    return [_tuple(t, ia, c.amount(r, a[2]), True, None, kind, who, hx, hy),
            _tuple(t + 40, ib, c.amount(r, b[2]), False, 'travel', kind, who, a[0], a[1])]


def record_user(conn, user_id: int, venue: int, amount: float, ok: bool, reason: str | None, who: str,
                pos_id: int | None, at: tuple[float, float] | None) -> None:
    v = place(venue)
    fx, fy = at if at else (v[0] - 140, v[1] - 90)
    _insert(conn, time.time(), venue, amount, ok, reason, 'user', who, fx, fy, user_id, pos_id)


def _cached(key: str, ttl: float, fn):
    hit = _cache.get(key)
    now = time.time()
    if hit and now - hit[0] < ttl:
        return hit[1]
    val = fn()
    _cache[key] = (now, val)
    return val


def today() -> str:
    return rome_now().strftime('%Y-%m-%d')


def stats(day: str | None = None) -> dict[str, Any]:
    day = day or today()

    def build():
        c = city()
        with get_connection() as conn:
            rows = conn.execute('SELECT venue, SUM(amount) AS s, COUNT(*) AS n FROM city_payments WHERE day = %s AND ok = 1 GROUP BY venue', (day,)).fetchall()
            hours = conn.execute('SELECT hour, SUM(amount) AS s FROM city_payments WHERE day = %s AND ok = 1 GROUP BY hour', (day,)).fetchall()
            rs = conn.execute('SELECT reason, COUNT(*) AS n FROM city_payments WHERE day = %s AND ok = 0 GROUP BY reason', (day,)).fetchall()
        by_cat = {k: 0.0 for k in CATS}
        rev: dict[int, list[float]] = {}
        vol, n = 0.0, 0
        for r in rows:
            s, k, vi = float(r['s'] or 0), int(r['n']), int(r['venue'])
            rev[vi] = [round(s), k]
            pl = place(vi)
            if pl:
                by_cat[pl[2]] += s
            vol += s
            n += k
        h24 = [0.0] * 24
        for r in hours:
            h24[int(r['hour'])] = round(float(r['s'] or 0))
        reasons = {'velocity': 0, 'travel': 0, 'limit': 0, 'funds': 0}
        for r in rs:
            reasons[str(r['reason'] or 'funds')] = reasons.get(str(r['reason'] or 'funds'), 0) + int(r['n'])
        return {'day': day, 'vol': round(vol), 'n': n, 'declined': sum(reasons.values()), 'by_cat': {k: round(v) for k, v in by_cat.items()},
                'hours': h24, 'reasons': reasons, 'rev': rev}

    return _cached('stats:' + day, 4.0, build)


def payments_since(since: int, limit: int = 400) -> list[dict[str, Any]]:
    with get_connection() as conn:
        if since <= 0:
            rows = conn.execute('SELECT * FROM city_payments WHERE ts > %s ORDER BY id DESC LIMIT %s', (time.time() - 45, limit)).fetchall()
            rows = list(reversed(rows))
        else:
            rows = conn.execute('SELECT * FROM city_payments WHERE id > %s ORDER BY id LIMIT %s', (since, limit)).fetchall()
    return [_pay_row(r) for r in rows]


def _pay_row(r) -> dict[str, Any]:
    out = {'id': int(r['id']), 'ts': round(float(r['ts']), 2), 'v': int(r['venue']), 'a': float(r['amount']), 'ok': bool(r['ok']),
           'k': r['kind'], 'w': r['who'], 'f': [float(r['fx']), float(r['fy'])]}
    if r['reason']:
        out['r'] = r['reason']
    return out


def venue_detail(vi: int) -> dict[str, Any]:
    c = city()
    day = today()
    with get_connection() as conn:
        hours = conn.execute('SELECT hour, SUM(amount) AS s FROM city_payments WHERE venue = %s AND day = %s AND ok = 1 GROUP BY hour', (vi, day)).fetchall()
        kinds = conn.execute('SELECT kind, COUNT(*) AS n FROM city_payments WHERE venue = %s AND day = %s AND ok = 1 GROUP BY kind', (vi, day)).fetchall()
        last = conn.execute('SELECT * FROM city_payments WHERE venue = %s ORDER BY id DESC LIMIT 6', (vi,)).fetchall()
    h24 = [0.0] * 24
    for r in hours:
        h24[int(r['hour'])] = round(float(r['s'] or 0))
    mix = {k: 0 for k in (*KINDS, 'user')}
    for r in kinds:
        mix[str(r['kind'])] = int(r['n'])
    st = stats(day)
    mine = st['rev'].get(vi, [0, 0])
    x, y, cat, name, rione = place(vi)
    rivals = c.by_cat[cat] + [sid for sid, sh in shops().items() if sh['cat'] == cat]
    rank = 1 + sum(1 for j in rivals if j != vi and st['rev'].get(j, [0])[0] > mine[0]) if mine[1] else 0
    return {'id': vi, 'name': name, 'cat': cat, 'rione': rione, 'rev': mine[0], 'n': mine[1], 'hours': h24, 'mix': mix,
            'rank': rank, 'of': len(rivals), 'last': [_pay_row(r) for r in last], 'shop': is_shop(vi)}
