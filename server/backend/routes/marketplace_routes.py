"""Маршрути магазину навчального банку TaxTech."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

from flask import Blueprint, Response, g, jsonify, make_response, request, send_from_directory
from urllib.parse import quote

from ..database import get_connection, get_returning_id_suffix, insert_last_id
from ..services import shop_sync
from ..services.idempotency_service import IdempotencyService
from .helpers import api_error, auth_required, require_idempotency_key

marketplace_bp = Blueprint('marketplace', __name__, url_prefix='/api/marketplace')
idempotency_service = IdempotencyService()

# Фото товарів із Open Icecat (відкрита ліцензія) + атрибуція в manifest.json
PRODUCT_IMAGES_DIR = Path(__file__).resolve().parent.parent / 'assets' / 'products'


def _load_image_manifest() -> dict[str, Any]:
    try:
        with open(PRODUCT_IMAGES_DIR / 'manifest.json', encoding='utf-8') as f:
            return (json.load(f) or {}).get('items') or {}
    except (OSError, ValueError):
        return {}


APPROVED_CODE = '00'
INSUFFICIENT_FUNDS_CODE = '51'
INVALID_ACCOUNT_CODE = '14'
PROCESSING_ERROR_CODE = '96'


def _now_sql() -> str:
    from ..config import USE_PG
    return 'NOW()' if USE_PG else 'CURRENT_TIMESTAMP'


def _due_at_sql(hours: int = 24) -> str:
    from ..config import USE_PG
    if USE_PG:
        return f"NOW() + INTERVAL '{int(hours)} hours'"
    return f"datetime('now', '+{int(hours)} hours')"


def _safe_add_column(conn: Any, table: str, ddl: str) -> None:
    """Add column if not exists. Uses SAVEPOINTs in PostgreSQL to avoid
    leaving the transaction in an aborted state when the column already exists."""
    from ..config import USE_PG
    if USE_PG:
        try:
            conn.execute('SAVEPOINT _safe_add_col')
            conn.execute(f'ALTER TABLE {table} ADD COLUMN {ddl}')
            conn.execute('RELEASE SAVEPOINT _safe_add_col')
        except Exception:
            try:
                conn.execute('ROLLBACK TO SAVEPOINT _safe_add_col')
            except Exception:
                pass
    else:
        try:
            conn.execute(f'ALTER TABLE {table} ADD COLUMN {ddl}')
        except Exception:
            pass


def _dt(val: Any) -> str | None:
    """Serialize a datetime/date value to ISO-8601 string (safe for jsonify)."""
    if val is None:
        return None
    if hasattr(val, 'isoformat'):
        return val.isoformat()
    return str(val)


def _generate_invoice_number() -> str:
    stamp = datetime.utcnow().strftime('%Y%m%d%H%M')
    return f"INV-{stamp}-{uuid4().hex[:6].upper()}"


def _generate_auth_code() -> str:
    return f"AUTH-{uuid4().hex[:10].upper()}"


def _complete_idempotency_in_conn(
    conn: Any,
    *,
    user_id: int,
    action: str,
    key: str | None,
    response_payload: dict[str, Any],
    response_code: int,
) -> None:
    if not key:
        return
    conn.execute(
        """
        UPDATE api_idempotency
        SET status = 'completed',
            response_code = %s,
            response_payload = %s,
            updated_at = %s
        WHERE user_id = %s AND action = %s AND idempotency_key = %s
        """,
        (
            int(response_code),
            json.dumps(response_payload, ensure_ascii=False),
            datetime.now(timezone.utc).isoformat(),
            user_id,
            action,
            key,
        ),
    )


def _generate_unique_invoice_number(conn: Any) -> str:
    for _ in range(10):
        candidate = _generate_invoice_number()
        row = conn.execute(
            'SELECT id FROM marketplace_invoices WHERE invoice_number = %s LIMIT 1',
            (candidate,),
        ).fetchone()
        if not row:
            return candidate
    return f"INV-{datetime.utcnow().strftime('%Y%m%d%H%M')}-{uuid4().hex[:10].upper()}"


def _ensure_schema() -> None:
    now_sql = _now_sql()
    from ..config import USE_PG
    pk_sql = 'SERIAL PRIMARY KEY' if USE_PG else 'INTEGER PRIMARY KEY'
    due_sql = _due_at_sql(24) if USE_PG else 'CURRENT_TIMESTAMP'
    with get_connection() as conn:
        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS marketplace_products (
                id {pk_sql},
                slug VARCHAR(80) UNIQUE NOT NULL,
                title VARCHAR(160) NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                price NUMERIC(14,2) NOT NULL CHECK(price >= 0),
                currency VARCHAR(6) NOT NULL DEFAULT 'TAX',
                image_emoji VARCHAR(16) NOT NULL DEFAULT '🛍️',
                badge VARCHAR(40),
                stock INTEGER NOT NULL DEFAULT 0,
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP NOT NULL DEFAULT {now_sql},
                updated_at TIMESTAMP NOT NULL DEFAULT {now_sql}
            )
            """
        )
        conn.execute('CREATE INDEX IF NOT EXISTS idx_marketplace_products_active ON marketplace_products(is_active)')
        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS marketplace_orders (
                id {pk_sql},
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                total_amount NUMERIC(14,2) NOT NULL CHECK(total_amount >= 0),
                currency VARCHAR(6) NOT NULL DEFAULT 'TAX',
                status VARCHAR(20) NOT NULL DEFAULT 'paid',
                payment_mode VARCHAR(20) NOT NULL DEFAULT 'pay_now',
                invoice_number VARCHAR(40),
                invoice_status VARCHAR(20) NOT NULL DEFAULT 'paid',
                invoice_due_at TIMESTAMP,
                payment_tx_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
                shipping_name VARCHAR(160) NOT NULL DEFAULT '',
                shipping_phone VARCHAR(40) NOT NULL DEFAULT '',
                shipping_address TEXT NOT NULL DEFAULT '',
                note TEXT NOT NULL DEFAULT '',
                created_at TIMESTAMP NOT NULL DEFAULT {now_sql}
            )
            """
        )
        conn.execute('CREATE INDEX IF NOT EXISTS idx_marketplace_orders_user ON marketplace_orders(user_id, created_at)')
        conn.execute('CREATE INDEX IF NOT EXISTS idx_marketplace_orders_invoice_number ON marketplace_orders(invoice_number)')
        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS marketplace_order_items (
                id {pk_sql},
                order_id INTEGER NOT NULL REFERENCES marketplace_orders(id) ON DELETE CASCADE,
                product_id INTEGER REFERENCES marketplace_products(id) ON DELETE SET NULL,
                title VARCHAR(160) NOT NULL,
                price NUMERIC(14,2) NOT NULL,
                qty INTEGER NOT NULL CHECK(qty > 0),
                line_total NUMERIC(14,2) NOT NULL
            )
            """
        )
        conn.execute('CREATE INDEX IF NOT EXISTS idx_marketplace_items_order ON marketplace_order_items(order_id)')

        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS marketplace_invoices (
                id {pk_sql},
                invoice_number VARCHAR(40) UNIQUE NOT NULL,
                order_id INTEGER NOT NULL UNIQUE REFERENCES marketplace_orders(id) ON DELETE CASCADE,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                amount NUMERIC(14,2) NOT NULL CHECK(amount >= 0),
                currency VARCHAR(6) NOT NULL DEFAULT 'TAX',
                status VARCHAR(20) NOT NULL DEFAULT 'issued',
                due_at TIMESTAMP NOT NULL DEFAULT {due_sql},
                paid_at TIMESTAMP,
                payment_tx_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
                created_at TIMESTAMP NOT NULL DEFAULT {now_sql}
            )
            """
        )
        conn.execute('CREATE INDEX IF NOT EXISTS idx_marketplace_invoices_user ON marketplace_invoices(user_id, created_at)')
        conn.execute('CREATE INDEX IF NOT EXISTS idx_marketplace_invoices_status ON marketplace_invoices(status, due_at)')

        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS marketplace_payment_authorizations (
                id {pk_sql},
                authorization_code VARCHAR(40) UNIQUE NOT NULL,
                idempotency_key VARCHAR(128),
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                order_id INTEGER REFERENCES marketplace_orders(id) ON DELETE SET NULL,
                invoice_number VARCHAR(40),
                amount NUMERIC(14,2) NOT NULL CHECK(amount >= 0),
                currency VARCHAR(6) NOT NULL DEFAULT 'TAX',
                payment_network VARCHAR(20) NOT NULL DEFAULT 'TAX_PAY',
                merchant_id VARCHAR(40) NOT NULL DEFAULT 'TAXTECH-MARKET',
                merchant_name VARCHAR(80) NOT NULL DEFAULT 'TaxTech Market',
                status VARCHAR(20) NOT NULL DEFAULT 'authorized',
                response_code VARCHAR(8) NOT NULL DEFAULT '00',
                decline_reason TEXT,
                balance_before NUMERIC(14,2) NOT NULL DEFAULT 0,
                balance_after NUMERIC(14,2),
                payment_tx_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
                created_at TIMESTAMP NOT NULL DEFAULT {now_sql},
                captured_at TIMESTAMP,
                reversed_at TIMESTAMP
            )
            """
        )
        conn.execute(
            'CREATE INDEX IF NOT EXISTS idx_marketplace_payment_auth_user '
            'ON marketplace_payment_authorizations(user_id, created_at)'
        )
        conn.execute(
            'CREATE INDEX IF NOT EXISTS idx_marketplace_payment_auth_invoice '
            'ON marketplace_payment_authorizations(invoice_number)'
        )
        conn.execute(
            'CREATE INDEX IF NOT EXISTS idx_marketplace_payment_auth_status '
            'ON marketplace_payment_authorizations(status)'
        )

        # Backward-compatible migrations for old DBs
        _safe_add_column(conn, 'marketplace_orders', "payment_mode VARCHAR(20) NOT NULL DEFAULT 'pay_now'")
        _safe_add_column(conn, 'marketplace_orders', 'shop_ref VARCHAR(40)')
        _safe_add_column(conn, 'marketplace_orders', 'shop_synced INTEGER NOT NULL DEFAULT 0')
        _safe_add_column(conn, 'marketplace_orders', 'invoice_number VARCHAR(40)')
        _safe_add_column(conn, 'marketplace_orders', "invoice_status VARCHAR(20) NOT NULL DEFAULT 'paid'")
        _safe_add_column(conn, 'marketplace_orders', 'invoice_due_at TIMESTAMP')
        _safe_add_column(conn, 'marketplace_orders', 'payment_auth_id INTEGER')
        _safe_add_column(conn, 'marketplace_invoices', 'payment_auth_id INTEGER')
        _safe_add_column(conn, 'marketplace_products', 'image_url TEXT')
        _safe_add_column(conn, 'marketplace_products', 'image_credit TEXT')

        # Fix missing SERIAL/auto-increment on PostgreSQL (tables created without it).
        if USE_PG:
            for tbl in ('marketplace_products', 'marketplace_orders', 'marketplace_order_items', 'marketplace_invoices'):
                seq = f'{tbl}_id_seq'
                for stmt in [
                    f'CREATE SEQUENCE IF NOT EXISTS {seq}',
                    f"ALTER TABLE {tbl} ALTER COLUMN id SET DEFAULT nextval('{seq}')",
                    f"SELECT setval('{seq}', COALESCE((SELECT MAX(id) FROM {tbl}), 0) + 1, false)",
                ]:
                    try:
                        conn.execute('SAVEPOINT _seq_fix')
                        conn.execute(stmt)
                        conn.execute('RELEASE SAVEPOINT _seq_fix')
                    except Exception:
                        try:
                            conn.execute('ROLLBACK TO SAVEPOINT _seq_fix')
                        except Exception:
                            pass

        products = [
            # Тільки справжні моделі відомих брендів; вигадані товари не тримаємо.
            # Смартфони
            ('real-iphone-16-pro-256', 'Apple iPhone 16 Pro 256GB', 'Чіп A18 Pro, камера 48MP з 5× оптичним зумом, titanium корпус', 62999.00, '📱', 'TOP', 14),
            ('real-iphone-16-128', 'Apple iPhone 16 128GB', 'Чіп A18, камера з підтримкою Camera Control', 42999.00, '📱', 'HOT', 22),
            ('real-iphone-15-256', 'Apple iPhone 15 256GB', 'Dynamic Island, USB-C, камера 48MP', 38999.00, '📱', 'SALE', 17),
            ('real-samsung-s25-ultra', 'Samsung Galaxy S25 Ultra 256GB', 'Snapdragon 8 Elite, вбудований S Pen, камера 200MP', 54999.00, '📱', 'TOP', 12),
            ('real-samsung-s25-128', 'Samsung Galaxy S25 128GB', '7-річні оновлення, Galaxy AI, тонкий корпус', 38999.00, '📱', 'NEW', 19),
            ('real-samsung-a55-256', 'Samsung Galaxy A55 5G 256GB', 'AMOLED 120Hz, захист IP67, камера 50MP', 17999.00, '📱', None, 35),
            ('real-google-pixel-9-pro', 'Google Pixel 9 Pro 128GB', 'Tensor G4, Magic Eraser, Gemini AI', 42999.00, '📱', 'HOT', 13),
            ('real-xiaomi-14t-pro', 'Xiaomi 14T Pro 256GB', 'Leica оптика, Dimensity 9300+, зарядка 120W', 26999.00, '📱', 'SALE', 21),
            ('real-xiaomi-redmi-14pro', 'Xiaomi Redmi Note 14 Pro+ 5G 256GB', 'AMOLED 120Hz, 50MP OIS, акумулятор 6200mAh', 11999.00, '📱', None, 44),
            ('real-oneplus-13-512', 'OnePlus 13 512GB', 'Snapdragon 8 Elite, зарядка 100W, Hasselblad камера', 32999.00, '📱', 'DEAL', 16),
            ('real-samsung-zfold6', 'Samsung Galaxy Z Fold 6 256GB', 'Складаний смартфон, 7.6" внутрішній дисплей', 69999.00, '📱', 'TOP', 7),

            # Ноутбуки
            ('real-macbook-air-m3-13', 'Apple MacBook Air 13" M3 16/256GB', 'Чіп M3, 18 год. автономності, Liquid Retina дисплей', 48999.00, '💻', 'TOP', 11),
            ('real-macbook-pro-m3-14', 'Apple MacBook Pro 14" M3 Pro 18/512GB', 'Чіп M3 Pro, ProRes відео, Liquid Retina XDR', 89999.00, '💻', 'PRO', 6),
            ('real-asus-zenbook-14-oled', 'ASUS ZenBook 14 OLED 32/1TB', 'OLED 2.8K дисплей, Intel Core Ultra 7, 1.37 кг', 34999.00, '💻', 'NEW', 15),
            ('real-lenovo-thinkpad-x1', 'Lenovo ThinkPad X1 Carbon 32/1TB', 'Корпоративний ультрабук, 14" IPS, сертифікований MIL-SPEC', 67999.00, '💻', None, 8),
            ('real-hp-spectre-x360', 'HP Spectre x360 14 16/1TB', 'Трансформер 2-в-1, OLED дисплей, Intel Evo', 58999.00, '💻', 'HOT', 9),
            ('real-dell-xps-15-9530', 'Dell XPS 15 9530 32/1TB', 'OLED 3.5K дисплей, Intel Core i9, GeForce RTX', 74999.00, '💻', 'PRO', 7),
            ('real-asus-rog-g14', 'ASUS ROG Zephyrus G14 32/1TB', 'AMD Ryzen 9 + RX 7900S, OLED 165Hz, ігровий', 69999.00, '🎮', 'HOT', 8),
            ('real-lenovo-legion-5pro', 'Lenovo Legion 5 Pro 32/1TB', 'Ryzen 7 7745HX, RTX 4070, 165Hz IPS', 58999.00, '🎮', 'DEAL', 11),
            ('real-msi-raider-ge78', 'MSI Raider GE78 HX 32/2TB', 'Intel Core i9, RTX 4090, 240Hz QHD+', 109999.00, '🎮', 'TOP', 4),

            # Планшети
            ('real-ipad-air-m2-11', 'Apple iPad Air 11" M2 128GB Wi-Fi', 'Чіп M2, Liquid Retina, Apple Pencil Pro сумісний', 28999.00, '📲', 'NEW', 16),
            ('real-ipad-pro-m4-13', 'Apple iPad Pro 13" M4 256GB Wi-Fi', 'Надтонкий OLED дисплей, чіп M4, Magic Keyboard', 62999.00, '📲', 'TOP', 9),
            ('real-samsung-tab-s10', 'Samsung Galaxy Tab S10 256GB', 'DeX режим, AMOLED 120Hz, S Pen у комплекті', 28999.00, '📲', 'HOT', 14),
            ('real-xiaomi-pad-6spro', 'Xiaomi Pad 6S Pro 256GB', 'Snapdragon 8 Gen 2, 144Hz IPS, зарядка 67W', 19999.00, '📲', 'SALE', 18),

            # Навушники
            ('real-airpods-pro-2', 'Apple AirPods Pro 2', 'ANC, Adaptive Audio, USB-C кейс, Lossless', 9499.00, '🎧', 'TOP', 28),
            ('real-airpods-4', 'Apple AirPods 4', 'ANC версія, USB-C, Personalized Spatial Audio', 4999.00, '🎧', 'NEW', 37),
            ('real-sony-wh1000xm5', 'Sony WH-1000XM5', 'Найкращий ANC у класі, 30 год. автономності, LDAC', 9999.00, '🎧', 'HOT', 21),
            ('real-samsung-buds3-pro', 'Samsung Galaxy Buds3 Pro', 'Hi-Fi звук, ANC, відкритий дизайн', 6999.00, '🎧', 'DEAL', 24),
            ('real-bose-qc45', 'Bose QuietComfort 45', 'Преміальний ANC, комфортна посадка, 24 год.', 8999.00, '🎧', 'SALE', 19),
            ('real-sony-wf1000xm5', 'Sony WF-1000XM5', 'Найкращі TWS навушники з ANC 2024', 7499.00, '🎧', None, 22),

            # Смарт-годинники
            ('real-applewatch-s10-41', 'Apple Watch Series 10 41mm', 'Найтонший Apple Watch, великий дисплей, sleep apnea', 15999.00, '⌚', 'NEW', 18),
            ('real-applewatch-ultra2', 'Apple Watch Ultra 2', 'Titanium, GPS L1/L5, до 60 год. з оптимізацією', 29999.00, '⌚', 'TOP', 10),
            ('real-samsung-watch7-44', 'Samsung Galaxy Watch 7 44mm', 'BioActive сенсор, body composition, Wear OS', 8999.00, '⌚', 'HOT', 23),
            ('real-garmin-fenix8-47', 'Garmin Fenix 8 47mm', 'AMOLED, multi-sport GPS, підводний до 100м', 29999.00, '⌚', 'PRO', 8),

            # Телевізори
            ('real-lg-oled-c4-55', 'LG OLED C4 55"', 'OLED evo, 4K 120Hz, Dolby Vision IQ, webOS 24', 49999.00, '📺', 'TOP', 11),
            ('real-samsung-qled-65-8k', 'Samsung Neo QLED 8K 65"', 'Quantum Matrix Pro, 8K AI Upscaling, 120Hz', 119999.00, '📺', 'PRO', 3),
            ('real-sony-bravia7-65', 'Sony Bravia 7 65" QLED', 'XR Processor, Bravia Acoustic Multi-Audio, Google TV', 59999.00, '📺', 'HOT', 7),
            ('real-philips-oled908-55', 'Philips OLED908 55" Ambilight', 'OLED 120Hz з 4-стороннім Ambilight, P5 AI', 59999.00, '📺', 'NEW', 9),

            # Побутова техніка
            ('real-dyson-v15-detect', 'Dyson V15 Detect Absolute', 'Лазерне виявлення пилу, HEPA фільтр, 60 хв.', 25999.00, '🧹', 'TOP', 13),
            ('real-dyson-v10-motorhead', 'Dyson Cyclone V10 Motorhead', 'Потужний, 60 хв., 14 насадок', 17999.00, '🧹', 'SALE', 16),
            ('real-roborock-s8-maxv', 'Roborock S8 MaxV Ultra', 'LiDAR + камера, самоочисна станція, FlexiArm', 29999.00, '🤖', 'HOT', 9),
            ('real-irobot-j9plus', 'iRobot Roomba j9+', 'Auto-Empty Base, Smart Map, Clean Base', 24999.00, '🤖', 'DEAL', 11),
            ('real-philips-airfryer5000', 'Philips AirFryer 5000 XL 6.2L', 'Rapid Air, NutriU рецепти, 6 пресетів', 4999.00, '🍟', 'NEW', 29),
            ('real-delonghi-magnifica', 'De\'Longhi Magnifica Evo', 'Автоматична кавомашина з кавомолкою', 21999.00, '☕', 'TOP', 12),
            ('real-nespresso-vertuo-next', 'Nespresso Vertuo Next', 'Centrifusion технологія, 5 розмірів кави', 7499.00, '☕', 'SALE', 24),
            ('real-kitchenaid-artisan', 'KitchenAid Artisan 5KSM175', 'Планетарний міксер 4.8л, 10 швидкостей', 24999.00, '🍳', 'PRO', 10),
            ('real-tefal-gv9710', 'Tefal Express Anti-Calc GV9710', 'Перукарня з системою Calc Collector', 8499.00, '🧺', 'HOT', 17),
            ('real-bosch-washer-9kg', 'Bosch Serie 6 WAU28UH2 9kg', 'A-клас, EcoSilence мотор, i-DOS автодозатор', 23999.00, '🧺', 'NEW', 8),
            ('real-lg-puricare-360', 'LG PuriCare 360° Air Purifier', 'True HEPA H13, CADR 360, ультрафіолетова лампа', 13999.00, '🌫️', None, 15),
        ]
        suffix = get_returning_id_suffix()
        existing_rows = conn.execute('SELECT slug FROM marketplace_products').fetchall()
        existing_slugs = {str(row.get('slug') or '') for row in (existing_rows or [])}
        for slug, title, description, price, emoji, badge, stock in products:
            if slug in existing_slugs:
                continue
            conn.execute(
                """
                INSERT INTO marketplace_products
                (slug, title, description, price, currency, image_emoji, badge, stock, is_active, created_at, updated_at)
                VALUES (%s, %s, %s, %s, 'TAX', %s, %s, %s, TRUE, """
                + now_sql
                + ", "
                + now_sql
                + ")"
                + suffix,
                (slug, title, description, float(price), emoji, badge, int(stock)),
            )
        # Вигадані «TaxTech»-товари більше не продаємо: лишаємо тільки справжні моделі.
        conn.execute("DELETE FROM marketplace_products WHERE slug LIKE 'arm-%'")
        # Фото лише там, де Open Icecat знає точну модель; решта лишається без фото.
        for slug, item in _load_image_manifest().items():
            conn.execute(
                'UPDATE marketplace_products SET image_url = %s, image_credit = %s WHERE slug = %s',
                (f"/api/marketplace/images/{item['file']}", item.get('credit'), slug),
            )


