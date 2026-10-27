"""Генератор синтетичних даних для пісочниці Kopiyka (ВІРТУАЛЬНІ гроші, TAX).

Створює N демо-користувачів з рахунками, віртуальними картками та ~6 місяцями
транзакцій, чиї суми й час подібні до PaySim:
  * суми — логнормальні (окремий профіль μ, σ на кожного користувача);
  * кількість операцій за день — Пуассон з добовою (година доби за Києвом)
    та тижневою сезонністю (п'ятниця–субота активніші);
  * щомісячна «зарплата» та рідкісні поповнення — віртуальні надходження.

Поверх нормального фону вбудовуються позначені шахрайські патерни:
  structuring                — серія переказів трохи нижче порогів 5k/10k/20k/50k;
  rapid_succession           — 6–10 вихідних переказів за ≤10 хвилин;
  money_mule                 — «мул» отримує від ≥6 різних відправників і за ≤30 хв
                               пересилає ~95% далі по ланцюжку (A→M1→M2);
  new_recipient_large_amount — перший переказ новому отримувачу у 5–15× більший за p75;
  night_batch                — 3–6 переказів між 02:00 і 05:00 UTC у межах 30 хв.

Ground truth кожної вставленої транзакції пишеться в research_labels
(transaction_id, is_fraud, pattern). Для переказів між рахунками пісочниці
обидві ноги (out та in) мають одну й ту саму мітку — для оцінювання
скорингу фільтруйте direction='out'.

Детермінованість: однаковий --seed та --anchor ⇒ ідентичні дані. Без --anchor
кінцем періоду є поточна хвилина (UTC), щоб правила з вікнами «за останні
N хвилин/годин» бачили свіжі події (див. --recent-share).

Запуск (із теки server/):
    .venv/bin/python scripts/seed_sandbox.py --users 50 --seed 42 --reset
"""
from __future__ import annotations

import argparse
import math
import os
import random
import string
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.config import ACCOUNT_PREFIX, CURRENCY_CODE, USE_PG  # noqa: E402
from backend.database import get_connection, get_returning_id_suffix, init_db, insert_last_id  # noqa: E402
from backend.services.card_service import _BIN_PREFIX, _luhn_checksum  # noqa: E402
from backend.utils.security import hash_password  # noqa: E402

KYIV = ZoneInfo('Europe/Kyiv')
SEED_EMAIL_DOMAIN = '@kopiyka.test'

# Тестові облікові дані — ЗГЕНЕРОВАНІ для пісочниці, не справжні. Значення за
# замовчуванням збігаються з server/.env.example; можна перевизначити через env.
DEFAULT_DEMO_EMAIL = 'demo@kopiyka.test'
DEFAULT_DEMO_PASSWORD = 'kp-sandbox-VXFGSH_CIiRy'

# ── Сезонність ────────────────────────────────────────────────────────────────
# Вага години доби (локальний час Києва): мало вночі, піки в обід і ввечері.
HOUR_WEIGHTS = [
    0.15, 0.08, 0.05, 0.04, 0.04, 0.08, 0.25, 0.55, 0.85, 1.00, 1.05, 1.15,
    1.40, 1.35, 1.10, 1.05, 1.10, 1.30, 1.55, 1.60, 1.40, 1.00, 0.65, 0.35,
]
# Множник активності за днем тижня (0 = понеділок).
DOW_MULT = [0.90, 0.95, 1.00, 1.00, 1.20, 1.30, 1.05]

MERCHANTS = [
    # (рахунок мерчанта, опис, множник середньої суми)
    ('MRC-GROCERY-01', 'Супермаркет (віртуальна покупка)', 1.0),
    ('MRC-GROCERY-02', 'Продукти біля дому (віртуальна покупка)', 0.6),
    ('MRC-CAFE-01', 'Кав\'ярня (віртуальна покупка)', 0.35),
    ('MRC-PHARMA-01', 'Аптека (віртуальна покупка)', 0.8),
    ('MRC-TRANSPORT-01', 'Транспорт (віртуальна покупка)', 0.2),
    ('MRC-FUEL-01', 'АЗС (віртуальна покупка)', 2.2),
    ('MRC-ONLINE-01', 'Інтернет-магазин (віртуальна покупка)', 2.8),
    ('MRC-UTILITIES-01', 'Комунальні послуги (віртуальна оплата)', 3.0),
    ('MRC-TELECOM-01', 'Мобільний зв\'язок (віртуальна оплата)', 0.9),
    ('MRC-CINEMA-01', 'Кіно (віртуальна покупка)', 0.9),
]

