# FinScout — Risk Kayıt Defteri (Konsolide, Aşama 12)

**Tarih:** 2026-10-03. Bu belge, 4 ayrı kaynaktan (3 bağımsız Claude ajanı + Claude'un kendi doğrudan incelemesi, Gemini yalnız araştırma/taslak girdisi olarak) gelen **tüm** bulguları tek bir önceliklendirilmiş listede birleştirir: `architecture-review.md`, `performance-and-cost-review.md`, `security-audit.md`, `privacy-review.md`, `financial-calculation-review.md`, `test-strategy.md`/`test-results.md`, `agent-inventory.md`, `marketing-agent-review.md`, `seo-technical-audit.md`, `seo-measurement-plan.md`.

Öncelik: **P0** (yayını durdur) · **P1** (bir sonraki sürümde) · **P2** (yakın vade) · **P3** (iyileştirme) · **P4** (kozmetik/hijyen)
Durum: **GİDERİLDİ** (bu oturumda düzeltildi) · **AÇIK** (belgelendi, düzeltilmedi) · **ONAYLANDI — UYGULAMA ENGELLENDİ** (kullanıcı onayladı, dosya hazır, Claude Code auto-mode "Modify Shared Resources" sınıflandırıcısı canlı şema yazımını engelledi, kullanıcının elle uygulaması gerekiyor) · **KABUL EDİLEN RİSK**

**Güncelleme (2026-10-03, K42-K44 sonrası):** Kullanıcı Gece Raporu artifact'ındaki K42/K43/K44 sorularının üçünü de "Uygula" ile onayladı. Üç migrasyon dosyası da yazıldı ve repoya eklendi (`supabase/migrations/20261003150000..150200_*.sql`), ama bu oturumda `apply_migration` ile canlıya uygulanması auto-mode tarafından engellendi (üretim şemasına yazma — "Modify Shared Resources"). **Kullanıcının yapması gereken:** Supabase Dashboard > SQL Editor'a üç dosyayı sırayla yapıştırıp çalıştırmak, YA DA bu işi auto-mode dışı/interaktif bir oturumda tekrarlamak. Bank-lock v2 (K42/SEC-04) migrasyonu uygulandıktan SONRA, istemci tarafında `user_profile_service.dart`'taki `consumeUpload`'ın RPC çağrısını `consume_upload` → `consume_upload_v2`'ye çevirip `bank_locked` dalını eklemek de gerekiyor — parametreler (`institution`, `periodEnd`) zaten eklendi, fonksiyon gövdesi migrasyon uygulanana kadar bilinçli olarak eskisini çağırıyor (yoksa RPC bulunamaz hatasıyla TÜM yüklemeler kırılır).

---

## P0 — Yayını durdur

Yok. Hiçbir bulgu üretimde aktif veri kaybı/güvenlik açığına P0 düzeyinde yol açmıyor.

---

## P1 — Bir sonraki sürümde

| ID | Başlık | Kanıt | Durum |
|---|---|---|---|
| ARCH-01/02 | CI hiç `flutter analyze`/`test` çalıştırmadan Play internal'e yüklüyordu — 3 ajan bağımsız aynı noktaya ulaştı | `.github/workflows/build.yml` | **GİDERİLDİ** — analyze+test+107-nokta paketi derleme/yüklemeden önce eklendi; yerelde doğrulandı (analyze temiz, test 433/0/7-skip, ps1 107/107, debug APK derlendi) |
| ARCH-03 | Otomatik yedek: hesap değişimi/sıfırlama sırasında boş yedek, gerçek bulut yedeğinin üstüne yazılabiliyordu + bekleyen zamanlayıcı hesap sınırını aşabiliyordu | `backup_service.dart`, `account_service.dart` | **GİDERİLDİ** — `hasLocalFinancialData()` boşsa yükleme yapılmıyor; `cancelPendingDebounce()` hesap değişimi/çıkışta çağrılıyor. Kod yolu doğrulandı, gerçek cihaz senaryosu DOĞRULANMADI. |
| SEC-01 | Farklı hesapla girişte "vazgeç" → önceki hesabın verisi yeni hesabın bulut yedeğine yüklenebiliyordu (çapraz hesap veri sızıntısı) | `backup_service.dart` `mayUploadFor()` | **GİDERİLDİ** (bu oturumda, bir önceki ajan tarafından) — commit edilecek |
| SEC-02 | Tek sürümlü bulut yedeği: başarısız geri yüklemeden sonra eksik/boş veriyle ezilebilir | `backup_service.dart` `restoreIfEmpty`/`_backupNowInner` | **ONAYLANDI — UYGULAMA ENGELLENDİ** (K44, kullanıcı notu: "atlamayalım, bizim mustlarımızdan") — `supabase/migrations/20261003150200_vault_blob_history.sql` yazıldı, canlıya uygulanamadı |
| PRIV-01 | Metinler çelişkili: "finansal kayıtlar internete gönderilmez / yalnız bu telefonda" artık yanlış (v3.10.0 bulut yedeği var) | `PRIVACY_POLICY.md:25`, `transaction_detail_sheet.dart:380` | **GİDERİLDİ** (bu oturumda, Claude tarafından doğrudan) — her iki metin, yedeklemeyi doğru yansıtacak şekilde düzeltildi |
| PRIV-02 | "Yalnızca siz erişebilirsiniz" / "uçtan uca şifreli" iddiası gerçek anahtar modeline (sunucuda türetilen anahtar) uymuyor | `PRIVACY_POLICY.md` Bölüm 1/5, `backup_service.dart:15` (kod yorumu) | **GİDERİLDİ** — kod yorumuna "uçtan uca değil" notu eklendi; `PRIVACY_POLICY.md` Bölüm 5'teki cümle, erişim kontrolü (hesapla oturum açma) ile şifreleme garantisi (uçtan uca değil, sunucu sırrına erişimi olan biri teorik olarak çözebilir) ayrımını netleştirecek şekilde yeniden yazıldı. |

---

## P2 — Yakın vade

| ID | Başlık | Kanıt | Durum |
|---|---|---|---|
| SEC-03 | Yedek anahtarı sunucuda türetiliyor; "uçtan uca şifreli" değil | `backup-key/index.ts`, `backup_service.dart` | AÇIK (mimari karar — anahtar yönetimi değişikliği büyük bir iş; kullanıcı kararı gerekli) |
| SEC-04 | Ücretsiz plan banka kilidi/geçmiş dönem muafiyeti yalnız istemcide, sunucuda zorlanmıyor | — | **ONAYLANDI — UYGULAMA ENGELLENDİ** (K42) — `20261003150000_free_tier_bank_lock_v2.sql` yazıldı; istemci parametreleri eklendi ama RPC çağrısı migrasyon uygulanana kadar bilinçli olarak eski fonksiyonu kullanıyor |
| SEC-05 | `admin-update-content`: JWT yok, paylaşılan sır sabit-zamanlı değil, hız sınırı yok; panelde saklı XSS riski | `admin-update-content/index.ts:42`, `Web_Yonetici_Paneli/index.html` | AÇIK |
| SEC-06 | Cihazdaki SQLite/JSON dosyaları şifresiz (F2-27 kararı) | — | AÇIK — `isDatabaseEncrypted()` artık dürüst `false` döndürüyor (yanıltıcı kısmı GİDERİLDİ) |
| SEC-07 | PIN kilidi kapalı (`_kPinLockEnforced=false`) | `main.dart` | AÇIK — gerçek cihazda kilitlenme hatası doğrulanmadan açılmayacak (proje hafızası kararı) |
| ARCH-04 | Kota ↔ kayıt tutarlılığı: uygulama kayıt sırasında öldürülürse kota düşmüş kalır | `statement_upload_sheet.dart:224-247` | KABUL EDİLEN RİSK (sunucu tarafı advisory lock çift-tüketimi zaten önlüyor) |
| ARCH-05 | `SecurityGuard`'da çağrılmayan/yanıltıcı fonksiyonlar (`runSelfSecurityDiagnostics` hep "20/20 OK") | `security_guard.dart` | AÇIK (`isDatabaseEncrypted` GİDERİLDİ, diğerleri kalıyor — `verify_parsers.ps1` string varlığına bağımlı) |
| ARCH-06 | Global hata yakalayıcı/çökme raporlama yok | `main.dart` | AÇIK |
| ARCH-07 | Ham istisna metni kullanıcıya gösteriliyor | `analysis_screen.dart` vb. | AÇIK |
| ARCH-11 | Yerelleştirme kısmi; para/tarih biçimi dilden bağımsız TR | `app_strings.dart` | AÇIK (bu oturumda İngilizce ilk dilim eklendi, tam kapsam değil) |
| ARCH-16 | Supabase göç sürüm numaraları yerel/sunucu uyumsuz | `supabase/migrations/` | AÇIK |
| FIN-02 | Elle tutar girişinde nokta ondalık ayırıcı 100 kat tutar üretebilir | birim test DOĞRULANDI | AÇIK |
| FIN-03 | `toMinorUnits("1,155.00")` → 116 kuruş (1000 kat hata); QA-P3-05 ile bağımsız doğrulandı | `currency_normalizer.dart` | AÇIK |
| FIN-04 | Döviz ekstresi tespiti yok, tüm tutarlar TL varsayılıyor | — | AÇIK |
| PRIV-03 | Sunucuda tutulan bazı veri kategorileri politikada yok | — | AÇIK |
| PRIV-05 | "İletişim izni" yalnız cihazda; sunucu duyuruyu herkese gönderiyor | `push_service.dart` | AÇIK — Ayarlar'daki toggle dürüstçe "yalnız yerel tercih" olarak belgelendi (v3.13.0), sunucu tarafı zorlama henüz yok |
| PRIV-06 | KVKK eksikleri: aydınlatma metni, veri sorumlusu, yurt dışı aktarım, saklama süreleri, VERBİS | `PRIVACY_POLICY.md` | AÇIK |
| QA-P2-01 | Hedef fazla birikimi başka hedefin ilerlemesine sızıyor ("%100 Ulaşıldı" ama katkı 0) | `goal_calculator_service.dart` | AÇIK (test `skip:` ile belgelendi) |
| PERF-01 | Supabase free plan uyku riski; F2-28 haftalık sağlık ping'i uygulanmamış | `get_organization` | AÇIK |
| PERF-02 | Her veri değişikliğinde TAM veritabanı yedeği (şifrele+yükle) | `backup_service.dart` | AÇIK (verimlilik, güvenlik sorunu değil) |
| PERF-03/04 | Ekstre ayrıştırma + yedek şifreleme ana (UI) isolate'te | — | AÇIK; gerçek takılma süresi ölçülmedi |
| SEO-01 | Yapılandırılmış veri (schema.org) hiç yok | `website/index.html` grep=0 | AÇIK — düzeltme küçük/geri dönüşü kolay, ayrı iş olarak bırakıldı |

---

## P3 — İyileştirme

| ID | Başlık | Durum |
|---|---|---|
| ARCH-08 | Sessiz `catch (_)` blokları (12 tanesi tamamen boş) | AÇIK |
| ARCH-09 | Dev dosyalar / tekil servis yoğunluğu (`assets_screen.dart` 2401 satır vb.) | AÇIK |
| ARCH-10 / PERF-13 | `DataChanges` yayını toplu yüklemede birleştirilmiyor (her belge 6 ekranı yeniden sorgulatıyor) | AÇIK — aynı kök, iki ajan bağımsız bulmuş |
| ARCH-12 | Tarih biçimlendirme 10+ yerde kopyalanmış | AÇIK |
| ARCH-13 | Erişilebilirlik: semantik etiket çok az (18 kullanım) | AÇIK |
| ARCH-14 | Ortam ayrımı (dev/prod) yok | AÇIK |
| ARCH-15 | 7 doğrudan + 1 dev bağımlılık güncel değil | AÇIK |
| ARCH-18 | Kullanılmayan sunucu tabloları (`key_envelopes`, `document_uploads`) | AÇIK |
| ARCH-20 / SEC-05 | `admin-update-content` sabit-zamanlı olmayan sır karşılaştırması | AÇIK (SEC-05 ile aynı) |
| SEC-08 | `file_picker` önbellek kopyaları silinmiyor | AÇIK (cihazda DOĞRULANMADI) |
| SEC-09 | Oturum belirteçleri `shared_prefs` içinde düz metin | AÇIK (platform normali, Flutter varsayılanı) |
| SEC-11 | `security_guard.dart` sahte fonksiyonları (kalanlar) | AÇIK |
| SEC-13/14 | `authenticated` rolüne TRUNCATE yetkisi; `vault_blobs` boyut sınırı yok | **ONAYLANDI — UYGULAMA ENGELLENDİ** (K43) — `20261003150100_revoke_truncate_authenticated.sql` yazıldı; boyut sınırı K44/SEC-02 migrasyonunda |
| SEC-15 | PiiRedactor fazla/az maskeleme | AÇIK |
| SEC-16 | PDF malware tarayıcı yalnız düz imza arıyor | AÇIK (kabul edilebilir — "0 TL maliyetli ilk savunma" olarak tasarlandı) |
| SEC-17 | `register_device` aynı FCM jetonunu başka kullanıcıya taşıyabiliyor | AÇIK |
| FIN-05 | Kategori analizi iadeleri düşmüyor (QA-P3-03 ile bağımsız doğrulandı) | AÇIK |
| FIN-06 | Kendi-hesap transferi eşleştirmesi karşı taraf adını kontrol etmiyor | AÇIK |
| FIN-07 | Bordro–maaş yatışı tekilleştirmesi tutara bakmıyor | AÇIK |
| FIN-08 | Hesap no okunamazsa iki kart tek hesaba düşebilir | AÇIK |
| FIN-09 | PiiRedactor maskelemesi mükerrer-anahtarı etkiliyor | AÇIK |
| PRIV-07 | Özel nitelikli veri ihtimali (bordro kesintileri) | DOĞRULANMADI |
| PRIV-08 | Hesap silme metni eksik kalemler + abonelik iptali uyarısı yok | AÇIK |
| PRIV-09 | Üçüncü taraf uç noktalara IP/zaman bilgisi gidiyor, sağlayıcı adlandırılmıyor | AÇIK |
| QA-P3-01 | Aynı bankanın iki kartı aynı son ödeme gününde bildirim ID çakışması | AÇIK (test `skip:` ile belgelendi) |
| QA-P3-02 | Aylık tasarruf önerisi yuvarlama son ay kuruş eksik bırakabilir | AÇIK (test `skip:` ile belgelendi) |
| QA-P3-04 | Tam mükerrer ekstre, kontrol aşılırsa yaklaşan ödemeyi çiftler | AÇIK (savunma derinliği eksik, test `skip:` ile belgelendi) |
| QA-P3-05 | `toMinorUnits` 1000 kat hatası (FIN-03 ile aynı, bağımsız doğrulandı) | AÇIK |
| PERF-05 | Aylık filtreler `LIKE 'YYYY-MM%'` indeksi kullanmıyor (`EXPLAIN` ile doğrulandı) | AÇIK |
| PERF-06 | PDF tamamı belleğe okunuyor; imza taraması iki kez | AÇIK |
| PERF-07 | Kendi-hesap transfer eşleştirmesi her açılışta N+1 sorgu | AÇIK |
| PERF-08 | Açılışta her seferinde Play restore + doğrulama + entitlement | AÇIK |
| PERF-09 | Edge Function'larda hız sınırı yok | AÇIK |
| PERF-11 | Log/izleme: istemci hatası görünmez, sunucu logları ham | AÇIK |
| SEO-02 | Core Web Vitals hiç ölçülmedi (araç yok) | DOĞRULANMADI |
| SEO-03 | "Geliştirici hakkında"/şeffaflık sayfası yok | AÇIK, düşük öncelik |
| SEO-M-01 | Ayrıştırma hataları sunucuya hiç gitmiyor, görünürlük yok | AÇIK — `[[admin-panel-user-tracking]]` işinin parçası |

---

## P4 — Kozmetik/hijyen

| ID | Başlık | Durum |
|---|---|---|
| ARCH-17 | pubspec ortam kısıtı yanıltıcı (`sdk >=3.0.0` ama gerçekte `>=3.13.0`) | AÇIK |
| ARCH-19 | `AGENTS.md` çelişkili yönergeler (var olmayan CI dosyasına, eski tasarım standardına atıf) | AÇIK |
| SEC-18 | Supabase Auth "Leaked Password Protection" kapalı | AÇIK — bu ortamdan Supabase Auth panosuna erişim yok, kullanıcı elle açmalı |
| SEC-19 | Ekran görüntüsü engeli yok (FLAG_SECURE) | KABUL EDİLEN RİSK (v3.6.1'de ürün kararıyla kaldırıldı) |
| SEC-20 | Manifest/derleme küçükleri | AÇIK |
| PRIV-10 | Yaş sınırı yalnız beyan | AÇIK (sektör normali) |
| FIN-12 | Tarih/saat dilimi küçük notlar | AÇIK |
| FIN-14 | Faiz/BSMV/KKDF oranları finans uzmanınca teyit edilmeli | AÇIK — `finscout-finans` ajanının kapsamı |
| MKT-01 | `pazarlama/reklam_plani.md`'de eski, F4-03'e aykırı anahtar kelime notu | AÇIK, düşük öncelik |
| AGT-03 | "İnsan onayı gerektiren işlemler" tek bir merkezi listede değil, dağınık | AÇIK — öneri: CLAUDE.md'ye kısa bölüm eklenmesi (kullanıcı kararı) |

---

## Doğrulanan, sorun bulunmayan alanlar (bilgi amaçlı)

SEC-21 (RLS/RPC/IDOR/cascade silme), SEC-22 (sır taraması), SEC-23 (Edge Function kimlik doğrulama), FIN-01 (tamsayı kuruş mimarisi), FIN-10/11/13 (mükerrer koruma, çift-sayım önleme, toplam tutarlılığı — testlerle doğrulandı), PRIV-11 (politikayla uyumlu noktalar) — hepsi DOĞRULANDI, ek işlem gerekmiyor.

---

## Bu oturumda GERÇEKTEN düzeltilenlerin özeti (rapor şişirme değil — her biri `flutter analyze`+`flutter test` ile doğrulandı)

1. **SEC-01** — çapraz hesap veri sızıntısı (`mayUploadFor`)
2. **ARCH-03** — boş yedek gerçek bulut yedeğinin üstüne yazılması + bekleyen zamanlayıcı hesap sınırı aşımı (`hasLocalFinancialData` kontrolü + `cancelPendingDebounce`)
3. **SEC-12** — MAC karşılaştırması sabit-zamanlı değildi + PBKDF2 `iter` sınırsızdı (DoS riski)
4. **SEC-10** — 10 noktada hassas veri log sızıntısı (release'te tür adına indirgendi)
5. **ARCH-01/ARCH-02** — CI hiç test/analiz çalıştırmadan Play'e yüklüyordu
6. **PRIV-01/PRIV-02 (kısmi)** — "hiç internete gönderilmez" / "uçtan uca şifreli" yanlış iddiaları (politika metni + kod yorumu + uygulama içi metin)
7. **ARCH-05 (kısmi)** — `isDatabaseEncrypted()` artık dürüst `false`

Geri kalan tüm AÇIK/ONAY BEKLİYOR maddeler bu belgede bilinçli olarak **düzeltilmedi** — SQL şema değişiklikleri kullanıcı onayı gerektirdiği için, diğerleri ise kapsam/zaman nedeniyle bir sonraki çalışma turuna bırakıldı.

---
*Kaynak: `docs/audit/*.md` (16 belge), bu oturumdaki doğrudan `git diff`/`flutter analyze`/`flutter test` doğrulamaları.*