def _expire_overdue_invoices(conn: Any) -> None:
    expired = conn.execute(
        """
        SELECT i.id, i.order_id
        FROM marketplace_invoices i
        JOIN marketplace_orders o ON o.id = i.order_id
        WHERE i.status = 'issued'
          AND o.status = 'awaiting_payment'
          AND i.due_at < """
        + _now_sql() +
        """
        """
    ).fetchall()
    if not expired:
        return

    for row in expired:
        order_id = int(row['order_id'])
        items = conn.execute(
            'SELECT product_id, qty FROM marketplace_order_items WHERE order_id = %s',
            (order_id,),
        ).fetchall()
        for item in items or []:
            pid = int(item.get('product_id') or 0)
            qty = int(item.get('qty') or 0)
            if pid > 0 and qty > 0:
                conn.execute(
                    'UPDATE marketplace_products SET stock = stock + %s, updated_at = ' + _now_sql() + ' WHERE id = %s',
                    (qty, pid),
                )

        conn.execute(
            "UPDATE marketplace_orders SET status = 'invoice_expired', invoice_status = 'expired' WHERE id = %s",
            (order_id,),
        )
        conn.execute(
            "UPDATE marketplace_invoices SET status = 'expired' WHERE id = %s",
            (int(row['id']),),
        )


def _dt_str(v: Any) -> str | None:
    """Convert datetime / date objects to ISO string; pass strings through."""
    if v is None:
        return None
    if hasattr(v, 'isoformat'):
        return v.isoformat()
    return str(v)


def _to_payload_product(row: dict[str, Any]) -> dict[str, Any]:
    slug = row.get('slug', '')
    image_url = row.get('image_url')

    return {
        'id': int(row['id']),
        'slug': slug,
        'title': row['title'],
        'description': row['description'],
        'price': float(row['price'] or 0),
        'currency': row.get('currency') or 'TAX',
        'image_emoji': row.get('image_emoji') or '🛍️',
        'image_url': image_url,
        'image_credit': row.get('image_credit') if image_url else None,
        'badge': row.get('badge'),
        'stock': int(row.get('stock') or 0),
    }


def _to_payload_order(row: dict[str, Any]) -> dict[str, Any]:
    return {
        'id': int(row['id']),
        'total_amount': float(row.get('total_amount') or 0),
        'currency': row.get('currency') or 'TAX',
        'status': row.get('status') or 'paid',
        'payment_mode': row.get('payment_mode') or 'pay_now',
        'invoice_number': row.get('invoice_number'),
        'invoice_status': row.get('invoice_status') or 'paid',

        'invoice_due_at': _dt(row.get('invoice_due_at')),
        'created_at': _dt(row.get('created_at')),
        'invoice_due_at': _dt_str(row.get('invoice_due_at')),
        'created_at': _dt_str(row.get('created_at')),
        'items_count': int(row.get('items_count') or 0),
    }


def _auth_payload(row: dict[str, Any] | None) -> dict[str, Any] | None:
    if not row:
        return None
    return {
        'id': int(row.get('id') or 0),
        'authorization_code': row.get('authorization_code'),
        'payment_network': row.get('payment_network') or 'TAX_PAY',
        'merchant_id': row.get('merchant_id') or 'TAXTECH-MARKET',
        'merchant_name': row.get('merchant_name') or 'TaxTech Market',
        'status': row.get('status') or 'authorized',
        'response_code': row.get('response_code') or APPROVED_CODE,
        'decline_reason': row.get('decline_reason'),
        'amount': float(row.get('amount') or 0),
        'currency': row.get('currency') or 'TAX',
        'balance_before': float(row.get('balance_before') or 0),
        'balance_after': (
            None if row.get('balance_after') is None else float(row.get('balance_after') or 0)
        ),
        'payment_tx_id': int(row.get('payment_tx_id') or 0),

        'created_at': _dt(row.get('created_at')),
        'captured_at': _dt(row.get('captured_at')),
        'reversed_at': _dt(row.get('reversed_at')),
        'created_at': _dt_str(row.get('created_at')),
        'captured_at': _dt_str(row.get('captured_at')),
        'reversed_at': _dt_str(row.get('reversed_at')),
    }


def _select_authorization(conn: Any, auth_id: int | None = None, auth_code: str | None = None) -> dict[str, Any] | None:
    if auth_id:
        row = conn.execute(
            'SELECT * FROM marketplace_payment_authorizations WHERE id = %s LIMIT 1',
            (int(auth_id),),
        ).fetchone()
    elif auth_code:
        row = conn.execute(
            'SELECT * FROM marketplace_payment_authorizations WHERE authorization_code = %s LIMIT 1',
            (str(auth_code),),
        ).fetchone()
    else:
        row = None
    return dict(row) if row else None


def _create_declined_authorization(
    conn: Any,
    *,
    user_id: int,
    account: dict[str, Any],
    amount: float,
    invoice_number: str,
    response_code: str,
    decline_reason: str,
    idempotency_key: str | None = None,
    payment_network: str = 'TAX_PAY',
) -> dict[str, Any]:
    suffix = get_returning_id_suffix()
    auth_code = _generate_auth_code()
    cur = conn.execute(
        """
        INSERT INTO marketplace_payment_authorizations
        (authorization_code, idempotency_key, user_id, account_id, invoice_number, amount, currency,
         payment_network, status, response_code, decline_reason, balance_before)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'declined', %s, %s, %s)
        """
        + suffix,
        (
            auth_code,
            idempotency_key,
            user_id,
            int(account.get('id') or 0),
            invoice_number,
            float(amount),
            str(account.get('currency') or 'TAX'),
            payment_network,
            response_code,
            decline_reason,
            float(account.get('balance') or 0),
        ),
    )
    auth_id = insert_last_id(cur)
    return _select_authorization(conn, auth_id=int(auth_id or 0)) or {'id': auth_id, 'authorization_code': auth_code}


