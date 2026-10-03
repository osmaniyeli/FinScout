# FinScout — Performans ve Maliyet İncelemesi (Denetim 1/5)

Tarih: 2026-10-03 · Salt-okunur · Commit `b7aa9fb`
Öncelik: P0–P4 · Durum etiketleri: DOĞRULANDI / BAŞARISIZ / GİDERİLDİ / DOĞRULANMADI / KAPSAM DIŞI / KABUL EDİLEN RİSK

> Ölçüm notu: Bu denetimde cihaz üzerinde süre/bellek ÖLÇÜLMEDİ. Aşağıdaki hiçbir bulgu ms veya MB cinsinden çalışma zamanı ölçümü içermez. Tek gerçek ölçüm, masaüstü SQLite 3.50.4 ile gerçek şema üzerinde `EXPLAIN QUERY PLAN` çıktısıdır (PERF-05). Android'deki SQLite sürümü farklıdır; ancak LIKE/indeks kuralları sürümden bağımsızdır.
> Koddaki "Ortalama 5 MB'lık ekstre için tarama süresi: 1 - 3 milisaniye" yorumu (`pdf_malware_scanner.dart:39`) ve v5 indeks dosyasındaki "~29 bin işlem" ölçümü (`assets/sql/v5_indexes.sql:2-3`) bu denetimde yeniden üretilmedi → DOĞRULANMADI.

## Özet tablo

| ID | Öncelik | Başlık | Durum |
|---|---|---|---|
| PERF-01 | P1 | Supabase free plan uyku riski; F2-28 haftalık sağlık ping'i uygulanmamış | DOĞRULANDI (eksiklik) |
| PERF-02 | P2 | Her veri değişikliğinde TAM veritabanı yedeği (şifrele + yükle) | DOĞRULANDI |
| PERF-03 | P2 | Ekstre ayrıştırma ana (UI) isolate'te | DOĞRULANDI (kod); takılma süresi DOĞRULANMADI |
| PERF-04 | P2 | Yedek şifreleme (saf Dart AES + PBKDF2 10.000 tur) ana isolate'te | DOĞRULANDI (kod); süre DOĞRULANMADI |
| PERF-05 | P3 | Aylık filtreler `LIKE 'YYYY-MM%'` indeksi kullanmıyor | DOĞRULANDI (EXPLAIN) |
| PERF-06 | P3 | PDF tamamı belleğe okunuyor; boyut kontrolü okumadan sonra; imza taraması iki kez | DOĞRULANDI |
| PERF-07 | P3 | Kendi-hesap transfer eşleştirmesi her açılışta tüm DB'de N+1 sorgu | DOĞRULANDI |
| PERF-08 | P3 | Açılışta her seferinde Play restore + `verify-purchase` + `entitlement` | DOĞRULANDI |
| PERF-09 | P3 | Edge Function'larda hız sınırı yok | DOĞRULANDI |
| PERF-10 | P3 | `send-push` büyük kitlede zaman aşımı riski | DOĞRULANMADI (ölçülmedi) |
| PERF-11 | P3 | Log / izleme: istemci hatası görünmez, sunucu logları ham | DOĞRULANDI |
| PERF-12 | P4 | Supabase performans danışmanı: 1 kullanılmayan indeks | DOĞRULANDI |
| PERF-13 | P3 | Toplu yüklemede her belge 6 ekranı yeniden sorgulatıyor | DOĞRULANDI (ARCH-10 ile aynı kök) |

---

