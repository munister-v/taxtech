-- PostgreSQL-схема навчального банку Kopiyka (пісочниця на ВІРТУАЛЬНИХ грошах, валюта VUAH).

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user',
    pin_hash TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMPTZ DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    account_number TEXT NOT NULL UNIQUE,
    currency TEXT NOT NULL DEFAULT 'VUAH',
    balance REAL NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS family_contacts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_name TEXT NOT NULL,
    relation_type TEXT NOT NULL,
    phone TEXT,
    account_number TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS savings_goals (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    target_amount REAL NOT NULL,
    current_amount REAL NOT NULL DEFAULT 0,
    deadline DATE,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS donations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fund_name TEXT NOT NULL,
    amount REAL NOT NULL,
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payouts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    payout_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'credited',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ── Платіжне ядро ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_orders (
    id SERIAL PRIMARY KEY,
    idempotency_key VARCHAR(64) NOT NULL UNIQUE,
    initiator_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    sender_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
    recipient_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
    amount NUMERIC(14,2) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    risk_score INTEGER NOT NULL DEFAULT 0,
    risk_level VARCHAR(20) NOT NULL DEFAULT 'low',
    risk_flags TEXT NOT NULL DEFAULT '[]',
    review_state VARCHAR(20) NOT NULL DEFAULT 'none',
    assigned_admin_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ,
    decision_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    decision_note TEXT,
    decided_at TIMESTAMPTZ,
    escalation_level INTEGER NOT NULL DEFAULT 0,
    approval_state VARCHAR(20) NOT NULL DEFAULT 'none',
    approval_requested_action VARCHAR(20),
    approval_requested_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    approval_requested_at TIMESTAMPTZ,
    approval_decided_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    approval_decided_at TIMESTAMPTZ,
    approval_note TEXT,
    tx_id_out INTEGER,
    tx_id_in INTEGER,
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status ON payment_orders(status);
CREATE INDEX IF NOT EXISTS idx_payment_orders_sender ON payment_orders(sender_account_id, created_at);

CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    tx_type TEXT NOT NULL,
    direction TEXT NOT NULL,
    amount REAL NOT NULL,
    description TEXT NOT NULL,
    related_account TEXT,
    payment_order_id INTEGER REFERENCES payment_orders(id),
    note TEXT,
    tags TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_transactions_account_created ON transactions(account_id, direction, created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_related ON transactions(related_account, created_at);

CREATE TABLE IF NOT EXISTS risk_events (
    id SERIAL PRIMARY KEY,
    payment_order_id INTEGER REFERENCES payment_orders(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    event_type VARCHAR(60) NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'low',
    score_delta INTEGER NOT NULL DEFAULT 0,
    details TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by INTEGER REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS payment_order_events (
    id SERIAL PRIMARY KEY,
    payment_order_id INTEGER NOT NULL REFERENCES payment_orders(id) ON DELETE CASCADE,
    actor_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    event_type VARCHAR(40) NOT NULL,
    details TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payment_order_events_order ON payment_order_events(payment_order_id);

CREATE TABLE IF NOT EXISTS integrity_hashes (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    prev_hash VARCHAR(64) NOT NULL,
    tx_hash VARCHAR(64) NOT NULL,
    chain_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_integrity_hashes_account ON integrity_hashes(account_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_integrity_hashes_tx ON integrity_hashes(transaction_id);

CREATE TABLE IF NOT EXISTS journal_entries (
    id              SERIAL PRIMARY KEY,
    payment_order_id INTEGER REFERENCES payment_orders(id) ON DELETE SET NULL,
    tx_id           INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
    account_id      INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    entry_type      VARCHAR(6) NOT NULL CHECK (entry_type IN ('debit','credit')),
    amount          NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    currency        VARCHAR(4) NOT NULL DEFAULT 'VUAH',
    description     TEXT NOT NULL DEFAULT '',
    balance_after   NUMERIC(14,2),
    settled         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_journal_account ON journal_entries(account_id);
CREATE INDEX IF NOT EXISTS idx_journal_order   ON journal_entries(payment_order_id);

CREATE TABLE IF NOT EXISTS fraud_velocity_cache (
    account_id  INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    bucket      VARCHAR(20) NOT NULL,
    hit_count   INTEGER NOT NULL DEFAULT 1,
    last_seen   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (account_id, bucket)
);

CREATE TABLE IF NOT EXISTS account_holds (
    id              SERIAL PRIMARY KEY,
    account_id      INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    payment_order_id INTEGER REFERENCES payment_orders(id) ON DELETE SET NULL,
    amount          NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    currency        VARCHAR(4) NOT NULL DEFAULT 'VUAH',
    reason          VARCHAR(100) NOT NULL DEFAULT 'authorization',
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','released','expired','captured')),
    expires_at      TIMESTAMPTZ NOT NULL,
    released_at     TIMESTAMPTZ,
    capture_tx_id   INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_holds_account ON account_holds(account_id);
CREATE INDEX IF NOT EXISTS idx_holds_status  ON account_holds(status);

CREATE TABLE IF NOT EXISTS api_idempotency (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(80) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    request_hash VARCHAR(64) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'processing',
    response_code INTEGER,
    response_payload TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, action, idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_api_idempotency_created ON api_idempotency(created_at);

-- ── Персональні фінанси ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payment_templates (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    recipient_account TEXT NOT NULL,
    amount REAL,
    description TEXT NOT NULL DEFAULT '',
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL DEFAULT 'info',
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    icon VARCHAR(10) NOT NULL DEFAULT '🔔',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS budget_limits (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tx_type VARCHAR(30) NOT NULL,
    monthly_limit NUMERIC(14,2) NOT NULL CHECK (monthly_limit > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, tx_type)
);

CREATE TABLE IF NOT EXISTS recurring_transactions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    amount NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    tx_type VARCHAR(30) NOT NULL DEFAULT 'transfer',
    recipient_account VARCHAR(50),
    description TEXT NOT NULL DEFAULT '',
    frequency VARCHAR(20) NOT NULL DEFAULT 'monthly',
    next_run_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS debts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_name VARCHAR(150) NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    direction VARCHAR(20) NOT NULL DEFAULT 'owed_to_me',
    description TEXT,
    is_settled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settled_at TIMESTAMPTZ
);

-- ── Віртуальні картки (номери з префіксом 0000 — свідомо невалідні) ────────
CREATE TABLE IF NOT EXISTS cards (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    card_number TEXT NOT NULL UNIQUE,
    card_type TEXT NOT NULL DEFAULT 'virtual',
    design VARCHAR(20) NOT NULL DEFAULT 'gold',
    status TEXT NOT NULL DEFAULT 'active',
    holder_name TEXT,
    cvv VARCHAR(3) NOT NULL DEFAULT '000',
    balance NUMERIC(14,2) NOT NULL DEFAULT 0,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATE NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_cards_account_id ON cards(account_id);
CREATE INDEX IF NOT EXISTS idx_cards_card_number ON cards(card_number);

-- ── Дослідницька таблиця: ground-truth мітки синтетичних транзакцій ────────
-- Заповнюється лише scripts/seed_sandbox.py; бізнес-логіка банку її не читає.
CREATE TABLE IF NOT EXISTS research_labels (
    transaction_id INTEGER PRIMARY KEY REFERENCES transactions(id) ON DELETE CASCADE,
    is_fraud BOOLEAN NOT NULL DEFAULT FALSE,
    pattern TEXT NOT NULL DEFAULT 'normal'
);
CREATE INDEX IF NOT EXISTS idx_research_labels_pattern ON research_labels(pattern);

-- Вхід через Face ID / Touch ID у веб-застосунку (WebAuthn passkey)
CREATE TABLE IF NOT EXISTS passkeys (
    id            SERIAL PRIMARY KEY,
    user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    credential_id TEXT NOT NULL UNIQUE,
    public_key    TEXT NOT NULL,
    sign_count    INTEGER NOT NULL DEFAULT 0,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
