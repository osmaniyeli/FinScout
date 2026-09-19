-- assets/sql/v1_seed_categories.sql
INSERT OR IGNORE INTO categories (id, parent_id, name, icon_name, color_hex, is_system) VALUES
('cat_market', NULL, 'Market & Bakkaliye', 'shopping_cart', '#2E7D32', 1),
('cat_fuel', NULL, 'Akaryakıt & Şarj', 'local_gas_station', '#E65100', 1),
('cat_transit', NULL, 'Ulaşım & Taksi', 'directions_car', '#0277BD', 1),
('cat_dining', NULL, 'Yeme - İçme & Kafe', 'restaurant', '#C2185B', 1),
('cat_subscriptions', NULL, 'Dijital Abonelik', 'subscriptions', '#512DA8', 1),
('cat_utilities', NULL, 'Faturalar & Kamu', 'receipt_long', '#F57C00', 1),
('cat_tax', NULL, 'Vergi & Harçlar', 'account_balance', '#D32F2F', 1),
('cat_home', NULL, 'Ev & Yapı Market', 'home_repair_service', '#5D4037', 1),
('cat_pet', NULL, 'Evcil Hayvan', 'pets', '#00796B', 1),
('cat_kids', NULL, 'Çocuk & Eğlence', 'child_care', '#7B1FA2', 1),
('cat_investment', NULL, 'Yatırım & Birikim', 'savings', '#FBC02D', 1),
('cat_clothing', NULL, 'Giyim & Moda', 'checkroom', '#303F9F', 1),
('cat_health', NULL, 'Sağlık & Eczane', 'local_pharmacy', '#0097A7', 1),
('cat_salary', NULL, 'Maaş & Gelir', 'payments', '#388E3C', 1),
('cat_general', NULL, 'Diğer Harcamalar', 'more_horiz', '#616161', 1);