FIRST_NAMES = ['Олена', 'Андрій', 'Ірина', 'Максим', 'Наталія', 'Олег', 'Софія', 'Тарас',
               'Юлія', 'Дмитро', 'Марія', 'Богдан', 'Катерина', 'Іван', 'Анна', 'Роман',
               'Оксана', 'Віктор', 'Дарина', 'Сергій']
LAST_NAMES = ['Коваленко', 'Бондаренко', 'Шевченко', 'Мельник', 'Кравченко', 'Ткаченко',
              'Олійник', 'Лисенко', 'Руденко', 'Савченко', 'Петренко', 'Марченко',
              'Мороз', 'Поліщук', 'Гончаренко', 'Левченко']

STRUCTURING_THRESHOLDS = [5_000, 10_000, 20_000, 50_000]
FRAUD_PATTERNS = ('structuring', 'rapid_succession', 'money_mule',
                  'new_recipient_large_amount', 'night_batch')


@dataclass
class SeedUser:
    index: int
    full_name: str
    email: str
    phone: str
    rate: float              # середня кількість витратних операцій на день
    mu: float                # параметри логнормальних сум
    sigma: float
    salary: float
    user_id: int = 0
    account_id: int = 0
    account_number: str = ''
    contacts: list[int] = field(default_factory=list)   # індекси «друзів» для P2P


@dataclass
class Event:
    """Подія для вставки: out-нога (і, для внутрішнього переказу, in-нога)."""
    ts: datetime
    sender: int | None            # індекс SeedUser або None (зовнішнє надходження)
    receiver: int | None          # індекс SeedUser або None (мерчант)
    amount: float
    tx_type: str
    description: str
    merchant: str | None = None
    is_fraud: bool = False
    pattern: str = 'normal'
    seq: int = 0                  # стабільний порядок для подій з однаковим ts


# ── Допоміжні генератори ──────────────────────────────────────────────────────

def _poisson(rng: random.Random, lam: float) -> int:
    """Пуассон (алгоритм Кнута) — достатньо для λ ≲ 30."""
    if lam <= 0:
        return 0
    limit, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= rng.random()
        if p <= limit:
            return k
        k += 1


def _lognormal_amount(rng: random.Random, mu: float, sigma: float,
                      lo: float = 5.0, hi: float = 60_000.0) -> float:
    return round(min(max(rng.lognormvariate(mu, sigma), lo), hi), 2)


def _p2p_amount(rng: random.Random) -> float:
    amt = rng.lognormvariate(math.log(450), 0.8)
    if rng.random() < 0.55:                       # люди часто переказують «круглі» суми
        return float(max(50, round(amt / 50) * 50))
    return round(max(20.0, amt), 2)


def _local_moment(rng: random.Random, day_local: datetime) -> datetime:
    """Випадковий момент доби з урахуванням HOUR_WEIGHTS → UTC."""
    hour = rng.choices(range(24), weights=HOUR_WEIGHTS, k=1)[0]
    local = day_local.replace(hour=hour, minute=rng.randrange(60), second=rng.randrange(60))
    return local.astimezone(timezone.utc)


def _fake_card_number(rng: random.Random) -> str:
    """Як у CardService: префікс 0000 і навмисно невалідна контрольна цифра Луна."""
    partial = _BIN_PREFIX + ''.join(rng.choices(string.digits, k=11))
    valid_check = (10 - _luhn_checksum(partial + '0')) % 10
    raw = partial + str((valid_check + 1) % 10)
    return f'{raw[:4]} {raw[4:8]} {raw[8:12]} {raw[12:16]}'


def _db_ts(ts: datetime) -> str:
    """Формат created_at: SQLite — як CURRENT_TIMESTAMP, PostgreSQL — ISO з таймзоною."""
    ts = ts.astimezone(timezone.utc)
    return ts.isoformat() if USE_PG else ts.strftime('%Y-%m-%d %H:%M:%S')


# ── Побудова популяції та подій ───────────────────────────────────────────────

