# 🏛️ Paraİz (Fintra) — Kurumsal Tasarım Sistemi & Kriptografik Güvenlik Anayasası

Bu doküman; Paraİz ekosisteminin tüm platformlarda (Mobil Uygulama, Web Yönetim Konsolu ve Kurumsal İletişim Varlıkları) tutarlı, tekil ve ödün verilmez bir standartta çalışmasını temin eden **Kurumsal Tasarım Sistemi (Design System)** ve **Askeri Düzeyde Güvenlik Sertleştirmesi (Security Hardening)** yönergelerini içerir.

> [!IMPORTANT]
> **Temel İlke (Single Source of Truth):**
> Paraİz'de hiçbir mecrada farklı bir tipografi, kontrolsüz renk tonu veya gevşetilmiş bir güvenlik standardı uygulanamaz. Tüm geliştiriciler ve tasarımcılar bu anayasaya uymakla yükümlüdür.

---

## BÖLÜM 1: KURUMSAL TASARIM SİSTEMİ & TİPOGRAFİ (Brand Identity & Design System)

### 1.1 Tipografi Anayasası (Typography Hierarchy)

Her mecrada aynı kurumsal ciddiyeti ve FinTech dinamizmini korumak adına iki font ailesi kesin olarak belirlenmiştir:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        TİPOGRAFİ EŞLEŞMESİ                             │
├────────────────────────────────────────────────────────────────────────┤
│  1. 'Plus Jakarta Sans'  ➔ Manşetler, Başlıklar, Butonlar ve Gövde     │
│     (Google Fonts ^6.2.1 — Açık iç boşluklu, tok ve prestijli duruş)  │
│                                                                        │
│  2. 'JetBrains Mono'     ➔ Finansal Rakamlar, Tutarlar, IBAN ve Tablo │
│     (₺ 248.560,00 — Tüm basamaklar cetvel gibi alt alta hizalanır)     │
└────────────────────────────────────────────────────────────────────────┘
```

#### Tipografi Boyut ve Kalınlık Skalası:
| Rol | Font Ailesi | Ağırlık | Boyut (pt) | Satır Aralığı | Kullanım Alanı |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Display Large** | Plus Jakarta Sans | 800 (ExtraBold) | 32 | 1.2 | Lansman manşetleri, ana karşılama |
| **Title Large** | Plus Jakarta Sans | 700 (Bold) | 22 | 1.25 | Modül başlıkları, kart ana başlıkları |
| **Title Medium** | Plus Jakarta Sans | 600 (SemiBold) | 16 | 1.3 | Liste başlıkları, diyalog başlıkları |
| **Body Large** | Plus Jakarta Sans | 500 (Medium) | 14 | 1.4 | Standart gövde metinleri, açıklamalar |
| **Body Medium** | Plus Jakarta Sans | 400 (Regular) | 13 | 1.45 | İkincil açıklamalar, dipnotlar |
| **Numeric Large** | JetBrains Mono | 700 (Bold) | 24 - 32 | 1.0 | Net Varlık, aylık toplam bakiye |
| **Numeric Medium** | JetBrains Mono | 600 (SemiBold) | 14 - 18 | 1.1 | İşlem satır tutarları, kart borçları |
| **Numeric Compact**| JetBrains Mono | 500 (Medium) | 11 - 13 | 1.1 | IBAN, yüzde oranları, kesim günleri |

#### Neden JetBrains Mono?
Standart fontlarda rakam genişlikleri değişkendir (`1` dar, `8` geniştir). Finansal tablolarda ve ekstrelerde rakamlar alt alta geldiğinde basamak kaymalarını önlemek ve cetvelle çizilmiş gibi nizami duruş sağlamak için `AppTheme.numericStyle` kullanılır.

---

### 1.2 Master Renk Paleti (Bright & Crystal FinTech Palette)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MASTER RENK PALETİ                              │
├───────────────────┬───────────────────┬────────────────────────────────┤
│ Cobalt Blue       │ Slate Navy        │ Emerald Green  │ Coral Red     │
│ #2563EB (Aksiyon) │ #0F172A (Otorite) │ #10B981 (Gelir)│ #EF4444 (Gider)│
├───────────────────┴───────────────────┴────────────────────────────────┤
│ Amber Orange: #F59E0B (Taksit & Uyarı) │ Indigo Tax: #6366F1           │
│ Canvas Light: #F8FAFC                  │ Surface Light: #FFFFFF        │
│ Canvas Dark:  #0F172A                  │ Surface Dark:  #1E293B        │
└────────────────────────────────────────────────────────────────────────┘
```

* **Kobalt Mavisi (`#2563EB`):** Güven, teknoloji ve birincil aksiyon butonu rengi.
* **Slate Lacivert (`#0F172A`):** Kasa güvenliği, kilit ekranı zemini ve tipografi ana metin rengi.
* **Zümrüt Yeşili (`#10B981`):** Gelir, pozitif bakiye ve doğrulama rozetleri.
* **Mercan Kırmızı (`#EF4444`):** Harcama, borç ve kritik anomali uyarıları.
* **Sıcak Amber (`#F59E0B`):** Taksit projeksiyonu, faiz/aidat ve bekleyen işlemler.

---

## BÖLÜM 2: KRİPTOGRAFİK GÜVENLİK & İŞLETİM SİSTEMİ SERTLEŞTİRMESİ

Paraİz, **Sıfır-Sunucu (Zero-Server) & Sıfır-Bilgi (Zero-Knowledge)** mimarisiyle çalışır.

