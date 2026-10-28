"""Репозиторій віртуальних карток пісочниці Kopiyka."""
from __future__ import annotations

import json
import threading

from ..database import USE_PG, get_connection, get_returning_id_suffix, insert_last_id
from .base import BaseRepository

_STYLE_READY = False
_STYLE_LOCK = threading.Lock()


def _ensure_style_column() -> None:
    """Колонка style (JSON зовнішнього вигляду картки) для старих баз."""
    global _STYLE_READY
    if _STYLE_READY:
        return
    with _STYLE_LOCK:
        if _STYLE_READY:
            return
        with get_connection() as conn:
            if USE_PG:
                conn.execute('ALTER TABLE cards ADD COLUMN IF NOT EXISTS style TEXT')
            elif 'style' not in {r['name'] for r in conn.execute('PRAGMA table_info(cards)').fetchall()}:
                conn.execute('ALTER TABLE cards ADD COLUMN style TEXT')
        _STYLE_READY = True


def _decode(row) -> dict | None:
    """Рядок картки як словник; style з JSON-тексту стає обʼєктом (або None)."""
    if not row:
        return None
    card = dict(row)
    raw = card.get('style')
    try:
        card['style'] = json.loads(raw) if isinstance(raw, str) and raw else None
    except ValueError:
        card['style'] = None
    return card


class CardRepository(BaseRepository):
    def issue_card(self, account_id: int, card_number: str, holder_name: str,
                   expires_at: str, card_type: str = 'virtual', design: str = 'gold',
                   cvv: str = '000') -> int:
        with self.connection() as conn:
            cursor = conn.execute(
                '''
                INSERT INTO cards(account_id, card_number, card_type, design, holder_name, expires_at, cvv)
                VALUES(%s, %s, %s, %s, %s, %s, %s)
                ''' + get_returning_id_suffix(),
                (account_id, card_number, card_type, design, holder_name, expires_at, cvv),
            )
            return insert_last_id(cursor)

    def list_cards(self, account_id: int) -> list[dict]:
        _ensure_style_column()
        with self.connection() as conn:
            # Join account to get account balance for primary card display
            rows = conn.execute(
                '''SELECT c.*, a.balance AS account_balance
                   FROM cards c JOIN accounts a ON a.id = c.account_id
                   WHERE c.account_id = %s ORDER BY c.issued_at DESC''',
                (account_id,),
            ).fetchall()
            return [_decode(r) for r in rows]

    def get_card(self, card_id: int, account_id: int):
        with self.connection() as conn:
            row = conn.execute(
                'SELECT * FROM cards WHERE id = %s AND account_id = %s',
                (card_id, account_id),
            ).fetchone()
            return _decode(row)

    def get_card_by_number(self, card_number: str):
        with self.connection() as conn:
            row = conn.execute(
                'SELECT c.*, a.account_number, a.balance, a.user_id '
                'FROM cards c JOIN accounts a ON a.id = c.account_id '
                'WHERE c.card_number = %s',
                (card_number,),
            ).fetchone()
            return dict(row) if row else None

    def set_status(self, card_id: int, account_id: int, status: str) -> None:
        with self.connection() as conn:
            conn.execute(
                'UPDATE cards SET status = %s WHERE id = %s AND account_id = %s',
                (status, card_id, account_id),
            )

    def set_style(self, card_id: int, account_id: int, style_json: str | None) -> None:
        _ensure_style_column()
        with self.connection() as conn:
            conn.execute(
                'UPDATE cards SET style = %s WHERE id = %s AND account_id = %s',
                (style_json, card_id, account_id),
            )

    def set_design(self, card_id: int, account_id: int, design: str) -> None:
        with self.connection() as conn:
            conn.execute(
                'UPDATE cards SET design = %s WHERE id = %s AND account_id = %s',
                (design, card_id, account_id),
            )

    def set_primary(self, account_id: int, card_id: int) -> None:
        """Знімає is_primary з усіх карток рахунку, встановлює на card_id."""
        with self.connection() as conn:
            conn.execute(
                'UPDATE cards SET is_primary = %s WHERE account_id = %s',
                (False, account_id),
            )
            conn.execute(
                'UPDATE cards SET is_primary = %s WHERE id = %s AND account_id = %s',
                (True, card_id, account_id),
            )

    def update_card_balance(self, card_id: int, account_id: int, delta: float) -> None:
        """Змінює balance картки на delta (може бути від'ємним)."""
        with self.connection() as conn:
            conn.execute(
                'UPDATE cards SET balance = balance + %s WHERE id = %s AND account_id = %s',
                (delta, card_id, account_id),
            )

    def get_primary_card(self, account_id: int):
        with self.connection() as conn:
            row = conn.execute(
                'SELECT * FROM cards WHERE account_id = %s AND is_primary = %s LIMIT 1',
                (account_id, True),
            ).fetchone()
            return dict(row) if row else None

    def count_active(self, account_id: int) -> int:
        with self.connection() as conn:
            row = conn.execute(
                "SELECT COUNT(*) AS n FROM cards WHERE account_id = %s AND status != 'closed'",
                (account_id,),
            ).fetchone()
            return int(row['n']) if row else 0
