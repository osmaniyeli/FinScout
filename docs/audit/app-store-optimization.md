# ASO (Google Play) Hazırlığı

**Tarih:** 2026-10-03. **Kaynak:** Gemini taslağı, Claude tarafından gerçek `tools/play_store/listing.json` ile karşılaştırıldı. **Bu dosya yalnız ÖNERİ içerir — `listing.json` bu denetimde DEĞİŞTİRİLMEDİ** (mağaza metni değişikliği K37 kararına göre ayrı bir "commit et" onayı gerektirir).

## Mevcut durum (gerçek dosyadan, DOĞRULANDI)

`tools/play_store/listing.json` → `tr-TR.title`: **"FinScout Harcama Takibi, Bütçe"**. (`en-US` ayrıca var, bu denetimde okunmadı — kapsam dışı bırakıldı.)

## Google Play / mağaza denetimi (Aşama 7 maddeleri, hızlı envanter)

- Application ID: `com.moneytrace.app` (confirmed, `AndroidManifest.xml`/`build.gradle` genelinde tutarlı — önceki oturumlarda defalarca doğrulanmış).
- İmzalama: Play App Signing kullanılıyor, gerçek SHA-1 bu oturumdan önce doğrulanmış ve Google Sign-In sorunu bu sayede çözülmüş (bkz. proje hafızası `play-signing-fingerprints`).
- Gizlilik politikası, Data Safety, hesap silme akışı: hepsi var ve bağlantılı (`PRIVACY_POLICY.md`, `DATA_DELETION.md`, Ayarlar ekranından linkli — bu oturumda Ayarlar'a Kullanım Şartları linki de eklendi, v3.13.0).
- Reklam kimliği (AD_ID): proje hafızasına göre "Hayır" deklare edilmiş olmalı (next-release-todos hafıza notu) — **bu denetimde Play Console'un kendisi kontrol edilmedi** (bu ortamdan erişim yok), DOĞRULANMADI.

## Mağaza başlığı/kısa açıklama — 3 alternatif (ÖNERİ, uygulanmadı)

Yanlış vaat içermeyen (yalnız gerçekten desteklenen 3 banka + cihazda işleme vurgusu):

1. **Net/öz:** Başlık "FinScout: Harcama Takibi & Ekstre Okuyucu" — Kısa açıklama: "Yapı Kredi, Garanti ve Enpara ekstrelerinizi cihazınızda okuyun, bütçenizi güvenle yönetin."
2. **Gizlilik/vergi odaklı:** Başlık "FinScout: Güvenli Bütçe ve Vergi Takibi" — Kısa açıklama: "Banka ekstreleri ve bordronuzu telefonda analiz edin. Verilerinizi dışarıya aktarmayın."
3. **Minimalist/felsefe odaklı:** Başlık "FinScout - Dürüst Harcama Analizi" — Kısa açıklama: "Karmaşık özellik yok. Sadece çalışan, cihazınızda kalan ekstre ve bütçe takibi."

**Claude notu:** Üçü de mevcut başlıktan (`"FinScout Harcama Takibi, Bütçe"`) farklı — bu bir A/B test fikri olarak düşünülmeli, körlemesine değiştirilmemeli. F1-01 kararı zaten "yalnız çalışan özellikler, banka adı yok, 'desteklenen bankalar uygulamada listelenir'" diyordu — **Alternatif 1 ve 2 banka adlarını (Yapı Kredi/Garanti/Enpara) doğrudan metne yazıyor, bu F1-01'in "banka adı yok" ilkesiyle ÇELİŞİYOR.** Bu çelişkiyi kullanıcıya açıkça belirtiyorum: hangi ilke önceliklendirilsin (somutluk için banka adı mı, F1-01'in soyut "desteklenen bankalar uygulamada listelenir" dili mi) kullanıcı kararı.

## Ekran görüntüsü mesaj sırası (öneri)

1. "Verileriniz Telefonunuzda Kalır" (gizlilik/mimari)
2. "Ekstrenizi Yükleyin, Otomatik Ayrışsın" (PDF okuma + kategori — gerçek banka logoları İLE, F1-01 çelişkisi burada YOK çünkü ekran görüntüsü zaten ürünün gerçek arayüzünü gösteriyor, abartı değil)
3. "Ödediğiniz Vergileri Görün" (BSMV/KKDF/SGK dökümü)
4. "Maaş Bordrosu Analizi (Deneme)" — **"(Deneme)" etiketi mutlaka kalmalı**, F1-05 kararı gereği
5. "Sade, Şeffaf ve Reklamsız Deneyim"

## A/B test hipotezleri (öneri, veri yok)

- **Hipotez 1:** "Cihazınızda okuyun" yerine "Verileriniz buluta gitmez" ifadesi kurulum oranını artırır. *Kanıt metriği: Mağaza Ziyaretçisi → Yükleme oranı.* **Claude notu: "buluta gitmez" artık TAM DOĞRU DEĞİL** — v3.12.0'dan beri türetilmiş veriler (PDF'in kendisi hariç) hesaba bağlı şifreli olarak buluta yedekleniyor. Bu ifade kullanılacaksa "PDF'iniz buluta gitmez" gibi daha dar/doğru olmalı.
- **Hipotez 2:** Ekran görüntülerinde önce banka logoları, sonra gizlilik mesajı göstermek hedef kitle uyumunu artırıp 1. gün elde tutmayı iyileştirir. *Kanıt metriği: Day-1 Retention.*

Her iki hipotez de GERÇEK A/B test altyapısı (Play Console Store Listing Experiments) gerektirir — bu ortamdan kurulamaz, kullanıcının Play Console'dan elle kurması gerekir.

---
*Kaynak: Gemini taslağı (2026-10-03), `tools/play_store/listing.json` (gerçek başlık doğrulandı), F1-01/F1-05/F4-03 kararları.*
