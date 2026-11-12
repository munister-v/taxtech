#!/usr/bin/env python3
"""Grows the Roma Live map without renumbering it.

Usage: python3 -I merge-city.py <old rome.json> <new rome.json from build-city.py on a bigger bbox> <out rome.json>

Building and venue ids are their index: payments, QR invoices and client shops (city_shops.b) point at them. So the old
extract keeps every index, and only what lies outside its bbox (12.452-12.501, 41.886-41.911) is appended from the new
build: buildings whose centre is outside (a building that straddles the old edge and is already there is skipped), the
venues outside, pointed at the merged building list. Roads, river, areas, labels and bounds come from the new build.
Outer buildings lose their courtyards and the smallest sheds: the outer ring is seen from afar.
"""
import json, math, sys

LAT0, LON0 = 41.8985, 12.4765
KX = 111320 * math.cos(math.radians(LAT0))
KY = 110540
OLD = ((12.4520 - LON0) * KX, (41.8860 - LAT0) * KY, (12.5010 - LON0) * KX, (41.9110 - LAT0) * KY)


def centre(ring):
    n = len(ring) // 2
    return sum(ring[0::2]) / n, sum(ring[1::2]) / n


def area(ring):
    s = 0.0
    n = len(ring) // 2
    for i in range(n):
        x1, y1 = ring[2 * i], ring[2 * i + 1]
        x2, y2 = ring[(2 * i + 2) % (2 * n)], ring[(2 * i + 3) % (2 * n)]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2


def in_old(x, y):
    return OLD[0] <= x <= OLD[2] and OLD[1] <= y <= OLD[3]


def main(old_p, new_p, out_p):
    A = json.load(open(old_p))
    B = json.load(open(new_p))
    nb_old = len(A['b'])
    # old building centres on a grid, to catch the ones that straddle the old edge
    G = 20
    grid = {}
    for i, b in enumerate(A['b']):
        cx, cy = centre(b[1])
        grid.setdefault((int(cx // G), int(cy // G)), []).append((cx, cy, i))

    def twin(cx, cy):
        for gx in (int(cx // G) - 1, int(cx // G), int(cx // G) + 1):
            for gy in (int(cy // G) - 1, int(cy // G), int(cy // G) + 1):
                for x, y, i in grid.get((gx, gy), ()):
                    if math.hypot(x - cx, y - cy) < 2.5:
                        return i
        return -1

    blds = list(A['b'])
    remap = {}
    dropped = 0
    for j, b in enumerate(B['b']):
        cx, cy = centre(b[1])
        if in_old(cx, cy):
            t = twin(cx, cy)
            remap[j] = t
            continue
        t = twin(cx, cy)
        if t >= 0:
            remap[j] = t
            continue
        if area(b[1]) < 40:
            remap[j] = -1
            dropped += 1
            continue
        remap[j] = len(blds)
        blds.append([b[0], b[1]])          # no courtyards out here

    venues = list(A['v'])
    added_v = 0
    for v in B['v']:
        if in_old(v[0], v[1]):
            continue
        row = list(v)
        row[4] = remap.get(v[4], -1) if v[4] >= 0 else -1
        venues.append(row)
        added_v += 1

    out = dict(B)
    # a kind of area the new dumps lack (a failed download) keeps the old one
    out['areas'] = {k: (B['areas'].get(k) or A['areas'].get(k, [])) for k in set(A['areas']) | set(B['areas'])}
    out['b'] = blds
    out['v'] = venues
    xs = [B['bounds'][0], B['bounds'][2], A['bounds'][0], A['bounds'][2]]
    ys = [B['bounds'][1], B['bounds'][3], A['bounds'][1], A['bounds'][3]]
    out['bounds'] = [min(xs), min(ys), max(xs), max(ys)]
    json.dump(out, open(out_p, 'w'), separators=(',', ':'), ensure_ascii=False)
    print('buildings', nb_old, '->', len(blds), '(dropped small', dropped, ') venues', len(A['v']), '->', len(venues),
          'bounds', out['bounds'])


if __name__ == '__main__':
    main(*sys.argv[1:4])