def build_users(rng: random.Random, n: int, demo_email: str) -> list[SeedUser]:
    users: list[SeedUser] = []
    used_phones: set[str] = set()
    for i in range(n):
        name = f'{rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}'
        if i == 0:
            name = 'Демо Користувач'
        while True:
            phone = '+38050' + ''.join(rng.choices(string.digits, k=7))
            if phone not in used_phones:
                used_phones.add(phone)
                break
        users.append(SeedUser(
            index=i,
            full_name=name,
            email=demo_email if i == 0 else f'user{i:03d}{SEED_EMAIL_DOMAIN}',
            phone=phone,
            rate=max(0.4, rng.gammavariate(2.0, 1.1)),
            mu=rng.gauss(math.log(140), 0.35),
            sigma=rng.uniform(0.7, 1.1),
            salary=round(rng.lognormvariate(math.log(30_000), 0.3), -2),
        ))
    avg_mult = sum(m for _, _, m in MERCHANTS) / len(MERCHANTS)
    for u in users:
        # Дохід корелює з витратами (як у реальних профілях): зарплата покриває
        # очікувані місячні витрати з запасом 10–40%, інакше багато операцій
        # відкидалося б через нестачу коштів.
        daily = u.rate * (0.8 * math.exp(u.mu + u.sigma ** 2 / 2) * avg_mult + 0.2 * 620)
        u.salary = max(u.salary, round(daily * 30.44 * rng.uniform(1.1, 1.4), -2))
    for u in users:
        others = [o.index for o in users if o.index != u.index]
        u.contacts = rng.sample(others, k=min(len(others), rng.randint(3, 6)))
    return users


def build_normal_events(rng: random.Random, users: list[SeedUser],
                        start: datetime, end: datetime) -> list[Event]:
    events: list[Event] = []
    day = start.astimezone(KYIV).replace(hour=0, minute=0, second=0, microsecond=0)
    end_local = end.astimezone(KYIV)
    for u in users:
        # Стартовий баланс, щоб перші витрати не впиралися в нуль
        events.append(Event(start - timedelta(hours=1), None, u.index,
                            round(rng.lognormvariate(math.log(15_000), 0.4), 2),
                            'topup', 'Стартове поповнення'))
    while day <= end_local:
        dow = day.weekday()
        for u in users:
            if day.day == 1 + (u.index % 5):        # зарплата 1–5 числа місяця
                ts = day.replace(hour=9, minute=rng.randrange(60)).astimezone(timezone.utc)
                if start <= ts <= end:
                    events.append(Event(ts, None, u.index, u.salary, 'topup',
                                        'Зарплата'))
            if rng.random() < 0.04:                   # рідкісне поповнення з «картки іншого банку»
                ts = _local_moment(rng, day)
                if start <= ts <= end:
                    events.append(Event(ts, None, u.index,
                                        round(rng.lognormvariate(math.log(2_000), 0.6), -1),
                                        'topup', 'Поповнення рахунку'))
            for _ in range(_poisson(rng, u.rate * DOW_MULT[dow])):
                ts = _local_moment(rng, day)
                if not (start <= ts <= end):
                    continue
                if rng.random() < 0.8:
                    acc, desc, mult = rng.choice(MERCHANTS)
                    amount = _lognormal_amount(rng, u.mu + math.log(mult), u.sigma)
                    events.append(Event(ts, u.index, None, amount, 'payment', desc, merchant=acc))
                else:
                    to = rng.choice(u.contacts)
                    events.append(Event(ts, u.index, to, _p2p_amount(rng), 'transfer',
                                        'Переказ знайомому'))
        day += timedelta(days=1)
    return events


def _fraud_time(rng: random.Random, start: datetime, end: datetime, recent: bool,
                span_minutes: int = 0) -> datetime:
    """Момент старту шахрайської серії: або в межах останніх ~6 годин, або будь-коли."""
    latest = end - timedelta(minutes=span_minutes + 1)
    if recent:
        return latest - timedelta(minutes=rng.randint(0, 360))
    return start + (latest - start) * rng.random()


