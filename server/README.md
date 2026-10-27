# Kopiyka — хмарна частина (навчальний банк на віртуальних грошах)

Сервер студентського дослідження: iOS-застосунок **Kopiyka** (асистент персональних
фінансів) вирішує, де виконувати AI-задачу — на iPhone чи на сервері. Цей каталог —
«хмара»: пісочниця-банк і дослідницький API `/api/research/*`.

> **Усі гроші тут віртуальні.** Валюта — `VUAH` («віртуальні гривні»), номери карток
> починаються з `0000` і навмисно не проходять перевірку Луна. Жодних реальних
> платежів, 3DS чи зовнішніх інтеграцій немає.

Код походить з `munister-v/army-bank` (Flask 3 + SQLite/PostgreSQL): збережено
шарування `routes → services → repositories`, банківське ядро та fraud engine;
усе зайве прибрано (див. «Що прибрано і чому»).

## Швидкий старт

```bash
cd server
python3.13 -m venv .venv            # Python 3.10+; перевірено на 3.13
.venv/bin/pip install -r requirements.txt
cp .env.example .env                 # за потреби додайте ANTHROPIC_API_KEY
.venv/bin/python scripts/seed_sandbox.py --users 50 --seed 42 --reset
.venv/bin/python start.py            # http://127.0.0.1:5050
```

* Порт за замовчуванням — **5050**, базовий шлях — **`/`** (API під `/api/...`).
  Змінюється через `PORT` та `BASE_PATH`.
* Для фізичного iPhone у тій самій Wi-Fi мережі: `HOST=0.0.0.0` у `.env`, а в клієнті
  використовуйте LAN-адресу Mac (`http://192.168.x.x:5050`). Симулятор бачить `127.0.0.1`.
* Продакшн-подібний запуск: `.venv/bin/gunicorn -w 2 -b 0.0.0.0:5050 backend.app:app`.

### Демо-вхід

Після `seed_sandbox.py` можна увійти як `demo@kopiyka.test` (рахунок `KP-100001`).
Пароль — у `server/.env.example` (`SEED_DEMO_PASSWORD`). Це **згенеровані тестові**
облікові дані пісочниці; тим самим паролем відкриваються всі `userNNN@kopiyka.test`.

```bash
curl -s -X POST http://127.0.0.1:5050/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"identity":"demo@kopiyka.test","password":"<SEED_DEMO_PASSWORD>"}'
# → {"ok": true, "data": {"token": "...", "user": {...}}}
```

Токен передається як `Authorization: Bearer <token>`.

## Змінні оточення

| Змінна | За замовчуванням | Призначення |
|---|---|---|
| `DATABASE_URL` | порожньо | Порожньо → SQLite; `postgresql://...` → PostgreSQL |
| `KOPIYKA_DATABASE_PATH` | `database/kopiyka_sandbox.db` | Шлях до SQLite-файлу |
| `SECRET_KEY` | dev-значення | Секрет сесій |
| `HOST` / `PORT` | `127.0.0.1` / `5050` | Адреса dev-сервера (`start.py`) |
| `BASE_PATH` | порожньо | Префікс за проксі |
| `ANTHROPIC_API_KEY` | порожньо | Ключ для `/api/research/llm` (без нього — 503) |
| `LLM_MODEL_SMALL` / `LLM_MODEL_LARGE` | `claude-haiku-5-5` / `claude-sonnet-5-5` | Зафіксовані моделі |
| `LLM_EFFORT` | `low` | `output_config.effort` для обох моделей |
| `LLM_MAX_TOKENS` | `4096` | Стеля відповіді |
| `LLM_TIMEOUT_SECONDS` | `60` | Таймаут SDK |
| `RESEARCH_ECHO_MAX_BYTES` | `5242880` | Ліміт тіла `/api/research/echo` |
| `ENFORCE_IDEMPOTENCY_HEADERS` | `1` | Вимагати `Idempotency-Key` для грошових POST |

