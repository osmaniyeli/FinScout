-- assets/sql/v6_owntransfer_index.sql
-- v6: Kendi-hesap transfer eşleştirmesi (TransactionRepository.reconcileOwnTransfers) hesaplar arası
-- TRANSFEROUT/TRANSFERIN adaylarını tx_kind + tutar + tarih ile arar. idx_transactions_kind (v2) yalnız
-- tx_kind'a bakıyordu; bu indeks aday sorgusunu tutar/tarihe göre de daraltır. Yalnız performans;
-- şema/veri değişmez, tekrar çalıştırılabilir.

CREATE INDEX IF NOT EXISTS idx_transactions_kind_amount_date ON transactions(tx_kind, billing_amount_cents, transaction_date);