def _authorize_and_capture_payment(
    conn: Any,
    *,
    user_id: int,
    account: dict[str, Any],
    amount: float,
    invoice_number: str,
    tx_type: str,
    description: str,
    order_id: int | None = None,
    idempotency_key: str | None = None,
    payment_network: str = 'TAX_PAY',
) -> dict[str, Any]:
    """Authorize and capture one marketplace payment.

    Mirrors card processing semantics:
    1. authorization record gets approved/declined response code;
    2. approved authorization is captured by atomic account debit;
    3. failed capture reverses the authorization instead of leaving a paid order.
    """
    if amount <= 0:
        auth = _create_declined_authorization(
            conn,
            user_id=user_id,
            account=account,
            amount=amount,
            invoice_number=invoice_number,
            response_code=PROCESSING_ERROR_CODE,
            decline_reason='Некоректна сума платежу.',
            idempotency_key=idempotency_key,
            payment_network=payment_network,
        )
        return {'approved': False, 'status_code': 400, 'error': 'Некоректна сума платежу.', 'authorization': auth}

    account_id = int(account.get('id') or 0)
    balance_before = float(account.get('balance') or 0)
    if account_id <= 0:
        auth = _create_declined_authorization(
            conn,
            user_id=user_id,
            account=account,
            amount=amount,
            invoice_number=invoice_number,
            response_code=INVALID_ACCOUNT_CODE,
            decline_reason='Банківський рахунок не знайдено.',
            idempotency_key=idempotency_key,
            payment_network=payment_network,
        )
        return {'approved': False, 'status_code': 404, 'error': 'Банківський рахунок не знайдено.', 'authorization': auth}

    if balance_before < amount:
        auth = _create_declined_authorization(
            conn,
            user_id=user_id,
            account=account,
            amount=amount,
            invoice_number=invoice_number,
            response_code=INSUFFICIENT_FUNDS_CODE,
            decline_reason='Недостатньо коштів на рахунку.',
            idempotency_key=idempotency_key,
            payment_network=payment_network,
        )
        return {'approved': False, 'status_code': 409, 'error': 'Недостатньо коштів на рахунку.', 'authorization': auth}

    suffix = get_returning_id_suffix()
    auth_code = _generate_auth_code()
    auth_cur = conn.execute(
        """
        INSERT INTO marketplace_payment_authorizations
        (authorization_code, idempotency_key, user_id, account_id, order_id, invoice_number, amount, currency,
         payment_network, status, response_code, balance_before)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'authorized', %s, %s)
        """
        + suffix,
        (
            auth_code,
            idempotency_key,
            user_id,
            account_id,
            order_id,
            invoice_number,
            float(amount),
            str(account.get('currency') or 'TAX'),
            payment_network,
            APPROVED_CODE,
            balance_before,
        ),
    )
    auth_id = int(insert_last_id(auth_cur) or 0)

    cur_debit = conn.execute(
        "UPDATE accounts SET balance = balance - %s "
        "WHERE id = %s AND user_id = %s AND status = 'active' AND balance >= %s",
        (float(amount), account_id, user_id, float(amount)),
    )
    if getattr(cur_debit, 'rowcount', 0) == 0:
        conn.execute(
            "UPDATE marketplace_payment_authorizations "
            "SET status = 'reversed', response_code = %s, decline_reason = %s, reversed_at = "
            + _now_sql()
            + " WHERE id = %s",
            (INSUFFICIENT_FUNDS_CODE, 'Баланс змінився до capture.', auth_id),
        )
        auth = _select_authorization(conn, auth_id=auth_id)
        return {'approved': False, 'status_code': 409, 'error': 'Недостатньо коштів на рахунку.', 'authorization': auth}

    updated = conn.execute(
        'SELECT balance FROM accounts WHERE id = %s LIMIT 1',
        (account_id,),
    ).fetchone()
    new_balance = float((updated or {}).get('balance') or 0)

    tx_cur = conn.execute(
        """
        INSERT INTO transactions(account_id, tx_type, direction, amount, description, related_account)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        + suffix,
        (account_id, tx_type, 'out', float(amount), description, 'TAXTECH-MARKET'),
    )
    payment_tx_id = int(insert_last_id(tx_cur) or 0)

    conn.execute(
        "UPDATE marketplace_payment_authorizations "
        "SET status = 'captured', balance_after = %s, payment_tx_id = %s, captured_at = "
        + _now_sql()
        + " WHERE id = %s",
        (new_balance, payment_tx_id, auth_id),
    )
    auth = _select_authorization(conn, auth_id=auth_id)
    return {
        'approved': True,
        'authorization': auth,
        'payment_tx_id': payment_tx_id,
        'new_balance': new_balance,
        'authorization_code': auth_code,
    }


# Категорії вітрини: ключові слова шукаються в назві й описі товару
CAT_KEYWORDS: dict[str, list[str]] = {
    'phones':     ['iphone', 'galaxy s', 'galaxy a', 'galaxy z', 'pixel', 'смартфон', 'xiaomi', 'redmi', 'oneplus'],
    'laptops':    ['macbook', 'ноутбук', 'laptop', 'zenbook', 'thinkpad', 'xps', 'legion', 'spectre', 'ультрабук'],
    'audio':      ['sony wh', 'sony wf', 'airpods', 'buds', 'навушники', 'headphone', 'bose'],
    'gaming':     ['playstation', 'xbox', 'nintendo', 'gamepad', 'геймпад', 'ps5'],
    'appliances': ['smart tv', 'телевізор', 'lg oled', 'qled', 'кавомашина', 'пральна', 'холодильник'],
    'home':       ['dyson', 'робот', 'пилосос', 'tefal', 'kitchenaid', 'puricare', 'міксер'],
    'wearables':  ['apple watch', 'galaxy watch', 'garmin', 'smartwatch'],
    'tablets':    ['ipad', 'tablet', 'планшет', 'galaxy tab', 'xiaomi pad'],
    'gadgets':    ['dji', 'дрон', 'gopro'],
    'women':      ["women's", 'женск', 'жіноч', 'woman', 'платье', 'блуз'],
    'men':        ["^men's", 'мужск', 'чолов'],
    'shoes':      ['кроссовк', 'кросівк', 'ботинки', 'туфли', 'sneaker', 'shoe', 'boot', 'sandal', 'loafer', 'slipper', 'шлепанц', 'вьетнамк', 'сандал', 'кросівк', 'черевик', 'туфл', 'сліпони', 'мокасин', 'шльопан', 'кеды', 'сапог', 'лофер', 'босонож', 'обувь'],
    'bags':       ['bag', 'backpack', 'wallet', 'clutch', 'сумка', 'рюкзак', 'гаманець', 'клатч', 'кошелек', 'портмоне', 'барсетк'],
    'accessories': ['belt', 'sunglasses', 'scarf', 'hat', 'cap', 'gloves', 'ремень', 'ремінь', 'окуляри', 'очки', 'шарф', 'шапка', 'кепка', 'перчатк', 'платок', 'часы'],
}


def _category_counts(conn: Any) -> dict[str, int]:
    rows = conn.execute(
        "SELECT title, description FROM marketplace_products WHERE is_active = TRUE AND COALESCE(image_url, '') <> ''"
    ).fetchall() or []
    counts = {key: 0 for key in CAT_KEYWORDS}
    for r in rows:
        text = f"{r.get('title') or ''} {r.get('description') or ''}".lower()
        for key, kws in CAT_KEYWORDS.items():
            if any((text.startswith(kw[1:]) if kw.startswith('^') else kw in text) for kw in kws):
                counts[key] += 1
    return {k: v for k, v in counts.items() if v}


@marketplace_bp.get('/catalog')
def catalog():
    _ensure_schema()
    search   = str(request.args.get('search')    or '').strip()
    category = str(request.args.get('category')  or '').strip()
    sort     = str(request.args.get('sort')       or 'default').strip()
    page     = max(1, int(request.args.get('page')     or 1))
    per_page = min(max(int(request.args.get('per_page') or 96), 4), 96)
    min_price = request.args.get('min_price')
    max_price = request.args.get('max_price')

    # У вітрині лише товари зі справжнім фото; решта лишається в базі для адмінки.
    where, params = ['is_active = TRUE', "COALESCE(image_url, '') <> ''"], []

    if search:
        like = f'%{search.lower()}%'
        where.append(
            "(LOWER(title) LIKE %s OR LOWER(description) LIKE %s OR LOWER(COALESCE(badge,'')) LIKE %s)"
        )
        params += [like, like, like]

    if min_price:
        try: where.append('price >= %s'); params.append(float(min_price))
        except ValueError: pass
    if max_price:
        try: where.append('price <= %s'); params.append(float(max_price))
        except ValueError: pass

    if category and category in CAT_KEYWORDS:
        kws = CAT_KEYWORDS[category]
        sub = ' OR '.join(['(LOWER(title) LIKE %s OR LOWER(description) LIKE %s)'] * len(kws))
        where.append(f'({sub})')
        for kw in kws:
            pat = f'{kw[1:]}%' if kw.startswith('^') else f'%{kw}%'
            params += [pat, pat]

    where_sql = 'WHERE ' + ' AND '.join(where)
    order_sql = {'price_asc': 'price ASC', 'price_desc': 'price DESC',
                 'name_asc': 'title ASC', 'newest': 'id DESC',
                 'stock': 'stock DESC, id ASC'}.get(sort, 'id ASC')

    count_sql = f'SELECT COUNT(*) AS total FROM marketplace_products {where_sql}'
    data_sql  = f'''
        SELECT id, slug, title, description, price, currency, image_emoji, image_url, image_credit, badge, stock
        FROM marketplace_products {where_sql}
        ORDER BY {order_sql}
        LIMIT %s OFFSET %s
    '''
    with get_connection() as conn:
        total = int(((conn.execute(count_sql, params).fetchone()) or {}).get('total') or 0)
        rows  = conn.execute(data_sql, params + [per_page, (page - 1) * per_page]).fetchall()
        categories = _category_counts(conn)

    pages = max(1, -(-total // per_page))
    return jsonify({'ok': True, 'data': {
        'items':    [_to_payload_product(dict(r)) for r in (rows or [])],
        'categories': categories,
        'total':    total,
        'page':     page,
        'per_page': per_page,
        'pages':    pages,
        'has_more': page < pages,
    }})


@marketplace_bp.get('/images/<path:name>')
def product_image(name: str):
    """Публічне фото товару (AsyncImage у застосунку не передає токен)."""
    if not name.endswith('.jpg'):
        return api_error('Не знайдено.', 404)
    resp = send_from_directory(PRODUCT_IMAGES_DIR, name, mimetype='image/jpeg', max_age=86400)
    resp.headers['Cache-Control'] = 'public, max-age=86400'
    return resp


@marketplace_bp.get('/catalog/<int:product_id>')
def catalog_product(product_id: int):
    """Single product detail for AJAX modal."""
    _ensure_schema()
    with get_connection() as conn:
        row = conn.execute(
            "SELECT * FROM marketplace_products WHERE id = %s AND is_active = TRUE AND COALESCE(image_url, '') <> '' LIMIT 1",
            (product_id,),
        ).fetchone()
    if not row:
        return api_error('Товар не знайдено.', 404)
    return jsonify({'ok': True, 'data': _to_payload_product(dict(row))})


@marketplace_bp.get('/orders')
@auth_required
def list_orders():
    _ensure_schema()
    user_id = int(g.current_user['id'])
    limit = min(max(int(request.args.get('limit') or 20), 1), 50)
    with get_connection() as conn:
        _expire_overdue_invoices(conn)
        orders = conn.execute(
            """
            SELECT
                o.id,
                o.total_amount,
                o.currency,
                o.status,
                o.payment_mode,
                o.invoice_number,
                o.invoice_status,
                o.invoice_due_at,
                o.created_at,
                COALESCE(COUNT(i.id), 0) AS items_count
            FROM marketplace_orders o
            LEFT JOIN marketplace_order_items i ON i.order_id = o.id
            WHERE o.user_id = %s
            GROUP BY o.id
            ORDER BY o.created_at DESC, o.id DESC
            LIMIT %s
            """,
            (user_id, limit),
        ).fetchall()
    payload = [_to_payload_order(dict(r)) for r in (orders or [])]
    return jsonify({'ok': True, 'data': {'orders': payload}})


@marketplace_bp.get('/invoices')
@auth_required
def list_invoices():
    _ensure_schema()
    user_id = int(g.current_user['id'])
    limit = min(max(int(request.args.get('limit') or 20), 1), 100)
    with get_connection() as conn:
        _expire_overdue_invoices(conn)
        rows = conn.execute(
            """
            SELECT invoice_number, amount, currency, status, due_at, paid_at, created_at, order_id
            FROM marketplace_invoices
            WHERE user_id = %s
            ORDER BY created_at DESC, id DESC
            LIMIT %s
            """,
            (user_id, limit),
        ).fetchall()
    invoices = []
    for row in rows or []:
        r = dict(row)
        invoices.append({
            'invoice_number': r.get('invoice_number'),
            'amount': float(r.get('amount') or 0),
            'currency': r.get('currency') or 'TAX',
            'status': r.get('status') or 'issued',

            'due_at': _dt(r.get('due_at')),
            'paid_at': _dt(r.get('paid_at')),
            'created_at': _dt(r.get('created_at')),
            'due_at': _dt_str(r.get('due_at')),
            'paid_at': _dt_str(r.get('paid_at')),
            'created_at': _dt_str(r.get('created_at')),
            'order_id': int(r.get('order_id') or 0),
        })
    return jsonify({'ok': True, 'data': {'invoices': invoices}})


@marketplace_bp.get('/invoice/<invoice_number>')
@auth_required
def get_invoice(invoice_number: str):
    _ensure_schema()
    user_id = int(g.current_user['id'])
    invoice_key = str(invoice_number or '').strip()
    if not invoice_key:
        return api_error('Не вказано номер інвойсу.')

    with get_connection() as conn:
        _expire_overdue_invoices(conn)
        inv = conn.execute(
            """
            SELECT
                i.id,
                i.invoice_number,
                i.order_id,
                i.amount,
                i.currency,
                i.status,
                i.due_at,
                i.paid_at,
                i.created_at,
                i.payment_tx_id,
                i.payment_auth_id,
                o.shipping_name,
                o.shipping_phone,
                o.shipping_address,
                o.note,
                o.status AS order_status,
                o.payment_mode
            FROM marketplace_invoices i
            JOIN marketplace_orders o ON o.id = i.order_id
            WHERE i.user_id = %s AND i.invoice_number = %s
            LIMIT 1
            """,
            (user_id, invoice_key),
        ).fetchone()
        if not inv:
            return api_error('Інвойс не знайдено.', 404)

        items = conn.execute(
            """
            SELECT product_id, title, price, qty, line_total
            FROM marketplace_order_items
            WHERE order_id = %s
            ORDER BY id ASC
            """,
            (int(inv['order_id']),),
        ).fetchall()
        auth_row = _select_authorization(conn, auth_id=int(inv.get('payment_auth_id') or 0))

    inv_d = dict(inv)
    payload_items = []
    for item in items or []:
        row = dict(item)
        payload_items.append({
            'product_id': int(row.get('product_id') or 0),
            'title': row.get('title') or 'Товар',
            'price': float(row.get('price') or 0),
            'qty': int(row.get('qty') or 0),
            'line_total': float(row.get('line_total') or 0),
        })

    can_pay = (inv_d.get('status') == 'issued')
    return jsonify({'ok': True, 'data': {
        'invoice_number': inv_d.get('invoice_number'),
        'order_id': int(inv_d.get('order_id') or 0),
        'status': inv_d.get('status') or 'issued',
        'amount': float(inv_d.get('amount') or 0),
        'currency': inv_d.get('currency') or 'TAX',

        'due_at': _dt(inv_d.get('due_at')),
        'paid_at': _dt(inv_d.get('paid_at')),
        'created_at': _dt(inv_d.get('created_at')),
        'due_at': _dt_str(inv_d.get('due_at')),
        'paid_at': _dt_str(inv_d.get('paid_at')),
        'created_at': _dt_str(inv_d.get('created_at')),
        'payment_tx_id': int(inv_d.get('payment_tx_id') or 0),
        'payment_authorization': _auth_payload(auth_row),
        'order_status': inv_d.get('order_status') or 'awaiting_payment',
        'payment_mode': inv_d.get('payment_mode') or 'invoice',
        'shipping': {
            'name': inv_d.get('shipping_name') or '',
            'phone': inv_d.get('shipping_phone') or '',
            'address': inv_d.get('shipping_address') or '',
            'note': inv_d.get('note') or '',
        },
        'can_pay': bool(can_pay),
        'pay_endpoint': f"/api/marketplace/invoice/{inv_d.get('invoice_number')}/pay",
        'items': payload_items,
    }})


@marketplace_bp.post('/invoice/<invoice_number>/pay')
@auth_required
def pay_invoice(invoice_number: str):
    _ensure_schema()
    user_id = int(g.current_user['id'])
    payload = request.get_json(silent=True) or {}
    idempotency_key, idem_err = require_idempotency_key(payload=payload, allow_body_fallback=True)
    if idem_err:
        return idem_err
    idem_action = 'marketplace_invoice_pay'
    if idempotency_key:
        reservation = idempotency_service.reserve(
            user_id=user_id,
            action=idem_action,
            key=idempotency_key,
            payload={'invoice_number': invoice_number},
        )
        state = reservation.get('state')
        if state == 'conflict':
            return api_error('Idempotency-Key уже використано з іншим payload.', 409)
        if state == 'replay':
            return jsonify(reservation.get('payload') or {'ok': False}), int(reservation.get('response_code') or 200)
        if state == 'processing':
            return api_error('Операція вже виконується. Спробуйте пізніше.', 409)

    invoice_key = str(invoice_number or '').strip()
    if not invoice_key:
        return api_error('Не вказано номер інвойсу.')

    with get_connection() as conn:
        _expire_overdue_invoices(conn)
        inv = conn.execute(
            """
            SELECT id, invoice_number, order_id, account_id, amount, currency, status, payment_tx_id, payment_auth_id
            FROM marketplace_invoices
            WHERE user_id = %s AND invoice_number = %s
            LIMIT 1
            """,
            (user_id, invoice_key),
        ).fetchone()
        if not inv:
            return api_error('Інвойс не знайдено.', 404)

        status = str(inv.get('status') or 'issued')
        if status == 'paid':
            account = conn.execute(
                'SELECT account_number, balance FROM accounts WHERE id = %s LIMIT 1',
                (int(inv['account_id']),),
            ).fetchone()
            auth = _select_authorization(conn, auth_id=int(inv.get('payment_auth_id') or 0))
            response_payload = {'ok': True, 'data': {
                'invoice_number': inv.get('invoice_number'),
                'order_id': int(inv.get('order_id') or 0),
                'status': 'paid',
                'payment_tx_id': int(inv.get('payment_tx_id') or 0),
                'new_balance': float((account or {}).get('balance') or 0),
                'account_number': (account or {}).get('account_number'),
                'payment_authorization': _auth_payload(auth),
            }}
            if idempotency_key:
                _complete_idempotency_in_conn(
                    conn,
                    user_id=user_id,
                    action=idem_action,
                    key=idempotency_key,
                    response_payload=response_payload,
                    response_code=200,
                )
            return jsonify(response_payload)
        if status in ('cancelled', 'expired'):
            return api_error('Інвойс недійсний або прострочений.', 409)

        account = conn.execute(
            'SELECT id, account_number, balance, currency FROM accounts WHERE id = %s AND user_id = %s LIMIT 1',
            (int(inv['account_id']), user_id),
        ).fetchone()
        if not account:
            return api_error('Банківський рахунок не знайдено.', 404)

        amount = float(inv.get('amount') or 0)
        payment = _authorize_and_capture_payment(
            conn,
            user_id=user_id,
            account=dict(account),
            amount=amount,
            invoice_number=str(inv.get('invoice_number') or invoice_key),
            order_id=int(inv.get('order_id') or 0),
            tx_type='marketplace_invoice',
            description=f"Оплата інвойсу {inv.get('invoice_number')} у магазині TaxTech",
            idempotency_key=idempotency_key,
            payment_network=str(payload.get('payment_network') or 'TAX_PAY').strip().upper()[:20] or 'TAX_PAY',
        )
        if not payment.get('approved'):
            response_payload = {
                'ok': False,
                'error': payment.get('error') or 'Платіж відхилено.',
                'data': {'payment_authorization': _auth_payload(payment.get('authorization'))},
            }
            if idempotency_key:
                _complete_idempotency_in_conn(
                    conn,
                    user_id=user_id,
                    action=idem_action,
                    key=idempotency_key,
                    response_payload=response_payload,
                    response_code=int(payment.get('status_code') or 409),
                )
            return jsonify(response_payload), int(payment.get('status_code') or 409)

        payment_tx_id = int(payment.get('payment_tx_id') or 0)
        new_balance = float(payment.get('new_balance') or 0)
        auth_id = int((payment.get('authorization') or {}).get('id') or 0)

        conn.execute(
            "UPDATE marketplace_invoices "
            "SET status = 'paid', paid_at = " + _now_sql() + ", payment_tx_id = %s, payment_auth_id = %s "
            "WHERE id = %s",
            (payment_tx_id, auth_id, int(inv['id'])),
        )
        conn.execute(
            """
            UPDATE marketplace_orders
            SET status = 'paid', invoice_status = 'paid', payment_tx_id = %s, payment_auth_id = %s
            WHERE id = %s
            """,
            (payment_tx_id, auth_id, int(inv['order_id'])),
        )

    try:
        with get_connection() as sconn:
            if not shop_sync.push_paid(sconn, int(inv['order_id']), int(payment_tx_id or 0)):
                shop_sync.push_order(sconn, int(inv['order_id']))
    except Exception:
        pass

    response_payload = {'ok': True, 'data': {
        'invoice_number': inv.get('invoice_number'),
        'order_id': int(inv.get('order_id') or 0),
        'status': 'paid',
        'payment_tx_id': int(payment_tx_id or 0),
        'new_balance': float(new_balance),
        'account_number': account.get('account_number'),
        'payment_authorization': _auth_payload(payment.get('authorization')),
    }}
    if idempotency_key:
        idempotency_service.complete(user_id, idem_action, idempotency_key, response_payload, 200)
    return jsonify(response_payload)


@marketplace_bp.post('/checkout')
@auth_required
def checkout():
    import traceback as _tb
    try:
        return _checkout_impl()
    except Exception as exc:
        import logging
        logging.getLogger(__name__).error('checkout error: %s', _tb.format_exc())
        return jsonify({'ok': False, 'error': f'[DEBUG] {type(exc).__name__}: {exc}'}), 500


def _checkout_impl():
    _ensure_schema()
    user_id = int(g.current_user['id'])
    payload = request.get_json(force=True) or {}
    cart_items = payload.get('items') or []
    if not isinstance(cart_items, list) or not cart_items:
        return api_error('Кошик порожній.')

    shipping_name = str(payload.get('shipping_name') or '').strip()
    shipping_phone = str(payload.get('shipping_phone') or '').strip()
    shipping_address = str(payload.get('shipping_address') or '').strip()
    note = str(payload.get('note') or '').strip()
    payment_mode = str(payload.get('payment_mode') or 'pay_now').strip().lower()

    if payment_mode not in ('pay_now', 'invoice'):
        return api_error('Некоректний режим оплати.')

    if len(shipping_name) < 2 or len(shipping_address) < 8:
        return api_error('Заповніть дані доставки (ПІБ та адресу).')

    requested: dict[int, int] = {}
    for item in cart_items:
        try:
            pid = int(item.get('product_id'))
            qty = int(item.get('qty') or 1)
        except Exception:
            return api_error('Некоректний склад кошика.')
        if pid <= 0 or qty <= 0 or qty > 50:
            return api_error('Некоректна кількість товару.')
        requested[pid] = requested.get(pid, 0) + qty

    idempotency_key, idem_err = require_idempotency_key(payload=payload, allow_body_fallback=True)
    if idem_err:
        return idem_err
    idem_action = 'marketplace_checkout'
    if idempotency_key:
        reservation = idempotency_service.reserve(
            user_id=user_id,
            action=idem_action,
            key=idempotency_key,
            payload={
                'items': sorted(
                    [{'product_id': int(pid), 'qty': int(qty)} for pid, qty in requested.items()],
                    key=lambda item: item['product_id'],
                ),
                'shipping_name': shipping_name,
                'shipping_phone': shipping_phone,
                'shipping_address': shipping_address,
                'note': note,
                'payment_mode': payment_mode,
            },
        )
        state = reservation.get('state')
        if state == 'conflict':
            return api_error('Idempotency-Key уже використано з іншим payload.', 409)
        if state == 'replay':
            return jsonify(reservation.get('payload') or {'ok': False}), int(reservation.get('response_code') or 200)
        if state == 'processing':
            return api_error('Операція вже виконується. Спробуйте пізніше.', 409)

    product_ids = sorted(requested.keys())
    placeholders = ', '.join(['%s'] * len(product_ids))
    suffix = get_returning_id_suffix()

    with get_connection() as conn:
        _expire_overdue_invoices(conn)
        account = conn.execute(
            'SELECT id, account_number, balance, currency FROM accounts WHERE user_id = %s',
            (user_id,),
        ).fetchone()
        if not account:
            return api_error('Банківський рахунок не знайдено.', 404)

        prod_rows = conn.execute(
            f"""
            SELECT id, title, price, currency, stock
            FROM marketplace_products
            WHERE is_active = TRUE AND id IN ({placeholders})
            """,
            tuple(product_ids),
        ).fetchall()
        by_id = {int(r['id']): dict(r) for r in (prod_rows or [])}
        if len(by_id) != len(product_ids):
            return api_error('Один або кілька товарів недоступні.')

        normalized_items: list[dict[str, Any]] = []
        total_amount = 0.0
        for pid in product_ids:
            row = by_id[pid]
            qty = requested[pid]
            stock = int(row.get('stock') or 0)
            if stock < qty:
                return api_error(f"Товар «{row.get('title') or 'позиція'}» закінчився на складі.")
            price = float(row.get('price') or 0)
            line_total = round(price * qty, 2)
            total_amount = round(total_amount + line_total, 2)
            normalized_items.append({
                'product_id': pid,
                'title': row.get('title') or f'Товар #{pid}',
                'price': price,
                'qty': qty,
                'line_total': line_total,
            })

        account_balance = float(account.get('balance') or 0)
        payment_tx_id = None
        payment_auth_id = None
        payment_authorization = None
        new_balance = account_balance
        order_status = 'awaiting_payment' if payment_mode == 'invoice' else 'paid'
        invoice_status = 'issued' if payment_mode == 'invoice' else 'paid'
        invoice_due_at = None
        invoice_number = _generate_unique_invoice_number(conn)

        if payment_mode == 'pay_now':
            payment = _authorize_and_capture_payment(
                conn,
                user_id=user_id,
                account=dict(account),
                amount=total_amount,
                invoice_number=invoice_number,
                tx_type='marketplace',
                description='Оплата у магазині TaxTech',
                idempotency_key=idempotency_key,
                payment_network=str(payload.get('payment_network') or 'TAX_PAY').strip().upper()[:20] or 'TAX_PAY',
            )
            payment_authorization = payment.get('authorization')
            if not payment.get('approved'):
                response_payload = {
                    'ok': False,
                    'error': payment.get('error') or 'Платіж відхилено.',
                    'data': {'payment_authorization': _auth_payload(payment_authorization)},
                }
                if idempotency_key:
                    _complete_idempotency_in_conn(
                        conn,
                        user_id=user_id,
                        action=idem_action,
                        key=idempotency_key,
                        response_payload=response_payload,
                        response_code=int(payment.get('status_code') or 409),
                    )
                return jsonify(response_payload), int(payment.get('status_code') or 409)
            payment_tx_id = int(payment.get('payment_tx_id') or 0)
            payment_auth_id = int((payment_authorization or {}).get('id') or 0)
            new_balance = float(payment.get('new_balance') or account_balance)

        order_cur = conn.execute(
            """
            INSERT INTO marketplace_orders
            (user_id, account_id, total_amount, currency, status, payment_mode, invoice_number, invoice_status, invoice_due_at, payment_tx_id, payment_auth_id, shipping_name, shipping_phone, shipping_address, note)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, """
            + (_due_at_sql(24) if payment_mode == 'invoice' else 'NULL')
            + ", %s, %s, %s, %s, %s, %s)"
            + suffix,
            (
                user_id,
                account['id'],
                total_amount,
                str(account.get('currency') or 'TAX'),
                order_status,
                payment_mode,
                invoice_number,
                invoice_status,
                payment_tx_id,
                payment_auth_id,
                shipping_name,
                shipping_phone,
                shipping_address,
                note,
            ),
        )
        order_id = insert_last_id(order_cur)

        if payment_auth_id:
            conn.execute(
                'UPDATE marketplace_payment_authorizations SET order_id = %s WHERE id = %s',
                (order_id, payment_auth_id),
            )

        # Reserve/consume stock immediately when order is created.
        for row in normalized_items:
            conn.execute(
                """
                INSERT INTO marketplace_order_items(order_id, product_id, title, price, qty, line_total)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (order_id, row['product_id'], row['title'], row['price'], row['qty'], row['line_total']),
            )
            conn.execute(
                'UPDATE marketplace_products SET stock = stock - %s, updated_at = ' + _now_sql() + ' WHERE id = %s',
                (row['qty'], row['product_id']),
            )

        inv_cur = conn.execute(
            """
            INSERT INTO marketplace_invoices
            (invoice_number, order_id, user_id, account_id, amount, currency, status, due_at, paid_at, payment_tx_id, payment_auth_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s, """
            + (_due_at_sql(24) if payment_mode == 'invoice' else _now_sql())
            + ", "
            + (_now_sql() if payment_mode == 'pay_now' else 'NULL')
            + ", %s, %s)"
            + suffix,
            (
                invoice_number,
                order_id,
                user_id,
                account['id'],
                total_amount,
                str(account.get('currency') or 'TAX'),
                invoice_status,
                payment_tx_id,
                payment_auth_id,
            ),
        )
        invoice_id = insert_last_id(inv_cur)

        if payment_mode == 'invoice':
            row_due = conn.execute(
                'SELECT due_at FROM marketplace_invoices WHERE id = %s LIMIT 1',
                (invoice_id,),
            ).fetchone()
            invoice_due_at = (row_due or {}).get('due_at')

    if order_status == 'paid':
        try:
            with get_connection() as sconn:
                shop_sync.push_order(sconn, int(order_id))
        except Exception:
            pass

    response_payload = {
        'ok': True,
        'data': {
            'order_id': int(order_id or 0),
            'invoice_id': int(invoice_id or 0),
            'invoice_number': invoice_number,
            'invoice_status': invoice_status,

            'invoice_due_at': _dt(invoice_due_at),
            'invoice_due_at': _dt_str(invoice_due_at),
            'payment_tx_id': int(payment_tx_id or 0),
            'total_amount': float(total_amount),
            'currency': str(account.get('currency') or 'TAX'),
            'account_number': account.get('account_number'),
            'new_balance': float(new_balance),
            'status': order_status,
            'payment_mode': payment_mode,
            'items': normalized_items,
            'invoice_link': f"/api/marketplace/invoice/{invoice_number}",
            'pay_link': f"/api/marketplace/invoice/{invoice_number}/pay",
            'payment_authorization': _auth_payload(payment_authorization),
        },
    }
    if idempotency_key:
        idempotency_service.complete(user_id, idem_action, idempotency_key, response_payload, 200)
    return jsonify(response_payload)