def build_fraud_events(rng: random.Random, users: list[SeedUser], start: datetime,
                       end: datetime, fraud_users: int, recent_share: float,
                       min_episodes: int = 2, max_episodes: int = 4) -> list[Event]:
    """Вбудовує позначені шахрайські патерни. Демо-користувач (індекс 0) не чіпається.

    Кожен «актор» отримує один тип патерну (по колу) і 2–4 епізоди в різний час.
    """
    events: list[Event] = []
    pool = [u.index for u in users[1:]]
    rng.shuffle(pool)
    actors = pool[:max(1, min(fraud_users, len(pool)))]
    strangers = pool[len(actors):] or pool

    episodes = [(actor, FRAUD_PATTERNS[k % len(FRAUD_PATTERNS)])
                for k, actor in enumerate(actors)
                for _ in range(rng.randint(min_episodes, max_episodes))]
    for actor, pattern in episodes:
        recent = rng.random() < recent_share

        if pattern == 'structuring':
            t0 = _fraud_time(rng, start, end, recent, span_minutes=60 if recent else 3 * 24 * 60)
            threshold = rng.choice(STRUCTURING_THRESHOLDS)
            targets = rng.sample(strangers, k=min(2, len(strangers)))
            for j in range(rng.randint(3, 5)):
                amount = round(threshold * rng.uniform(0.905, 0.994), 2)
                ts = t0 + timedelta(hours=rng.uniform(0, 72)) if not recent else t0 + timedelta(minutes=12 * j)
                events.append(Event(ts, actor, rng.choice(targets), amount, 'transfer',
                                    'Повернення боргу', is_fraud=True, pattern=pattern))

        elif pattern == 'rapid_succession':
            t0 = _fraud_time(rng, start, end, recent, span_minutes=10)
            for j in range(rng.randint(6, 10)):
                ts = t0 + timedelta(seconds=rng.randint(20, 75) * j)
                events.append(Event(ts, actor, rng.choice(strangers),
                                    round(rng.uniform(200, 2_000), 2), 'transfer',
                                    'Переказ', is_fraud=True, pattern=pattern))

        elif pattern == 'money_mule':
            # actor = мул M1; next_hop = M2; отримувачі коштів — різні «жертви»
            t0 = _fraud_time(rng, start, end, recent,
                             span_minutes=(60 if recent else 2 * 24 * 60) + 60)
            senders = rng.sample([s for s in pool if s != actor], k=min(len(pool) - 1, rng.randint(6, 9)))
            total = 0.0
            last_in = t0
            for s in senders:
                ts = t0 + timedelta(minutes=rng.uniform(0, 2 * 24 * 60)) if not recent \
                    else t0 + timedelta(minutes=rng.uniform(0, 60))
                amount = round(rng.uniform(800, 4_500), 2)
                total += amount
                last_in = max(last_in, ts)
                events.append(Event(ts, s, actor, amount, 'transfer', 'Оплата за оголошенням',
                                    is_fraud=True, pattern=pattern))
            hop1 = rng.choice([s for s in pool if s != actor and s not in senders] or pool)
            ts_out = last_in + timedelta(minutes=rng.uniform(3, 25))
            forward = round(total * rng.uniform(0.93, 0.97), 2)
            events.append(Event(ts_out, actor, hop1, forward, 'transfer', 'Переказ',
                                is_fraud=True, pattern=pattern))
            hop2 = rng.choice([s for s in pool if s not in (actor, hop1)] or pool)
            events.append(Event(ts_out + timedelta(minutes=rng.uniform(4, 25)), hop1, hop2,
                                round(forward * rng.uniform(0.93, 0.97), 2), 'transfer', 'Переказ',
                                is_fraud=True, pattern=pattern))

        elif pattern == 'new_recipient_large_amount':
            ts = _fraud_time(rng, start, end, recent)
            u = users[actor]
            p75 = math.exp(u.mu + 0.674 * u.sigma)
            fresh = [s for s in strangers if s not in u.contacts] or strangers
            amount = round(min(p75 * rng.uniform(5, 15), 45_000), 2)
            events.append(Event(ts, actor, rng.choice(fresh), max(amount, 1_500.0), 'transfer',
                                'Терміново, допоможи', is_fraud=True, pattern=pattern))

        elif pattern == 'night_batch':
            base = _fraud_time(rng, start, end, recent, span_minutes=30)
            t0 = base.replace(hour=rng.randint(2, 4), minute=rng.randint(0, 29))
            if t0 > end - timedelta(minutes=31):
                t0 -= timedelta(days=1)
            for j in range(rng.randint(3, 6)):
                events.append(Event(t0 + timedelta(minutes=rng.uniform(0, 29)), actor,
                                    rng.choice(strangers), round(rng.uniform(300, 3_000), 2),
                                    'transfer', 'Переказ', is_fraud=True, pattern=pattern))
    return events


# ── Запис у БД ────────────────────────────────────────────────────────────────

def _reset(conn) -> int:
    rows = conn.execute(
        'SELECT id FROM users WHERE email LIKE %s', (f'%{SEED_EMAIL_DOMAIN}',)
    ).fetchall()
    ids = [r['id'] for r in rows]
    for uid in ids:
        acc = conn.execute('SELECT id FROM accounts WHERE user_id = %s', (uid,)).fetchone()
        if acc:
            # payment_orders/journal посилаються на рахунок без CASCADE — чистимо явно
            conn.execute('DELETE FROM journal_entries WHERE account_id = %s', (acc['id'],))
            conn.execute('DELETE FROM account_holds WHERE account_id = %s', (acc['id'],))
        conn.execute('DELETE FROM users WHERE id = %s', (uid,))
    return len(ids)


