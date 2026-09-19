-- Tarihe göre harcama akışı ve aylık filtreleme
CREATE INDEX idx_transactions_date ON transactions(transaction_date DESC);

-- Kategori bazlı harcama dağılımı (Halka grafik sorguları için)
CREATE INDEX idx_transactions_category_date ON transactions(category_id, transaction_date);

-- Hesaba göre ekstre hareketlerini getirme
CREATE INDEX idx_transactions_account ON transactions(account_id, transaction_date DESC);

-- Mükerrer PDF engelleme kontrolü
CREATE INDEX idx_statements_hash ON statements(file_sha256);

-- Gelecek taksit projeksiyon sorguları
CREATE INDEX idx_installments_due ON installments(next_due_date ASC);

-- Vergi ve devlet payı kümülatif sorguları
CREATE INDEX idx_tax_deductions_type_date ON tax_deductions(tax_type, tax_date);