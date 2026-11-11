#!/usr/bin/env python3
"""Derives server/backend/assets/rome_city.json from web/src/city/rome.json for the server-side city (city_service.py).

Venue ids are their index in rome.json "v", so the map and the server name the same place by the same number.
Usage: python3 -I web/scripts/build-city-server.py web/src/city/rome.json server/backend/assets/rome_city.json
"""
import json, random, sys

src, out = sys.argv[1], sys.argv[2]
D = json.load(open(src))
rioni = [l for l in D['labels'] if l[3] == 0]


def rione(x, y):
    best, bd = '', 1e18
    for l in rioni:
        d = (l[0] - x) ** 2 + (l[1] - y) ** 2
        if d < bd:
            best, bd = l[2], d
    return best


shop_b = {v[4] for v in D['v']}
homes = []
for i, b in enumerate(D['b']):
    if i in shop_b:
        continue
    r = b[1]
    n = len(r) // 2
    homes.append([round(sum(r[0::2]) / n), round(sum(r[1::2]) / n)])
random.Random(11).shuffle(homes)
data = {
    'venues': [[v[0], v[1], v[2], v[3], rione(v[0], v[1])] for v in D['v']],
    'homes': homes[:3000],
    'bounds': D['bounds'],
}
json.dump(data, open(out, 'w'), separators=(',', ':'), ensure_ascii=False)
print('venues', len(data['venues']), 'homes', len(data['homes']))
