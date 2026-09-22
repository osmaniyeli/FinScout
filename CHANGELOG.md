# Değişiklik Günlüğü (Changelog)

Paraİz (MoneyTrace) projesindeki tüm önemli değişiklikler, yeni özellikler, güvenlik sertleştirmeleri ve hata düzeltmeleri bu dosyada belgelenmektedir.

Format, [Keep a Changelog](https://keepachangelog.com/tr/1.0.0/) standardına dayanmaktadır ve bu proje [Semantic Versioning](https://semver.org/lang/tr/) (SemVer) kurallarına uyar.

---

## [3.5.2] - 2026-09-22

### 🛡️ Güvenlik & Kalite Kapısı (Quality Gate)
- **100-Nokta Otomatik Doğrulama Süiti**: CI/CD kalite kapısı (`quality_gate`) ve Git `pre-push` kancası ile entegre 21 süit ve 100 test.
- **Fail-Fast Dağıtım Modeli**: GitHub Actions üzerinde testleri geçmeyen hiçbir commit veya tag için APK/AAB derlemesi üretilmez.
- **R8 Obfuscation & Kod Küçültme**: Tersine mühendislik saldırılarına karşı derleme seviyesinde R8 kuralları aktif edildi.

### 🏦 Banka Ekstre Entegrasyonları
- **Garanti BBVA**: Paracard ve Bonus Kredi Kartı ekstre formatları, taksit projeksiyonu ve işlem ayrıştırma motoru eklendi.
- **Türkiye İş Bankası**: Maximum Kart ve Hesap Özeti formatları (`X/Y` taksit desenleri ve sektör etiketleri) eklendi.
- **Akbank**: Axess, Wings ve Neo hesap dökümleri ayrıştırıcı desteği getirildi.
- **Evrensel Hata Toleranslı Ayrıştırıcı (GenericBankStatementParser)**: Halkbank (Paraf), Ziraat (Bankkart), VakıfBank, TEB ve DenizBank gibi tüm yerli bankalar için fallback işlem kurtarma motoru devreye alındı.
- **Akıllı Banka & Belge Algılayıcı (BankDetector)**: 9 finans kurumunu ve TCMB IBAN kodlarını (0062, 0064, 0046, 0012, 0010, 0015 vb.) tanıyan kurum tanıma zekası eklendi.

### ⚙️ Yönetici Paneli & Remote Config
- **Çift Yönlü Senkronizasyon Aracı (`tools/sync_config.ps1`)**: Web Yönetici Paneli ile Flutter mobil uygulaması arasında şema korumalı ve tip güvenceli çift yönlü config senkronizasyonu.
- **12 Modül Kill-Switch**: Web arayüzünde eksik olan `dashboard_summary` ve `newsletter_subscription` modülleri eklenerek tüm alt sistemler merkezi şaltere bağlandı.
- **Web Paneli JSON İçe Aktar (Import)**: Var olan `remote_config.json` dosyasını sürükle-bırak veya dosya seçiciyle yükleyip simülatörde anında görme desteği.

### 🚀 Dağıtım & Sürüm Otomasyonu
- **Semantik Sürümleme Betiği (`tools/release.ps1`)**: `pubspec.yaml`, `CHANGELOG.md`, test doğrulama ve Git tag (`v*`) oluşturma otomasyonu.

---

## [3.5.1] - 2026-09-20

### ✨ Eklenen Özellikler
- **FIPS 197 Uyumlu AES-256-CBC & PBKDF2 Şifreleme Kasası**: Çevrimdışı `.vault` yedekleme ve parola korumalı içe/dışa aktarım.
- **12 Mikro-Etkileşim Bileşeni**: Shakuro Dynamic Island Kapsülü, Better Sleep tarzı bildirim sayfası, Radar Satın Alma butonu, günlük seri (streak) takibi ve laser card efektleri.
- **FinPay & iBank UI Tasarım Dili**: Yüzen buzlu cam (frosted glass) alt gezinti çubuğu ve modern finansal kart bileşenleri.

### 🔒 Güvenlik
- **Çoklu Platform Ekran Görüntüsü & Kayıt Engelleme**: Android `FLAG_SECURE`, iOS `UIBlurEffect` ve Flutter gizlilik kalkanı entegrasyonu.
- **Kernel Seviyesinde Anti-Tapjacking**: `filterTouchesWhenObscured` ile bankacılık katmanı kaplama saldırılarına karşı tam koruma.
- **Alt-Milisaniyelik PDF Zararlı Yazılım Tarayıcısı**: Sıfır maliyetle `/Launch`, `/JavaScript` ve gömülü dosya exploit'lerini engelleme.

---

## [3.5.0] - 2026-09-15

### 🚀 İlk Kararlı Sürüm
- Çevrimdışı öncelikli (Offline-first) ve sıfır-bilgi (Zero-knowledge) yerel mimari.
- Enpara ve Yapı Kredi PDF hesap dökümü ayrıştırma motoru.
- SQLite tabanlı yerel harcama, nakit akışı ve hedef takibi.
- Bağımsız Web Yönetici Paneli (`Web_Yonetici_Paneli`) ve telefon simülatörü.