# ═══════════════════════════════════════════════════════════════════
#  ADMIN MARKETPLACE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════

def _admin_required(func):
    from functools import wraps
    from .helpers import role_required
    @wraps(func)
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs)
    return auth_required(role_required('admin', 'platform_admin')(wrapper))


def _slugify(text: str) -> str:
    import re
    s = text.lower().strip()
    s = re.sub(r'[^\w\s-]', '', s)
    s = re.sub(r'[\s_]+', '-', s)
    s = re.sub(r'-+', '-', s)
    return s[:80]


def _unique_slug(conn: Any, base: str, exclude_id: int | None = None) -> str:
    slug = _slugify(base)
    candidate = slug
    i = 2
    while True:
        q = 'SELECT id FROM marketplace_products WHERE slug = %s'
        params: list = [candidate]
        if exclude_id:
            q += ' AND id != %s'
            params.append(exclude_id)
        row = conn.execute(q, params).fetchone()
        if not row:
            return candidate
        candidate = f'{slug}-{i}'
        i += 1


# ── Stats ──────────────────────────────────────────────────────────

@marketplace_bp.get('/admin/stats')
@auth_required
def admin_marketplace_stats():
    from .helpers import role_required
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        from .helpers import api_error as _ae
        return _ae('Недостатньо прав.', 403)
    _ensure_schema()
    with get_connection() as conn:
        total_products = (conn.execute(
            'SELECT COUNT(*) AS n FROM marketplace_products').fetchone() or {}).get('n') or 0
        active_products = (conn.execute(
            'SELECT COUNT(*) AS n FROM marketplace_products WHERE is_active = TRUE').fetchone() or {}).get('n') or 0
        low_stock = (conn.execute(
            'SELECT COUNT(*) AS n FROM marketplace_products WHERE is_active = TRUE AND stock <= 5').fetchone() or {}).get('n') or 0
        out_of_stock = (conn.execute(
            'SELECT COUNT(*) AS n FROM marketplace_products WHERE stock = 0').fetchone() or {}).get('n') or 0

        total_orders = (conn.execute(
            'SELECT COUNT(*) AS n FROM marketplace_orders').fetchone() or {}).get('n') or 0
        paid_orders = (conn.execute(
            "SELECT COUNT(*) AS n FROM marketplace_orders WHERE status = 'paid'").fetchone() or {}).get('n') or 0
        pending_orders = (conn.execute(
            "SELECT COUNT(*) AS n FROM marketplace_orders WHERE status = 'awaiting_payment'").fetchone() or {}).get('n') or 0
        revenue = (conn.execute(
            "SELECT COALESCE(SUM(total_amount),0) AS s FROM marketplace_orders WHERE status = 'paid'").fetchone() or {}).get('s') or 0

        top_products = conn.execute(
            """
            SELECT p.id, p.title, p.image_emoji, p.stock,
                   COALESCE(SUM(oi.qty),0) AS sold,
                   COALESCE(SUM(oi.line_total),0) AS revenue
            FROM marketplace_products p
            LEFT JOIN marketplace_order_items oi ON oi.product_id = p.id
            LEFT JOIN marketplace_orders o ON o.id = oi.order_id AND o.status = 'paid'
            GROUP BY p.id, p.title, p.image_emoji, p.stock
            ORDER BY sold DESC
            LIMIT 5
            """
        ).fetchall()

    return jsonify({'ok': True, 'data': {
        'total_products': int(total_products),
        'active_products': int(active_products),
        'low_stock': int(low_stock),
        'out_of_stock': int(out_of_stock),
        'total_orders': int(total_orders),
        'paid_orders': int(paid_orders),
        'pending_orders': int(pending_orders),
        'revenue': float(revenue),
        'top_products': [
            {
                'id': int(r['id']), 'title': r['title'],
                'emoji': r['image_emoji'], 'stock': int(r['stock']),
                'sold': int(r['sold']), 'revenue': float(r['revenue']),
            } for r in (top_products or [])
        ],
    }})


# ── Product list (admin, all including inactive) ───────────────────