### PostgreSQL (необов'язково)

```bash
createdb kopiyka_sandbox
echo 'DATABASE_URL=postgresql://localhost:5432/kopiyka_sandbox' >> .env
.venv/bin/python scripts/seed_sandbox.py --reset   # схема створюється автоматично
```

Схеми: `database/schema.sql` (SQLite) і `database/schema_pg.sql` (PostgreSQL). Таблиці
депозитів і кредитів створюють їхні сервіси при першому зверненні.

## Дослідницький API — `/api/research/*`

Кожна відповідь має конверт `{"ok": true, ...}` і `server_ms` — wall-time обробника
(float, мс; без часу авторизації). Мережева складова = повний час запиту − `server_ms`.

### `GET /api/research/ping` — RTT, без авторизації

```json
{"ok": true, "server_time": "2026-10-27T09:45:49.618+00:00", "server_ms": 0.037}
```

### `POST /api/research/echo` — пропускна здатність, без авторизації

Тіло — сирі байти будь-якого типу, до 5 МБ (читається потоково, не зберігається).

```bash
head -c 1048576 /dev/urandom | curl -s -X POST --data-binary @- \
  -H 'Content-Type: application/octet-stream' http://127.0.0.1:5050/api/research/echo
```
```json
{"ok": true, "bytes_received": 1048576, "server_ms": 0.211}
```
Понад ліміт — `413 {"ok": false, "error": "...", "server_ms": ...}`.

### `POST /api/research/fraud/score` — серверний скоринг (Bearer)

Оцінює **гіпотетичний** переказ з рахунку поточного користувача; нічого не виконує й не пише.

```json
{"amount": 9900, "balance": 25000, "description": "терміново",
 "recipient_account": "KP-100007", "layers": ["l1"]}
```

* `amount` — обов'язково; `balance` — за замовчуванням фактичний баланс рахунку;
* `recipient_account` та/або `recipient_account_id` — відсутнє доповнюється з БД;
* `layers` — підмножина `["l1","l2","l3"]`, за замовчуванням усі.

```json
{"ok": true, "score": 46, "level": "medium",
 "flags": ["structuring", "suspicious_description"],
 "details": {"amount": 9900.0, "threshold": 10000, "pct_below": 1.0, "matched_keywords": ["терміново"]},
 "confidence": 1.0, "layers_run": ["l1"], "layers_requested": ["l1"], "server_ms": 1.727}
```

`layers_run` — фактично виконані шари: при досягненні `critical` engine зупиняється
раніше (early-exit), тож `layers_run` може бути коротшим за `layers_requested`.

| Шар | Правила | Дані |
|---|---|---|
| `l1` | structuring, round_amount, description, balance_depletion, threshold_masking (5) | лише аргументи запиту — еквівалент «на пристрої» |
| `l2` | velocity, account_age, high_amount (z-score), IQR, inactivity, time_anomaly, pass_through, historical_fraud, rapid_succession, night_batch, card_topup_abuse, journal_orphans (12) | історія відправника |
| `l3` | freq_escalation, behavioral_entropy, duplicate, smurfing, amount_progression, new_recipient, new_recipient_large_amount, counterparty_concentration, transfer_graph (ping-pong / fan-out / 2-hop cycle), money_mule, risk_propagation (11) | пара відправник/отримувач, граф, **дані інших клієнтів** |

Разом 28 правил-класів (22 «історичні» + 6, позначені в коді `NEW`), логіка правил не змінювалась.

**SQLite vs PostgreSQL.** У вихідному коді на SQLite engine зупинявся після Layer 1
(`USE_PG`-гейт). Тепер **усі шари працюють на обох СУБД**; жодне правило не лишилось
PostgreSQL-only:
* `STDDEV` і `PERCENTILE_CONT` на SQLite рахуються в Python з тією ж семантикою
  (вибіркове σ, лінійна інтерполяція перцентиля);
