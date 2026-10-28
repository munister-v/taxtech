"""Підтягує каталог магазину munister (shop.munister.com.ua) у магазин застосунку.

Читає публічний фід /feed/google.xml (назва, ціна, фото, бренд, категорія) і
робить upsert у marketplace_products за slug `munister-<id>`. Ціни у гривнях,
валюта застосунку TAX 1:1. Запуск (із теки server/):
    .venv/bin/python scripts/import_munister_shop.py [--replace-demo]
--replace-demo ховає (is_active=FALSE) усе, що не з munister.
"""
from __future__ import annotations

import argparse
import ssl
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.database import get_connection  # noqa: E402
from backend.routes.marketplace_routes import _ensure_schema  # noqa: E402

FEED = 'https://shop.munister.com.ua/feed/google.xml'
G = '{http://base.google.com/ns/1.0}'


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={'User-Agent': 'munister-app-import/1.0'})
    try:
        import certifi
        ctx = ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=120, context=ctx) as r:
        return r.read()


def parse(xml: bytes) -> list[dict]:
    out = []
    for item in ET.fromstring(xml).iter('item'):
        link = (item.findtext('link') or '').rstrip('/')
        price = (item.findtext(G + 'price') or '').split()[0] if item.findtext(G + 'price') else ''
        image = item.findtext(G + 'image_link') or ''
        title = (item.findtext('title') or '').strip()
        if not (link and price and image and title) or item.findtext(G + 'availability') != 'in_stock':
            continue
        out.append({
            'id': link.rsplit('/', 1)[-1],
            'title': title[:160],
            'price': float(price),
            'image': image,
            'brand': (item.findtext(G + 'brand') or '').strip(),
            'type': (item.findtext(G + 'product_type') or '').strip(),
        })
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--replace-demo', action='store_true')
    args = ap.parse_args()
    _ensure_schema()
    items = parse(fetch(FEED))
    if not items:
        sys.exit('фід порожній, базу не чіпаю')
    seen = set()
    with get_connection() as conn:
        for it in items:
            slug = f"munister-{it['id']}"
            seen.add(slug)
            desc = ' · '.join(x for x in (it['brand'], it['type']) if x)
            row = conn.execute('SELECT id FROM marketplace_products WHERE slug = %s', (slug,)).fetchone()
            if row:
                conn.execute(
                    'UPDATE marketplace_products SET title=%s, description=%s, price=%s, image_url=%s, image_credit=%s, is_active=TRUE, updated_at=CURRENT_TIMESTAMP WHERE slug=%s',
                    (it['title'], desc, it['price'], it['image'], 'munister', slug))
            else:
                conn.execute(
                    "INSERT INTO marketplace_products (slug, title, description, price, currency, image_emoji, stock, is_active, image_url, image_credit) VALUES (%s,%s,%s,%s,'TAX','🛍️',10,TRUE,%s,%s)",
                    (slug, it['title'], desc, it['price'], it['image'], 'munister'))
        # що зникло з фіду (розпродано) — ховаємо
        for r in conn.execute("SELECT slug FROM marketplace_products WHERE slug LIKE 'munister-%' AND is_active = TRUE").fetchall() or []:
            if r['slug'] not in seen:
                conn.execute('UPDATE marketplace_products SET is_active = FALSE WHERE slug = %s', (r['slug'],))
        if args.replace_demo:
            conn.execute("UPDATE marketplace_products SET is_active = FALSE WHERE slug NOT LIKE 'munister-%'")
    print(f'імпортовано {len(items)} товарів')


if __name__ == '__main__':
    main()
