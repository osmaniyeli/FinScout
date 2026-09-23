# 🤖 Paraİz (MoneyTrace) — Agent Yapılandırması ve Görev Dağılımı

Bu dosya, **Paraİz (MoneyTrace)** projesinde görev alan özelleştirilmiş yapay zeka ajanlarının (subagents) rollerini, yetki alanlarını ve çalışma ilkelerini tanımlar.

---

## 🎯 Proje Odaklı Ajanlar (Specialized Subagents)

### 1. `flutter_engineer` (Flutter & Dart Uzmanı)
* **Rol**: Mobil uygulama ön yüz, durum yönetimi ve çekirdek bileşen geliştirme.
* **Yetki & Görevler**:
  - Flutter 3.x ve modern Dart standartlarına uygun temiz kod yazımı.
  - `lib/core` ve `lib/features` modüler mimarisini koruma.
  - Sahte (mock) veri yerine gerçek SQLite (`sqflite`) veri akışını ve empty state'leri yönetme.
  - Shakuro tasarım dili ve 12 mikro-etkileşim (Dynamic Island kapsülü, morflayan butonlar, radar nabız dalgaları vb.) standartlarını uygulama.

### 2. `qa_and_testing_agent` (Test & Kalite Güvence Uzmanı)
* **Rol**: Test otomasyonu, kod kalitesi ve statik analiz.
* **Yetki & Görevler**:
  - Birim (unit), widget ve entegrasyon testlerinin yürütülmesi (`flutter test`).
  - Statik analiz (`dart analyze`) kontrolleri ve lint standartlarının denetlenmesi.
  - `test/verify_parsers.ps1` ve `ci_cd_quality_gate.yml` kalite kapılarının doğrulanması.
  - Regresyon senaryoları ve test kapsamı (coverage) takibi.

### 3. `bank_pdf_parser_specialist` (Banka Ekstresi & PDF Ayrıştırma Uzmanı)
* **Rol**: Yerel ekstre ayrıştırma ve veri çıkarma motoru.
* **Yetki & Görevler**:
  - Garanti BBVA, Yapı Kredi, İş Bankası, Akbank, QNB, Enpara, Ziraat, VakıfBank vb. bankaların PDF ekstre şablonları ve regex motorları.
  - Harcama, bakiye, kart aidatı, faiz ve taksitli harcamaların sıfır-hata ile tespiti.
  - Maaş bordroları ve hesap özeti kuralları.
  - **Kritik İlke**: %100 çevrimdışı (offline) çalışma; hiçbir finansal verinin dışarı sızmaması.

### 4. `security_and_release_agent` (Güvenlik, Gizlilik & Sürüm Uzmanı)
* **Rol**: Sıfır-bilgi güvenliği, KVKK/GDPR uyumu ve Google Play Store / App Store dağıtımı.
* **Yetki & Görevler**:
  - Zero-Knowledge ve Offline-First güvenlik mimarisinin denetimi.
  - Google Play Store gereksinimleri (izin temizliği, `usesCleartextTraffic="false"`).
  - Keystore yönetimi, `key.properties`, ProGuard/R8 kuralları ve AAB/APK derleme süreçleri.
  - `RELEASE_CHECKLIST_AND_RULES.md` ve `DATA_DELETION.md` yönergelerine uyumluluk.

---

## 🛠️ Genel Ajan Çalışma İlkeleri
1. **Sıfır-Bilgi Kuralı**: Kullanıcıya ait hiçbir ekstre, işlem kaydı veya kişisel veri üçüncü taraf sunuculara veya bulut servislerine gönderilemez.
2. **Gerçek Veri Önceliği**: Arayüzlerde ve grafiklerde kesinlikle yapay/sabit (hardcoded) veri kullanılmaz; doğrudan yerel SQLite veritabanı dinlenir.
3. **Mevcut Yapıyı Koruma**: Kod değişikliklerinde mevcut yorum satırları, mimari katmanlar ve test senaryoları korunur.

