"""Валюти навчального банку: IBAN (ISO 13616, mod 97), курси з прозорим спредом і конвертація.

Курси детерміновані: базовий середній курс плюс повільний дрейф до ±0.4% за годину. Клієнт купує за ask
і продає за bid; різниця до середнього і є ціною обміну. Усе навчальне, TAX це віртуальний токен.
"""
from __future__ import annotations

import hashlib
import re
import zlib
from datetime import datetime, timezone

BANK_CODE = '322001'
COUNTRY = 'UA'
SPREAD = 0.005
SUPPORTED = ('USD', 'EUR', 'GBP', 'PLN', 'CHF')
MID = {'USD': 41.50, 'EUR': 45.20, 'GBP': 53.00, 'PLN': 10.50, 'CHF': 47.30}
NUMERIC = {'TAX': '980', 'USD': '840', 'EUR': '978', 'GBP': '826', 'PLN': '985', 'CHF': '756'}
NAMES = {'TAX': 'TAX token', 'USD': 'US dollar', 'EUR': 'Euro', 'GBP': 'Pound sterling', 'PLN': 'Polish zloty', 'CHF': 'Swiss franc'}
MAX_AMOUNT = 1_000_000.0


# ── IBAN ──────────────────────────────────────────────────────────────────────
def _numeric(s: str) -> str:
    return ''.join(str(int(ch, 36)) for ch in s)


def iban_check_digits(country: str, bban: str) -> str:
    n = int(_numeric(bban + country + '00'))
    return f'{98 - n % 97:02d}'


def make_iban(currency: str, ref: int, user_id: int) -> str:
    """UA + 2 контрольні + 6 код банку + 19 знаків рахунку: код валюти (3) і 16 цифр з номера рахунку."""
    seed = hashlib.sha256(f'{currency}|{int(user_id)}|{int(ref)}'.encode()).hexdigest()
    body = f'{NUMERIC.get(currency, "980")}{int(seed, 16) % 10**16:016d}'
    bban = BANK_CODE + body
    return f'{COUNTRY}{iban_check_digits(COUNTRY, bban)}{bban}'


def clean_iban(raw: str) -> str:
    return re.sub(r'\s+', '', str(raw or '')).upper()


def valid_iban(raw: str) -> bool:
    s = clean_iban(raw)
    if not re.fullmatch(r'[A-Z]{2}\d{2}[A-Z0-9]{11,30}', s):
        return False
    return int(_numeric(s[4:] + s[:4])) % 97 == 1


def pretty_iban(iban: str) -> str:
    s = clean_iban(iban)
    return ' '.join(s[i:i + 4] for i in range(0, len(s), 4))


# ── Курси ─────────────────────────────────────────────────────────────────────
def mid_rate(cur: str, now: datetime | None = None) -> float:
    now = now or datetime.now(timezone.utc)
    seed = zlib.crc32(f'{cur}|{now:%Y%m%d%H}'.encode())
    drift = ((seed % 1001) - 500) / 500 * 0.004
    return round(MID[cur] * (1 + drift), 4)


def quote(cur: str, now: datetime | None = None) -> dict:
    mid = mid_rate(cur, now)
    return {'currency': cur, 'name': NAMES[cur], 'mid': mid, 'bid': round(mid * (1 - SPREAD), 4), 'ask': round(mid * (1 + SPREAD), 4)}


def rates(now: datetime | None = None) -> list[dict]:
    return [quote(c, now) for c in SUPPORTED]


def convert(frm: str, to: str, amount: float, now: datetime | None = None) -> dict:
    """Результат обміну й ціна спреду в TAX. Крос-курс йде через TAX: продаж за bid, купівля за ask."""
    if frm == to or frm not in NUMERIC or to not in NUMERIC:
        raise ValueError('Невірна пара валют.')
    q = {c: quote(c, now) for c in SUPPORTED}
    tax_in = amount if frm == 'TAX' else amount * q[frm]['bid']
    mid_value = amount if frm == 'TAX' else amount * q[frm]['mid']
    out = tax_in if to == 'TAX' else tax_in / q[to]['ask']
    rate = out / amount if amount else 0.0
    out_mid = out if to == 'TAX' else out * q[to]['mid']
    return {'from': frm, 'to': to, 'from_amount': round(amount, 2), 'to_amount': round(out, 2),
            'rate': round(rate, 6), 'spread_tax': round(mid_value - out_mid, 2)}
