-- assets/sql/v2_statement_intelligence.sql
-- v2: Ekstre zekası — işlem türü, karşı taraf, sektör, ödeme düzeni, mükerrer koruması

ALTER TABLE transactions ADD COLUMN tx_kind TEXT NOT NULL DEFAULT 'OTHER';
ALTER TABLE transactions ADD COLUMN counterparty TEXT;
ALTER TABLE transactions ADD COLUMN sector TEXT;
ALTER TABLE transactions ADD COLUMN balance_after_cents INTEGER;
ALTER TABLE transactions ADD COLUMN fingerprint TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_fingerprint ON transactions(fingerprint) WHERE fingerprint IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_transactions_kind ON transactions(tx_kind);
CREATE INDEX IF NOT EXISTS idx_transactions_counterparty ON transactions(counterparty);

ALTER TABLE statements ADD COLUMN statement_date TEXT;
ALTER TABLE statements ADD COLUMN due_date TEXT;
ALTER TABLE statements ADD COLUMN statement_balance_cents INTEGER;
ALTER TABLE statements ADD COLUMN minimum_payment_cents INTEGER;
ALTER TABLE statements ADD COLUMN is_reconciled INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS scheduled_payments (
    id TEXT PRIMARY KEY NOT NULL,
    statement_id TEXT REFERENCES statements(id) ON DELETE CASCADE,
    account_id TEXT REFERENCES accounts(id) ON DELETE CASCADE,
    due_date TEXT NOT NULL,
    description TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    kind TEXT NOT NULL DEFAULT 'SCHEDULED',
    created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_scheduled_payments_due ON scheduled_payments(due_date ASC);

INSERT OR IGNORE INTO categories (id, parent_id, name, icon_name, color_hex, is_system) VALUES
('cat_insurance', NULL, 'Sigorta & BES', 'health_and_safety', '#0E7490', 1),
('cat_shopping', NULL, 'Online Alışveriş', 'shopping_bag', '#EA580C', 1),
('cat_electronics', NULL, 'Elektronik', 'devices', '#4338CA', 1),
('cat_education', NULL, 'Eğitim & Kitap', 'school', '#7C3AED', 1),
('cat_travel', NULL, 'Seyahat & Konaklama', 'flight', '#0891B2', 1),
('cat_personal_care', NULL, 'Kişisel Bakım', 'spa', '#DB2777', 1),
('cat_transfer', NULL, 'Havale & Transfer', 'swap_horiz', '#475569', 1),
('cat_card_payment', NULL, 'Kart Borcu Ödemesi', 'credit_score', '#1D4ED8', 1),
('cat_fees', NULL, 'Faiz & Banka Ücretleri', 'percent', '#B91C1C', 1),
('cat_cash', NULL, 'Nakit Çekim', 'local_atm', '#15803D', 1),
('cat_loan', NULL, 'Kredi Taksitleri', 'account_balance_wallet', '#9333EA', 1);
