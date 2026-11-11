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

    def pick_cat(self, r: random.Random, h: float) -> str:
        w = [WEIGHT[c] * _profile(c, h) for c in CATS]
        x = r.random() * sum(w)
        for c, wi in zip(CATS, w):
            x -= wi
            if x <= 0:
                return c
        return 'cafe'

    def pick_venue(self, r: random.Random, x: float, y: float, cat: str, tourist: bool) -> int:
        lst = self.by_cat[cat]
        walk = 520 if tourist else 340
        best, bw = lst[0], -1.0
        for _ in range(18):
            i = lst[r.randrange(len(lst))]
            v = self.venues[i]
            w = self.pop[i] * math.exp(-math.hypot(v[0] - x, v[1] - y) / walk) * (.5 + r.random())
            if w > bw:
                best, bw = i, w
        return best

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
    _schema_ready = True


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
        t = start
        # a Poisson process whose rate follows the Roman day
        while True:
            h = rome_now(t).hour + rome_now(t).minute / 60
            rate = .15 + 1.6 * busy(h)
            t += r.expovariate(rate)
            if t >= now:
                break
            h = rome_now(t).hour + rome_now(t).minute / 60
            ai = r.randrange(ACCOUNTS)
            kind, hx, hy, who = c.accounts[ai]
            if r.random() < .012:
                rows += _fraud(r, min(t, now - 60), ai)
                continue
            cat = c.pick_cat(r, h)
            vi = c.pick_venue(r, hx, hy, cat, kind == 'tou')
            amt = c.amount(r, cat)
            ok, reason = True, None
            if r.random() < .004:
                ok, reason = False, 'funds'
            rows.append(_tuple(t, vi, amt, ok, reason, kind, who, hx + r.uniform(-25, 25), hy + r.uniform(-25, 25)))
        rows.sort(key=lambda x: x[0])
        _bulk(conn, rows)
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
    v = city().venues[venue]
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
            by_cat[c.venues[vi][2]] += s
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
    cat = c.venues[vi][2]
    rank = 1 + sum(1 for j in c.by_cat[cat] if st['rev'].get(j, [0])[0] > mine[0]) if mine[1] else 0
    v = c.venues[vi]
    return {'id': vi, 'name': v[3], 'cat': cat, 'rione': v[4], 'rev': mine[0], 'n': mine[1], 'hours': h24, 'mix': mix,
            'rank': rank, 'of': len(c.by_cat[cat]), 'last': [_pay_row(r) for r in last]}
