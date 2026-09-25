-- assets/sql/v5_indexes.sql
-- v5: Sık sorgular için eksik indeksler (yalnız performans; şema/veri değişmez, tekrar çalıştırılabilir).
-- Gerekçe EXPLAIN QUERY PLAN ile ölçüldü (sentetik 5 yıllık veri, ~29 bin işlem):
-- indekssiz tabloda tam tarama ya da her sorguda geçici "AUTOMATIC COVERING INDEX" kuruluyordu.
-- Bilerek EKLENMEYENLER: transactions(account_id, ...) ve tax_deductions(transaction_id) — istatistiksiz
-- (ANALYZE yok) sorgu planlayıcı bunlarla taksit alt sorgusunu ve bordro vergi sorgusunu yavaşlatıyordu.

-- Ana sayfa son işlemler: LEFT JOIN installments ON transaction_id (önce: AUTOMATIC COVERING INDEX); işlem silme
CREATE INDEX IF NOT EXISTS idx_installments_transaction ON installments(transaction_id);

-- Ücret raporu: aynı ekstredeki ayrı BSMV/KKDF satırlarını sayan ilişkili alt sorgu
-- (önce: her ücret satırı için tüm 'TAX' işlemleri taranıyordu)
CREATE INDEX IF NOT EXISTS idx_transactions_statement_kind ON transactions(statement_id, tx_kind);

-- Aynı dönem mükerrer kontrolü (isSamePeriodAlreadyImported) + cüzdan "son ekstre" alt sorgusu
-- (önce: SCAN statements)
CREATE INDEX IF NOT EXISTS idx_statements_account_date ON statements(account_id, statement_date);
