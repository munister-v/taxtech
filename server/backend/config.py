"""Конфігурація навчального банку Kopiyka (з .env).

Усі гроші в цьому сервері віртуальні (валюта VUAH — «віртуальні гривні»),
це пісочниця для дослідження edge/cloud-маршрутизації AI-задач.
"""
from pathlib import Path
import os

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

# .env шукаємо поруч із server/, а потім у поточній теці процесу
load_dotenv(BASE_DIR / '.env')
load_dotenv()

_default_db_path = BASE_DIR / 'database' / 'kopiyka_sandbox.db'
DATABASE_PATH = Path(os.getenv('KOPIYKA_DATABASE_PATH') or _default_db_path)
SCHEMA_PATH = BASE_DIR / 'database' / 'schema.sql'
SCHEMA_PG_PATH = BASE_DIR / 'database' / 'schema_pg.sql'

DATABASE_URL = os.getenv('DATABASE_URL', '').strip()
USE_PG = bool(DATABASE_URL)

SECRET_KEY = os.getenv('SECRET_KEY') or 'kopiyka-sandbox-dev-secret-key'
TOKEN_TTL_HOURS = int(os.getenv('TOKEN_TTL_HOURS') or '720')  # 30 днів за замовчуванням
DEBUG = (os.getenv('DEBUG') or '0') == '1'

# Базовий шлях при розміщенні за проксі (наприклад /kopiyka). За замовчуванням — корінь.
BASE_PATH = (os.getenv('BASE_PATH') or '').rstrip('/')

# Адреса та порт dev-сервера (start.py). Для доступу з фізичного iPhone у
# локальній мережі встановіть HOST=0.0.0.0.
HOST = os.getenv('HOST', '127.0.0.1').strip() or '127.0.0.1'
PORT = int(os.getenv('PORT') or '5050')

# ── Віртуальна валюта ────────────────────────────────────────────────────────
# Код валюти навмисно НЕ з ISO 4217: VUAH = «віртуальна гривня» пісочниці.
CURRENCY_CODE = 'VUAH'
CURRENCY_LABEL = 'віртуальні гривні'
ACCOUNT_PREFIX = 'KP-'           # номери рахунків: KP-100001, KP-100002, …

# Примітивний anti-bruteforce rate-limit для auth endpoints
AUTH_RATE_LIMIT_ENABLED = (os.getenv('AUTH_RATE_LIMIT_ENABLED', '1') == '1')
AUTH_RATE_WINDOW_SECONDS = int(os.getenv('AUTH_RATE_WINDOW_SECONDS', '60'))
AUTH_LOGIN_RATE_LIMIT = int(os.getenv('AUTH_LOGIN_RATE_LIMIT', '12'))
AUTH_REGISTER_RATE_LIMIT = int(os.getenv('AUTH_REGISTER_RATE_LIMIT', '8'))
ENABLE_RATE_LIMIT_IN_TESTS = (os.getenv('ENABLE_RATE_LIMIT_IN_TESTS', '0') == '1')

# Rate-limit для критичних фінансових mutation endpoint'ів
CRITICAL_RATE_LIMIT_WINDOW_SECONDS = int(os.getenv('CRITICAL_RATE_LIMIT_WINDOW_SECONDS', '60'))
CRITICAL_MONEY_RATE_LIMIT = int(os.getenv('CRITICAL_MONEY_RATE_LIMIT', '30'))

# Обов'язковий заголовок Idempotency-Key для monetary endpoint'ів
ENFORCE_IDEMPOTENCY_HEADERS = (os.getenv('ENFORCE_IDEMPOTENCY_HEADERS', '1') == '1')
ENFORCE_IDEMPOTENCY_IN_TESTS = (os.getenv('ENFORCE_IDEMPOTENCY_IN_TESTS', '0') == '1')

# Демо-нарахування віртуальних надходжень (POST /api/payouts/demo-accrual).
ALLOW_DEMO_PAYOUT_ACCRUAL = (os.getenv('ALLOW_DEMO_PAYOUT_ACCRUAL', '0') == '1')

# ── Дослідницький API (/api/research/*) ─────────────────────────────────────
# Максимальний розмір тіла для /api/research/echo (оцінка пропускної здатності).
RESEARCH_ECHO_MAX_BYTES = int(os.getenv('RESEARCH_ECHO_MAX_BYTES') or str(5 * 1024 * 1024))

# Anthropic Messages API. Моделі ЗАФІКСОВАНІ заради відтворюваності
# експериментів — не замінюйте їх на «останню» версію посеред серії вимірювань.
ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY', '').strip()
LLM_MODEL_SMALL = os.getenv('LLM_MODEL_SMALL', '').strip() or 'claude-haiku-5-5'
LLM_MODEL_LARGE = os.getenv('LLM_MODEL_LARGE', '').strip() or 'claude-sonnet-5-5'
LLM_MAX_TOKENS = int(os.getenv('LLM_MAX_TOKENS') or '4096')
# Рівень зусиль моделі (output_config.effort): low|medium|high. Фіксований,
# щоб порівняння small/large були чесними між прогонами.
LLM_EFFORT = (os.getenv('LLM_EFFORT') or 'low').strip().lower()
LLM_TIMEOUT_SECONDS = float(os.getenv('LLM_TIMEOUT_SECONDS') or '60')
LLM_MAX_PROMPT_CHARS = int(os.getenv('LLM_MAX_PROMPT_CHARS') or '20000')
