#!/usr/bin/env python3
"""Builds web/public/city/rome.json for the Roma Live map (CityLive.tsx) from OpenStreetMap Overpass dumps.

Usage: python3 -I build-city.py <dir with buildings.json venues.json ways.json> <out.json>  (web/src/city/rome.json)

The three dumps come from overpass-api.de for the bbox 41.8860,12.4520,41.9110,12.5010 (Vatican to the Colosseum):
  buildings.json  way["building"]                                   out geom
  venues.json     amenity / shop / tourism POIs                     out center tags
  ways.json       highway, river, water, parks                      out geom
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

def main(src, out):
    rnd = random.Random(7)
    B = json.load(open(os.path.join(src, 'buildings.json')))['elements']
    V = json.load(open(os.path.join(src, 'venues.json')))['elements']
    W = json.load(open(os.path.join(src, 'ways.json')))['elements']

    blds = []
    for e in B:
        g = e.get('geometry')
        if not g or len(g) < 4:
            continue
        pts = [xy(p) for p in g]
        if pts[0] == pts[-1]:
            pts = pts[:-1]
        # a closed ring: split at the vertex farthest from the first one and simplify both halves
        far = max(range(len(pts)), key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
        if far == 0:
            continue
        pts = simplify(pts[:far + 1], 0.8)[:-1] + simplify(pts[far:] + [pts[0]], 0.8)[:-1]
        dedup = []
        for p in pts:
            if not dedup or dedup[-1] != p:
                dedup.append(p)
        pts = dedup
        if len(pts) < 3:
            continue
        a = area(pts)
        if abs(a) < 12:
            continue
        if a < 0:
            pts.reverse()  # counter-clockwise
        t = e.get('tags', {})
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
            elif kind in ('roof', 'kiosk', 'shed'):
                h = 4
            else:
                h = 14 + rnd.random() * 9
        h = max(3, min(h, 140))
        blds.append({'p': pts, 'h': round(h), 'a': abs(a), 'n': t.get('name')})

    # spatial grid for point-in-building lookup
    G = 60
    grid = {}
    for i, b in enumerate(blds):
        xs = [p[0] for p in b['p']]; ys = [p[1] for p in b['p']]
        b['bb'] = (min(xs), min(ys), max(xs), max(ys))
        for gx in range(min(xs) // G, max(xs) // G + 1):
            for gy in range(min(ys) // G, max(ys) // G + 1):
                grid.setdefault((gx, gy), []).append(i)

    def find_b(x, y):
        best, bd = -1, 1e9
        for gx in (x // G - 1, x // G, x // G + 1):
            for gy in (y // G - 1, y // G, y // G + 1):
                for i in grid.get((gx, gy), ()):
                    x0, y0, x1, y1 = blds[i]['bb']
                    if x0 <= x <= x1 and y0 <= y <= y1 and inside(x, y, blds[i]['p']):
                        return i
                    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                    d = math.hypot(cx - x, cy - y)
                    if d < bd:
                        best, bd = i, d
        return best if bd < 35 else -1

    venues = []
    seen = set()
    for e in V:
        t = e.get('tags', {})
        if 'lat' in e:
            p = {'lat': e['lat'], 'lon': e['lon']}
        elif 'center' in e:
            p = e['center']
        else:
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
        bi = find_b(x, y)
        sub = a or t.get('shop') or t.get('tourism') or ''
        venues.append([x, y, c, name[:40], bi, sub[:18]])

    roads = {'major': [], 'mid': [], 'minor': [], 'foot': []}
    cls = {'motorway': 'major', 'trunk': 'major', 'primary': 'major', 'secondary': 'mid', 'tertiary': 'mid',
           'residential': 'minor', 'unclassified': 'minor', 'living_street': 'minor', 'service': 'minor',
           'pedestrian': 'foot', 'footway': 'foot'}
    water, parks, river = [], [], []
    for e in W:
        g = e.get('geometry')
        if not g or len(g) < 2:
            continue
        t = e.get('tags', {})
        pts = simplify([xy(p) for p in g], 1.2)
        flat = [c for p in pts for c in p]
        if 'highway' in t:
            k = cls.get(t['highway'])
            if k == 'minor' and t['highway'] == 'service' and t.get('service') in ('parking_aisle', 'driveway'):
                continue
            if k:
                roads[k].append(flat)
        elif t.get('waterway') == 'river':
            river.append(flat)
        elif t.get('natural') == 'water':
            if len(pts) > 3:
                water.append(flat)
        else:
            if len(pts) > 3 and abs(area(pts)) > 400:
                parks.append(flat)

    data = {
        'origin': [LAT0, LON0],
        'bounds': [min(b['bb'][0] for b in blds), min(b['bb'][1] for b in blds), max(b['bb'][2] for b in blds), max(b['bb'][3] for b in blds)],
        'b': [[b['h']] + [c for p in b['p'] for c in p] for b in blds],
        'v': venues,
        'roads': roads, 'river': river, 'water': water, 'parks': parks,
        'credit': '© OpenStreetMap contributors, ODbL',
    }
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w') as f:
        json.dump(data, f, separators=(',', ':'), ensure_ascii=False)
    print('buildings', len(blds), 'venues', len(venues), 'in-building', sum(1 for v in venues if v[4] >= 0),
          'roads', {k: len(v) for k, v in roads.items()}, 'river', len(river), 'parks', len(parks), 'bytes', os.path.getsize(out))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
