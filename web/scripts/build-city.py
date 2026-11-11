#!/usr/bin/env python3
"""Builds web/public/city/rome.json for the Roma Live map (CityLive.tsx) from OpenStreetMap Overpass dumps.

Usage: python3 -I build-city.py <dir with buildings.json venues.json ways.json> <out.json>  (web/src/city/rome.json)

The three dumps come from overpass-api.de for the bbox 41.8860,12.4520,41.9110,12.5010 (Vatican to the Colosseum):
  buildings.json  way["building"]                                   out geom
  venues.json     amenity / shop / tourism POIs                     out center tags
  ways.json       highway, river, water, parks                      out geom
  extra.json      building / park / water multipolygons, squares    out geom
  labels.json     rioni, squares, monuments, attractions            out center tags
Coordinates become local metres around the centre (x east, y north), rounded to 1 m.
Data © OpenStreetMap contributors, ODbL.
"""
import json, math, sys, random, os

LAT0, LON0 = 41.8985, 12.4765
KX = 111320 * math.cos(math.radians(LAT0))
KY = 110540

def xy(p):
    return (round((p['lon'] - LON0) * KX), round((p['lat'] - LAT0) * KY))

def simplify(pts, eps):
    if len(pts) < 3:
        return pts
    # Douglas-Peucker
    def rec(a, b):
        (x1, y1), (x2, y2) = pts[a], pts[b]
        dx, dy = x2 - x1, y2 - y1
        L = math.hypot(dx, dy) or 1e-9
        best, bi = -1, -1
        for i in range(a + 1, b):
            d = abs(dy * pts[i][0] - dx * pts[i][1] + x2 * y1 - y2 * x1) / L
            if d > best:
                best, bi = d, i
        if best > eps:
            return rec(a, bi)[:-1] + rec(bi, b)
        return [pts[a], pts[b]]
    return rec(0, len(pts) - 1)

def area(poly):
    s = 0
    for i in range(len(poly)):
        x1, y1 = poly[i]; x2, y2 = poly[(i + 1) % len(poly)]
        s += x1 * y2 - x2 * y1
    return s / 2

def inside(px, py, poly):
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]; xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi:
            c = not c
        j = i
    return c

CAT = {
    'restaurant': 'food', 'fast_food': 'food',
    'cafe': 'cafe', 'ice_cream': 'cafe', 'bakery': 'cafe',
    'bar': 'bar', 'pub': 'bar', 'nightclub': 'bar',
    'hotel': 'stay', 'guest_house': 'stay',
    'museum': 'culture', 'gallery': 'culture', 'attraction': 'culture', 'theatre': 'culture', 'cinema': 'culture',
    'bank': 'money', 'atm': 'money', 'bureau_de_change': 'money',
    'pharmacy': 'health', 'fuel': 'shop', 'marketplace': 'shop',
}