* `_cutoff()` повертає мітку у форматі SQLite (`YYYY-MM-DD HH:MM:SS`) — раніше ISO-рядок
  з `T` ламав текстове порівняння, і вікна «за останні N хвилин» на SQLite були порожні;
* `CardTopupAbuseRule` мала `LIKE 'CARD_TOPUP%'` з одиночним `%`, через що на PostgreSQL
  (psycopg2) правило мовчки падало; виправлено на `%%` (працює в обох СУБД).

Перевірено: однаковий seed на SQLite і PostgreSQL 14 → 150 скорингів, 0 розбіжностей
у `score`/`flags`, 0 збоїв правил.

### `POST /api/research/llm` — хмарна LLM (Bearer)

```json
{"task": "scam_check", "prompt": "Вам нараховано виграш, надішліть код з SMS", "tier": "small"}
```

* `task`: `support` | `scam_check` | `receipt` (короткі системні промпти українською в
  `backend/services/research_service.py`);
* `tier`: `small` → `claude-haiku-5-5`, `large` → `claude-sonnet-5-5`.

Формат відповіді (значення умовні — реальний виклик API під час розробки не робився):

```json
{"ok": true, "text": "Вердикт: шахрайство\nВпевненість: 95\nПричина: ...",
 "model": "claude-haiku-5-5", "input_tokens": 98, "output_tokens": 31,
 "stop_reason": "end_turn", "task": "scam_check", "tier": "small", "server_ms": 812.4}
```

Без `ANTHROPIC_API_KEY` → `503 {"ok": false, "error": "LLM недоступна: ...", "server_ms": ...}`.
Помилки Anthropic API: 429 (rate limit), 502 (ключ/модель/запит), 504 (таймаут/мережа).

**Відтворюваність.** Моделі закріплені (не «latest»), `effort`, `max_tokens` і системні
промпти фіксовані, ретраї SDK вимкнені (`max_retries=0`), щоб `server_ms` не містив
прихованих повторів. **`temperature=0` неможливий:** з API-версії `2026-10-21` (і в SDK
`anthropic==2.3.0`) параметри `temperature/top_p/top_k` прибрано, а Haiku 5.5 / Sonnet 5.5
приймають лише дефолтний семплінг. Тож відповіді не детерміновані побайтно — для
вимірювань робіть кілька прогонів. Серверні fallback-моделі навмисно **не** ввімкнені:
вони підмінили б модель і зламали порівняння; відмова моделі видно як `stop_reason: "refusal"`.

## Банківський API пісочниці (коротко)

| Група | Ендпоінти |
|---|---|
| Auth | `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/logout`, `GET /api/auth/me`, сесії, зміна пароля |
| Рахунок | `GET /api/accounts/main`, `GET /api/dashboard`, `GET /api/transactions/history`, `GET /api/transactions/{id}` |
| Гроші | `POST /api/transactions/topup` (віртуальне поповнення), `POST /api/transactions/transfer`, `POST /api/transactions/transfer-by-card` — з `Idempotency-Key` |
| Картки | `GET/POST /api/cards`, `PATCH /api/cards/{id}/block` (заморозити/розморозити), `.../close`, `.../design`, `.../set_primary`, `GET .../reveal`, `POST .../topup` |
| Депозити | `GET/POST /api/deposits`, `GET /api/deposits/{id}`, `POST /api/deposits/{id}/close` |
| Кредити | `GET/POST /api/credits`, `GET /api/credits/{id}`, `POST /api/credits/{id}/repay` |
| Виписки | `GET /api/transactions/statement` (PDF), `GET /api/transactions/{id}/receipt` (PDF), `GET /api/transactions/export` (CSV) |
| Фінанси | цілі, контакти, шаблони, бюджети, регулярні платежі, борги, PIN, теги, сповіщення, аналітика |

Повний живий список: `GET /api` (генерується з зареєстрованих маршрутів).

