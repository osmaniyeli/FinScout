# 🛡️ Paraİz (MoneyTrace) — Kişisel Finans & Bütçe Yönetim Platformu

> **Sıfır-Bilgi (Zero-Knowledge) & Çevrimdışı-Öncelikli (Offline-First) Güvenli Bütçe, Ekstre Ayrıştırma ve Finansal Analitik Mimarisi**  
> *Secure, Offline-First Personal Finance, Statement Parser & Financial Analytics Suite*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
[![SQLite](https://img.shields.io/badge/SQLite-Sqflite-003B57?logo=sqlite)](https://www.sqlite.org/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)]()
[![License](https://img.shields.io/badge/License-Proprietary-red)]()
[![Tests](https://img.shields.io/badge/Tests-70%20%2F%2070%20Passing-success)]()

---

## 🇹🇷 Türkçe (Turkish) Açıklama

### 1. Ürün Özeti
**Paraİz (MoneyTrace)**; banka hesap ekstrelerini (PDF / Excel), kredi kartı harcamalarını, nakit ödemeleri ve maaş bordrolarını **hiçbir dış sunucuya veri göndermeden (%100 cihaz içinde)** ayrıştıran, kategorize eden ve akıllı tasarruf projeksiyonları sunan yeni nesil bir kişisel finans uygulamasıdır.

### 2. Öne Çıkan Özellikler
- **Gerçek Dinamik Veri & Sıfır Sahte Grafik**: Tüm analizler, harcama dağılımları, aylık sütun grafikleri ve KDV matrahları yerel SQLite veritabanındaki gerçek işlemlerden hesaplanır. Veri bulunmadığında veya temiz moddayken sahte rakamlar yerine yönlendirici "Temiz Durum (Empty State)" sunulur.
- **Akıllı Ekstre Ayrıştırma (OCR & PDF)**: Türkiye'deki önde gelen bankaların (Garanti BBVA, Yapı Kredi, İş Bankası, Akbank, QNB, Enpara, Ziraat, VakıfBank) ekstrelerini ve maaş bordrolarını tek dokunuşla tanır; kart aidatlarını, faizleri ve abonelikleri otomatik yakalar.
- **12 Modern Mikro-Etkileşim & Shakuro Tasarım Dili**:
  - Yüzen Dynamic Island Bildirim Kapsülü (<%25 ekran alanı, kaydırarak kapatma).
  - Morflayan CSV/PDF İndirme ve Paylaşma Butonları.
  - Radar Nabız Dalgalı Güvenli Ödeme ve Onay Butonları.
  - Alışkanlık Serisi (30-Day Streak) ve Konfeti Kutlama Efektleri.
  - Yay fiziğiyle kayan kapsül alt navigasyon çubuğu.
- **Çift Dilli İletişim (Türkçe 🇹🇷 / English 🇬🇧)**: Uygulama ayarlarından ve haftalık finans bülteni aboneliğinden tek tıkla dil seçimi.
- **Sıfır-Bilgi & 20 Maddelik Güvenlik Standardı**: PIN kilidi ve cihaz içi şifreleme, UTF-8 BOM Excel ihracı, JSON tam sistem yedeği ve hukuki iade dilekçesi oluşturucu.

### 3. Proje Mimarisi
```
Ev Ekonomisi/
├── moneytrace/                      # Ana Flutter Mobil Uygulaması
│   ├── lib/
│   │   ├── core/                    # Veritabanı, tema, güvenlik, ortak bileşenler
│   │   │   ├── database/            # SQLite tabloları ve TransactionRepository
│   │   │   ├── config/              # RemoteConfigService (Dinamik şalterler & dil)
│   │   │   ├── parser/              # Banka ekstre ve bordro regex motorları
│   │   │   └── widgets/             # 12 adet morflayan ve yaylı animasyon bileşeni
│   │   └── features/                # Ekran modülleri (Dashboard, Cashflow, Analysis, Goals, Assets)
│   ├── android/                     # Android yapılandırması (Google Play hazır)
│   └── test/verify_parsers.ps1      # 70 testlik otomatik doğrulama süiti
├── Web_Yonetici_Paneli/             # Sıfır-bağımlılıklı Web Yönetim Portalı & Canlı Simülatör
└── Sistem_Dokumantasyonu/           # Mimari, banka formatları ve güvenlik dokümantasyonu
```

### 4. Google Play Store Dağıtım Hazırlığı
1. **İzin Güvenliği**: Google Play gereksinimlerine aykırı `READ_MEDIA_VIDEO` ve `READ_MEDIA_AUDIO` izinleri kaldırılmış, `android:usesCleartextTraffic="false"` standardı uygulanmıştır.
2. **İmzalama (Release Signing)**:
   ```bash
   cd moneytrace/android
   cp key.properties.example key.properties
   # key.properties dosyasını kendi keystore şifrelerinizle doldurun
   ```
3. **App Bundle (AAB) Üretimi**:
   ```bash
   cd moneytrace
   flutter build appbundle --release
   ```

---

## 🇬🇧 English Overview

### 1. Executive Summary
**Paraİz (MoneyTrace)** is an offline-first, zero-knowledge personal finance and expense analytics mobile suite. It parses bank statements (PDF / Excel), payslips, cash receipts, and installments **entirely on-device (zero data ever sent to external cloud servers)**.

### 2. Key Highlights
- **100% Authentic Dynamic Data**: All charts, category shares, monthly bar trends, and VAT summaries dynamically calculate from SQLite tables. No fake/dummy hardcoded numbers. Features rich empty states when no transactions are recorded.
- **Bank Statement Orchestration**: Automatic identification and extraction of transactions, card fees, cash advance interest, and recurring subscriptions across all major Turkish banking formats.
- **Unified Micro-Interaction Language**:
  - Floating Dynamic Island Capsule (<= 25% height, drag-to-dismiss).
  - Morphing Download & Share Buttons.
  - Radar-Wave Checkout & Verification Buttons.
  - Streak Confetti Celebrations & Habit Gamification.
  - Spring-physics floating capsule navigation bar.
- **Bilingual Support (Turkish 🇹🇷 & English 🇬🇧)**: Language selection available in Settings and Newsletter subscription sheets.
- **20-Point Security Standard**: Client-side encryption, UTF-8 BOM CSV exports, and zero tracking.

### 3. Build & Test Instructions

#### Run Test Suite
```powershell
powershell -ExecutionPolicy Bypass -File moneytrace\test\verify_parsers.ps1
```
*(70 / 70 Automated Tests Passing)*

#### Run Mobile Application
```bash
cd moneytrace
flutter pub get
flutter run
```

#### Build Production Release AAB for Google Play
```bash
cd moneytrace
flutter build appbundle --release
```

---

## 📄 Lisans & Gizlilik / License & Privacy
Bu proje **Sıfır-Sunucu (Zero-Server) & Sıfır-Bilgi (Zero-Knowledge)** prensibiyle korunmaktadır. Hiçbir finansal veri üçüncü taraf sunucularla paylaşılmaz.  
*All financial data remains strictly on the user's physical device.*
