-- migration_v1.sql
PRAGMA foreign_keys = ON;

-- 1. HESAPLAR VE KARTLAR TABLOSU
-- Enpara vadesiz hesap, Yapı Kredi Asıl Kart, Dijital Kart ve Ek Kart gibi varlıklar burada tutulur.
CREATE TABLE accounts (
    id TEXT PRIMARY KEY NOT NULL,              -- UUID v4
    institution_name TEXT NOT NULL,          -- 'Enpara', 'Yapı Kredi', 'Chase' vb.
    account_type TEXT NOT NULL,              -- 'CHECKING', 'CREDIT_CARD', 'CASH', 'INVESTMENT'
    account_name TEXT NOT NULL,              -- 'Enpara Vadesiz TL', 'Worldcard Asıl'
    card_mask TEXT,                          -- '4462 12****** 8281'
    card_holder TEXT,                        -- 'ABDULLAH YEŞİLDEMİR', 'GİZEM YEŞİLDEMİR'
    currency_code TEXT NOT NULL DEFAULT 'TRY', -- ISO 4217: 'TRY', 'USD', 'EUR'
    credit_limit_cents INTEGER DEFAULT 0,    -- Kart limiti (25.000 TL -> 2500000)
    current_balance_cents INTEGER DEFAULT 0, -- Vadesiz bakiye veya güncel borç
    is_active INTEGER NOT NULL DEFAULT 1,    -- 1: Aktif, 0: Arşivlenmiş
    created_at INTEGER NOT NULL              -- Unix Epoch (Milisaniye)
);