@marketplace_bp.get('/admin/products')
@auth_required
def admin_list_products():
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    search = str(request.args.get('search') or '').strip()
    active_filter = request.args.get('active')  # 'true' | 'false' | None
    page = max(1, int(request.args.get('page') or 1))
    per_page = 25
    offset = (page - 1) * per_page

    where_parts = []
    params: list = []
    if search:
        where_parts.append('(LOWER(title) LIKE %s OR LOWER(slug) LIKE %s)')
        like = f'%{search.lower()}%'
        params += [like, like]
    if active_filter == 'true':
        where_parts.append('is_active = TRUE')
    elif active_filter == 'false':
        where_parts.append('is_active = FALSE')

    where_sql = ('WHERE ' + ' AND '.join(where_parts)) if where_parts else ''

    with get_connection() as conn:
        total = (conn.execute(
            f'SELECT COUNT(*) AS n FROM marketplace_products {where_sql}', params
        ).fetchone() or {}).get('n') or 0
        rows = conn.execute(
            f"""
            SELECT id, slug, title, description, price, currency,
                   image_emoji, image_url, badge, stock, is_active, created_at, updated_at
            FROM marketplace_products
            {where_sql}
            ORDER BY id DESC
            LIMIT %s OFFSET %s
            """,
            params + [per_page, offset],
        ).fetchall()

    items = []
    for r in (rows or []):
        items.append({
            'id': int(r['id']),
            'slug': r['slug'],
            'title': r['title'],
            'description': r.get('description') or '',
            'price': float(r['price'] or 0),
            'currency': r.get('currency') or 'TAX',
            'image_emoji': r.get('image_emoji') or '🛍️',
            'image_url': r.get('image_url') or None,
            'badge': r.get('badge'),
            'stock': int(r.get('stock') or 0),
            'is_active': bool(r.get('is_active')),
            'created_at': str(r.get('created_at') or ''),
            'updated_at': str(r.get('updated_at') or ''),
        })

    return jsonify({'ok': True, 'data': {
        'items': items,
        'total': int(total),
        'page': page,
        'per_page': per_page,
        'pages': max(1, -(-int(total) // per_page)),
    }})


# ── Create product ─────────────────────────────────────────────────

@marketplace_bp.post('/admin/products')
@auth_required
def admin_create_product():
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    body = request.get_json(force=True) or {}

    title = str(body.get('title') or '').strip()
    if len(title) < 2:
        return api_error('Назва товару обовʼязкова.')
    description = str(body.get('description') or '').strip()
    try:
        price = float(body.get('price') or 0)
        assert price >= 0
    except Exception:
        return api_error('Некоректна ціна.')
    stock = max(0, int(body.get('stock') or 0))
    emoji = str(body.get('image_emoji') or '🛍️').strip()[:16] or '🛍️'
    image_url = str(body.get('image_url') or '').strip() or None
    badge = str(body.get('badge') or '').strip()[:40] or None
    currency = str(body.get('currency') or 'TAX').strip()[:6] or 'TAX'
    is_active = bool(body.get('is_active', True))

    suffix = get_returning_id_suffix()
    now_sql = _now_sql()

    with get_connection() as conn:
        slug = _unique_slug(conn, title)
        cur = conn.execute(
            f"""
            INSERT INTO marketplace_products
            (slug, title, description, price, currency, image_emoji, image_url, badge, stock, is_active, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, {now_sql}, {now_sql})
            """ + suffix,
            (slug, title, description, price, currency, emoji, image_url, badge, stock, is_active),
        )
        new_id = int(insert_last_id(cur) or 0)
        row = conn.execute(
            'SELECT * FROM marketplace_products WHERE id = %s LIMIT 1', (new_id,)
        ).fetchone()

    return jsonify({'ok': True, 'data': dict(row) if row else {'id': new_id}}), 201


# ── Update product ─────────────────────────────────────────────────

@marketplace_bp.patch('/admin/products/<int:product_id>')
@auth_required
def admin_update_product(product_id: int):
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    body = request.get_json(force=True) or {}

    fields: list[str] = []
    params: list = []

    if 'title' in body:
        title = str(body['title']).strip()
        if len(title) < 2:
            return api_error('Назва товару обовʼязкова.')
        fields.append('title = %s')
        params.append(title)

    if 'description' in body:
        fields.append('description = %s')
        params.append(str(body['description']).strip())

    if 'price' in body:
        try:
            price = float(body['price'])
            assert price >= 0
        except Exception:
            return api_error('Некоректна ціна.')
        fields.append('price = %s')
        params.append(price)

    if 'stock' in body:
        fields.append('stock = %s')
        params.append(max(0, int(body['stock'])))

    if 'image_emoji' in body:
        fields.append('image_emoji = %s')
        params.append(str(body['image_emoji']).strip()[:16] or '🛍️')

    if 'image_url' in body:
        fields.append('image_url = %s')
        params.append(str(body['image_url']).strip() or None)

    if 'badge' in body:
        badge = str(body['badge']).strip()[:40] or None
        fields.append('badge = %s')
        params.append(badge)

    if 'currency' in body:
        fields.append('currency = %s')
        params.append(str(body['currency']).strip()[:6] or 'TAX')

    if 'is_active' in body:
        fields.append('is_active = %s')
        params.append(bool(body['is_active']))

    if not fields:
        return api_error('Немає полів для оновлення.')

    fields.append(f'updated_at = {_now_sql()}')
    params.append(product_id)

    with get_connection() as conn:
        existing = conn.execute(
            'SELECT id FROM marketplace_products WHERE id = %s LIMIT 1', (product_id,)
        ).fetchone()
        if not existing:
            return api_error('Товар не знайдено.', 404)

        conn.execute(
            f"UPDATE marketplace_products SET {', '.join(fields)} WHERE id = %s",
            params,
        )
        row = conn.execute(
            'SELECT * FROM marketplace_products WHERE id = %s LIMIT 1', (product_id,)
        ).fetchone()

    return jsonify({'ok': True, 'data': dict(row) if row else {}})


# ── Toggle active ──────────────────────────────────────────────────

@marketplace_bp.patch('/admin/products/<int:product_id>/toggle')
@auth_required
def admin_toggle_product(product_id: int):
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    with get_connection() as conn:
        row = conn.execute(
            'SELECT id, is_active FROM marketplace_products WHERE id = %s LIMIT 1', (product_id,)
        ).fetchone()
        if not row:
            return api_error('Товар не знайдено.', 404)
        new_active = not bool(row['is_active'])
        conn.execute(
            f"UPDATE marketplace_products SET is_active = %s, updated_at = {_now_sql()} WHERE id = %s",
            (new_active, product_id),
        )
    return jsonify({'ok': True, 'data': {'id': product_id, 'is_active': new_active}})


# ── Delete product ─────────────────────────────────────────────────

@marketplace_bp.delete('/admin/products/<int:product_id>')
@auth_required
def admin_delete_product(product_id: int):
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    with get_connection() as conn:
        row = conn.execute(
            'SELECT id FROM marketplace_products WHERE id = %s LIMIT 1', (product_id,)
        ).fetchone()
        if not row:
            return api_error('Товар не знайдено.', 404)
        used = conn.execute(
            'SELECT id FROM marketplace_order_items WHERE product_id = %s LIMIT 1', (product_id,)
        ).fetchone()
        if used:
            # Soft-delete: just deactivate
            conn.execute(
                f"UPDATE marketplace_products SET is_active = FALSE, updated_at = {_now_sql()} WHERE id = %s",
                (product_id,),
            )
            return jsonify({'ok': True, 'data': {'deleted': False, 'deactivated': True,
                'message': 'Товар є в замовленнях — деактивовано замість видалення.'}})
        conn.execute('DELETE FROM marketplace_products WHERE id = %s', (product_id,))
    return jsonify({'ok': True, 'data': {'deleted': True}})


# ── Admin orders list ──────────────────────────────────────────────

@marketplace_bp.get('/admin/orders')
@auth_required
def admin_list_orders():
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    status_filter = str(request.args.get('status') or '').strip()
    date_from = str(request.args.get('date_from') or '').strip()
    date_to   = str(request.args.get('date_to')   or '').strip()
    search    = str(request.args.get('search')    or '').strip()
    page = max(1, int(request.args.get('page') or 1))
    per_page = int(request.args.get('per_page') or 30)
    per_page = min(per_page, 5000)
    offset = (page - 1) * per_page

    where_parts = []
    params: list = []
    if status_filter:
        where_parts.append('o.status = %s')
        params.append(status_filter)
    if date_from:
        where_parts.append('o.created_at >= %s')
        params.append(date_from)
    if date_to:
        where_parts.append('o.created_at <= %s')
        params.append(date_to + ' 23:59:59')
    if search:
        where_parts.append("(LOWER(u.full_name) LIKE %s OR u.phone LIKE %s OR o.shipping_name ILIKE %s)")
        like = f'%{search.lower()}%'
        params += [like, like, like]
    where_sql = ('WHERE ' + ' AND '.join(where_parts)) if where_parts else ''

    with get_connection() as conn:
        total = (conn.execute(
            f'SELECT COUNT(*) AS n FROM marketplace_orders o JOIN users u ON u.id = o.user_id {where_sql}', params
        ).fetchone() or {}).get('n') or 0

        rows = conn.execute(
            f"""
            SELECT o.id, o.total_amount, o.currency, o.status, o.payment_mode,
                   o.invoice_number, o.invoice_status, o.invoice_due_at,
                   o.shipping_name, o.shipping_phone, o.shipping_address,
                   o.created_at, o.note,
                   u.phone AS user_phone, u.full_name AS user_name
            FROM marketplace_orders o
            JOIN users u ON u.id = o.user_id
            {where_sql}
            ORDER BY o.id DESC
            LIMIT %s OFFSET %s
            """,
            params + [per_page, offset],
        ).fetchall()

    items = []
    for r in (rows or []):
        items.append({
            'id': int(r['id']),
            'total_amount': float(r.get('total_amount') or 0),
            'currency': r.get('currency') or 'TAX',
            'status': r.get('status') or '',
            'payment_mode': r.get('payment_mode') or '',
            'invoice_number': r.get('invoice_number') or '',
            'invoice_status': r.get('invoice_status') or '',
            'invoice_due_at': str(r.get('invoice_due_at') or ''),
            'shipping_name': r.get('shipping_name') or '',
            'shipping_phone': r.get('shipping_phone') or '',
            'shipping_address': r.get('shipping_address') or '',
            'note': r.get('note') or '',
            'created_at': str(r.get('created_at') or ''),
            'user_phone': r.get('user_phone') or '',
            'user_name': r.get('user_name') or '',
        })

    return jsonify({'ok': True, 'data': {
        'items': items,
        'total': int(total),
        'page': page,
        'per_page': per_page,
        'pages': max(1, -(-int(total) // per_page)),
    }})


# ── Update order status ────────────────────────────────────────────

@marketplace_bp.patch('/admin/orders/<int:order_id>/status')
@auth_required
def admin_update_order_status(order_id: int):
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    body = request.get_json(force=True) or {}
    new_status = str(body.get('status') or '').strip()
    allowed = ('paid', 'shipped', 'delivered', 'cancelled', 'awaiting_payment', 'processing')
    if new_status not in allowed:
        return api_error(f'Статус має бути одним із: {", ".join(allowed)}.')
    with get_connection() as conn:
        row = conn.execute(
            'SELECT id FROM marketplace_orders WHERE id = %s LIMIT 1', (order_id,)
        ).fetchone()
        if not row:
            return api_error('Замовлення не знайдено.', 404)
        conn.execute(
            "UPDATE marketplace_orders SET status = %s WHERE id = %s",
            (new_status, order_id),
        )
    return jsonify({'ok': True, 'data': {'id': order_id, 'status': new_status}})


# ── Quick stock update ─────────────────────────────────────────────

@marketplace_bp.patch('/admin/products/<int:product_id>/stock')
@auth_required
def admin_update_stock(product_id: int):
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    body = request.get_json(force=True) or {}
    try:
        stock = max(0, int(body.get('stock') or 0))
    except (ValueError, TypeError):
        return api_error('Некоректне значення залишку.')
    with get_connection() as conn:
        row = conn.execute('SELECT id FROM marketplace_products WHERE id = %s LIMIT 1', (product_id,)).fetchone()
        if not row:
            return api_error('Товар не знайдено.', 404)
        conn.execute(
            f'UPDATE marketplace_products SET stock = %s, updated_at = {_now_sql()} WHERE id = %s',
            (stock, product_id),
        )
    return jsonify({'ok': True, 'data': {'id': product_id, 'stock': stock}})


# ── Customers list ─────────────────────────────────────────────────

@marketplace_bp.get('/admin/customers')
@auth_required
def admin_list_customers():
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    page = max(1, int(request.args.get('page') or 1))
    per_page = 30
    offset = (page - 1) * per_page
    search = str(request.args.get('search') or '').strip()

    where_sql = ''
    params: list = []
    if search:
        where_sql = "WHERE (LOWER(u.full_name) LIKE %s OR u.phone LIKE %s)"
        like = f'%{search.lower()}%'
        params = [like, like]

    with get_connection() as conn:
        total_row = conn.execute(
            f"""
            SELECT COUNT(DISTINCT o.user_id) AS n
            FROM marketplace_orders o
            JOIN users u ON u.id = o.user_id
            {where_sql}
            """, params,
        ).fetchone()
        total = int((total_row or {}).get('n') or 0)

        rows = conn.execute(
            f"""
            SELECT o.user_id,
                   u.full_name, u.phone,
                   COUNT(o.id) AS total_orders,
                   COALESCE(SUM(CASE WHEN o.status='paid' THEN o.total_amount ELSE 0 END), 0) AS total_spent,
                   MAX(o.created_at) AS last_order_at
            FROM marketplace_orders o
            JOIN users u ON u.id = o.user_id
            {where_sql}
            GROUP BY o.user_id, u.full_name, u.phone
            ORDER BY last_order_at DESC
            LIMIT %s OFFSET %s
            """,
            params + [per_page, offset],
        ).fetchall()

    items = [{
        'user_id': int(r['user_id']),
        'full_name': r.get('full_name') or '',
        'phone': r.get('phone') or '',
        'total_orders': int(r['total_orders']),
        'total_spent': float(r['total_spent']),
        'last_order_at': str(r.get('last_order_at') or ''),
    } for r in (rows or [])]

    return jsonify({'ok': True, 'data': {
        'items': items, 'total': total, 'page': page,
        'per_page': per_page, 'pages': max(1, -(-total // per_page)),
    }})


# ── Customer detail ────────────────────────────────────────────────

@marketplace_bp.get('/admin/customers/<int:user_id>')
@auth_required
def admin_customer_detail(user_id: int):
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    with get_connection() as conn:
        user_row = conn.execute(
            'SELECT id, full_name, phone FROM users WHERE id = %s LIMIT 1', (user_id,)
        ).fetchone()
        if not user_row:
            return api_error('Користувача не знайдено.', 404)

        stats_row = conn.execute(
            """
            SELECT COUNT(id) AS total_orders,
                   COALESCE(SUM(CASE WHEN status='paid' THEN total_amount ELSE 0 END), 0) AS total_spent
            FROM marketplace_orders WHERE user_id = %s
            """, (user_id,),
        ).fetchone()

        orders = conn.execute(
            """
            SELECT id, total_amount, currency, status, created_at,
                   shipping_name, shipping_phone, shipping_address, invoice_number
            FROM marketplace_orders WHERE user_id = %s ORDER BY id DESC LIMIT 50
            """, (user_id,),
        ).fetchall()

    return jsonify({'ok': True, 'data': {
        'user_id': int(user_row['id']),
        'full_name': user_row.get('full_name') or '',
        'phone': user_row.get('phone') or '',
        'total_orders': int((stats_row or {}).get('total_orders') or 0),
        'total_spent': float((stats_row or {}).get('total_spent') or 0),
        'orders': [{
            'id': int(r['id']),
            'total_amount': float(r['total_amount']),
            'currency': r.get('currency') or 'TAX',
            'status': r.get('status') or '',
            'created_at': str(r.get('created_at') or ''),
            'shipping_name': r.get('shipping_name') or '',
            'shipping_phone': r.get('shipping_phone') or '',
            'shipping_address': r.get('shipping_address') or '',
            'invoice_number': r.get('invoice_number') or '',
        } for r in (orders or [])],
    }})


# ── Order detail (with items) ──────────────────────────────────────

@marketplace_bp.get('/admin/orders/<int:order_id>')
@auth_required
def admin_order_detail(order_id: int):
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    with get_connection() as conn:
        o = conn.execute(
            """
            SELECT o.id, o.total_amount, o.currency, o.status, o.payment_mode,
                   o.invoice_number, o.shipping_name, o.shipping_phone,
                   o.shipping_address, o.note, o.created_at,
                   u.full_name AS user_name, u.phone AS user_phone
            FROM marketplace_orders o
            JOIN users u ON u.id = o.user_id
            WHERE o.id = %s LIMIT 1
            """, (order_id,),
        ).fetchone()
        if not o:
            return api_error('Замовлення не знайдено.', 404)

        items = conn.execute(
            """
            SELECT oi.id, oi.title, oi.price, oi.qty, oi.line_total,
                   oi.product_id, COALESCE(p.image_emoji, '🛍️') AS image_emoji
            FROM marketplace_order_items oi
            LEFT JOIN marketplace_products p ON p.id = oi.product_id
            WHERE oi.order_id = %s
            ORDER BY oi.id ASC
            """, (order_id,),
        ).fetchall()

    return jsonify({'ok': True, 'data': {
        'id': int(o['id']),
        'total_amount': float(o['total_amount']),
        'currency': o.get('currency') or 'TAX',
        'status': o.get('status') or '',
        'payment_mode': o.get('payment_mode') or '',
        'invoice_number': o.get('invoice_number') or '',
        'shipping_name': o.get('shipping_name') or '',
        'shipping_phone': o.get('shipping_phone') or '',
        'shipping_address': o.get('shipping_address') or '',
        'note': o.get('note') or '',
        'created_at': str(o.get('created_at') or ''),
        'user_name': o.get('user_name') or '',
        'user_phone': o.get('user_phone') or '',
        'items': [{
            'id': int(r['id']),
            'title': r.get('title') or '',
            'price': float(r['price']),
            'qty': int(r['qty']),
            'line_total': float(r['line_total']),
            'image_emoji': r.get('image_emoji') or '🛍️',
        } for r in (items or [])],
    }})


# ── Analytics — daily revenue last 30 days ─────────────────────────

@marketplace_bp.get('/admin/analytics')
@auth_required
def admin_analytics():
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    from ..config import USE_PG
    if USE_PG:
        date_expr   = "DATE_TRUNC('day', created_at)::date"
        cutoff_expr = "NOW() - INTERVAL '30 days'"
    else:
        date_expr   = "DATE(created_at)"
        cutoff_expr = "datetime('now', '-30 days')"

    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT {date_expr} AS day,
                   COALESCE(SUM(CASE WHEN status='paid' THEN total_amount ELSE 0 END), 0) AS revenue,
                   COUNT(*) AS orders_count
            FROM marketplace_orders
            WHERE created_at >= {cutoff_expr}
            GROUP BY {date_expr}
            ORDER BY day ASC
            """
        ).fetchall()

        # Category distribution (top products by revenue)
        top_cats = conn.execute(
            """
            SELECT p.image_emoji AS emoji, p.title,
                   COALESCE(SUM(oi.line_total), 0) AS revenue,
                   COALESCE(SUM(oi.qty), 0) AS units
            FROM marketplace_products p
            JOIN marketplace_order_items oi ON oi.product_id = p.id
            JOIN marketplace_orders o ON o.id = oi.order_id AND o.status = 'paid'
            GROUP BY p.id, p.image_emoji, p.title
            ORDER BY revenue DESC
            LIMIT 8
            """
        ).fetchall()

    return jsonify({'ok': True, 'data': {
        'daily': [{'day': str(r['day']), 'revenue': float(r['revenue']),
                   'orders_count': int(r['orders_count'])} for r in (rows or [])],
        'top_products': [{'emoji': r['emoji'], 'title': r['title'],
                          'revenue': float(r['revenue']), 'units': int(r['units'])}
                         for r in (top_cats or [])],
    }})


# ── CSV export ─────────────────────────────────────────────────────

@marketplace_bp.get('/admin/export/orders.csv')
@auth_required
def admin_export_orders_csv():
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    import csv
    import io

    date_from = str(request.args.get('from') or '').strip()
    date_to   = str(request.args.get('to')   or '').strip()
    where_parts: list[str] = []
    params: list = []
    if date_from:
        where_parts.append('o.created_at >= %s')
        params.append(date_from)
    if date_to:
        where_parts.append('o.created_at <= %s')
        params.append(date_to + ' 23:59:59')
    where_sql = ('WHERE ' + ' AND '.join(where_parts)) if where_parts else ''

    with get_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT o.id, o.created_at, u.full_name, u.phone,
                   o.shipping_name, o.shipping_phone, o.shipping_address,
                   o.total_amount, o.currency, o.status, o.invoice_number, o.note
            FROM marketplace_orders o
            JOIN users u ON u.id = o.user_id
            {where_sql}
            ORDER BY o.id DESC LIMIT 10000
            """, params,
        ).fetchall()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['ID', 'Дата', 'Клієнт', 'Телефон акаунту', 'Отримувач',
                     'Тел. доставки', 'Адреса', 'Сума', 'Валюта', 'Статус',
                     'Рахунок-фактура', 'Нотатка'])
    for r in (rows or []):
        writer.writerow([
            r['id'], r['created_at'], r.get('full_name', ''), r.get('phone', ''),
            r.get('shipping_name', ''), r.get('shipping_phone', ''),
            r.get('shipping_address', ''), r['total_amount'],
            r.get('currency', 'TAX'), r.get('status', ''),
            r.get('invoice_number', ''), r.get('note', ''),
        ])

    resp = make_response('\ufeff' + output.getvalue())
    resp.headers['Content-Type'] = 'text/csv; charset=utf-8'
    resp.headers['Content-Disposition'] = 'attachment; filename="marketplace-orders.csv"'
    return resp


@marketplace_bp.get('/order/<int:order_id>/receipt')
@auth_required
def order_receipt_pdf(order_id: int):
    """Генерує PDF-квитанцію про оплату замовлення у маркетплейсі."""
    user_id = int(g.current_user['id'])
    try:
        from ..services.statement_service import StatementService

        with get_connection() as conn:
            row = conn.execute(
                """
                SELECT o.id, o.payment_tx_id, o.status, o.total_amount,
                       o.invoice_number, o.shipping_name, o.created_at
                FROM marketplace_orders o
                WHERE o.id = %s AND o.user_id = %s
                LIMIT 1
                """,
                (order_id, user_id),
            ).fetchone()

        if not row:
            return api_error('Замовлення не знайдено.', 404)

        tx_id = int((row.get('payment_tx_id') or 0))
        if not tx_id:
            return api_error('Оплату ще не здійснено — квитанція недоступна.', 409)

        receipt = StatementService().generate_receipt_with_meta(user_id, tx_id)
        pdf_bytes = receipt['pdf_bytes']

        inv = str(row.get('invoice_number') or order_id)
        filename = f'receipt-{inv}.pdf'
        return Response(
            pdf_bytes,
            mimetype='application/pdf',
            headers={
                'Content-Disposition': f'attachment; filename="{filename}"; filename*=UTF-8\'\'{quote(filename)}',
                'Cache-Control': 'no-store',
            },
        )
    except Exception as exc:
        return api_error(str(exc))


# ═══════════════════════════════════════════════════════════════════
#  SEED — real products with photos (admin only, idempotent)
# ═══════════════════════════════════════════════════════════════════

REAL_PRODUCTS = [

    # ══════════════════════════════════════════════════════════════
    # СМАРТФОНИ
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'apple-iphone-15-pro-256',
        'title': 'Apple iPhone 15 Pro 256GB',
        'description': 'Титановий корпус, чіп A17 Pro, основна камера 48 МП з оптичним зумом 5×, USB-C зі швидкістю USB 3, Action Button. Дисплей Super Retina XDR 6.1" ProMotion 120 Гц.',
        'price': 44999, 'currency': 'TAX', 'image_emoji': '📱',
        'image_url': 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=700&q=85&fit=crop',
        'badge': 'NEW', 'stock': 12,
    },
    {
        'slug': 'apple-iphone-15-128',
        'title': 'Apple iPhone 15 128GB',
        'description': 'Чіп A16 Bionic, Dynamic Island, камера 48 МП, USB-C, Ceramic Shield, iOS 17. Колір: чорний зоряний.',
        'price': 33999, 'currency': 'TAX', 'image_emoji': '📱',
        'image_url': 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?w=700&q=85&fit=crop',
        'badge': None, 'stock': 24,
    },
    {
        'slug': 'samsung-galaxy-s24-ultra',
        'title': 'Samsung Galaxy S24 Ultra 256GB',
        'description': 'Snapdragon 8 Gen 3 for Galaxy, камера 200 МП з AI-зумом 100×, вбудований S Pen, Galaxy AI, екран Dynamic AMOLED 2X 6.8" 120 Гц.',
        'price': 38999, 'currency': 'TAX', 'image_emoji': '📱',
        'image_url': 'https://images.unsplash.com/photo-1610945415295-d9bbf067e59c?w=700&q=85&fit=crop',
        'badge': 'HOT', 'stock': 8,
    },
    {
        'slug': 'samsung-galaxy-s24-plus',
        'title': 'Samsung Galaxy S24+ 256GB',
        'description': 'Snapdragon 8 Gen 3, Dynamic AMOLED 2X 6.7" 120 Гц, акумулятор 4900 мАг, 45 Вт зарядка, IP68, Galaxy AI.',
        'price': 29999, 'currency': 'TAX', 'image_emoji': '📱',
        'image_url': 'https://images.unsplash.com/photo-1567581935884-3349723552ca?w=700&q=85&fit=crop',
        'badge': None, 'stock': 15,
    },
    {
        'slug': 'google-pixel-9-pro',
        'title': 'Google Pixel 9 Pro 128GB',
        'description': 'Tensor G4, Magic Eraser, Best Take, добового знімання в класі, 7 років оновлень Android. LTPO OLED 6.3" до 120 Гц.',
        'price': 29999, 'currency': 'TAX', 'image_emoji': '📱',
        'image_url': 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=700&q=85&fit=crop',
        'badge': None, 'stock': 5,
    },
    {
        'slug': 'xiaomi-14-ultra',
        'title': 'Xiaomi 14 Ultra 512GB',
        'description': 'Snapdragon 8 Gen 3, камера Leica Summilux 1" Sony LYT-900 50 МП, HyperOS, 90 Вт дротова зарядка + 80 Вт бездротова.',
        'price': 41999, 'currency': 'TAX', 'image_emoji': '📱',
        'image_url': 'https://images.unsplash.com/photo-1574944985070-8f3ebc6b79d2?w=700&q=85&fit=crop',
        'badge': 'PRO', 'stock': 6,
    },
    {
        'slug': 'oneplus-12-256',
        'title': 'OnePlus 12 256GB',
        'description': 'Snapdragon 8 Gen 3, Hasselblad камера 50 МП, 100 Вт SUPERVOOC, 50 Вт бездротова, AMOLED 6.82" 120 Гц, акум 5400 мАг.',
        'price': 24999, 'currency': 'TAX', 'image_emoji': '📱',
        'image_url': 'https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=700&q=85&fit=crop',
        'badge': 'SALE', 'stock': 11,
    },
    {
        'slug': 'samsung-galaxy-a55-5g',
        'title': 'Samsung Galaxy A55 5G 256GB',
        'description': 'Exynos 1480, Super AMOLED 6.6" 120 Гц, потрійна камера 50+12+5 МП, акум 5000 мАг, IP67, алюмінієвий корпус.',
        'price': 14999, 'currency': 'TAX', 'image_emoji': '📱',
        'image_url': 'https://images.unsplash.com/photo-1581993192873-5b53ce935000?w=700&q=85&fit=crop',
        'badge': None, 'stock': 30,
    },
    {
        'slug': 'xiaomi-redmi-note-13-pro-plus',
        'title': 'Xiaomi Redmi Note 13 Pro+ 5G 256GB',
        'description': 'MediaTek Dimensity 7200-Ultra, камера 200 МП OIS, 120 Вт HyperCharge, AMOLED 6.67" 120 Гц, IP68.',
        'price': 12999, 'currency': 'TAX', 'image_emoji': '📱',
        'image_url': 'https://images.unsplash.com/photo-1598033129183-c4f50c736f10?w=700&q=85&fit=crop',
        'badge': 'DEAL', 'stock': 40,
    },

    # ══════════════════════════════════════════════════════════════
    # НОУТБУКИ
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'apple-macbook-air-m3-15',
        'title': 'Apple MacBook Air 15" M3 16/512',
        'description': 'Чіп Apple M3 8-ядер CPU + 10-ядер GPU, 16 ГБ RAM, 512 ГБ SSD, Liquid Retina 15.3", до 18 год автономності, MagSafe 3.',
        'price': 64999, 'currency': 'TAX', 'image_emoji': '💻',
        'image_url': 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=700&q=85&fit=crop',
        'badge': 'M3', 'stock': 6,
    },
    {
        'slug': 'apple-macbook-pro-14-m3-pro',
        'title': 'Apple MacBook Pro 14" M3 Pro',
        'description': 'M3 Pro 11-ядер CPU / 14-ядер GPU, 18 ГБ Unified Memory, 512 ГБ SSD, Liquid Retina XDR 120 Гц, ProMotion, HDMI 2.1, SD.',
        'price': 89999, 'currency': 'TAX', 'image_emoji': '💻',
        'image_url': 'https://images.unsplash.com/photo-1611186871525-a7b9617c3a05?w=700&q=85&fit=crop',
        'badge': 'PRO', 'stock': 4,
    },
    {
        'slug': 'asus-rog-strix-g16-2024',
        'title': 'ASUS ROG Strix G16 (2024)',
        'description': 'Intel Core i9-14900HX, GeForce RTX 4080 16 ГБ, 32 ГБ DDR5, 1 ТБ NVMe PCIe 4.0, QHD 240 Гц, ROG Intelligent Cooling.',
        'price': 89999, 'currency': 'TAX', 'image_emoji': '💻',
        'image_url': 'https://images.unsplash.com/photo-1603481546238-487240415921?w=700&q=85&fit=crop',
        'badge': 'GAMING', 'stock': 3,
    },
    {
        'slug': 'dell-xps-15-9530',
        'title': 'Dell XPS 15 9530',
        'description': 'Intel Core i7-13700H, OLED 3.5K InfinityEdge 60 Гц, 16 ГБ LPDDR5, 512 ГБ SSD, RTX 4060 8 ГБ, Thunderbolt 4.',
        'price': 69999, 'currency': 'TAX', 'image_emoji': '💻',
        'image_url': 'https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=700&q=85&fit=crop',
        'badge': None, 'stock': 4,
    },
    {
        'slug': 'lenovo-thinkpad-x1-carbon-g12',
        'title': 'Lenovo ThinkPad X1 Carbon Gen 12',
        'description': 'Intel Core Ultra 7 165U, 32 ГБ LPDDR5X, 1 ТБ SSD, IPS 14" 2.8K OLED 120 Гц, вага 1.12 кг, MIL-SPEC, 57 Вт-год.',
        'price': 74999, 'currency': 'TAX', 'image_emoji': '💻',
        'image_url': 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=700&q=85&fit=crop',
        'badge': 'TOP', 'stock': 5,
    },
    {
        'slug': 'hp-spectre-x360-14',
        'title': 'HP Spectre x360 14" OLED',
        'description': 'Intel Core Ultra 7 155H, OLED 2.8K 120 Гц сенсорний, 32 ГБ LPDDR5, 2 ТБ SSD, 360° шарнір, OMEN AI, батарея 66 Вт-год.',
        'price': 67999, 'currency': 'TAX', 'image_emoji': '💻',
        'image_url': 'https://images.unsplash.com/photo-1541807084-5c52b6b3adef?w=700&q=85&fit=crop',
        'badge': None, 'stock': 4,
    },
    {
        'slug': 'asus-zenbook-14-oled',
        'title': 'ASUS ZenBook 14 OLED',
        'description': 'AMD Ryzen 7 8845HS, OLED 2.8K 120 Гц, 16 ГБ LPDDR5X, 1 ТБ SSD PCIe 4.0, вага 1.2 кг, ErgoSense клавіатура, USB4.',
        'price': 41999, 'currency': 'TAX', 'image_emoji': '💻',
        'image_url': 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=700&q=85&fit=crop',
        'badge': 'SALE', 'stock': 7,
    },

    # ══════════════════════════════════════════════════════════════
    # ПЛАНШЕТИ
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'apple-ipad-pro-m4-11',
        'title': 'Apple iPad Pro 11" M4 256GB',
        'description': 'Чіп M4, найтонший OLED Ultra Retina XDR дисплей, Wi-Fi 6E, Apple Pencil Pro, Magic Keyboard Folio, USB 4 Thunderbolt.',
        'price': 42999, 'currency': 'TAX', 'image_emoji': '📲',
        'image_url': 'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?w=700&q=85&fit=crop',
        'badge': 'M4', 'stock': 5,
    },
    {
        'slug': 'apple-ipad-air-m2-11',
        'title': 'Apple iPad Air 11" M2 128GB',
        'description': 'Чіп M2, Liquid Retina 11", Touch ID, 12 МП фронтальна камера, USB-C, Wi-Fi 6E, до 10 год автономності.',
        'price': 28999, 'currency': 'TAX', 'image_emoji': '📲',
        'image_url': 'https://images.unsplash.com/photo-1561154464-82e9adf32764?w=700&q=85&fit=crop',
        'badge': None, 'stock': 10,
    },
    {
        'slug': 'samsung-galaxy-tab-s9-fe',
        'title': 'Samsung Galaxy Tab S9 FE 256GB',
        'description': 'Exynos 1380, TFT 10.9" 90 Гц, S Pen у комплекті, IP68, 8 ГБ RAM, 8000 мАг, DeX режим.',
        'price': 14999, 'currency': 'TAX', 'image_emoji': '📲',
        'image_url': 'https://images.unsplash.com/photo-1586143779970-4eeec4aad8de?w=700&q=85&fit=crop',
        'badge': 'DEAL', 'stock': 18,
    },

    # ══════════════════════════════════════════════════════════════
    # АУДІО — НАВУШНИКИ
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'sony-wh-1000xm5',
        'title': 'Sony WH-1000XM5',
        'description': 'Найкраще шумоподавлення у класі, 8 мікрофонів, 30 год заряду, LDAC Hi-Res, Multipoint, Speak-to-Chat. Складана конструкція.',
        'price': 9999, 'currency': 'TAX', 'image_emoji': '🎧',
        'image_url': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=700&q=85&fit=crop',
        'badge': 'HOT', 'stock': 15,
    },
    {
        'slug': 'bose-qc45',
        'title': 'Bose QuietComfort 45',
        'description': 'Активне шумоподавлення TriPort, 24 год заряду, режим Aware, Bluetooth 5.1, вага 238 г. Бездротові + аналоговий кабель.',
        'price': 8999, 'currency': 'TAX', 'image_emoji': '🎧',
        'image_url': 'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=700&q=85&fit=crop',
        'badge': None, 'stock': 12,
    },
    {
        'slug': 'apple-airpods-pro-2',
        'title': 'Apple AirPods Pro 2 (USB-C)',
        'description': 'H2 чіп, адаптивне прозорість, Conversation Awareness, Lossless Audio, до 6 год (30 год із кейсом), IP54.',
        'price': 8499, 'currency': 'TAX', 'image_emoji': '🎧',
        'image_url': 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=700&q=85&fit=crop',
        'badge': None, 'stock': 20,
    },
    {
        'slug': 'samsung-galaxy-buds-2-pro',
        'title': 'Samsung Galaxy Buds2 Pro',
        'description': '24-бітний звук Hi-Fi, ANC з шумоподавленням 2.0, IPX7, до 8 год (29 год із кейсом), Bixby голосове керування.',
        'price': 5499, 'currency': 'TAX', 'image_emoji': '🎧',
        'image_url': 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=700&q=85&fit=crop',
        'badge': 'SALE', 'stock': 25,
    },
    {
        'slug': 'jbl-charge-5',
        'title': 'JBL Charge 5',
        'description': 'Потужний Bluetooth-динамік, IP67, PartyBoost, потужність 30 Вт, до 20 год роботи, вбудований павербанк, USB-A.',
        'price': 3999, 'currency': 'TAX', 'image_emoji': '🔊',
        'image_url': 'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=700&q=85&fit=crop',
        'badge': None, 'stock': 35,
    },
    {
        'slug': 'sonos-era-300',
        'title': 'Sonos Era 300',
        'description': 'Просторовий звук Dolby Atmos, 6 підсилювачів, Wi-Fi 6, Bluetooth, AirPlay 2, Trueplay автонастройка.',
        'price': 12999, 'currency': 'TAX', 'image_emoji': '🔊',
        'image_url': 'https://images.unsplash.com/photo-1545454675-3531b543be5d?w=700&q=85&fit=crop',
        'badge': 'TOP', 'stock': 8,
    },

    # ══════════════════════════════════════════════════════════════
    # РОЗУМНІ ГОДИННИКИ / WEARABLES
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'apple-watch-series-9-45',
        'title': 'Apple Watch Series 9 45mm',
        'description': 'S9 SiP, жест Double Tap, Always-On Retina дисплей 2000 ніт, ЕКГ, SpO2, температура тіла, Crash Detection, WR50.',
        'price': 14999, 'currency': 'TAX', 'image_emoji': '⌚',
        'image_url': 'https://images.unsplash.com/photo-1434494878577-86c23bcb06b9?w=700&q=85&fit=crop',
        'badge': None, 'stock': 9,
    },
    {
        'slug': 'apple-watch-ultra-2',
        'title': 'Apple Watch Ultra 2 49mm',
        'description': 'S9 SiP, титановий корпус, 3000 ніт, точний GPS L1+L5, Action Button, до 60 год у режимі Ultralow Power, WR100 EN13319.',
        'price': 29999, 'currency': 'TAX', 'image_emoji': '⌚',
        'image_url': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=700&q=85&fit=crop',
        'badge': 'PRO', 'stock': 4,
    },
    {
        'slug': 'samsung-galaxy-watch-7-44',
        'title': 'Samsung Galaxy Watch 7 44mm',
        'description': 'BioActive Sensor, AI Energy Score, добовий трекінг здоров\'я, AMOLED 1.5", до 40 год, Galaxy AI Coach, 5ATM+IP68.',
        'price': 9999, 'currency': 'TAX', 'image_emoji': '⌚',
        'image_url': 'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?w=700&q=85&fit=crop',
        'badge': None, 'stock': 14,
    },
    {
        'slug': 'garmin-fenix-7-pro',
        'title': 'Garmin Fenix 7 Pro Solar',
        'description': 'Сонячна зарядка, мультисмуговий GPS, TOPO-мапи, пульсоксиметр, до 37 днів, сапфірове скло, RunIQ спортивні метрики.',
        'price': 24999, 'currency': 'TAX', 'image_emoji': '⌚',
        'image_url': 'https://images.unsplash.com/photo-1551816230-ef5deaed4a26?w=700&q=85&fit=crop',
        'badge': 'TOP', 'stock': 6,
    },

    # ══════════════════════════════════════════════════════════════
    # МОНІТОРИ
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'lg-ultragear-27gp95r',
        'title': 'LG UltraGear 27" 4K OLED 240Гц',
        'description': 'OLED 4K UHD 240 Гц, 0.03 мс GTG, G-Sync Compatible, HDR True Black 400, DisplayPort 1.4, HDMI 2.1 4K@144 Гц.',
        'price': 39999, 'currency': 'TAX', 'image_emoji': '🖥️',
        'image_url': 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=700&q=85&fit=crop',
        'badge': 'HOT', 'stock': 5,
    },
    {
        'slug': 'samsung-odyssey-g9-49',
        'title': 'Samsung Odyssey G9 49" DQHD',
        'description': 'Вигнутий 49" 1000R, 5120×1440 DQHD, VA 240 Гц, 1 мс MPRT, HDR1000, G-Sync + FreeSync Premium Pro, USB-хаб.',
        'price': 49999, 'currency': 'TAX', 'image_emoji': '🖥️',
        'image_url': 'https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=700&q=85&fit=crop',
        'badge': 'GAMING', 'stock': 3,
    },
    {
        'slug': 'dell-u2723qe-27-4k',
        'title': 'Dell UltraSharp 27" 4K USB-C',
        'description': 'IPS Black 4K 60 Гц, 2000:1 контраст, DCI-P3 98%, USB-C 90 Вт Power Delivery, KVM-перемикач, розкладна ніжка.',
        'price': 22999, 'currency': 'TAX', 'image_emoji': '🖥️',
        'image_url': 'https://images.unsplash.com/photo-1487017159836-4e23ece2e4cf?w=700&q=85&fit=crop',
        'badge': None, 'stock': 8,
    },

    # ══════════════════════════════════════════════════════════════
    # ІГРОВІ КОНСОЛІ / GAMING
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'sony-playstation-5-slim',
        'title': 'Sony PlayStation 5 Slim + Spider-Man 2',
        'description': '4K 120 fps, SSD 1 ТБ кастомний, DualSense з гаптикою, Ray Tracing, ALLM, VRR, Tempest 3D Audio, гра у комплекті.',
        'price': 21999, 'currency': 'TAX', 'image_emoji': '🎮',
        'image_url': 'https://images.unsplash.com/photo-1606813907291-d86efa9b94db?w=700&q=85&fit=crop',
        'badge': 'BUNDLE', 'stock': 7,
    },
    {
        'slug': 'microsoft-xbox-series-x',
        'title': 'Microsoft Xbox Series X 1TB',
        'description': '4K 120fps, SSD 1 ТБ, Quick Resume, Auto HDR, Smart Delivery, Game Pass Ultimate 3 міс., зворотна сумісність 4000+ ігор.',
        'price': 17999, 'currency': 'TAX', 'image_emoji': '🎮',
        'image_url': 'https://images.unsplash.com/photo-1621259182978-fbf93132d53d?w=700&q=85&fit=crop',
        'badge': None, 'stock': 5,
    },
    {
        'slug': 'nintendo-switch-oled',
        'title': 'Nintendo Switch OLED White',
        'description': '7" OLED-екран з живими кольорами, 64 ГБ вбудованої пам\'яті, покращений звук, широка підставка, LAN-порт у доці.',
        'price': 13499, 'currency': 'TAX', 'image_emoji': '🎮',
        'image_url': 'https://images.unsplash.com/photo-1578303512597-81e6cc155b3e?w=700&q=85&fit=crop',
        'badge': None, 'stock': 10,
    },
    {
        'slug': 'razer-blackwidow-v4-pro',
        'title': 'Razer BlackWidow V4 Pro (Green)',
        'description': 'Razer Green механічні перемикачі, бездротовий 2.4 ГГц + BT, Chroma RGB, Media Dial, Magnetic Wrist Rest, N-Key Rollover.',
        'price': 7999, 'currency': 'TAX', 'image_emoji': '⌨️',
        'image_url': 'https://images.unsplash.com/photo-1541140532-eb96c28cae42?w=700&q=85&fit=crop',
        'badge': None, 'stock': 16,
    },
    {
        'slug': 'logitech-mx-master-3s',
        'title': 'Logitech MX Master 3S',
        'description': '8000 DPI сенсор, MagSpeed ​​електромагнітне колесо, безшумні кнопки, до 70 год, USB-C, Flow міжпристроєве керування.',
        'price': 3999, 'currency': 'TAX', 'image_emoji': '🖱️',
        'image_url': 'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=700&q=85&fit=crop',
        'badge': 'TOP', 'stock': 40,
    },

    # ══════════════════════════════════════════════════════════════
    # ФОТОАПАРАТИ / КАМЕРИ
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'sony-a7-iv',
        'title': 'Sony Alpha A7 IV Body',
        'description': 'BSI CMOS 33 МП повний кадр, AF на очі та тварин, 4K 60fps 10-bit, IBIS 5.5 ступеня, 828 кадрів на заряд, Weather Sealed.',
        'price': 84999, 'currency': 'TAX', 'image_emoji': '📷',
        'image_url': 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=700&q=85&fit=crop',
        'badge': 'PRO', 'stock': 3,
    },
    {
        'slug': 'canon-eos-r50',
        'title': 'Canon EOS R50 + 18-45mm Kit',
        'description': 'APS-C 24.2 МП, 4K без кадрування, AF Dual Pixel CMOS II, Vari-Angle дисплей, до 15 кадрів/с RAW, Wi-Fi + BT.',
        'price': 27999, 'currency': 'TAX', 'image_emoji': '📷',
        'image_url': 'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=700&q=85&fit=crop',
        'badge': 'NEW', 'stock': 6,
    },
    {
        'slug': 'gopro-hero-12-black',
        'title': 'GoPro HERO12 Black',
        'description': '5.3K60 + 4K120 відео, HyperSmooth 6.0, водонепроникний до 10 м, 1/1.9" сенсор, Max Lens Mod 2.0 сумісний.',
        'price': 12999, 'currency': 'TAX', 'image_emoji': '📷',
        'image_url': 'https://images.unsplash.com/photo-1502977249166-824b3a8a4d6d?w=700&q=85&fit=crop',
        'badge': None, 'stock': 14,
    },

    # ══════════════════════════════════════════════════════════════
    # ТЕХНІКА ДЛЯ ДОМУ
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'samsung-qled-55-q80d',
        'title': 'Samsung QLED 55" Q80D 4K 144Гц',
        'description': 'Технологія Quantum Dot, 4K 144 Гц, Neural Quantum Processor 4K, Object Tracking Sound+, Motion Xcelerator Turbo+.',
        'price': 29999, 'currency': 'TAX', 'image_emoji': '📺',
        'image_url': 'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=700&q=85&fit=crop',
        'badge': 'QLED', 'stock': 4,
    },
    {
        'slug': 'lg-oled-65-c3',
        'title': 'LG OLED 65" evo C3 4K 120Гц',
        'description': 'OLED evo α9 Gen6 AI, Dolby Vision IQ + Atmos, HDMI 2.1 ×4, 4K 120 Гц, G-Sync, FreeSync, webOS 23, Magic Remote.',
        'price': 54999, 'currency': 'TAX', 'image_emoji': '📺',
        'image_url': 'https://images.unsplash.com/photo-1567690187548-f07b1d7bf5a9?w=700&q=85&fit=crop',
        'badge': 'OLED', 'stock': 5,
    },
    {
        'slug': 'delonghi-dinamica-plus',
        'title': 'DeLonghi Dinamica Plus ECAM370',
        'description': 'Зернова кавомашина, 13-ступінчастий млин, LatteCrema Hot System, 15 напоїв через TFT-дисплей, ECAM370.95.T, латте на льоду.',
        'price': 18999, 'currency': 'TAX', 'image_emoji': '☕',
        'image_url': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=700&q=85&fit=crop',
        'badge': None, 'stock': 6,
    },
    {
        'slug': 'dyson-v15-detect',
        'title': 'Dyson V15 Detect Absolute',
        'description': 'Лазерне виявлення пилу, 280 AW всмоктування, HEPA-фільтр, 60 хв автономності, LCD Real Count дисплей, 11 насадок.',
        'price': 22999, 'currency': 'TAX', 'image_emoji': '🌀',
        'image_url': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=700&q=85&fit=crop',
        'badge': None, 'stock': 8,
    },
    {
        'slug': 'xiaomi-robot-vacuum-s20',
        'title': 'Xiaomi Robot Vacuum S20+',
        'description': 'LiDAR навігація, 6000 Па всмоктування, авто-спорожнення станція 2.5 л, 3-в-1 пилосос+швабра+самоочищення, Mi Home App.',
        'price': 13999, 'currency': 'TAX', 'image_emoji': '🤖',
        'image_url': 'https://images.unsplash.com/photo-1572894773815-71c1feee7d9f?w=700&q=85&fit=crop',
        'badge': 'HOT', 'stock': 11,
    },
    {
        'slug': 'irobot-roomba-j9-plus',
        'title': 'iRobot Roomba j9+ Self-Empty',
        'description': 'Smart Mapping + 3D-сенсор, Auto-Empty 60 днів, PrecisionVision для перешкод, 100% більше всмоктування, Imprint Link.',
        'price': 29999, 'currency': 'TAX', 'image_emoji': '🤖',
        'image_url': 'https://images.unsplash.com/photo-1609081219090-a6d81d3085bf?w=700&q=85&fit=crop',
        'badge': None, 'stock': 5,
    },
    {
        'slug': 'philips-3200-lattego',
        'title': 'Philips Series 3200 LatteGo EP3246',
        'description': 'Кавомашина з LatteGo молочною системою, AdvancedBrew, 5 ступенів міцності, керамічний млин, 6 напоїв, тихий режим.',
        'price': 14999, 'currency': 'TAX', 'image_emoji': '☕',
        'image_url': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=700&q=85&fit=crop',
        'badge': 'DEAL', 'stock': 9,
    },

    # ══════════════════════════════════════════════════════════════
    # РОЗУМНИЙ ДІМ / SMART HOME
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'philips-hue-starter-e27',
        'title': 'Philips Hue Starter Kit E27 (4 лампи + Bridge)',
        'description': '16 млн кольорів, Zigbee Bridge, сумісність з Alexa / Google / Apple HomeKit, розклади, сцени, Hue Entertainment sync.',
        'price': 4999, 'currency': 'TAX', 'image_emoji': '💡',
        'image_url': 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=700&q=85&fit=crop',
        'badge': None, 'stock': 20,
    },
    {
        'slug': 'amazon-echo-show-10',
        'title': 'Amazon Echo Show 10 (3rd Gen)',
        'description': 'Розумний дисплей 10.1" HD з рухом, Alexa, відео Zoom/Ring, Zigbee-хаб, вбудований динамік 3" + 2×0.8", Wi-Fi 6.',
        'price': 7999, 'currency': 'TAX', 'image_emoji': '🔊',
        'image_url': 'https://images.unsplash.com/photo-1518444065439-e933c06ce9cd?w=700&q=85&fit=crop',
        'badge': None, 'stock': 12,
    },
    {
        'slug': 'xiaomi-smart-air-purifier-4-pro',
        'title': 'Xiaomi Smart Air Purifier 4 Pro',
        'description': 'HEPA H13 + активоване вугілля, 60 м² до 500 м³/год CADR, лазерний датчик PM2.5, OLED-дисплей, Mi Home, 38 дБ.',
        'price': 6999, 'currency': 'TAX', 'image_emoji': '🌬️',
        'image_url': 'https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=700&q=85&fit=crop',
        'badge': None, 'stock': 15,
    },

    # ══════════════════════════════════════════════════════════════
    # ДРОНИ / ГАДЖЕТИ
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'dji-mini-4-pro',
        'title': 'DJI Mini 4 Pro (RC 2)',
        'description': '4K/60fps HDR, OmniDirectional obstacle sensing, ActiveTrack 360°, 34 хв польоту, вага 249 г, передача на 20 км, VertShot.',
        'price': 34999, 'currency': 'TAX', 'image_emoji': '🚁',
        'image_url': 'https://images.unsplash.com/photo-1579829366248-204fe8413f31?w=700&q=85&fit=crop',
        'badge': 'PRO', 'stock': 3,
    },
    {
        'slug': 'dji-osmo-pocket-3',
        'title': 'DJI Osmo Pocket 3',
        'description': '1" CMOS 20 МП, 4K/120fps, 3-осьовий стабілізатор, OLED-дисплей, ActiveTrack, до 166 хв запису, D-Log M 10-bit.',
        'price': 19999, 'currency': 'TAX', 'image_emoji': '🎥',
        'image_url': 'https://images.unsplash.com/photo-1617802690992-15d93263d3a9?w=700&q=85&fit=crop',
        'badge': None, 'stock': 7,
    },

    # ══════════════════════════════════════════════════════════════
    # АКСЕСУАРИ / ЗАРЯДКИ / ПАВЕРБАНКИ
    # ══════════════════════════════════════════════════════════════
    {
        'slug': 'anker-power-bank-26800-pd',
        'title': 'Anker PowerCore 26800mAh 65W PD',
        'description': 'Ємність 26800 мАг, 65 Вт Power Delivery для ноутбуків, USB-C + 2×USB-A, 3 одночасні пристрої, PowerIQ 3.0.',
        'price': 2999, 'currency': 'TAX', 'image_emoji': '🔋',
        'image_url': 'https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?w=700&q=85&fit=crop',
        'badge': 'SALE', 'stock': 45,
    },
    {
        'slug': 'belkin-gan-65w-charger',
        'title': 'Belkin GaN 65W 3-Port Charger',
        'description': 'GaN технологія, 2×USB-C + 1×USB-A, 65 Вт сукупна потужність, Intelligent Power Sharing, захист від перегріву.',
        'price': 1999, 'currency': 'TAX', 'image_emoji': '🔌',
        'image_url': 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=700&q=85&fit=crop',
        'badge': None, 'stock': 60,
    },
    {
        'slug': 'apple-magsafe-15w',
        'title': 'Apple MagSafe Charger 15W 1m',
        'description': 'Бездротова зарядка 15 Вт для iPhone 12-16 і AirPods, магнітне центрування, Qi-сумісний 7.5 Вт для старших iPhone.',
        'price': 1599, 'currency': 'TAX', 'image_emoji': '🔌',
        'image_url': 'https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=700&q=85&fit=crop',
        'badge': None, 'stock': 80,
    },
    {
        'slug': 'sandisk-extreme-pro-2tb',
        'title': 'SanDisk Extreme PRO Portable SSD 2TB',
        'description': 'Швидкість 2000 МБ/с читання / 2000 МБ/с запис, USB 3.2 Gen 2×2, IP55 пиловий/водозахист, NVMe PCIe, компактний.',
        'price': 6999, 'currency': 'TAX', 'image_emoji': '💾',
        'image_url': 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=700&q=85&fit=crop',
        'badge': 'TOP', 'stock': 22,
    },

    # ══════════════════════════════════════════════════════════════
    # ARM-BRANDED (synced from munister.com.ua/marketplace)
    # ══════════════════════════════════════════════════════════════
    {'slug':'arm-phone-max-512','title':'TaxTech Phone Max 512GB','description':'Флагманський смартфон 6.8", 120Hz, 120W зарядка, 512GB внутрішньої пам\'яті','price':29999,'currency':'TAX','image_emoji':'📱','image_url':None,'badge':'TOP','stock':18},
    {'slug':'arm-phone-lite-5g-256','title':'TaxTech Phone Lite 5G 256GB','description':'Смартфон 120Hz, NFC, батарея 5000mAh, підтримка 5G','price':13999,'currency':'TAX','image_emoji':'📱','image_url':None,'badge':'DEAL','stock':44},
    {'slug':'arm-phone-ultra-pro','title':'TaxTech Phone Ultra Pro','description':'Титановий чіп, 200MP камера, 12GB RAM, преміум флагман','price':41999,'currency':'TAX','image_emoji':'📱','image_url':None,'badge':'HOT','stock':7},
    {'slug':'arm-phone-pro-256','title':'TaxTech Phone Pro 256GB','description':'Потужний смартфон з камерою 108MP і швидкою зарядкою 67W','price':21999,'currency':'TAX','image_emoji':'📱','image_url':None,'badge':None,'stock':25},
    {'slug':'arm-phone-lite-128','title':'TaxTech Phone Lite 128GB','description':'Доступний смартфон із AMOLED дисплеєм 90Hz і батареєю 5000mAh','price':11999,'currency':'TAX','image_emoji':'📱','image_url':None,'badge':'SALE','stock':35},
    {'slug':'arm-book-pro-15','title':'TaxTech Book Pro 15','description':'Ноутбук 32GB RAM, 1TB SSD, Retina-дисплей, для професіоналів','price':45999,'currency':'TAX','image_emoji':'💻','image_url':None,'badge':'PRO','stock':9},
    {'slug':'arm-book-air-14','title':'TaxTech Book Air 14','description':'Легкий ультрабук 16GB, 512GB SSD, 1.3кг, до 18 год роботи','price':32999,'currency':'TAX','image_emoji':'💻','image_url':None,'badge':'NEW','stock':17},
    {'slug':'arm-monitor-27-qhd','title':'TaxTech Monitor 27" QHD','description':'Монітор 27", 165Hz, HDR, USB-C, ідеальний для роботи і гейму','price':11999,'currency':'TAX','image_emoji':'🖥️','image_url':None,'badge':'HOT','stock':28},
    {'slug':'arm-monitor-24-ips','title':'TaxTech Monitor 24" IPS','description':'IPS монітор 24" Full HD, 75Hz, низька затримка, USB-C hub','price':6999,'currency':'TAX','image_emoji':'🖥️','image_url':None,'badge':None,'stock':20},
    {'slug':'arm-smart-tv-50-4k','title':'TaxTech Smart TV 50" 4K','description':'4K телевізор Dolby Vision, Google TV, 60Hz, Wi-Fi 5, HDMI 2.1','price':18999,'currency':'TAX','image_emoji':'📺','image_url':None,'badge':'TOP','stock':20},
    {'slug':'arm-tablet-11','title':'TaxTech Tablet 11"','description':'Планшет 11" з підтримкою стилуса, 8GB/256GB, 2K дисплей 120Hz','price':15499,'currency':'TAX','image_emoji':'📲','image_url':None,'badge':None,'stock':22},
    {'slug':'arm-earbuds-pro-anc','title':'TaxTech Earbuds Pro ANC','description':'Бездротові навушники з ANC, 36г роботи, IPX4, aptX Adaptive','price':3299,'currency':'TAX','image_emoji':'🎧','image_url':None,'badge':'SALE','stock':32},
    {'slug':'arm-earbuds-lite','title':'TaxTech Earbuds','description':'Бездротові TWS навушники, 24г роботи, BT 5.3, ENC мікрофон','price':1299,'currency':'TAX','image_emoji':'🎧','image_url':None,'badge':None,'stock':60},
    {'slug':'arm-watch-series-4','title':'TaxTech Watch Series 4','description':'Розумний годинник, GPS, ЕКГ, AMOLED, SpO2, 7 днів роботи','price':7899,'currency':'TAX','image_emoji':'⌚','image_url':None,'badge':None,'stock':21},
    {'slug':'arm-speaker-max','title':'TaxTech Speaker Max','description':'Портативна колонка 40W, IPX5, 20 год, AUX+BT 5.3, стерео-пара','price':3999,'currency':'TAX','image_emoji':'🔊','image_url':None,'badge':'SALE','stock':15},
    {'slug':'arm-speaker-mini','title':'TaxTech Speaker Mini','description':'Компактна BT колонка 15W, IPX7, 12 год, TWS режим','price':1299,'currency':'TAX','image_emoji':'🔊','image_url':None,'badge':'TOP','stock':45},
    {'slug':'arm-coffee-pro','title':'TaxTech Coffee Pro','description':'Кавоварка еспресо з капучинатором, 15 бар, термоблок, 1.5л','price':8499,'currency':'TAX','image_emoji':'☕','image_url':None,'badge':None,'stock':12},
    {'slug':'arm-robot-vacuum-x5','title':'TaxTech Robot Vacuum X5','description':'Робот-пилосос LiDAR, вологе прибирання 3000Pa, 150хв роботи','price':12499,'currency':'TAX','image_emoji':'🤖','image_url':None,'badge':'HOT','stock':16},
    {'slug':'arm-stick-vacuum','title':'TaxTech Stick Vacuum','description':'Бездротовий вертикальний пилосос 450W, 45хв, HEPA фільтр','price':6999,'currency':'TAX','image_emoji':'🌀','image_url':None,'badge':None,'stock':18},
    {'slug':'arm-smart-lamp-rgb','title':'TaxTech Smart Lamp RGB','description':'Розумна лампа RGB, голосове керування, 16M кольорів, Wi-Fi','price':1599,'currency':'TAX','image_emoji':'💡','image_url':None,'badge':None,'stock':32},
    {'slug':'arm-smart-lamp','title':'TaxTech Smart Lamp','description':'Розумна LED лампа, регулювання яскравості та температури','price':699,'currency':'TAX','image_emoji':'💡','image_url':None,'badge':None,'stock':50},
    {'slug':'arm-home-security-kit','title':'TaxTech Home Security Kit','description':'Камера + датчики руху/дверей + хаб, Wi-Fi, Alexa/Google Home','price':7299,'currency':'TAX','image_emoji':'🏠','image_url':None,'badge':'DEAL','stock':17},
    {'slug':'arm-air-fryer-pro-55l','title':'TaxTech Air Fryer Pro 5.5L','description':'Фритюрниця 5.5л, 1500W, 8 режимів, цифровий дисплей, таймер','price':4599,'currency':'TAX','image_emoji':'🍳','image_url':None,'badge':'NEW','stock':30},
    {'slug':'arm-air-fryer-xl','title':'TaxTech Air Fryer XL','description':'Фритюрниця 7л, 1700W, 12 режимів, сенсорний дисплей','price':4699,'currency':'TAX','image_emoji':'🍳','image_url':None,'badge':None,'stock':22},
    {'slug':'arm-air-purifier-hepa','title':'TaxTech Air Purifier HEPA','description':'Очищувач повітря HEPA H13, до 50м², PM2.5 сенсор, нічний режим','price':6299,'currency':'TAX','image_emoji':'💨','image_url':None,'badge':'HOT','stock':13},
    {'slug':'arm-smart-kettle','title':'TaxTech Smart Kettle','description':'Розумний чайник 1.7л, 2200W, підтримка температури, Wi-Fi','price':1899,'currency':'TAX','image_emoji':'🫖','image_url':None,'badge':'NEW','stock':28},
    {'slug':'arm-power-bank-26800','title':'TaxTech Power Bank 26800mAh','description':'Power Bank 26800mAh, 65W PD, 3 порти USB-C+A, дисплей','price':2499,'currency':'TAX','image_emoji':'🔋','image_url':None,'badge':'SALE','stock':38},
    {'slug':'arm-powerbank-1899','title':'TaxTech PowerBank','description':'Power Bank 10000mAh, 22.5W, 2 USB-A + 1 USB-C, LED індикатор','price':1899,'currency':'TAX','image_emoji':'🔋','image_url':None,'badge':'NEW','stock':55},
    {'slug':'arm-gan-charger-65w','title':'TaxTech GaN Charger 65W','description':'Компактна GaN зарядка 65W, USB-C + USB-A, PD 3.0, PPS','price':1299,'currency':'TAX','image_emoji':'⚡','image_url':None,'badge':None,'stock':110},
    {'slug':'arm-wireless-mouse-pro','title':'TaxTech Wireless Mouse Pro','description':'Ергономічна бездротова миша 4000dpi, до 70 год, BT 5.0 + 2.4G','price':1399,'currency':'TAX','image_emoji':'🖱️','image_url':None,'badge':None,'stock':90},
    {'slug':'arm-wireless-mouse','title':'TaxTech Wireless Mouse','description':'Бездротова миша 1600dpi, до 30 год, BT 5.0, тихі кнопки','price':699,'currency':'TAX','image_emoji':'🖱️','image_url':None,'badge':None,'stock':75},
    {'slug':'arm-mechanical-keyboard','title':'TaxTech Mechanical Keyboard','description':'Механічна клавіатура TKL, RGB підсвітка, PBT клавіші, BT+USB','price':2899,'currency':'TAX','image_emoji':'⌨️','image_url':None,'badge':None,'stock':30},
    {'slug':'arm-webcam-2k','title':'TaxTech Webcam 2K','description':'Веб-камера 2K 30fps, автофокус, вбудований мікрофон, USB-C','price':2499,'currency':'TAX','image_emoji':'📷','image_url':None,'badge':None,'stock':25},
    {'slug':'arm-router-ax3000','title':'TaxTech Router AX3000','description':'Wi-Fi 6 роутер AX3000, 4 антени, MU-MIMO, OFDMA, до 200м²','price':3599,'currency':'TAX','image_emoji':'📡','image_url':None,'badge':'TOP','stock':20},
    {'slug':'arm-card-holder','title':'TaxTech Card Holder','description':'Шкіряний тримач для карток з RFID захистом, до 8 карток','price':899,'currency':'TAX','image_emoji':'💳','image_url':None,'badge':None,'stock':80},
    {'slug':'arm-hoodie','title':'TaxTech Hoodie','description':'Худі TaxTech з флісовою підкладкою, унісекс, розміри S-XXL','price':2499,'currency':'TAX','image_emoji':'👕','image_url':None,'badge':'NEW','stock':40},
    {'slug':'arm-mug','title':'TaxTech Mug','description':'Термокружка TaxTech 350мл, нержавіюча сталь, зберігає тепло 6 год','price':699,'currency':'TAX','image_emoji':'☕','image_url':None,'badge':None,'stock':100},
    {'slug':'arm-bundle-phone-watch','title':'TaxTech Bundle: Phone + Watch','description':'ARM Phone Lite 5G 256GB + TaxTech Watch Series 4 — ексклюзивний комплект','price':20499,'currency':'TAX','image_emoji':'📦','image_url':None,'badge':'DEAL','stock':10},
]