def insert_all(users: list[SeedUser], events: list[Event], rng: random.Random,
               password_hash: str, start: datetime) -> dict:
    sfx = get_returning_id_suffix()
    stats = Counter()
    skipped = Counter()
    with get_connection() as conn:
        for u in users:
            created = start - timedelta(days=rng.randint(20, 400))
            cur = conn.execute(
                'INSERT INTO users(full_name, phone, email, password_hash, role, created_at) '
                "VALUES(%s, %s, %s, %s, 'user', %s)" + sfx,
                (u.full_name, u.phone, u.email.lower(), password_hash, _db_ts(created)),
            )
            u.user_id = insert_last_id(cur)
            u.account_number = f'{ACCOUNT_PREFIX}{100000 + u.user_id}'
            cur = conn.execute(
                'INSERT INTO accounts(user_id, account_number, currency, balance, created_at) '
                'VALUES(%s, %s, %s, 0, %s)' + sfx,
                (u.user_id, u.account_number, CURRENCY_CODE, _db_ts(created)),
            )
            u.account_id = insert_last_id(cur)
            for c in range(rng.choice((1, 1, 2))):
                expires = (start + timedelta(days=3 * 365)).strftime('%Y-%m-01')
                conn.execute(
                    'INSERT INTO cards(account_id, card_number, card_type, design, status, holder_name, '
                    'cvv, is_primary, issued_at, expires_at) VALUES(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)',
                    (u.account_id, _fake_card_number(rng), 'virtual',
                     rng.choice(('gold', 'navy', 'rose', 'emerald')), 'active',
                     u.full_name.upper()[:26], ''.join(rng.choices(string.digits, k=3)),
                     (c == 0) if USE_PG else int(c == 0), _db_ts(created + timedelta(days=1)), expires),
                )

        balances = defaultdict(float)
        events.sort(key=lambda e: (e.ts, e.seq))

        def add_tx(user: SeedUser, tx_type: str, direction: str, amount: float,
                   description: str, related: str | None, ts: datetime, ev: Event) -> None:
            cur = conn.execute(
                'INSERT INTO transactions(account_id, tx_type, direction, amount, description, '
                'related_account, created_at) VALUES(%s, %s, %s, %s, %s, %s, %s)' + sfx,
                (user.account_id, tx_type, direction, amount, description, related, _db_ts(ts)),
            )
            tx_id = insert_last_id(cur)
            conn.execute(
                'INSERT INTO research_labels(transaction_id, is_fraud, pattern) VALUES(%s, %s, %s)',
                (tx_id, ev.is_fraud if USE_PG else int(ev.is_fraud), ev.pattern),
            )
            stats[(direction, ev.pattern)] += 1

        for ev in events:
            if ev.sender is None:                                  # зовнішнє надходження
                rcv = users[ev.receiver]
                balances[rcv.index] += ev.amount
                add_tx(rcv, ev.tx_type, 'in', ev.amount, ev.description, None, ev.ts, ev)
                continue
            snd = users[ev.sender]
            if balances[snd.index] < ev.amount:
                if not ev.is_fraud:
                    skipped['insufficient_funds'] += 1
                    continue
                # шахрайські серії не повинні зникати — «доливаємо» віртуальні гроші заздалегідь
                top = round(ev.amount - balances[snd.index] + 500, 2)
                balances[snd.index] += top
                add_tx(snd, 'topup', 'in', top, 'Поповнення рахунку', None,
                       ev.ts - timedelta(minutes=7), Event(ev.ts, None, snd.index, top, 'topup', ''))
            balances[snd.index] -= ev.amount
            if ev.receiver is None:                                # оплата мерчанту
                add_tx(snd, ev.tx_type, 'out', ev.amount, ev.description, ev.merchant, ev.ts, ev)
            else:                                                  # внутрішній переказ (дві ноги)
                rcv = users[ev.receiver]
                balances[rcv.index] += ev.amount
                add_tx(snd, ev.tx_type, 'out', ev.amount, ev.description, rcv.account_number, ev.ts, ev)
                add_tx(rcv, ev.tx_type, 'in', ev.amount, ev.description, snd.account_number, ev.ts, ev)

        for u in users:
            conn.execute('UPDATE accounts SET balance = %s WHERE id = %s',
                         (round(balances[u.index], 2), u.account_id))
    return {'stats': stats, 'skipped': skipped}


