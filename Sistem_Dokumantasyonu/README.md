# Paraİz (MoneyTrace) - Sistem ve Mimari Dokümantasyon Dizini

Bu klasör (`Desktop/Ev Ekonomisi/Sistem_Dokumantasyonu`), Paraİz projesine ait tüm mimari kararları, menü çalışma mantıklarını, diyagramları, yönetici paneli özelliklerini ve derleme talimatlarını derli toplu olarak sunmaktadır.

---

## 📚 Dokümantasyon Dosyaları

| Dosya | Başlık | İçerik Özeti |
| :--- | :--- | :--- |
| [`01_PROJE_GENEL_BAKIS_VE_MIMARI.md`](./01_PROJE_GENEL_BAKIS_VE_MIMARI.md) | **Proje Genel Bakış & Sistem Mimarisi** | Zero-Knowledge felsefesi, PII maskeleme, SQLite kasa şeması ve uçtan uca Mermaid sistem mimarisi şeması. |
| [`02_MENULER_VE_CALISMA_MANTIGI.md`](./02_MENULER_VE_CALISMA_MANTIGI.md) | **Menüler ve Çalışma Mantığı** | 5 ana ekranın (Dashboard, Nakit Akışı, Analiz, Hedefler, Varlıklar) ve modal pencerelerin akış diyagramları ve detaylı mantığı. |
| [`03_YONETICI_PANELI_VE_UZAKTAN_KONTROL.md`](./03_YONETICI_PANELI_VE_UZAKTAN_KONTROL.md) | **Ayrık Web Yönetici Portalı** | Mobil güvenlik için ayrıştırılan Web Portalı mimarisi, Canlı Simülatör, remote_config.json şeması ve Sequence diyagramı. |
| [`04_IPHONE_VE_ANDROID_DERLEME_KILAVUZU.md`](./04_IPHONE_VE_ANDROID_DERLEME_KILAVUZU.md) | **iPhone & Android Derleme Kılavuzu** | Android APK derleme adımları, iPhone (iOS) TestFlight / Xcode yönergeleri ve sıfır kullanıcı verisiyle temiz test yönergesi. |
| [`05_TUM_ISLER_VE_GELISTIRME_KRONOLOJISI.md`](./05_TUM_ISLER_VE_GELISTIRME_KRONOLOJISI.md) | **Tüm İşler ve Kronoloji** | Başlangıçtan bugüne kadar çözülen kritik sorunlar, eklenen özellikler ve 49/49 başarılı otomatik test süiti. |
| [`06_GORSEL_KATALOG_VE_EKRAN_TASARIMLARI.md`](./06_GORSEL_KATALOG_VE_EKRAN_TASARIMLARI.md) | **Görsel Tasarım Kataloğu** | Tüm modüllere ait yüksek çözünürlüklü arayüz tasarımları, Web Yönetici Portalı ve Crystal Glass konsept görselleri. |
| [`07_GLOBAL_MARKA_VE_ISIM_STRATEJISI.md`](./07_GLOBAL_MARKA_VE_ISIM_STRATEJISI.md) | **Global Marka & İsim Stratejisi** | Küresel pazarlar için 8 adet uluslararası FinTech marka ismi önerisi, semantik analizler ve konumlandırma matrisi. |
| [`08_GUVENLIK_MIMARISI_VE_MIKRO_ETKİLEŞİMLER.md`](./08_GUVENLIK_MIMARISI_VE_MIKRO_ETK%C4%B0LE%C5%9E%C4%B0MLER.md) | **Güvenlik Mimarisi & Mikro-Etkileşimler** | 20 maddelik güvenlik standardı, PII maskeleme ve 12 adet Shakuro mikro-etkileşim kütüphanesi. |
| [`09_ASO_VE_MAGAZA_LANSMAN_PAKETI.md`](./09_ASO_VE_MAGAZA_LANSMAN_PAKETI.md) | **ASO & Mağaza Lansman Paketi** | Google Play ve App Store için ASO başlıkları, 4000 karakter açıklama, anahtar kelimeler, 6'lı vitrin senaryosu ve Veri Güvenliği beyanı. |
| [`10_MONETIZASYON_VE_REKLAM_STRATEJISI.md`](./10_MONETIZASYON_VE_REKLAM_STRATEJISI.md) | **Monetizasyon & Reklam Stratejisi** | Freemium vs Pro matrisi, gizlilik dostu ödüllü reklam mimarisi, IAP fiyatlandırma psikolojisi ve paywall tetikleyicileri. |
| [`11_KULLANICI_KAZANIMI_VE_REKLAM_KAMPANYALARI.md`](./11_KULLANICI_KAZANIMI_VE_REKLAM_KAMPANYALARI.md) | **Kullanıcı Kazanımı (UA) & Kampanyalar** | Meta Reels & TikTok için 3 adet viral video kanca senaryosu, Google UAC metin varyasyonları ve 30 günlük bütçeleme planı. |
| [`12_BUYUME_METRIKLERI_VE_REMOTE_CONFIG_REHBERI.md`](./12_BUYUME_METRIKLERI_VE_REMOTE_CONFIG_REHBERI.md) | **Büyüme Metrikleri & Remote Config** | Birim ekonomi (CAC, LTV, ROAS) formülleri, Web Yönetici Paneli uzaktan kontrol stratejisi ve kullanıcı tutundurma (retention) kalkanları. |
| [`13_KURUMSAL_TASARIM_SISTEMI_VE_GUVENLIK_ANAYASASI.md`](./13_KURUMSAL_TASARIM_SISTEMI_VE_GUVENLIK_ANAYASASI.md) | **Kurumsal Tasarım & Güvenlik Anayasası** | Master tipografi (Plus Jakarta Sans & JetBrains Mono), renk paleti, NIST AES-256 Kripto motoru, OS FLAG_SECURE ve kilit mimarisi. |

---

## 🚀 Hızlı Başlangıç

1. **Test Süitini Çalıştırma**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File moneytrace\test\verify_parsers.ps1
   ```
2. **Android Test APK'sını Derleme**:
   ```powershell
   cd moneytrace
   flutter build apk --release --no-tree-shake-icons
   ```
3. **iPhone İçin Derleme**:
   ```bash
   cd moneytrace/ios && pod install && cd ..
   flutter build ipa --release
   ```
