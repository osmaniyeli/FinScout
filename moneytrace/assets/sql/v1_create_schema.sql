-- assets/sql/v1_create_schema.sql
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY NOT NULL,
    institution_name TEXT NOT NULL,
    account_type TEXT NOT NULL,
    account_name TEXT NOT NULL,
    card_mask TEXT,
    card_holder TEXT,
    currency_code TEXT NOT NULL DEFAULT 'TRY',
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS statements (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    file_sha256 TEXT NOT NULL UNIQUE,
    file_name TEXT,
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    total_spend_cents INTEGER NOT NULL DEFAULT 0,
    total_income_cents INTEGER NOT NULL DEFAULT 0,
    total_tax_cents INTEGER NOT NULL DEFAULT 0,
    is_processed INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY NOT NULL,
    parent_id TEXT REFERENCES categories(id),
    name TEXT NOT NULL,
    icon_name TEXT NOT NULL,
    color_hex TEXT NOT NULL,
    is_system INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    statement_id TEXT REFERENCES statements(id) ON DELETE SET NULL,
    transaction_date TEXT NOT NULL,
    transaction_type TEXT NOT NULL,
    raw_description TEXT NOT NULL,
    clean_merchant TEXT NOT NULL,
    category_id TEXT NOT NULL REFERENCES categories(id),
    billing_amount_cents INTEGER NOT NULL,
    billing_currency TEXT NOT NULL DEFAULT 'TRY',
    original_amount_cents INTEGER,
    original_currency TEXT,
    exchange_rate REAL,
    is_recurring INTEGER NOT NULL DEFAULT 0,
    is_tax_deductible INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS installments (
    id TEXT PRIMARY KEY NOT NULL,
    transaction_id TEXT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    current_installment INTEGER NOT NULL,
    total_installment INTEGER NOT NULL,
    remaining_amount_cents INTEGER NOT NULL,
    monthly_amount_cents INTEGER NOT NULL,
    due_date TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS tax_deductions (
    id TEXT PRIMARY KEY NOT NULL,
    transaction_id TEXT REFERENCES transactions(id) ON DELETE CASCADE,
    statement_id TEXT REFERENCES statements(id) ON DELETE CASCADE,
    tax_type TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    tax_date TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS merchant_rules (
    id TEXT PRIMARY KEY NOT NULL,
    raw_pattern TEXT UNIQUE NOT NULL,
    user_category_id TEXT NOT NULL REFERENCES categories(id),
    created_at INTEGER NOT NULL
);

-- Hedefler ve Birikim Modülü
CREATE TABLE IF NOT EXISTS goals (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL,
    category_type TEXT NOT NULL, -- 'vehicle', 'house', 'motorcycle', 'boat', 'gift', 'travel', 'electronics', 'other'
    target_amount_cents INTEGER NOT NULL,
    current_saved_cents INTEGER NOT NULL DEFAULT 0,
    currency_code TEXT NOT NULL DEFAULT 'TRY',
    target_date TEXT NOT NULL,
    monthly_plan_cents INTEGER,
    status TEXT NOT NULL DEFAULT 'ACTIVE', -- 'ACTIVE', 'COMPLETED', 'PAUSED'
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS goal_contributions (
    id TEXT PRIMARY KEY NOT NULL,
    goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    amount_cents INTEGER NOT NULL,
    contribution_date TEXT NOT NULL,
    note TEXT,
    created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_installments_due ON installments(due_date ASC);
CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);
CREATE INDEX IF NOT EXISTS idx_goal_contributions_goal ON goal_contributions(goal_id);