### PERF-01 — P1 — Free plan uyku riski, F2-28 uygulanmamış
- Kanıt: Organizasyon planı `free` (`get_organization` → `plan: free`, `tier_free`). Zamanlanmış hiçbir iş yok: `cron.job` tablosu mevcut değil (sorgu `42P01 relation "cron.job" does not exist`); `.github/workflows/` altında `schedule:` tetikli iş yok (yalnız `build.yml` push/manuel, `pages.yml` push/manuel). Repoda "F2-28 / health ping / keep-alive" geçen hiçbir dosya yok (grep boş).
- Etki: Supabase ücretsiz projeleri bir süre etkinlik olmazsa duraklatılır (süre Supabase'in güncel politikasına bağlı; bu denetimde doğrulanmadı). Duraklayan projede giriş, kota (`consume_upload`), yedek, abonelik doğrulaması çalışmaz → **ekstre yükleme tamamen durur** (kota sunucuya ulaşılamazsa kayıt yapılmıyor: `statement_upload_sheet.dart:221-228`). Mevcut kullanıcı sayısı küçük (profiles = 8) olduğundan doğal trafik garantisi yok.
- Dar düzeltme: `.github/workflows/health-ping.yml` — `on: schedule: - cron: '0 6 * * 1'` + publishable key ile `GET /rest/v1/app_content?select=key&limit=1` (RLS'nin anon okumaya izin verdiği tablo; doğrulanmalı). Başarısızlıkta iş kırmızı yansın (GitHub e-postası = ucuz uyarı). Not: GitHub, 60 gün commit olmayan depolarda zamanlanmış iş akışlarını devre dışı bırakabilir — kalıcı çözüm Pro plan ya da harici izleyici.

### PERF-02 — P2 — Her değişiklikte tam yedek
- Kanıt: `DataChanges.notify()` → 9 sn debounce → `getAllDataForExport()` tüm tabloları okur (`transaction_repository.dart:726-770`), tüm JSON'u şifreler ve `vault_blobs`'a `upsert` eder (`backup_service.dart:95-98,155-185`). Artımlı/fark yedeği yok. Tek kategori düzeltmesi bile tam yedek tetikler (`updateTransactionCategory` → notify).
- Maliyet: Şu an `vault_blobs` toplam 184 kB, 2 satır (canlı sorgu) — bugün ihmal edilebilir. Ölçek: blob boyutu × değişiklik sıklığı × kullanıcı; Supabase free plan veritabanı boyutu ve egress sınırlarına doğru büyür (sınır değerleri bu denetimde doğrulanmadı). Postgres'te TOAST'lı büyük `text` güncellemesi her seferinde yeni satır sürümü → şişme/autovacuum yükü.
- Dar düzeltme: (a) Debounce'u uzat ve uygulama arka plana geçince (`AppLifecycleState.paused`) yedekle; (b) yüklemeden önce şifresiz JSON'un SHA-256'sı bir önceki yüklemeyle aynıysa atla; (c) ARCH-03'teki boş DB koruması.

### PERF-03 — P2 — Ayrıştırma ana isolate'te
- Kanıt: PDFium çağrıları pdfrx'in kendi arka plan isolate'inde (`pdfrx_engine-0.6.1/lib/src/native/pdfrx_pdfium.dart:56,102,684` `BackgroundWorker.compute`) — DOĞRULANDI. Ancak her sayfanın `loadStructuredText()` sonucu ana isolate'e döner; `RawTextFragment` listesi oluşturma, `StatementLayout.fromFragments` (`pdf_extractor_service.dart:61-91`), SHA-256 (`:46`), malware taraması (latin1 decode + RegExp, `pdf_malware_scanner.dart:101-117`) ve `StatementOrchestrator.processDocument` (parser + zenginleştirme + PII regex + mutabakat, `statement_orchestrator.dart:40-150`) ana isolate'te çalışır. `lib/` içinde `compute`/`Isolate.run` yalnız sözlük yükleme (`category_engine.dart:65`) ve PIN hash'te (`security_auth_service.dart:124`).
- Etki: Çok sayfalı ekstrelerde ve toplu yüklemede animasyon takılması olası. Süre ÖLÇÜLMEDİ → DOĞRULANMADI.
- Dar düzeltme: `processDocument`'i `Isolate.run` içine al (girdi `StatementLayout` + `userRules` + sözlük; `CategoryEngine` tekilinin isolate'e taşınması gerekeceğinden önce sözlüğü parametre olarak geçir). Önce Flutter DevTools ile korpustaki en büyük PDF'te ölç.

### PERF-04 — P2 — Yedek şifreleme ana isolate'te, saf Dart AES
- Kanıt: `AesCipher` elle yazılmış AES (`aes_cipher.dart:59-243`, `_encryptBlock` vb.) ve PBKDF2-SHA256 10.000 tur, 64 bayt (`:246-275, 349`). `BackupService._backupNowInner` bunu doğrudan çağırıyor (`backup_service.dart:172`), `compute` yok. Geri yüklemede `decryptVaultPayload` da ana isolate'te (`:215`).
- Etki: Veri büyüdükçe her 9 sn'lik debounce sonrası UI donması olası; süre ÖLÇÜLMEDİ → DOĞRULANMADI.
- Dar düzeltme: `encryptVaultPayload`/`decryptVaultPayload` çağrısını `Isolate.run`'a sar (saf fonksiyonlar, String in/String out — taşıması kolay). Kriptografik doğruluk (elle yazılmış AES, MAC karşılaştırması) güvenlik parçasının kapsamı → çapraz referans.

### PERF-05 — P3 — `LIKE 'YYYY-MM%'` indeks kullanmıyor (ölçüldü)
- Kanıt (EXPLAIN QUERY PLAN, gerçek `assets/sql/v1…v6` şeması, Python sqlite3 3.50.4):
  - `WHERE t.transaction_date LIKE '2026-09%'` → **`SCAN t`** (tam tablo taraması)
  - `WHERE t.transaction_date >= '2026-09-01' AND t.transaction_date < '2026-10-01'` → `SEARCH t USING INDEX idx_transactions_date`
  - Aylık trend (`strftime` + GROUP BY) → `SCAN transactions` + `USE TEMP B-TREE FOR GROUP BY` (beklenen; tüm geçmiş)
  - Kendi-transfer aday sorgusu → `SEARCH … idx_transactions_kind_amount_date (tx_kind=? AND billing_amount_cents=?)` (v6 indeksi çalışıyor; tarih `julianday()` içinde olduğundan aralık kısmı kullanılmıyor)
  - Son işlemler (filtresiz) → `SCAN t USING INDEX idx_transactions_date` + `USE TEMP B-TREE FOR LAST TERM OF ORDER BY` (`created_at` ikincil sıralama)
  - SHA mükerrer kontrolü → `SEARCH statements USING COVERING INDEX` (iyi)
- Etkilenen sorgular: `getMonthlySummary` (`transaction_repository.dart:465`), `getRecentTransactions(yearMonth)` (`:502`), `getCategorySpendingAnalysis` (`:569`) — ana sayfa ve analiz her açılışta/değişiklikte.
- Dar düzeltme: `LIKE ?` + `'$yearMonth%'` yerine `transaction_date >= ? AND transaction_date < ?` (ayın ilk günü / sonraki ayın ilk günü). Şema değişikliği gerektirmez. Kişisel veri hacminde (binlerce satır) fark küçük olabilir; gerçek cihaz süresi DOĞRULANMADI.

### PERF-06 — P3 — PDF belleğe tam okuma, sonradan boyut kontrolü, çift tarama
- Kanıt: `pickFiles(withData: kIsWeb)` ile mobilde yol alınıyor (iyi, `statement_upload_sheet.dart:101-106`), ama `_readBytes` dosyanın tamamını okuyor (`:169`) ve 15 MB sınırı ancak sonra `validatePdfFile` içinde kontrol ediliyor (`security_guard.dart:249-251`). `PlatformFile.size` okumadan önce mevcut ama kullanılmıyor. `scanPdfForMalware` (`:177`) ve `validatePdfFile` (`:182` → `security_guard.dart:263` tekrar `PdfMalwareScanner.scanBytes`) aynı dosyayı iki kez `latin1.decode` edip tarıyor; yorumdaki "bellek kopyalamasını engeller" ifadesi (`pdf_malware_scanner.dart:99-100`) doğru değil — `latin1.decode` dosya boyutunda yeni bir String ayırır.
- Dar düzeltme: Okumadan önce `file.size > 15 MB` ise reddet; `:177`'deki ayrı tarama çağrısını kaldır, sonucu `validatePdfFile`'dan döndür (tehdit mesajı için).

### PERF-07 — P3 — Kendi-hesap transfer eşleştirmesi: tüm DB, N+1
- Kanıt: Her açılışta (`main.dart:55,80-89`) ve her ekstre kaydından sonra `reconcileOwnTransfers` çalışır; tüm `TRANSFEROUT` satırlarını çeker, her biri için ayrı aday sorgusu + 2 `UPDATE` (`transaction_repository.dart:286-325`). Eşleşen olursa `DataChanges.notify()` → tam yedek (PERF-02).
- Dar düzeltme: Yalnız henüz eşleşmemiş ve son N gün içindeki satırlar; ya da tek bir `UPDATE … WHERE id IN (SELECT …)` ile küme tabanlı. Açılıştaki çağrıyı "son açılıştan beri yeni ekstre var mı" bayrağına bağla.

### PERF-08 — P3 — Açılışta abonelik doğrulama zinciri
- Kanıt: `SubscriptionService.initialize()` her açılışta `loadProducts()` + `restorePurchases()` (`subscription_service.dart:163-171`); restore 8 sn'ye kadar bekler (`:288-291`), satın alma varsa `verify-purchase` Edge Function'ı (`:426`) → her çağrıda servis hesabıyla yeni Google OAuth jetonu üretir (`verify-purchase/index.ts:43-75`, önbellek yok) → Play Developer API → ardından `entitlement` RPC.
- Maliyet: Edge Function çağrısı/abone/açılış. Free plan Edge çağrı kotası değeri bu denetimde doğrulanmadı. Bugünkü hacimde ihmal edilebilir (subscriptions = 0 satır).
- Dar düzeltme: Önbellekteki yetki geçerliyse ve son doğrulama < 24 saat ise açılışta yalnız `entitlement` RPC; tam restore günde bir.

### PERF-09 — P3 — Edge Function'larda hız sınırı yok
- Kanıt: `supabase/functions/*/index.ts` içinde `429`, `rate`, `throttle` yok (grep). `admin-update-content` `verify_jwt=false` + düz sır karşılaştırması (`index.ts:42`) → kaba kuvvet denemesine açık ve her deneme bir fonksiyon çağrısı (maliyet). Auth hız sınırları yerel `config.toml:196-208`'de tanımlı (e-posta 30, giriş 30, doğrulama 30) — bunlar yalnız yerel CLI içindir; barındırılan projedeki değerler panelden yönetilir → DOĞRULANMADI.
- İstemci tarafı "rate limit" (`SecurityGuard.checkRateLimit`, `security_guard.dart:194-213`) yalnız hızlı manuel girişte kullanılıyor; sunucu koruması sağlamaz.
- Dar düzeltme: `admin-update-content` için başarısız denemede sabit gecikme + IP başına basit sayaç (ör. küçük bir tablo), ya da JWT + `is_admin()`'e geçiş. Kullanıcı fonksiyonları (`backup-key`, `verify-purchase`) JWT gerektirdiğinden risk düşük.

### PERF-10 — P3 — `send-push` ölçeklenmesi
- Kanıt: Tek çağrıda en fazla 10.000 cihaz (`send-push/index.ts:205`), 20'şerli paralel FCM HTTP v1 isteği (`:227-240`), sonra geçersiz jeton temizliği. Edge Function duvar saati sınırı ve 10.000 cihazdaki toplam süre ÖLÇÜLMEDİ → DOĞRULANMADI. Bugün `devices` = 5 satır; pratik risk yok.
- Dar düzeltme (gerektiğinde): FCM topic'lerine (`/topics/announcements`) geçiş — tek istek, jeton listesi gerekmez.

### PERF-11 — P3 — Log ve izleme
- İstemci: çökme/hata raporlama yok (ARCH-06); `debugPrint` release'te de çalışır ama toplanmaz. Uygulama içi "audit log" (`SecurityGuard.logAudit`) bellekte 200 kayıt tutar, hiç okunmaz (`security_guard.dart:~330-350`).
- Sunucu: Edge Function'lar `console.log/error` kullanıyor; `delete-account/index.ts:36` ve `backup-key/index.ts:59` kullanıcı UUID'sini logluyor (e-posta değil). Supabase log saklama süresi free planda kısa (değer doğrulanmadı). Uyarı/alarm yok.
- Dar düzeltme: PERF-01'deki zamanlanmış iş aynı zamanda temel bir "ayakta mı" alarmı olur; Edge Function hatalarını haftalık `query_logs` ile gözden geçirme rutini.

### PERF-12 — P4 — Supabase performans danışmanı
- `get_advisors(type: performance)`: yalnız 1 INFO bulgusu — `admin_notifications_created_idx` hiç kullanılmamış (tablo 0 satır; normal). Eksik FK indeksi veya RLS `auth.uid()` yeniden değerlendirme uyarısı YOK — DOĞRULANDI. Politikalar `(select auth.uid())` desenini kullanıyor (`20260923175347_init_accounts_vault.sql:65`).

### PERF-13 — P3 — Toplu yüklemede tekrarlı yeniden yükleme
- Bkz. ARCH-10: her belge kaydı → `DataChanges.notify()` → 6 ekran sorgusu + yedek zamanlayıcısının sıfırlanması. Toplu işte bildirimi sona ertele ya da birleştir.

---

## Yerel veritabanı ve indeksler — genel değerlendirme
- Şema v6, `PRAGMA foreign_keys = ON` (`app_database.dart:59-61`); göçler sqflite'ın `onCreate/onUpgrade` işlem bağlamında çalışır.
- Mevcut indeksler (`assets/sql`): `idx_transactions_date`, `_category`, `_fingerprint` (UNIQUE kısmi), `_kind`, `_counterparty`, `_statement_kind`, `_kind_amount_date`; `idx_installments_due`, `_transaction`; `idx_statements_account_date`; `idx_scheduled_payments_due`; `idx_goals_status`; `idx_goal_contributions_goal`; `statements.file_sha256 UNIQUE`. Ekstre kaydı tek işlem içinde satır satır `insert` (`transaction_repository.dart:112-240`) — `batch()` kullanılmıyor ama işlem içinde olduğundan kabul edilebilir; süre DOĞRULANMADI.
- `_runSqlAsset` SQL'i `;` ile bölüyor (`app_database.dart:66-77`) — tohum verisinde metin içi `;` olursa bozulur; şu an sorun yok (korpus testleri geçiyorsa) → P4 not.
- `ANALYZE` hiç çalıştırılmıyor; v5 yorumu planlayıcının istatistiksiz olduğunu kabul ediyor (`v5_indexes.sql:4-5`). KABUL EDİLEN RİSK.

## Arka plan işleri
- Açılışta `unawaited` başlatılan 6 iş (`main.dart:50-63`): sözlük yükleme (isolate), hatırlatıcı senkronu, kendi-transfer eşleştirme, abonelik, push, yedek dinleyicisi, CMS yenileme. Sıra/çakışma kaynaklı ilk-kare takılması ÖLÇÜLMEDİ → DOĞRULANMADI.
- Uygulama kapalıyken çalışan iş: yalnız zamanlanmış yerel bildirimler ve FCM arka plan işleyicisi; periyodik senkron yok (bilinçli, pil açısından iyi).

## Supabase maliyet özeti (bugünkü durum, canlı salt-okunur sorgular)
| Kalem | Değer | Risk |
|---|---|---|
| Plan | free | Uyku (PERF-01) |
| En büyük tablo | `vault_blobs` 184 kB | Düşük; tam-yedek modeli ölçekte büyür (PERF-02) |
| Toplam kullanıcı | profiles = 8 | — |
| Edge Function | 5 aktif | `admin-update-content` korumasız çağrılabilir (PERF-09) |
| Zamanlanmış iş | yok | — |