# Parsed snapshot from a public marketplace-style product feed.
# Kept static so Render boot does not depend on a third-party API.
REAL_PRODUCTS.extend([{'slug': 'feed-apple-airpods-max-silver',
  'title': 'Apple AirPods Max Silver',
  'description': 'Parsed marketplace item · Apple. The Apple AirPods Max in Silver are premium over-ear '
                 'headphones with high-fidelity audio, adaptive EQ, and active noise cancellation. '
                 'Experience immersive sound in style.',
  'price': 22550,
  'currency': 'TAX',
  'image_emoji': '🎧',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/apple-airpods-max-silver/thumbnail.webp',
  'badge': 'NEW',
  'stock': 59},
 {'slug': 'feed-apple-iphone-charger',
  'title': 'Apple iPhone Charger',
  'description': 'Parsed marketplace item · Apple. The Apple iPhone Charger is a high-quality charger '
                 'designed for fast and efficient charging of your iPhone. Ensure your device stays powered '
                 'up and ready to go.',
  'price': 820,
  'currency': 'TAX',
  'image_emoji': '📱',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/apple-iphone-charger/thumbnail.webp',
  'badge': 'NEW',
  'stock': 31},
 {'slug': 'feed-apple-magsafe-battery-pack',
  'title': 'Apple MagSafe Battery Pack',
  'description': 'Parsed marketplace item · Apple. The Apple MagSafe Battery Pack is a portable and '
                 'convenient way to add extra battery life to your MagSafe-compatible iPhone. Attach it '
                 'magnetically for a secure connection.',
  'price': 4100,
  'currency': 'TAX',
  'image_emoji': '🛍️',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/apple-magsafe-battery-pack/thumbnail.webp',
  'badge': 'LIMITED',
  'stock': 1},
 {'slug': 'feed-beats-flex-wireless-earphones',
  'title': 'Beats Flex Wireless Earphones',
  'description': 'Parsed marketplace item · Beats. The Beats Flex Wireless Earphones offer a comfortable and '
                 'versatile audio experience. With magnetic earbuds and up to 12 hours of battery life, they '
                 'are ideal for everyday use.',
  'price': 2050,
  'currency': 'TAX',
  'image_emoji': '📱',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/beats-flex-wireless-earphones/thumbnail.webp',
  'badge': 'HOT',
  'stock': 50},
 {'slug': 'feed-iphone-12-silicone-case-with-magsafe-plum',
  'title': 'iPhone 12 Silicone Case with MagSafe Plum',
  'description': 'Parsed marketplace item · Apple. The iPhone 12 Silicone Case with MagSafe in Plum is a '
                 'stylish and protective case designed for the iPhone 12. It features MagSafe technology for '
                 'easy attachment of accessories.',
  'price': 1230,
  'currency': 'TAX',
  'image_emoji': '📱',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/iphone-12-silicone-case-with-magsafe-plum/thumbnail.webp',
  'badge': 'NEW',
  'stock': 69},
 {'slug': 'feed-selfie-lamp-with-iphone',
  'title': 'Selfie Lamp with iPhone',
  'description': 'Parsed marketplace item · GadgetMaster. The Selfie Lamp with iPhone is a portable and '
                 'adjustable LED light designed to enhance your selfies and video calls. Attach it to your '
                 'iPhone for well-lit photos.',
  'price': 615,
  'currency': 'TAX',
  'image_emoji': '📱',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/selfie-lamp-with-iphone/thumbnail.webp',
  'badge': 'NEW',
  'stock': 58},
 {'slug': 'feed-apple-macbook-pro-14-inch-space-grey',
  'title': 'Apple MacBook Pro 14 Inch Space Grey',
  'description': 'Parsed marketplace item · Apple. The MacBook Pro 14 Inch in Space Grey is a powerful and '
                 "sleek laptop, featuring Apple's M1 Pro chip for exceptional performance and a stunning "
                 'Retina display.',
  'price': 82000,
  'currency': 'TAX',
  'image_emoji': '💻',
  'image_url': 'https://cdn.dummyjson.com/product-images/laptops/apple-macbook-pro-14-inch-space-grey/thumbnail.webp',
  'badge': 'NEW',
  'stock': 24},
 {'slug': 'feed-asus-zenbook-pro-dual-screen-laptop',
  'title': 'Asus Zenbook Pro Dual Screen Laptop',
  'description': 'Parsed marketplace item · Asus. The Asus Zenbook Pro Dual Screen Laptop is a '
                 'high-performance device with dual screens, providing productivity and versatility for '
                 'creative professionals.',
  'price': 73800,
  'currency': 'TAX',
  'image_emoji': '💻',
  'image_url': 'https://cdn.dummyjson.com/product-images/laptops/asus-zenbook-pro-dual-screen-laptop/thumbnail.webp',
  'badge': 'NEW',
  'stock': 45},
 {'slug': 'feed-huawei-matebook-x-pro',
  'title': 'Huawei Matebook X Pro',
  'description': 'Parsed marketplace item · Huawei. The Huawei Matebook X Pro is a slim and stylish laptop '
                 'with a high-resolution touchscreen display, offering a premium experience for users on the '
                 'go.',
  'price': 57400,
  'currency': 'TAX',
  'image_emoji': '💻',
  'image_url': 'https://cdn.dummyjson.com/product-images/laptops/huawei-matebook-x-pro/thumbnail.webp',
  'badge': 'TOP',
  'stock': 75},
 {'slug': 'feed-lenovo-yoga-920',
  'title': 'Lenovo Yoga 920',
  'description': 'Parsed marketplace item · Lenovo. The Lenovo Yoga 920 is a 2-in-1 convertible laptop with '
                 'a flexible hinge, allowing you to use it as a laptop or tablet, offering versatility and '
                 'portability.',
  'price': 45100,
  'currency': 'TAX',
  'image_emoji': '💻',
  'image_url': 'https://cdn.dummyjson.com/product-images/laptops/lenovo-yoga-920/thumbnail.webp',
  'badge': 'NEW',
  'stock': 40},
 {'slug': 'feed-new-dell-xps-13-9300-laptop',
  'title': 'New DELL XPS 13 9300 Laptop',
  'description': 'Parsed marketplace item · Dell. The New DELL XPS 13 9300 Laptop is a compact and powerful '
                 'device, featuring a virtually borderless InfinityEdge display and high-end performance for '
                 'various tasks.',
  'price': 61500,
  'currency': 'TAX',
  'image_emoji': '💻',
  'image_url': 'https://cdn.dummyjson.com/product-images/laptops/new-dell-xps-13-9300-laptop/thumbnail.webp',
  'badge': 'NEW',
  'stock': 74},
 {'slug': 'feed-brown-leather-belt-watch',
  'title': 'Brown Leather Belt Watch',
  'description': 'Parsed marketplace item · Fashion Timepieces. The Brown Leather Belt Watch is a stylish '
                 'timepiece with a classic design. Featuring a genuine leather strap and a sleek dial, it '
                 'adds a touch of sophistication to your look.',
  'price': 3690,
  'currency': 'TAX',
  'image_emoji': '⌚',
  'image_url': 'https://cdn.dummyjson.com/product-images/mens-watches/brown-leather-belt-watch/thumbnail.webp',
  'badge': 'NEW',
  'stock': 32},
 {'slug': 'feed-longines-master-collection',
  'title': 'Longines Master Collection',
  'description': 'Parsed marketplace item · Longines. The Longines Master Collection is an elegant and '
                 "refined watch known for its precision and craftsmanship. With a timeless design, it's a "
                 'symbol of luxury and sophistication.',
  'price': 61500,
  'currency': 'TAX',
  'image_emoji': '⌚',
  'image_url': 'https://cdn.dummyjson.com/product-images/mens-watches/longines-master-collection/thumbnail.webp',
  'badge': 'NEW',
  'stock': 100},
 {'slug': 'feed-rolex-cellini-date-black-dial',
  'title': 'Rolex Cellini Date Black Dial',
  'description': 'Parsed marketplace item · Rolex. The Rolex Cellini Date with Black Dial is a classic and '
                 'prestigious watch. With a black dial and date complication, it exudes sophistication and '
                 "is a symbol of Rolex's heritage.",
  'price': 369000,
  'currency': 'TAX',
  'image_emoji': '⌚',
  'image_url': 'https://cdn.dummyjson.com/product-images/mens-watches/rolex-cellini-date-black-dial/thumbnail.webp',
  'badge': 'TOP',
  'stock': 40},
 {'slug': 'feed-rolex-datejust',
  'title': 'Rolex Datejust',
  'description': 'Parsed marketplace item · Rolex. The Rolex Datejust is an iconic and versatile timepiece '
                 "with a date window. Known for its timeless design and reliability, it's a symbol of "
                 "Rolex's watchmaking excellence.",
  'price': 451000,
  'currency': 'TAX',
  'image_emoji': '⌚',
  'image_url': 'https://cdn.dummyjson.com/product-images/mens-watches/rolex-datejust/thumbnail.webp',
  'badge': 'NEW',
  'stock': 86},
 {'slug': 'feed-rolex-submariner-watch',
  'title': 'Rolex Submariner Watch',
  'description': 'Parsed marketplace item · Rolex. The Rolex Submariner is a legendary dive watch with a '
                 "rich history. Known for its durability and water resistance, it's a symbol of adventure "
                 'and exploration.',
  'price': 574000,
  'currency': 'TAX',
  'image_emoji': '⌚',
  'image_url': 'https://cdn.dummyjson.com/product-images/mens-watches/rolex-submariner-watch/thumbnail.webp',
  'badge': 'NEW',
  'stock': 55},
 {'slug': 'feed-apple-watch-series-4-gold',
  'title': 'Apple Watch Series 4 Gold',
  'description': 'Parsed marketplace item · Apple. The Apple Watch Series 4 in Gold is a stylish and '
                 'advanced smartwatch with features like heart rate monitoring, fitness tracking, and a '
                 'beautiful Retina display.',
  'price': 14350,
  'currency': 'TAX',
  'image_emoji': '⌚',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/apple-watch-series-4-gold/thumbnail.webp',
  'badge': 'NEW',
  'stock': 33},
 {'slug': 'feed-monopod',
  'title': 'Monopod',
  'description': 'Parsed marketplace item · TechGear. The Monopod is a versatile camera accessory for stable '
                 'and adjustable shooting. Perfect for capturing selfies, group photos, and videos with '
                 'ease.',
  'price': 820,
  'currency': 'TAX',
  'image_emoji': '🛍️',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/monopod/thumbnail.webp',
  'badge': 'HOT',
  'stock': 48},
 {'slug': 'feed-selfie-stick-monopod',
  'title': 'Selfie Stick Monopod',
  'description': 'Parsed marketplace item · SnapTech. The Selfie Stick Monopod is a extendable and foldable '
                 'device for capturing the perfect selfie or group photo. Compatible with smartphones and '
                 'cameras.',
  'price': 533,
  'currency': 'TAX',
  'image_emoji': '🛍️',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/selfie-stick-monopod/thumbnail.webp',
  'badge': 'LIMITED',
  'stock': 11},
 {'slug': 'feed-tv-studio-camera-pedestal',
  'title': 'TV Studio Camera Pedestal',
  'description': 'Parsed marketplace item · ProVision. The TV Studio Camera Pedestal is a professional-grade '
                 'camera support system for smooth and precise camera movements in a studio setting. Ideal '
                 'for broadcast and production.',
  'price': 20500,
  'currency': 'TAX',
  'image_emoji': '📷',
  'image_url': 'https://cdn.dummyjson.com/product-images/mobile-accessories/tv-studio-camera-pedestal/thumbnail.webp',
  'badge': 'LIMITED',
  'stock': 15},
 {'slug': 'feed-iphone-13-pro',
  'title': 'iPhone 13 Pro',
  'description': 'Parsed marketplace item · Apple. The iPhone 13 Pro is a cutting-edge smartphone with a '
                 'powerful camera system, high-performance chip, and stunning display. It offers advanced '
                 'features for users who demand top-notch technology.',
  'price': 45100,
  'currency': 'TAX',
  'image_emoji': '📱',
  'image_url': 'https://cdn.dummyjson.com/product-images/smartphones/iphone-13-pro/thumbnail.webp',
  'badge': 'NEW',
  'stock': 56},
 {'slug': 'feed-oppo-f19-pro-plus',
  'title': 'Oppo F19 Pro Plus',
  'description': 'Parsed marketplace item · Oppo. The Oppo F19 Pro Plus is a feature-rich smartphone with a '
                 'focus on camera capabilities. It boasts advanced photography features and a powerful '
                 'performance for a premium user experience.',
  'price': 16400,
  'currency': 'TAX',
  'image_emoji': '📱',
  'image_url': 'https://cdn.dummyjson.com/product-images/smartphones/oppo-f19-pro-plus/thumbnail.webp',
  'badge': 'NEW',
  'stock': 78},
 {'slug': 'feed-realme-x',
  'title': 'Realme X',
  'description': 'Parsed marketplace item · Realme. The Realme X is a mid-range smartphone known for its '
                 'sleek design and impressive display. It offers a good balance of performance and camera '
                 'capabilities for users seeking a quality device.',
  'price': 12300,
  'currency': 'TAX',
  'image_emoji': '📱',
  'image_url': 'https://cdn.dummyjson.com/product-images/smartphones/realme-x/thumbnail.webp',
  'badge': 'LIMITED',
  'stock': 12},
 {'slug': 'feed-calvin-klein-heel-shoes',
  'title': 'Calvin Klein Heel Shoes',
  'description': 'Parsed marketplace item · Calvin Klein. Calvin Klein Heel Shoes are elegant and '
                 'sophisticated, designed for formal occasions. With a classic design and high-quality '
                 'materials, they complement your stylish ensemble.',
  'price': 3280,
  'currency': 'TAX',
  'image_emoji': '👟',
  'image_url': 'https://cdn.dummyjson.com/product-images/womens-shoes/calvin-klein-heel-shoes/thumbnail.webp',
  'badge': 'TOP',
  'stock': 93}])