def clean(pts, eps, ccw):
    """Closed ring -> simplified, de-duplicated, oriented (ccw for outers, cw for holes) list of points or None."""
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]
    if len(pts) < 3:
        return None
    far = max(range(len(pts)), key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
    if far == 0:
        return None
    pts = simplify(pts[:far + 1], eps)[:-1] + simplify(pts[far:] + [pts[0]], eps)[:-1]
    out = []
    for p in pts:
        if not out or out[-1] != p:
            out.append(p)
    if len(out) > 1 and out[0] == out[-1]:
        out.pop()
    if len(out) < 3:
        return None
    a = area(out)
    if abs(a) < 12:
        return None
    if (a > 0) != ccw:
        out.reverse()
    return out


def join_ways(ways):
    """Member ways of a multipolygon -> closed rings (joined end to end)."""
    ways = [w[:] for w in ways if len(w) >= 2]
    rings = []
    while ways:
        cur = ways.pop(0)
        changed = True
        while cur[0] != cur[-1] and changed:
            changed = False
            for i, w in enumerate(ways):
                if w[0] == cur[-1]:
                    cur += w[1:]
                elif w[-1] == cur[-1]:
                    cur += w[::-1][1:]
                elif w[-1] == cur[0]:
                    cur = w + cur[1:]
                elif w[0] == cur[0]:
                    cur = w[::-1] + cur[1:]
                else:
                    continue
                ways.pop(i)
                changed = True
                break
        if cur[0] == cur[-1] and len(cur) >= 4:
            rings.append(cur)
    return rings


def polygons(e, eps):
    """An OSM way or multipolygon relation (out geom) -> list of [outer, hole, ...] point rings."""
    if e['type'] == 'way':
        g = e.get('geometry')
        if not g:
            return []
        r = clean([xy(p) for p in g], eps, True)
        return [[r]] if r else []
    outs, ins = [], []
    for m in e.get('members', []):
        if m.get('type') != 'way' or not m.get('geometry'):
            continue
        (ins if m.get('role') == 'inner' else outs).append([xy(p) for p in m['geometry'] if p])
    res = []
    holes = [h for h in (clean(r, eps, False) for r in join_ways(ins)) if h]
    for r in join_ways(outs):
        o = clean(r, eps, True)
        if not o:
            continue
        mine = [h for h in holes if inside(h[0][0], h[0][1], o)]
        res.append([o] + mine)
    return res


def height_of(t, rnd):
    h = None
    try:
        if 'height' in t:
            h = float(t['height'].replace('m', '').strip())
        elif 'building:levels' in t:
            h = float(t['building:levels'].split(';')[0]) * 3.4 + 2
    except ValueError:
        h = None
    kind = t.get('building', 'yes')
    if h is None:
        if kind in ('church', 'cathedral', 'basilica'):
            h = 26 + rnd.random() * 12
        elif kind in ('roof', 'kiosk', 'shed', 'ruins'):
            h = 4
        else:
            h = 14 + rnd.random() * 9
    return max(3, min(h, 140))


flat = lambda ring: [c for p in ring for c in p]


def main(src, out):
    rnd = random.Random(7)
    B = json.load(open(os.path.join(src, 'buildings.json')))['elements']
    V = json.load(open(os.path.join(src, 'venues.json')))['elements']
    W = json.load(open(os.path.join(src, 'ways.json')))['elements']
    X = json.load(open(os.path.join(src, 'extra.json')))['elements']
    L = json.load(open(os.path.join(src, 'labels.json')))['elements']

    blds = []
    for e in B + [x for x in X if x['type'] == 'relation' and 'building' in x.get('tags', {})]:
        t = e.get('tags', {})
        h = height_of(t, rnd)
        for poly in polygons(e, 0.7):
            blds.append({'r': poly, 'p': poly[0], 'h': round(h)})

    G = 60
    grid = {}
    for i, b in enumerate(blds):
        xs = [p[0] for p in b['p']]; ys = [p[1] for p in b['p']]
        b['bb'] = (min(xs), min(ys), max(xs), max(ys))
        for gx in range(min(xs) // G, max(xs) // G + 1):
            for gy in range(min(ys) // G, max(ys) // G + 1):
                grid.setdefault((gx, gy), []).append(i)

    def in_b(x, y, b):
        if not inside(x, y, b['r'][0]):
            return False
        return not any(inside(x, y, h) for h in b['r'][1:])

    def find_b(x, y):
        best, bd = -1, 1e9
        for gx in (x // G - 1, x // G, x // G + 1):
            for gy in (y // G - 1, y // G, y // G + 1):
                for i in grid.get((gx, gy), ()):
                    x0, y0, x1, y1 = blds[i]['bb']
                    if x0 <= x <= x1 and y0 <= y <= y1 and in_b(x, y, blds[i]):
                        return i
                    # nearest wall vertex, for places drawn on the pavement
                    for p in blds[i]['p']:
                        d = math.hypot(p[0] - x, p[1] - y)
                        if d < bd:
                            best, bd = i, d
        return best if bd < 18 else -1

    venues = []
    seen = set()
    for e in V:
        t = e.get('tags', {})
        p = {'lat': e['lat'], 'lon': e['lon']} if 'lat' in e else e.get('center')
        if not p:
            continue
        a = t.get('amenity')
        if a in CAT:
            c = CAT[a]
        elif 'shop' in t:
            c = 'shop'
        elif t.get('tourism') in CAT:
            c = CAT[t['tourism']]
        else:
            continue
        x, y = xy(p)
        name = t.get('name') or t.get('brand')
        if not name:
            continue
        key = (name, x // 4, y // 4)
        if key in seen:
            continue
        seen.add(key)
        sub = a or t.get('shop') or t.get('tourism') or ''
        info = {}
        if t.get('addr:street'):
            info['a'] = (t['addr:street'] + (' ' + t['addr:housenumber'] if t.get('addr:housenumber') else ''))[:48]
        if t.get('opening_hours'):
            info['h'] = t['opening_hours'][:60]
        if t.get('cuisine'):
            info['c'] = t['cuisine'].replace('_', ' ').replace(';', ', ')[:40]
        if t.get('stars'):
            info['s'] = t['stars'][:3]
        row = [x, y, c, name[:44], find_b(x, y), sub[:18]]
        if info:
            row.append(info)
        venues.append(row)

    roads = {'major': [], 'mid': [], 'minor': [], 'foot': []}
    cls = {'motorway': 'major', 'trunk': 'major', 'primary': 'major', 'secondary': 'mid', 'tertiary': 'mid',
           'residential': 'minor', 'unclassified': 'minor', 'living_street': 'minor', 'service': 'minor',
           'pedestrian': 'foot', 'footway': 'foot'}
    river = []
    for e in W:
        g = e.get('geometry')
        if not g or len(g) < 2:
            continue
        t = e.get('tags', {})
        if 'highway' in t and t.get('area') != 'yes':
            k = cls.get(t['highway'])
            if k == 'minor' and t['highway'] == 'service' and t.get('service') in ('parking_aisle', 'driveway'):
                continue
            if k:
                roads[k].append(flat(simplify([xy(p) for p in g], 1.0)))
        elif t.get('waterway') == 'river':
            river.append(flat(simplify([xy(p) for p in g], 1.2)))

    areas = {'park': [], 'water': [], 'square': []}
    for e in X + [w for w in W if w.get('tags', {}).get('natural') == 'water' or w.get('tags', {}).get('leisure') == 'park']:
        t = e.get('tags', {})
        if 'building' in t:
            continue
        if t.get('natural') == 'water' or t.get('waterway') == 'riverbank':
            k = 'water'
        elif t.get('leisure') in ('park', 'garden', 'pitch') or t.get('landuse') in ('grass', 'forest', 'recreation_ground'):
            k = 'park'
        elif t.get('place') == 'square' or t.get('area') == 'yes':
            k = 'square'
        else:
            continue
        for poly in polygons(e, 1.5):
            if k == 'park' and abs(area(poly[0])) < 150:
                continue
            areas[k].append([flat(r) for r in poly])

    labels = []
    seenl = set()
    for e in L:
        t = e.get('tags', {})
        p = {'lat': e['lat'], 'lon': e['lon']} if 'lat' in e else e.get('center')
        n = t.get('name:it') or t.get('name')
        if not p or not n or n in seenl:
            continue
        if t.get('place') in ('quarter', 'neighbourhood', 'suburb'):
            k = 0
            n = n.split(' - ')[0]
        elif t.get('place') == 'square':
            k = 2
        else:
            k = 1
        x, y = xy(p)
        seenl.add(n)
        labels.append([x, y, n[:36], k])

    # bounds from the dense core only
    bxs = sorted(b['bb'][0] for b in blds); bys = sorted(b['bb'][1] for b in blds)
    bxe = sorted(b['bb'][2] for b in blds); bye = sorted(b['bb'][3] for b in blds)
    data = {
        'origin': [LAT0, LON0],
        'bounds': [bxs[0], bys[0], bxe[-1], bye[-1]],
        'b': [[b['h']] + [flat(r) for r in b['r']] for b in blds],
        'v': venues,
        'roads': roads, 'river': river, 'areas': areas, 'labels': labels,
        'credit': '© OpenStreetMap contributors, ODbL',
    }
    os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
    with open(out, 'w') as f:
        json.dump(data, f, separators=(',', ':'), ensure_ascii=False)
    print('buildings', len(blds), 'with courtyards', sum(1 for b in blds if len(b['r']) > 1), 'venues', len(venues),
          'in-building', sum(1 for v in venues if v[4] >= 0), 'areas', {k: len(v) for k, v in areas.items()},
          'labels', len(labels), 'bytes', os.path.getsize(out))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
