"""Головний Flask-застосунок навчального банку Kopiyka.

Хмарна частина студентського дослідження: пісочниця-банк на ВІРТУАЛЬНИХ
грошах (TAX) + дослідницький API (/api/research/*), за допомогою якого
iOS-клієнт вирішує, де виконувати AI-задачу — на iPhone чи на сервері.
"""
from __future__ import annotations

import os
import re
import uuid

from flask import Flask, abort, g, jsonify, request, send_from_directory
from flask_compress import Compress

from .config import (
    ALLOW_DEMO_PAYOUT_ACCRUAL,
    BASE_DIR,
    BASE_PATH,
    CURRENCY_CODE,
    CURRENCY_LABEL,
    ENABLE_RATE_LIMIT_IN_TESTS,
    ENFORCE_IDEMPOTENCY_HEADERS,
    ENFORCE_IDEMPOTENCY_IN_TESTS,
    RESEARCH_ECHO_MAX_BYTES,
)
from .database import init_db
from .routes.account_routes import account_bp
from .routes.auth_routes import auth_bp
from .routes.card_routes import card_bp
from .routes.credit_routes import credit_bp
from .routes.deposit_routes import deposit_bp
from .routes.feature_routes import feature_bp
from .routes.research_routes import research_bp
from .routes.marketplace_routes import marketplace_bp
from .routes.three_ds_routes import three_ds_bp
from .routes.passkey_routes import passkey_bp

API_VERSION = '1.0.0'
SERVICE_NAME = 'TaxTech Sandbox Bank'

# Дозволені Origin для браузерних клієнтів (iOS-застосунку CORS не потрібен).
# Додаткові origin'и можна передати через CORS_ORIGINS="https://a,https://b".
_DEFAULT_ORIGINS = {
    'http://localhost:5173',
    'http://localhost:5050',
    'http://127.0.0.1:5050',
}


