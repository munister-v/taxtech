"""Модуль роботи з БД: PostgreSQL або SQLite.

Уся схема (включно з платіжним ядром та дослідницькою таблицею
research_labels) описана у database/schema.sql та database/schema_pg.sql.
Таблиці депозитів і кредитів створюють їхні сервіси (_ensure_table).
"""
from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from .config import DATABASE_PATH, DATABASE_URL, SCHEMA_PATH, SCHEMA_PG_PATH, USE_PG

if USE_PG:
    import psycopg2
    import psycopg2.pool
    from psycopg2.extras import RealDictCursor

# ── PostgreSQL connection pool (shared across all requests) ──────────────────
# Reuses connections instead of opening a new one per request (~50-200ms saved)
_pg_pool: 'psycopg2.pool.ThreadedConnectionPool | None' = None


def _get_pg_pool():
    global _pg_pool
    if _pg_pool is None or _pg_pool.closed:
        _pg_pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=1,
            maxconn=5,          # невеликий пул: dev-сервер і дослідницькі прогони
            dsn=DATABASE_URL,
            cursor_factory=RealDictCursor,
            connect_timeout=5,  # don't block app boot forever when PG is cold/unreachable
        )
    return _pg_pool


def dict_factory(cursor: sqlite3.Cursor, row: tuple) -> dict:
    """Повертає рядок SQLite у вигляді словника."""
    return {col[0]: row[idx] for idx, col in enumerate(cursor.description)}


@contextmanager
def get_connection_sqlite() -> Iterator[sqlite3.Connection]:
    """Підключення до SQLite."""
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DATABASE_PATH, timeout=30)
    conn.row_factory = dict_factory
    conn.execute('PRAGMA foreign_keys = ON;')
    conn.execute('PRAGMA journal_mode = WAL;')
    conn.execute('PRAGMA synchronous = NORMAL;')
    conn.execute('PRAGMA busy_timeout = 30000;')
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@contextmanager
def get_connection_pg() -> Iterator:
    """Отримує з'єднання з пулу, повертає після використання."""
    pool = _get_pg_pool()
    conn = pool.getconn()
    had_error = False

    # Пул може віддати «мертве» з'єднання після простою.
    # Validate once on checkout and replace dead connections immediately.
    try:
        cur = conn.cursor()
        cur.execute('SELECT 1')
        cur.fetchone()
        cur.close()
    except Exception:
        try:
            pool.putconn(conn, close=True)
        except Exception:
            pass
        conn = pool.getconn()

    try:
        yield conn
        conn.commit()
    except Exception:
        had_error = True
        try:
            if not getattr(conn, 'closed', 1):
                conn.rollback()
        except Exception:
            # Ignore rollback failure on broken/closed connections.
            pass
        raise
    finally:
        try:
            is_closed = bool(getattr(conn, 'closed', 1))
            if had_error or is_closed:
                pool.putconn(conn, close=True)
            else:
                pool.putconn(conn)
        except Exception:
            pass


class _SqliteConnWrapper:
    """Обгортка: execute приймає SQL з %s і підставляє ? для SQLite."""
    def __init__(self, conn):
        self._conn = conn

    def execute(self, sql: str, params=()):
        sql = sql.replace('%s', '?')
        return self._conn.execute(sql, params)


class _PgConnWrapper:
    """Обгортка: execute через cursor для однакового API."""
    def __init__(self, conn):
        self._conn = conn

    def execute(self, sql: str, params=()):
        cur = self._conn.cursor()
        cur.execute(sql, params)
        return cur


@contextmanager
def get_connection() -> Iterator:
    """Єдиний контекст підключення: у репозиторіях використовуйте %s у SQL."""
    if USE_PG:
        with get_connection_pg() as conn:
            yield _PgConnWrapper(conn)
    else:
        with get_connection_sqlite() as conn:
            yield _SqliteConnWrapper(conn)


def init_db() -> None:
    """Ініціалізує схему БД (ідемпотентно: CREATE ... IF NOT EXISTS)."""
    if USE_PG:
        schema_sql = Path(SCHEMA_PG_PATH).read_text(encoding='utf-8')
        with get_connection_pg() as conn:
            with conn.cursor() as cur:
                cur.execute(schema_sql)
    else:
        schema_sql = Path(SCHEMA_PATH).read_text(encoding='utf-8')
        with get_connection_sqlite() as conn:
            conn.executescript(schema_sql)


def get_returning_id_suffix() -> str:
    """Для INSERT у PostgreSQL додайте ' RETURNING id' до запиту."""
    return ' RETURNING id' if USE_PG else ''


def insert_last_id(cursor) -> int:
    """Повертає id після INSERT: RETURNING id для PG, lastrowid для SQLite."""
    if USE_PG:
        row = cursor.fetchone()
        return row['id'] if row else None
    return cursor.lastrowid
