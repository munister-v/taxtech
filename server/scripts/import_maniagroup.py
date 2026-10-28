"""Підтягує каталог maniagroup.com.ua (WooCommerce) у магазин «munister».

Читає сторінки вітрини /shop/page/N/ (назва, ціна, фото, посилання), робить
upsert у marketplace_products за slug `mania-<sku>`. Ціни у гривнях, валюта
магазину TAX 1:1. Запуск (із теки server/):
    .venv/bin/python scripts/import_maniagroup.py --pages 25 [--replace-demo]
--replace-demo ховає (is_active=0) товари, які не з maniagroup.
"""
from __future__ import annotations

import argparse
import html
import re
import sys
import ssl
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.database import get_connection  # noqa: E402
from backend.routes.marketplace_routes import _ensure_schema  # noqa: E402

BASE = 'https://maniagroup.com.ua'
ITEM = re.compile(r'<li class="product .*?</li>', re.S)


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={'User-Agent': 'munister-shop-import/1.0'})
    try:
        import certifi
        ctx = ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=30, context=ctx) as r:
        return r.read().decode('utf-8', 'replace')


def parse(page_html: str) -> list[dict]:
    out = []
    for block in ITEM.findall(page_html):
        m_link = re.search(r'href="(https://maniagroup\.com\.ua/product/sku/(\d+)/)"', block)
        m_title = re.search(r'loop-product__title">(.*?)</h2>', block, re.S)
        m_price = re.search(r'<bdi>([\d,\.]+)', block)
        m_img = re.search(r'<img[^>]+src="([^"]+)"', block)
        if not (m_link and m_title and m_price and m_img):
            continue
        img = re.sub(r'-\d+x\d+(\.\w+)$', r'\1', m_img.group(1))
        out.append({
            'sku': m_link.group(2),
            'title': html.unescape(re.sub(r'<[^>]+>', '', m_title.group(1))).strip()[:160],
            'price': float(m_price.group(1).replace(',', '')),
            'image': img,
            'url': m_link.group(1),
        })
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--pages', type=int, default=25)
    ap.add_argument('--replace-demo', action='store_true')
    args = ap.parse_args()
    _ensure_schema()
    items: list[dict] = []
    for n in range(1, args.pages + 1):
        try:
            batch = parse(fetch(f'{BASE}/shop/' if n == 1 else f'{BASE}/shop/page/{n}/'))
        except Exception as exc:  # noqa: BLE001
            print(f'сторінка {n}: {exc}')
            break
        if not batch:
            break
        items += batch
    with get_connection() as conn:
        for it in items:
            slug = f"mania-{it['sku']}"
            row = conn.execute('SELECT id FROM marketplace_products WHERE slug = %s', (slug,)).fetchone()
            desc = f"maniagroup.com.ua · арт. {it['sku']}"
            if row:
                conn.execute(
                    'UPDATE marketplace_products SET title=%s, description=%s, price=%s, image_url=%s, image_credit=%s, is_active=TRUE, updated_at=CURRENT_TIMESTAMP WHERE slug=%s',
                    (it['title'], desc, it['price'], it['image'], 'Фото: maniagroup.com.ua', slug))
            else:
                conn.execute(
                    "INSERT INTO marketplace_products (slug, title, description, price, currency, image_emoji, stock, is_active, image_url, image_credit) VALUES (%s,%s,%s,%s,'TAX','🛍️',10,TRUE,%s,%s)",
                    (slug, it['title'], desc, it['price'], it['image'], 'Фото: maniagroup.com.ua'))
        if args.replace_demo:
            conn.execute("UPDATE marketplace_products SET is_active = FALSE WHERE slug NOT LIKE 'mania-%'")
    print(f'імпортовано {len(items)} товарів')


if __name__ == '__main__':
    main()