def create_app() -> Flask:
    """Створює та налаштовує Flask-застосунок."""
    db_boot_ok = True
    try:
        init_db()
    except Exception as exc:
        db_boot_ok = False
        print(f'[Kopiyka] DB bootstrap warning: {exc}')

    app = Flask(__name__, static_folder=None)
    from .config import SECRET_KEY
    app.secret_key = SECRET_KEY
    app.config['DB_BOOT_OK'] = db_boot_ok
    # Кирилиця у JSON без \uXXXX-екранування: читабельніше й компактніше для мобільного клієнта
    app.json.ensure_ascii = False
    # Ліміт тіла запиту: echo приймає до RESEARCH_ECHO_MAX_BYTES (+ запас на заголовки multipart).
    app.config['MAX_CONTENT_LENGTH'] = RESEARCH_ECHO_MAX_BYTES + 64 * 1024
    app.config.setdefault('ENABLE_RATE_LIMIT_IN_TESTS', ENABLE_RATE_LIMIT_IN_TESTS)
    app.config.setdefault('ENFORCE_IDEMPOTENCY_HEADERS', ENFORCE_IDEMPOTENCY_HEADERS)
    app.config.setdefault('ENFORCE_IDEMPOTENCY_IN_TESTS', ENFORCE_IDEMPOTENCY_IN_TESTS)
    app.config.setdefault('ALLOW_DEMO_PAYOUT_ACCRUAL', ALLOW_DEMO_PAYOUT_ACCRUAL)

    # ── Gzip для великих JSON-відповідей (лише якщо клієнт надсилає Accept-Encoding) ──
    app.config['COMPRESS_REGISTER'] = False
    app.config['COMPRESS_MIMETYPES'] = ['application/json']
    app.config['COMPRESS_MIN_SIZE'] = 500
    app.config['COMPRESS_LEVEL'] = 6
    Compress(app)
    prefix = BASE_PATH or ''

    allowed_origins = set(_DEFAULT_ORIGINS)
    allowed_origins.update(
        o.strip() for o in (os.getenv('CORS_ORIGINS') or '').split(',') if o.strip()
    )

    def _append_expose_header(resp, *header_names: str):
        existing = (resp.headers.get('Access-Control-Expose-Headers') or '').strip()
        parts = [p.strip() for p in existing.split(',') if p.strip()]
        for name in header_names:
            if name and name not in parts:
                parts.append(name)
        if parts:
            resp.headers['Access-Control-Expose-Headers'] = ', '.join(parts)

    def _cors(resp):
        origin = request.headers.get('Origin', '')
        if origin in allowed_origins:
            resp.headers['Access-Control-Allow-Origin'] = origin
            resp.headers['Access-Control-Allow-Methods'] = 'GET, POST, PATCH, PUT, DELETE, OPTIONS'
            resp.headers['Access-Control-Allow-Headers'] = (
                'Content-Type, Authorization, Idempotency-Key, X-Request-Id'
            )
            resp.headers['Vary'] = 'Origin'
        return resp

    @app.before_request
    def set_request_id():
        incoming = (request.headers.get('X-Request-Id') or '').strip()
        if incoming:
            incoming = re.sub(r'[^a-zA-Z0-9._:-]', '', incoming)[:120]
        g.request_id = incoming or uuid.uuid4().hex

    @app.after_request
    def add_headers(resp):
        resp.headers['X-Content-Type-Options'] = 'nosniff'
        resp.headers.setdefault('Referrer-Policy', 'strict-origin-when-cross-origin')
        resp.headers.setdefault('X-Frame-Options', 'DENY')
        req_id = str(getattr(g, 'request_id', '') or '').strip()
        if req_id:
            resp.headers['X-Request-Id'] = req_id
        _append_expose_header(resp, 'X-Request-Id', 'X-Refresh-Token')
        _cors(resp)
        if request.path.startswith(prefix + '/api/') and '/marketplace/images/' not in request.path:
            resp.headers['Cache-Control'] = 'no-store'
        return resp

    @app.before_request
    def cors_preflight():
        """CORS preflight для /api/* без catch-all маршруту (щоб невідомі шляхи давали 404, а не 405)."""
        if request.method == 'OPTIONS' and request.path.startswith(prefix + '/api/'):
            r = app.make_default_options_response()
            if 'Access-Control-Allow-Origin' in _cors(r).headers:
                r.headers['Access-Control-Max-Age'] = '86400'
            return r
        return None

    @app.errorhandler(400)
    def bad_request(e):
        return jsonify({'ok': False, 'error': getattr(e, 'description', None) or 'Невірний запит.'}), 400

    @app.errorhandler(404)
    def not_found(_e):
        return jsonify({'ok': False, 'error': 'Не знайдено.'}), 404

    @app.errorhandler(405)
    def method_not_allowed(_e):
        return jsonify({'ok': False, 'error': 'Метод не підтримується.'}), 405

    @app.errorhandler(413)
    def too_large(_e):
        limit_mb = RESEARCH_ECHO_MAX_BYTES / (1024 * 1024)
        return jsonify({'ok': False, 'error': f'Тіло запиту завелике (максимум {limit_mb:g} МБ).'}), 413

    @app.errorhandler(500)
    def server_error(_e):
        import logging
        import traceback
        logging.getLogger(__name__).error('500 error: %s', traceback.format_exc())
        return jsonify({'ok': False, 'error': 'Внутрішня помилка сервера.'}), 500

    app.register_blueprint(auth_bp,     url_prefix=prefix + '/api/auth')
    app.register_blueprint(account_bp,  url_prefix=prefix + '/api')
    app.register_blueprint(card_bp,     url_prefix=prefix + '/api')
    app.register_blueprint(feature_bp,  url_prefix=prefix + '/api')
    app.register_blueprint(deposit_bp,  url_prefix=prefix + '/api')
    app.register_blueprint(credit_bp,   url_prefix=prefix + '/api')
    app.register_blueprint(research_bp, url_prefix=prefix + '/api/research')
    app.register_blueprint(marketplace_bp, url_prefix=prefix + '/api/marketplace')
    app.register_blueprint(three_ds_bp, url_prefix=prefix + '/api/3ds')
    app.register_blueprint(passkey_bp, url_prefix=prefix + '/api/auth/passkey')

    @app.get(prefix + '/api')
    @app.get(prefix + '/api/')
    def api_catalog():
        """Автоматичний каталог зареєстрованих API-маршрутів (без ручного опису)."""
        routes = []
        for rule in app.url_map.iter_rules():
            if not rule.rule.startswith(prefix + '/api/'):
                continue
            methods = sorted(m for m in rule.methods if m not in {'HEAD', 'OPTIONS'})
            routes.append({'path': rule.rule, 'methods': methods})
        routes.sort(key=lambda r: r['path'])
        return jsonify({
            'ok': True,
            'service': SERVICE_NAME,
            'version': API_VERSION,
            'currency': CURRENCY_CODE,
            'notice': f'Навчальна пісочниця: усі суми — {CURRENCY_LABEL}, не справжні гроші.',
            'routes': routes,
        })

    @app.get(prefix + '/api/version')
    def api_version():
        return jsonify({
            'ok': True,
            'service': SERVICE_NAME,
            'version': API_VERSION,
            'base_path': prefix or '/',
            'currency': CURRENCY_CODE,
        })

    @app.get(prefix + '/health')
    def health():
        return {
            'ok': True,
            'service': SERVICE_NAME,
            'db_boot_ok': bool(app.config.get('DB_BOOT_OK', True)),
        }

    # ── Мобільний веб-застосунок банку (збірка web/ → server/frontend) ──────────
    # Файли збірки віддаємо як є, решту шляхів (не /api) - index.html: маршрути вирішує застосунок.
    frontend = BASE_DIR / 'frontend'

    @app.get(prefix + '/' if prefix else '/')
    @app.get(prefix + '/<path:path>')
    def web_app(path: str = ''):
        if path.startswith(('api/', 'health')) or not (frontend / 'index.html').is_file():
            abort(404)
        target = (frontend / path).resolve() if path else None
        if target and target.is_file() and frontend.resolve() in target.parents:
            resp = send_from_directory(frontend, path)
            # файли з хешем у назві не змінюються - кешуємо надовго
            if path.startswith('assets/'):
                resp.headers['Cache-Control'] = 'public, max-age=31536000, immutable'
            return resp
        resp = send_from_directory(frontend, 'index.html')
        resp.headers['Cache-Control'] = 'no-cache'
        return resp

    return app


app = create_app()

if __name__ == '__main__':
    from .config import DEBUG, HOST, PORT
    app.run(debug=DEBUG, host=HOST, port=PORT)