## Синтетичні дані — `scripts/seed_sandbox.py`

```bash
.venv/bin/python scripts/seed_sandbox.py --users 50 --months 6 --seed 42 --reset
# --anchor 2026-10-27T12:00:00Z  — фіксований кінець періоду (для побайтно однакових даних)
# --fraud-users 8 --recent-share 0.25
```

* Суми — логнормальні (власні μ, σ кожного користувача), кількість операцій за день —
  Пуассон з добовою (за Києвом) і тижневою сезонністю, щомісячна «зарплата», дохід
  корелює з витратами (PaySim-подібно). 80% — оплати мерчантам, 20% — P2P-перекази.
* Вбудовані позначені патерни: `structuring`, `rapid_succession`, `money_mule`
  (ланцюжок A→M1→M2), `new_recipient_large_amount`, `night_batch`. Частина епізодів
  (`--recent-share`) потрапляє в останні ~6 годин, щоб правила з часовими вікнами їх бачили.
* Ground truth: таблиця `research_labels(transaction_id, is_fraud, pattern)` для **кожної**
  згенерованої транзакції. У внутрішніх переказах обидві ноги мають однакову мітку —
  для оцінки precision/recall фільтруйте `direction = 'out'`.
* Детермінованість: той самий `--seed` і `--anchor` ⇒ ідентичні транзакції та мітки.

```sql
SELECT l.pattern, COUNT(*) FROM transactions t
JOIN research_labels l ON l.transaction_id = t.id
WHERE t.direction = 'out' GROUP BY l.pattern;
```

## Тести

```bash
.venv/bin/python -m pytest -q
```

Тести працюють на ізольованій тимчасовій SQLite-БД. LLM-тести підміняють SDK `anthropic`
фейковим клієнтом — мережа не використовується.

## Що прибрано і чому

| Прибрано | Чому |
|---|---|
| CRM / ліди / prospecting / Google Search / Meta API / website enrichment / US lead map | Не стосується персональних фінансів; зовнішні API |
| Маркетплейс, месенджер (+ шифрування), дзвінки, push, webhooks, інтеграції | Поза межами дослідження; зовнішні сервіси |
| 3DS | У пісочниці немає реальних карток; ризик оцінює fraud engine |
| Passkeys, 2FA | Не потрібні для дослідження; менше залежностей (`webauthn`, `pywebpush`, `cryptography`) |
| Адмін-панелі, compliance (KYC/AML), operator desk, platform, payment audit, документи | Адмінський функціонал, не клієнтський; таблиці теж прибрано |
| `openrouter_service.py`, `ai_drafts.py`, `agent_routes.py` | Замінено дослідницьким `/api/research/llm` (Anthropic SDK) |
| Settlement / netting / reversal / EOD | Використовувались лише адмінкою; `hold_service`, `ledger_service`, `integrity_service`, `idempotency_service` залишено |
| `api_docs.py` (OpenAPI/Postman вихідного проєкту) | Описував видалені ендпоінти; `GET /api` тепер генерує каталог автоматично |
| Фронтенд, маркетингові сайти, deploy-конфіги | Клієнт — iOS-застосунок |
| Військова термінологія | Роль `soldier` → `user`, прибрано `military_status`, «Army Bank» → Kopiyka, `UAH`/`₴`/«грн» → `VUAH`, рахунки `AB-` → `KP-`, BIN `4721` → `0000` |

## Обмеження, про які варто пам'ятати

* Правила з часовими вікнами рахують від **поточного** часу сервера (UTC). Історичні
  транзакції з `research_labels` не можна «переграти» станом на момент їх створення без
  зміни запитів; для live-оцінки використовуйте свіжі епізоди (`--recent-share`).
* `time_night_utc` / `night_batch_activity` залежать від години UTC під час запиту.
* Layer 3 використовує дані інших клієнтів (граф, money mule, propagation) — на пристрої
  їх принципово немає; саме ця різниця й вимірюється.
