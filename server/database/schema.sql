-- SQLite-схема навчального банку Kopiyka (пісочниця на ВІРТУАЛЬНИХ грошах, валюта TAX).
-- Усі дати зберігаються як текст 'YYYY-MM-DD HH:MM:SS' в UTC (формат CURRENT_TIMESTAMP).
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user',
    pin_hash TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TEXT DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    account_number TEXT NOT NULL UNIQUE,
    currency TEXT NOT NULL DEFAULT 'TAX',
    balance REAL NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS family_contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    contact_name TEXT NOT NULL,
    relation_type TEXT NOT NULL,
    phone TEXT,
    account_number TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS savings_goals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    target_amount REAL NOT NULL,
    current_amount REAL NOT NULL DEFAULT 0,
    deadline TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS donations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    fund_name TEXT NOT NULL,
    amount REAL NOT NULL,
    comment TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS payouts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    payout_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'credited',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ── Платіжне ядро ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    idempotency_key TEXT NOT NULL UNIQUE,
    initiator_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    sender_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
    recipient_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
    amount REAL NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending',
    risk_score INTEGER NOT NULL DEFAULT 0,
    risk_level TEXT NOT NULL DEFAULT 'low',
    risk_flags TEXT NOT NULL DEFAULT '[]',
    review_state TEXT NOT NULL DEFAULT 'none',
    assigned_admin_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    assigned_at TEXT,
    decision_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    decision_note TEXT,
    decided_at TEXT,
    escalation_level INTEGER NOT NULL DEFAULT 0,
    approval_state TEXT NOT NULL DEFAULT 'none',
    approval_requested_action TEXT,
    approval_requested_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    approval_requested_at TEXT,
    approval_decided_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    approval_decided_at TEXT,
    approval_note TEXT,
    tx_id_out INTEGER,
    tx_id_in INTEGER,
    failure_reason TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status ON payment_orders(status);
CREATE INDEX IF NOT EXISTS idx_payment_orders_sender ON payment_orders(sender_account_id, created_at);

CREATE TABLE IF NOT EXISTS transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    tx_type TEXT NOT NULL,
    direction TEXT NOT NULL,
    amount REAL NOT NULL,
    description TEXT NOT NULL,
    related_account TEXT,
    payment_order_id INTEGER,
    note TEXT,
    tags TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_transactions_account_created ON transactions(account_id, direction, created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_related ON transactions(related_account, created_at);

CREATE TABLE IF NOT EXISTS risk_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_order_id INTEGER REFERENCES payment_orders(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'low',
    score_delta INTEGER NOT NULL DEFAULT 0,
    details TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    resolved_at TEXT,
    resolved_by INTEGER REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS payment_order_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_order_id INTEGER NOT NULL REFERENCES payment_orders(id) ON DELETE CASCADE,
    actor_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    details TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_payment_order_events_order ON payment_order_events(payment_order_id);

CREATE TABLE IF NOT EXISTS integrity_hashes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    prev_hash TEXT NOT NULL,
    tx_hash TEXT NOT NULL,
    chain_hash TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS journal_entries (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_order_id INTEGER REFERENCES payment_orders(id) ON DELETE SET NULL,
    tx_id            INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
    account_id       INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    entry_type       TEXT NOT NULL CHECK (entry_type IN ('debit','credit')),
    amount           REAL NOT NULL CHECK (amount > 0),
    currency         TEXT NOT NULL DEFAULT 'TAX',
    description      TEXT NOT NULL DEFAULT '',
    balance_after    REAL,
    settled          INTEGER NOT NULL DEFAULT 0,
    created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_journal_account ON journal_entries(account_id);

CREATE TABLE IF NOT EXISTS fraud_velocity_cache (
    account_id  INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    bucket      TEXT NOT NULL,
    hit_count   INTEGER NOT NULL DEFAULT 1,
    last_seen   TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (account_id, bucket)
);

CREATE TABLE IF NOT EXISTS account_holds (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id       INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    payment_order_id INTEGER REFERENCES payment_orders(id) ON DELETE SET NULL,
    amount           REAL NOT NULL CHECK (amount > 0),
    currency         TEXT NOT NULL DEFAULT 'TAX',
    reason           TEXT NOT NULL DEFAULT 'authorization',
    status           TEXT NOT NULL DEFAULT 'active',
    expires_at       TEXT NOT NULL,
    released_at      TEXT,
    capture_tx_id    INTEGER,
    created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS api_idempotency (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'processing',
    response_code INTEGER,
    response_payload TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (user_id, action, idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_api_idempotency_created ON api_idempotency(created_at);

-- ── Персональні фінанси ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    action TEXT NOT NULL,
    details TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS payment_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    name TEXT NOT NULL,
    recipient_account TEXT NOT NULL,
    amount REAL,
    description TEXT NOT NULL DEFAULT '',
    is_system INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'info',
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    icon TEXT NOT NULL DEFAULT '🔔',
    is_read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS budget_limits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tx_type TEXT NOT NULL,
    monthly_limit REAL NOT NULL CHECK (monthly_limit > 0),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (user_id, tx_type)
);

CREATE TABLE IF NOT EXISTS recurring_transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount REAL NOT NULL CHECK (amount > 0),
    tx_type TEXT NOT NULL DEFAULT 'transfer',
    recipient_account TEXT,
    description TEXT NOT NULL DEFAULT '',
    frequency TEXT NOT NULL DEFAULT 'monthly',
    next_run_date TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS debts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_name TEXT NOT NULL,
    amount REAL NOT NULL,
    direction TEXT NOT NULL DEFAULT 'owed_to_me',
    description TEXT,
    is_settled INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    settled_at TEXT
);

-- ── Віртуальні картки (номери з префіксом 0000 — свідомо невалідні) ────────
CREATE TABLE IF NOT EXISTS cards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    card_number TEXT NOT NULL UNIQUE,
    card_type TEXT NOT NULL DEFAULT 'virtual',
    design TEXT NOT NULL DEFAULT 'gold',
    status TEXT NOT NULL DEFAULT 'active',
    holder_name TEXT,
    cvv TEXT NOT NULL DEFAULT '000',
    balance REAL NOT NULL DEFAULT 0,
    is_primary INTEGER NOT NULL DEFAULT 0,
    issued_at TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL,
    FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_cards_account_id ON cards(account_id);
CREATE INDEX IF NOT EXISTS idx_cards_card_number ON cards(card_number);

-- ── Дослідницька таблиця: ground-truth мітки синтетичних транзакцій ────────
-- Заповнюється лише scripts/seed_sandbox.py; бізнес-логіка банку її не читає.
CREATE TABLE IF NOT EXISTS research_labels (
    transaction_id INTEGER PRIMARY KEY REFERENCES transactions(id) ON DELETE CASCADE,
    is_fraud INTEGER NOT NULL DEFAULT 0,
    pattern TEXT NOT NULL DEFAULT 'normal'
);
CREATE INDEX IF NOT EXISTS idx_research_labels_pattern ON research_labels(pattern);

-- Вхід через Face ID / Touch ID у веб-застосунку (WebAuthn passkey)
CREATE TABLE IF NOT EXISTS passkeys (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    credential_id TEXT NOT NULL UNIQUE,
    public_key    TEXT NOT NULL,
    sign_count    INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT DEFAULT CURRENT_TIMESTAMP
);