# ── CLI ───────────────────────────────────────────────────────────────────────

def parse_args(argv=None):
    p = argparse.ArgumentParser(description='Синтетичні дані пісочниці Kopiyka (віртуальні гроші).')
    p.add_argument('--users', type=int, default=50, help='кількість демо-користувачів (≥2)')
    p.add_argument('--months', type=float, default=6.0, help='тривалість історії, місяців')
    p.add_argument('--seed', type=int, default=42, help='seed генератора (детермінованість)')
    p.add_argument('--anchor', type=str, default=None,
                   help='кінець періоду, ISO-8601 UTC (за замовчуванням — поточна хвилина)')
    p.add_argument('--fraud-users', type=int, default=None,
                   help='скільки користувачів-«акторів» шахрайства (за замовчуванням ~15%% від N)')
    p.add_argument('--recent-share', type=float, default=0.25,
                   help='частка шахрайських серій в останні ~6 годин (для правил з вікнами)')
    p.add_argument('--reset', action='store_true',
                   help=f'спершу видалити попередньо згенерованих користувачів (*{SEED_EMAIL_DOMAIN})')
    return p.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    if args.users < 2:
        print('Потрібно щонайменше 2 користувачі.', file=sys.stderr)
        return 2
    rng = random.Random(args.seed)
    if args.anchor:
        end = datetime.fromisoformat(args.anchor.replace('Z', '+00:00'))
        end = end if end.tzinfo else end.replace(tzinfo=timezone.utc)
    else:
        end = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    start = end - timedelta(days=round(30.44 * args.months))
    fraud_users = args.fraud_users if args.fraud_users is not None else max(5, round(args.users * 0.15))

    demo_email = (os.getenv('SEED_DEMO_EMAIL') or DEFAULT_DEMO_EMAIL).strip().lower()
    demo_password = os.getenv('SEED_DEMO_PASSWORD') or DEFAULT_DEMO_PASSWORD
    if not demo_email.endswith(SEED_EMAIL_DOMAIN):
        print(f'SEED_DEMO_EMAIL має закінчуватися на {SEED_EMAIL_DOMAIN} (щоб --reset його знаходив).',
              file=sys.stderr)
        return 2

    init_db()
    with get_connection() as conn:
        existing = conn.execute('SELECT COUNT(*) AS n FROM users WHERE email LIKE %s',
                                (f'%{SEED_EMAIL_DOMAIN}',)).fetchone()['n']
        if existing and not args.reset:
            print(f'У БД уже є {existing} згенерованих користувачів. Запустіть з --reset.', file=sys.stderr)
            return 1
        if existing:
            print(f'Видалено попередніх згенерованих користувачів: {_reset(conn)}')

    users = build_users(rng, args.users, demo_email)
    events = build_normal_events(rng, users, start, end)
    events += build_fraud_events(rng, users, start, end, fraud_users, args.recent_share)
    for i, ev in enumerate(events):
        ev.seq = i
    # Один спільний хеш пароля для всіх демо-акаунтів (bcrypt повільний; це тестові дані)
    result = insert_all(users, events, rng, hash_password(demo_password), start)

    stats = result['stats']
    total = sum(stats.values())
    out_total = sum(v for (d, _), v in stats.items() if d == 'out')
    out_fraud = sum(v for (d, p), v in stats.items() if d == 'out' and p != 'normal')
    print(f'Пісочниця Kopiyka (усі суми — токени TAX, {CURRENCY_CODE})')
    print(f'Період: {start.isoformat()} … {end.isoformat()}  seed={args.seed}')
    print(f'Користувачів: {len(users)}, транзакцій: {total} (вихідних: {out_total})')
    print(f'Шахрайських вихідних: {out_fraud} ({out_fraud / max(out_total, 1):.2%})')
    for pattern in FRAUD_PATTERNS:
        n = stats.get(('out', pattern), 0)
        print(f'  {pattern:<28} out={n}')
    if result['skipped']:
        print(f'Пропущено звичайних операцій (не вистачило коштів): {dict(result["skipped"])}')
    print(f'Демо-вхід: {demo_email} (пароль — SEED_DEMO_PASSWORD у server/.env.example)')
    print(f'Рахунок демо-користувача: {users[0].account_number}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
