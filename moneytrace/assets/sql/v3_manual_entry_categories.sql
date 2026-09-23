-- assets/sql/v3_manual_entry_categories.sql
-- v3: Hızlı giriş ve sesli girişte kullanılan, v1'de tanımlanmamış kategoriler.
-- transactions.category_id yabancı anahtar olduğundan bu kimlikler olmadan manuel kayıtlar reddediliyordu.

INSERT OR IGNORE INTO categories (id, parent_id, name, icon_name, color_hex, is_system) VALUES
('cat_auto_repair', NULL, 'Oto Tamir & Bakım', 'build_circle', '#F59E0B', 1),
('cat_bonus', NULL, 'Prim & İkramiye', 'card_giftcard', '#10B981', 1),
('cat_rent_income', NULL, 'Kira Geliri', 'home_work', '#059669', 1),
('cat_dividend', NULL, 'Faiz & Temettü', 'trending_up', '#0D9488', 1),
('cat_extra_income', NULL, 'Ek Gelir', 'add_circle_outline', '#14B8A6', 1),
('cat_gold', NULL, 'Altın / Emtia', 'monetization_on', '#F59E0B', 1),
('cat_fx', NULL, 'Döviz', 'currency_exchange', '#3B82F6', 1),
('cat_cash_vault', NULL, 'Nakit Kasa', 'account_balance_wallet', '#10B981', 1),
('cat_deposit', NULL, 'Vadeli Mevduat', 'savings', '#6366F1', 1),
('cat_stocks', NULL, 'Hisse & Borsa', 'show_chart', '#8B5CF6', 1),
('cat_bes', NULL, 'BES / Emeklilik', 'verified_user', '#06B6D4', 1),
('cat_crypto', NULL, 'Kripto Varlık', 'currency_bitcoin', '#F97316', 1);