-- 2. YÜKLENEN BELGELER (EKSTRE & BORDRO ARŞİVİ)
-- Ham PDF diske kaydedilmez; hash ve işlem özeti saklanır.
CREATE TABLE statements (
    id TEXT PRIMARY KEY NOT NULL,              -- UUID v4
    account_id TEXT NOT NULL,                -- accounts(id) referansı
    statement_type TEXT NOT NULL,            -- 'BANK_CHECKING', 'CREDIT_CARD', 'PAYSLIP'
    period_start TEXT NOT NULL,              -- 'YYYY-MM-DD'
    period_end TEXT NOT NULL,                -- 'YYYY-MM-DD'
    due_date TEXT,                           -- Son ödeme tarihi: 'YYYY-MM-DD'
    total_debit_cents INTEGER NOT NULL,      -- Dönem harcamaları / kesintiler
    total_credit_cents INTEGER NOT NULL,     -- Dönem ödemeleri / yatan maaş
    closing_balance_cents INTEGER,           -- Dönem sonu borcu veya bakiyesi
    file_sha256 TEXT NOT NULL UNIQUE,        -- Mükerrer yüklemeyi engelleyen dosya hash'i
    parsed_at INTEGER NOT NULL,              -- Analiz edilme zamanı
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

-- 3. KATEGORİLER
CREATE TABLE categories (
    id TEXT PRIMARY KEY NOT NULL,              -- 'cat_market', 'cat_fuel', 'cat_tax' vb.
    parent_id TEXT,                          -- Üst kategori (Alt kategori desteği için)
    name TEXT NOT NULL,                      -- 'Market & Bakkaliye', 'Akaryakıt'
    icon_name TEXT NOT NULL,                 -- 'shopping_cart', 'local_gas_station'
    color_hex TEXT NOT NULL,                 -- '#2E7D32', '#D32F2F'
    is_system INTEGER NOT NULL DEFAULT 1,    -- 1: Sabit sistem kategorisi, 0: Özel
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- 4. TÜM FİNANSAL İŞLEMLER (GELİR / GİDER / TRANSFER)
CREATE TABLE transactions (
    id TEXT PRIMARY KEY NOT NULL,              -- UUID v4
    account_id TEXT NOT NULL,                -- accounts(id)
    statement_id TEXT,                       -- statements(id) (PDF'ten geldiyse)
    transaction_date TEXT NOT NULL,          -- 'YYYY-MM-DD'
    transaction_type TEXT NOT NULL,          -- 'DEBIT' (Gider), 'CREDIT' (Gelir)
    raw_description TEXT NOT NULL,           -- Ekstredeki ham metin
    clean_merchant TEXT NOT NULL,            -- Temizlenmiş POS/Kurum adı
    category_id TEXT NOT NULL,               -- categories(id)
    mcc_code INTEGER,                        -- ISO 18245: 5411, 5541 vb.
    
    -- Parasal Değerler (Tamsayı Kuruş Standardı)
    billing_amount_cents INTEGER NOT NULL,   -- Karttan/hesaptan düşen yerel tutar
    billing_currency TEXT NOT NULL DEFAULT 'TRY',
    original_amount_cents INTEGER,           -- Yurt dışı orijinal çekim tutarı (Cent)
    original_currency TEXT,                  -- 'USD', 'EUR'
    exchange_rate REAL,                      -- İşlem anındaki takas kuru
    
    -- Özel Nitelikler
    is_installment INTEGER NOT NULL DEFAULT 0, -- 1: Taksitli harcama
    is_recurring INTEGER NOT NULL DEFAULT 0,   -- 1: Düzenli abonelik (Netflix vb.)
    fast_or_tracking_id TEXT,                -- FAST sorgu no, dekont ref no
    created_at INTEGER NOT NULL,
    
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (statement_id) REFERENCES statements(id) ON DELETE SET NULL,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT
);

-- 5. TAKSİT VE GELECEK DÖNEM BORÇ PROJEKSİYONU
-- Kredi kartı ekstrelerindeki 1/3, 2/3 gibi taksitleri geleceğe dağıtır.
CREATE TABLE installments (
    id TEXT PRIMARY KEY NOT NULL,              -- UUID v4
    transaction_id TEXT NOT NULL,            -- transactions(id)
    current_installment INTEGER NOT NULL,    -- 1
    total_installment INTEGER NOT NULL,      -- 3
    monthly_amount_cents INTEGER NOT NULL,   -- Her ay düşecek taksit tutarı
    remaining_amount_cents INTEGER NOT NULL, -- Geleceğe kalan borç yükü
    next_due_date TEXT NOT NULL,             -- 'YYYY-MM-DD'
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
);

-- 6. DEVLET PAYI VE YASAL KESİNTİLER
-- Bordrodaki gelir vergisi, kredilerdeki BSMV/KKDF, MTV ve harçları tutar.
CREATE TABLE tax_deductions (
    id TEXT PRIMARY KEY NOT NULL,              -- UUID v4
    transaction_id TEXT,                     -- transactions(id) (Varsa bağlı işlem)
    statement_id TEXT NOT NULL,              -- statements(id)
    tax_type TEXT NOT NULL,                  -- 'BSMV', 'KKDF', 'INCOME_TAX', 'STAMP_TAX', 'MTV', 'VAT'
    amount_cents INTEGER NOT NULL,           -- Vergi/kesinti tutarı (Kuruş)
    tax_date TEXT NOT NULL,                  -- 'YYYY-MM-DD'
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
    FOREIGN KEY (statement_id) REFERENCES statements(id) ON DELETE CASCADE
);

-- 7. KULLANICI KURAL HAFIZASI (MERCHANT NORMALIZATION)
-- Trendyol, Amazon vb. pazar yerlerinde kullanıcının seçtiği kategoriyi hatırlar.
CREATE TABLE user_category_rules (
    id TEXT PRIMARY KEY NOT NULL,              -- UUID v4
    keyword_pattern TEXT UNIQUE NOT NULL,    -- 'TRENDYOL.COM', 'HEPSIBURADA'
    category_id TEXT NOT NULL,               -- Kullanıcının sabitlediği kategori
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- 8. KATEGORİ BÜTÇE LİMİTLERİ (İLERLEME ÇUBUKLARI İÇİN)
CREATE TABLE budget_limits (
    id TEXT PRIMARY KEY NOT NULL,              -- UUID v4
    category_id TEXT NOT NULL UNIQUE,        -- categories(id)
    limit_cents INTEGER NOT NULL,            -- Aylık tavan sınır (₺10.000 -> 1000000)
    month_year TEXT NOT NULL,                -- 'YYYY-MM'
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- 9. VARLIK VE BİRİKİM PORTFÖYÜ (ALTIN, DÖVİZ, BES)
CREATE TABLE assets (
    id TEXT PRIMARY KEY NOT NULL,              -- UUID v4
    asset_type TEXT NOT NULL,                -- 'GOLD_GRAM', 'GOLD_QUARTER', 'USD', 'EUR', 'BES'
    asset_name TEXT NOT NULL,                -- 'Gram Altın', 'Allianz BES'
    quantity REAL NOT NULL,                  -- 42.0 (Gram) veya 1000.0 (Birim)
    average_cost_cents INTEGER NOT NULL,     -- Birim alış maliyeti
    current_value_cents INTEGER,             -- Güncel piyasa karşılığı
    updated_at INTEGER NOT NULL
);

-- 10. UYGULAMA METADATA VE KOTA TABLOSU
CREATE TABLE app_meta (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
);