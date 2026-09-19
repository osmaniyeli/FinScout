-- Temel Sistem Kategorileri
INSERT INTO categories (id, parent_id, name, icon_name, color_hex, is_system) VALUES
('cat_market', NULL, 'Market & Bakkaliye', 'shopping_cart', '#2E7D32', 1),
('cat_fuel', NULL, 'Akaryakıt & Ulaşım', 'local_gas_station', '#E65100', 1),
('cat_dining', NULL, 'Yeme - İçme', 'restaurant', '#C2185B', 1),
('cat_utilities', NULL, 'Faturalar & Hizmetler', 'receipt_long', '#0288D1', 1),
('cat_subscriptions', NULL, 'Dijital Abonelikler', 'subscriptions', '#512DA8', 1),
('cat_home', NULL, 'Ev Bakım & Hırdavat', 'home_repair_service', '#795548', 1),
('cat_tax', NULL, 'Vergi & Harçlar', 'account_balance', '#D32F2F', 1),
('cat_pets', NULL, 'Evcil Hayvan', 'pets', '#00796B', 1),
('cat_entertainment', NULL, 'Eğlence & Çocuk', 'attractions', '#FBC02D', 1),
('cat_wealth', NULL, 'Yatırım & Birikim', 'savings', '#388E3C', 1),
('cat_general', NULL, 'Genel Alışveriş', 'local_mall', '#616161', 1);

-- Varsayılan Uygulama Durumu ve Kota Bilgileri
INSERT INTO app_meta (key, value) VALUES
('db_version', '1'),
('persona_mode', 'SCOUT'),           -- 'SCOUT' (İzci esprili mod) veya 'CORPORATE'
('free_tier_pdf_limit', '1'),         -- Aylık ücretsiz hak
('current_month_pdf_count', '0'),
('active_currency', 'TRY');