### 2.1 Kriptografik Motor (NIST FIPS 197 Standardı)
- **Şifreleme Algoritması:** AES-256-CBC blok şifreleme ve PKCS#7 dolgusu (`aes_cipher.dart`).
- **Anahtar Türetimi (KDF):** PBKDF2-HMAC-SHA256 (10.000 iterasyon) ile kullanıcı parolasından türetilen bağımsız anahtarlar (Key Separation: 32 bayt AES şifreleme anahtarı, 32 bayt HMAC doğrulama anahtarı).
- **Encrypt-then-MAC (HMAC-SHA256):** Şifreli metin deşifre edilmeden önce HMAC bütünlüğü doğrulanır. Padding oracle ve bit-flipping saldırılarına izin verilmez.
- **CSPRNG Güvenliği:** Rastgele token ve tuzlar `Random.secure()` kriptografik üreteci ile sağlanır.
- **Parola Korumalı Kasa Yedekleme (`.vault`):** Dışa aktarılan sistem yedekleri AES-256 ile şifrelenir; yanlış parola girildiğinde veri bütünlüğü kesin olarak korunur ve işlem reddedilir.

### 2.2 İşletim Sistemi Seviyesinde Güvenlik
- **Anti-Screen Scraping & Task Switcher Kalkanı (`FLAG_SECURE`):**
  `MainActivity.kt` içinde `WindowManager.LayoutParams.FLAG_SECURE` bayrağı ile işletim sisteminin ekran görüntüsü alması, ekran kaydı yapması ve uygulama değiştiricide finansal kart önizlemelerini önbelleğe alması engellenir.
- **iOS Gizlilik Bulanıklığı (`UIBlurEffect`):**
  `AppDelegate.swift` dosyasında `applicationWillResignActive` tetiklendiğinde pencere üzerine koyu bulanıklık katmanı eklenerek snapshot sızıntıları önlenir.
- **Flutter Dinamik Gizlilik Kalkanı (`_isPrivacyShieldActive`):**
  Uygulama arka plana geçtiğinde UI anında zümrüt kalkanlı siyah güvenlik örtüsüyle maskelenir.
- **Anti-ADB USB Sızıntı Kalkanı:**
  `AndroidManifest.xml` içinde `android:allowBackup="false"` ve `android:fullBackupContent="false"` tanımlanarak, USB hata ayıklama üzerinden fiziksel saldırganların `paraiz_vault.db` veritabanını çekmesi engellenmiştir.
- **Anti-Tapjacking & Şeffaf Katman Kalkanı:**
  `window.decorView.filterTouchesWhenObscured = true` ile bankacılık truva atlarının şeffaf arayüz bindirmeleriyle dokunma çalması (tapjacking) kernel seviyesinde engellenir.
- **Tek Geçişli Sub-Millisecond PDF Kötü Amaçlı Yazılım Tarayıcısı:**
  `pdf_malware_scanner.dart` ile yüklenen tüm PDF dosyalarında `/Launch`, `/JavaScript`, `/EmbeddedFiles` ve `/OpenAction` komutları sıfır maliyetle anında taranır; zararlı dosyalar reddedilir.
- **Oturum Önbellekli Cihaz Bütünlüğü Kontrolü:**
  `device_integrity_guard.dart` yerel platform kanalı üzerinden root/su ikili kontrollerini oturum boyunca önbelleğe alarak kullanıcıyı yormadan güvenliği denetler.

---

## BÖLÜM 3: ÇOK KATMANLI GİRİŞ & ARAYÜZ ETKİLEŞİMLERİ

### 3.1 Uygulama Açılış Kilidi (App Lock Gate)
- **Soğuk Açılış & Yaşam Döngüsü:** Uygulama ilk açıldığında veya arka planda 30 saniye üzeri kaldıktan sonra otomatik olarak kilitlenir (`app_lock_screen.dart`).
- **Çoklu Güvenlik Yöntemi:** Yüz Tanıma (Face ID), Parmak İzi (Touch ID) ve 4 haneli tuzlu PIN bağımsız olarak veya aynı anda devrede olabilir.
- **Bypass Koruması:** `PopScope(canPop: false)` ile Android sistem geri tuşu kilidi kapatamaz.

### 3.2 Frontend Joe Kayan Çift Taraflı Kartlar (Sliding Overlay Cards)
- Kredi kartı yönetiminde (`CreditCardActionSheet`) ve Onboarding giriş ekranında kayan çift taraflı kart mimarisi uygulanır:
  - Taraf A: Borç Ödeme (Asgari/Tamam/Kaynak Hesap)
  - Taraf B: Limit ve Hesap Kesim Günü Düzenleme
- `Curves.easeInOutCubic` yay fiziğiyle 0.65 saniyede akıcı geçiş sağlanır.

### 3.3 Deterministik Banka Dekont & Ekstre Eşleme Motoru (Field Mapping Engine)
- Körü körüne regex okumasına karşı; Tutar, Tarih, Açıklama ve Alıcı alanlarının kullanıcı tarafından görsel olarak eşleştirilmesine imkan tanır.
- İşlem tutarı (`2.750,00 TL`) ile bakiye (`34.250,00 TL`) arasındaki karışıklıkları deterministik şablon kütüphanesi (`BankMappingTemplate`) ile %100 doğrulukla çözer.

---

## BÖLÜM 4: DOĞRULAMA & TEST ANLAŞMASI

Tüm geliştirmeler ve değişiklikler `moneytrace\test\verify_parsers.ps1` süiti ile test edilir:
- **Toplam Test:** 20 Bölüm, **95 / 95 Başarılı Test (100% PASS)**
- **Boş Fonksiyon Kuralı:** Kod tabanında `onPressed: () {}` veya `onTap: () {}` sayısı **kesinlikle 0** olmalıdır.
- **Örnek Dosyalar Güvenliği:** `Örnek görselleri` klasörü kesinlikle korunur ve değiştirilmez.