@marketplace_bp.post('/admin/seed-products')
@auth_required
def admin_seed_products():
    """Seed / upsert DB with real demo products (idempotent — upserts by slug)."""
    if g.current_user.get('role') not in ('admin', 'platform_admin'):
        return api_error('Недостатньо прав.', 403)
    _ensure_schema()
    now_sql = _now_sql()
    inserted, updated = 0, 0
    with get_connection() as conn:
        for p in REAL_PRODUCTS:
            existing = conn.execute(
                'SELECT id FROM marketplace_products WHERE slug = %s LIMIT 1',
                (p['slug'],),
            ).fetchone()
            if existing:
                conn.execute(
                    f"""
                    UPDATE marketplace_products
                    SET title=%s, description=%s, price=%s, currency=%s,
                        image_emoji=%s, image_url=%s, badge=%s, stock=%s,
                        is_active=TRUE, updated_at={now_sql}
                    WHERE slug=%s
                    """,
                    (
                        p['title'], p['description'], p['price'], p['currency'],
                        p['image_emoji'], p.get('image_url'), p.get('badge'),
                        p.get('stock', 10), p['slug'],
                    ),
                )
                updated += 1
            else:
                conn.execute(
                    f"""
                    INSERT INTO marketplace_products
                    (slug, title, description, price, currency, image_emoji, image_url, badge, stock, is_active, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE, {now_sql}, {now_sql})
                    """,
                    (
                        p['slug'], p['title'], p['description'],
                        p['price'], p['currency'], p['image_emoji'],
                        p.get('image_url'), p.get('badge'), p.get('stock', 10),
                    ),
                )
                inserted += 1
    return jsonify({'ok': True, 'data': {'inserted': inserted, 'updated': updated}})


# ═══════════════════════════════════════════════════════════════════
#  MERCHANT API: магазин SAINT AGNES виставляє інвойс клієнту TaxTech
# ═══════════════════════════════════════════════════════════════════

@marketplace_bp.post('/merchant/invoices')
def merchant_create_invoice():
    """Server-to-server (HMAC): магазин просить виставити інвойс на оплату замовлення.

    Клієнт бачить його в додатку (розділ інвойсів) і платить існуючим /invoice/<n>/pay;
    після оплати банк сам викликає вебхук магазину (shop_sync.push_paid).
    """
    raw = request.get_data()
    if not shop_sync.verify(raw, request.headers.get('X-TaxTech-Timestamp', ''), request.headers.get('X-TaxTech-Signature', '')):
        return api_error('Підпис недійсний.', 401)
    _ensure_schema()
    data = json.loads(raw or b'{}')
    ref = str(data.get('order_ref') or '').strip()[:40]
    ident = str(data.get('customer') or '').strip().lower()
    try:
        amount = round(float(data.get('amount') or 0), 2)
    except Exception:
        amount = 0
    if not ref or not ident or amount <= 0:
        return api_error('Потрібні order_ref, customer і amount.')
    suffix = get_returning_id_suffix()
    with get_connection() as conn:
        dup = conn.execute('SELECT invoice_number FROM marketplace_orders WHERE shop_ref = %s LIMIT 1', (ref,)).fetchone()
        if dup:
            return jsonify({'ok': True, 'invoice_number': dup['invoice_number'], 'duplicate': True})
        user = conn.execute(
            'SELECT id FROM users WHERE LOWER(email) = %s OR phone = %s LIMIT 1', (ident, ident),
        ).fetchone()
        if not user:
            return api_error('Клієнта TaxTech не знайдено.', 404)
        account = conn.execute(
            'SELECT id, currency FROM accounts WHERE user_id = %s', (int(user['id']),),
        ).fetchone()
        if not account:
            return api_error('Рахунок клієнта не знайдено.', 404)
        invoice_number = _generate_unique_invoice_number(conn)
        cur = conn.execute(
            """
            INSERT INTO marketplace_orders
            (user_id, account_id, total_amount, currency, status, payment_mode, invoice_number, invoice_status,
             invoice_due_at, shipping_name, shipping_phone, shipping_address, note, shop_ref)
            VALUES (%s, %s, %s, %s, 'awaiting_payment', 'invoice', %s, 'issued', """ + _due_at_sql(24) + """, %s, %s, %s, %s, %s)"""
            + suffix,
            (int(user['id']), account['id'], amount, str(account.get('currency') or 'TAX'), invoice_number,
             str(data.get('shipping_name') or ''), str(data.get('shipping_phone') or ''),
             str(data.get('shipping_address') or ''), f'Saint Agnes {ref}', ref),
        )
        order_id = insert_last_id(cur)
        conn.execute(
            'INSERT INTO marketplace_order_items(order_id, product_id, title, price, qty, line_total) VALUES (%s, NULL, %s, %s, 1, %s)',
            (order_id, f'Saint Agnes order {ref}', amount, amount),
        )
        conn.execute(
            """
            INSERT INTO marketplace_invoices
            (invoice_number, order_id, user_id, account_id, amount, currency, status, due_at)
            VALUES (%s, %s, %s, %s, %s, %s, 'issued', """ + _due_at_sql(24) + ")",
            (invoice_number, order_id, int(user['id']), account['id'], amount, str(account.get('currency') or 'TAX')),
        )
    return jsonify({'ok': True, 'invoice_number': invoice_number, 'order_id': int(order_id or 0)})
