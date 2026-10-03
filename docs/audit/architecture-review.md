# FinScout — Mimari İnceleme (Denetim 1/5, Aşama 2)

Tarih: 2026-10-03 · Salt-okunur; kaynak koda dokunulmadı · Commit `b7aa9fb`
Öncelik: P0 (yayını durdur) · P1 (bir sonraki sürümde) · P2 (yakın vade) · P3 (iyileştirme) · P4 (kozmetik/hijyen)
Durum etiketleri: DOĞRULANDI / BAŞARISIZ / GİDERİLDİ / DOĞRULANMADI / KAPSAM DIŞI / KABUL EDİLEN RİSK

## Çalıştırılan kontroller

| Komut | Sonuç |
|---|---|
| `flutter analyze` (moneytrace) | **No issues found! (ran in 13.2s)** — DOĞRULANDI. Not: yalnız `flutter_lints` varsayılanları açık; katı kurallar (`strict-casts`, `strict-raw-types`, `unawaited_futures`, `avoid_dynamic_calls`) kapalı (`analysis_options.yaml`). |
| `flutter pub outdated` | 7 doğrudan + 1 dev bağımlılık güncel değil (ayrıntı ARCH-15). |
| `EXPLAIN QUERY PLAN` (Python sqlite3 3.50.4, `assets/sql/v1…v6` ile kurulan bellek-içi şema) | bkz. performance-and-cost-review.md PERF-05. |
| Supabase `list_tables`, `list_edge_functions`, `list_migrations`, `pg_proc` sorgusu, `get_advisors(performance)` | Salt-okunur; bulgular aşağıda. |
| `flutter test` | **ÇALIŞTIRILMADI** — aynı dizinde 4 paralel ajan var; `build/`/`.dart_tool` kilit çakışması riski. DOĞRULANMADI. |

---

## Özet tablo

| ID | Öncelik | Başlık | Durum |
|---|---|---|---|
| ARCH-01 | P1 | "107 kontrollük" kalite kapısı Dart kodunu test etmiyor | **GİDERİLDİ** — CI'a gerçek `flutter test` eklendi (ARCH-02), ps1 artık tek başına kapı değil |
| ARCH-02 | P1 | CI, test/analiz çalıştırmadan Play internal kanalına yüklüyor | **GİDERİLDİ** (2026-10-03) — `.github/workflows/build.yml`'e `flutter analyze` + `flutter test` + `verify_parsers.ps1` adımları, derleme/Play adımlarından ÖNCE eklendi. Üç ajanın bağımsız vardığı ortak bulgu. `tools/ci_cd_quality_gate.yml` DEPRECATED başlığıyla işaretlendi (silinmedi). Yerel doğrulama: analyze temiz, test 433/0, ps1 107/107, debug APK derlemesi başarılı — CI'da henüz (bir sonraki push'ta) doğrulanacak. |
| ARCH-03 | P1 | Otomatik yedek: boş DB'yi buluttaki yedeğin üstüne yazma + oturum değişiminde bekleyen zamanlayıcı | **GİDERİLDİ** (2026-10-03, bkz. bulgu altında) |
| ARCH-04 | P2 | Kota düştükten sonra kayıt/iade arasında tutarsızlık penceresi | DOĞRULANDI (kod yolu) |
| ARCH-05 | P2 | `SecurityGuard`'da ölü ve yanıltıcı ("her zaman OK") fonksiyonlar | DOĞRULANDI |
| ARCH-06 | P2 | Global hata yakalayıcı ve çökme raporlama yok | DOĞRULANDI |
| ARCH-07 | P2 | Ham istisna metni kullanıcıya gösteriliyor | DOĞRULANDI |
| ARCH-08 | P3 | Sessiz `catch` blokları | DOĞRULANDI |
| ARCH-09 | P3 | Dev dosyalar / tekil servis yoğunluğu | DOĞRULANDI |
| ARCH-10 | P3 | `DataChanges` yayını toplu yüklemede birleştirilmiyor | DOĞRULANDI |
| ARCH-11 | P2 | Yerelleştirme kısmi; para/tarih biçimi dilden bağımsız TR | DOĞRULANDI |
| ARCH-12 | P3 | Tarih biçimlendirme 10+ yerde kopyalanmış | DOĞRULANDI |
| ARCH-13 | P3 | Erişilebilirlik: semantik etiket çok az | DOĞRULANDI (sayım); ekran okuyucu testi DOĞRULANMADI |
| ARCH-14 | P3 | Ortam ayrımı (dev/prod) yok | DOĞRULANDI |
| ARCH-15 | P3 | Bağımlılık güncelliği | DOĞRULANDI |
| ARCH-16 | P2 | Supabase göç sürüm numaraları yerel/sunucu uyumsuz | DOĞRULANDI |
| ARCH-17 | P4 | pubspec ortam kısıtı gerçeği yansıtmıyor | DOĞRULANDI |
| ARCH-18 | P3 | Kullanılmayan sunucu tabloları | DOĞRULANDI |
| ARCH-19 | P4 | AGENTS.md / ölü CI dosyası çelişkili yönerge | DOĞRULANDI |
| ARCH-20 | P3 | `admin-update-content`: sabit-zamanlı olmayan sır karşılaştırması, hız sınırı yok | DOĞRULANDI (güvenlik ajanına çapraz referans) |

---

## Bulgular

### ARCH-01 — P1 — Kalite kapısı (`verify_parsers.ps1`) Dart kodunu test etmiyor
- Kanıt: `moneytrace/test/verify_parsers.ps1:42-61` maskeleme regex'lerini PowerShell'de **yeniden yazıp** yine PowerShell çıktısını doğruluyor (ör. `:44 $maskedText = [regex]::Replace(...)`, `:58 Assert-Test "TCKN Masking"`). Dosyada `flutter test`/`dart` çağrısı yok (grep boş). Banka tespitleri de `-match 'ENPARA'` gibi metin eşleşmeleri (`:84,113,146`). 94 `Assert-Test` çağrısı var (döngülerle 107'ye ulaşıyor olabilir).
- Etki: Dart'taki `PiiRedactor` (`lib/core/security/pii_redactor.dart:5-25`) veya parser'lar bozulsa kapı yine yeşil yanar → yanlış güven. Pre-push hook (`tools/setup_hooks.ps1`) yalnız bunu çalıştırıyor ve PowerShell yoksa `exit 0`.
- Dar düzeltme: Kapıyı `flutter analyze && flutter test` (+ korpus mevcutsa `pdf_corpus_probe_test.dart`) olarak yeniden tanımla; ps1'yi ya kaldır ya "regex taslak testleri" diye yeniden adlandır. Gerçek korpus testi zaten Dart'ta var — doğruluk kâhini o olmalı.

### ARCH-02 — P1 — CI test/analiz koşmadan Play'e yüklüyor
- Kanıt: `.github/workflows/build.yml` adımları: Checkout → Java → Flutter → `pub get` → APK → AAB → artifact → `r0adkll/upload-google-play` (track `internal`, `status: completed`). Hiçbir `flutter analyze`/`flutter test` adımı yok. `tools/ci_cd_quality_gate.yml` `.github/workflows` dışında olduğu için GitHub tarafından çalıştırılmıyor.
- Dar düzeltme: `Install Dependencies`'ten sonra `flutter analyze` ve `flutter test` adımları ekle (korpus PDF'leri repoda olmadığından korpus testi CI'da atlanır — test zaten env yoksa atlıyor mu, DOĞRULANMADI).

### ARCH-03 — P1 — Otomatik yedekte veri kaybı / hesaplar arası karışma yolu
- Kanıt:
  1. `BackupService._onDataChanged` her `DataChanges.notify()`'da 9 sn'lik zamanlayıcı kurar (`backup_service.dart:39,93-98`). `_backupNowInner` yerel DB boş olsa da yükler; boşluk kontrolü yok (`:144-185`, `upsert … onConflict user_id,blob_id`).
  2. `confirmAccountSwitch()` → `wipeLocalData()` → `clearAllUserData()` → `DataChanges.notify()` (`account_service.dart:241`, `user_profile_service.dart:750-753`, `transaction_repository.dart:851-855`). Hemen ardından `restoreIfEmpty()` denenir (`account_service.dart:284-290`); restore ağ hatasıyla `false` dönerse (`backup_service.dart:218-221` hatayı yutar) 9 sn sonra **boş** yedek yeni hesabın buluttaki gerçek yedeğinin üstüne yazılır.
  3. `signOut()` `backupNow(force:true)` çağırır ama bekleyen `_debounceTimer`'ı iptal etmez (`account_service.dart:330-345`; `clearCachedKey` yalnız anahtarı siler, `backup_service.dart:102-104`). 9 sn içinde başka hesapla girilirse ve yerelde önceki hesabın verisi duruyorsa (onay diyaloğu beklerken, `account_service.dart:249-256`), zamanlayıcı önceki hesabın verisini yeni hesabın anahtarıyla yeni hesabın `vault_blobs` satırına yazabilir.
- Etki: Kullanıcının bulut yedeği kalıcı olarak boşalabilir; ender durumda A'nın finansal verisi B'nin yedeğine girer.
- Dar düzeltme: (a) `_backupNowInner` başında `hasLocalFinancialData()` false ise yükleme yapma (veya yalnız açık "verilerimi sil" akışında izin ver); (b) `signOut()` ve `wipeLocalData()` başında `_debounceTimer?.cancel()`; (c) yükleme anındaki `user.id`'nin, verinin `localDataOwnerId()`'siyle eşleştiğini kontrol et.
- Not: çalışma zamanında tekrar üretilmedi → davranış DOĞRULANMADI, kod yolu DOĞRULANDI.
- **Güncelleme (2026-10-03, Claude tarafından doğrudan düzeltildi, commit edilmedi):** Üç madde de kapatıldı:
  1. Madde 3 (A'nın verisinin B'nin kasasına yazılması) — bir önceki ajanın eklediği `mayUploadFor(localOwnerId, sessionUserId)` kontrolü (`backup_service.dart:114-115`) ile zaten kapanmıştı.
  2. Madde 2 (boş DB'nin gerçek buluttaki yedeğin üstüne yazılması) — `_backupNowInner` artık `UserProfileService.hasLocalFinancialData()` false ise (sahip kontrolünden bağımsız olarak) hiç yükleme yapmıyor (`backup_service.dart:171-178`). Bu, `confirmAccountSwitch` sonrası sahip=oturum olduğu ama veri henüz `restoreIfEmpty()` ile geri gelmediği pencereyi de kapatıyor.
  3. Madde (b) bekleyen zamanlayıcı iptali — yeni `BackupService.cancelPendingDebounce()` metodu; `confirmAccountSwitch()` içinde `wipeLocalData()`'dan ÖNCE ve `signOut()` içinde zorunlu `backupNow(force:true)`'dan ÖNCE çağrılıyor (`account_service.dart`).
  - Doğrulama: `flutter analyze` temiz, `flutter test` 433 geçti/7 atlandı/0 başarısız (önceki temel çizgiyle aynı) — davranışsal regresyon yok. Çalışma zamanında (gerçek hesap değişimi senaryosu) tekrar üretilmedi; kod yolu DOĞRULANDI, çalışma zamanı davranışı DOĞRULANMADI. → **GİDERİLDİ (kod yolu)**.

### ARCH-04 — P2 — Kota ↔ kayıt tutarlılığı
- Kanıt: `_consumeAndSave` önce `consume_upload` RPC, sonra yerel kayıt; kayıt istisnası olursa `refund_upload` (`statement_upload_sheet.dart:224-247`). İade de ağ ister; başarısızsa yalnız loglanır (yorum `:239-241`). Uygulama kayıt sırasında öldürülürse kota düşmüş, kayıt yok — iade hiç denenmez.
- Sunucu tarafı yarış: `consume_upload` ve `refund_upload` `pg_advisory_xact_lock(hashtextextended(uid||':'||period))` kullanıyor (`supabase/migrations/20260925142652_refund_upload.sql:62,112`; canlı tanımda da var — `pg_proc.prosrc` kontrolü `has_lock=true`) → eşzamanlı çift tüketim korunuyor: DOĞRULANDI.
- Dar düzeltme: KABUL EDİLEN RİSK olarak belgelenebilir; istenirse `consumptionId`'yi kayıttan önce yerelde (secure storage) "askıda" olarak sakla, açılışta kayıtla eşleşmeyenleri iade et.

### ARCH-05 — P2 — `SecurityGuard`: ölü ve yanıltıcı kod
`lib/core/security/security_guard.dart` (412 satır) içindeki herkese açık metotların dış çağıran sayısı (grep, `lib/` + `test/`):

| Metot | Satır | Dış çağrı |
|---|---|---|
| `hashPin`, `verifyPinHash`, `verifyBiometricOrPin` | 55, 63-76 | 0 (PIN gerçekte `security_auth_service.dart:124` PBKDF2 ile) |
| `canAccessAdminConsole`, `containsSqlInjectionPayload`, `escapeHtml`, `generateCsrfToken`, `isOriginAllowed`, `validateHttpsUrl` | 78-170 | 0 |
| `secureStoragePayload`, `decryptStoragePayload` | ~173-188 | 0 |
| `checkRecordOwnership`, `setCurrentProfile` | 217, 47 | 0 (`_currentProfileId = 'default-profile-uuid'` sabit) |
| `verifyNoHardcodedSecrets`, `validateExcelFile`, `safeExecute`, `getRecommendedSecurityHeaders`, `getAuditLogs` | 235, 280, ~295, 316, ~350 | 0 |
| `isDatabaseEncrypted` | 355-358 | 0 — **her zaman `true`** döner, SQLCipher yok |
| `createEncryptedBackupPackage`, `decryptBackupPackage` | 367-378 | 0 |
| `runSelfSecurityDiagnostics` | 382-411 | 0 — 20 maddenin hepsini sabit "OK" döner |
| `logAudit` | ~330-347 | yalnız sınıf içi; bellekte 200 kayıt, hiç okunmuyor |
| Kullanılanlar | `scanPdfForMalware`, `validatePdfFile`, `checkRateLimit`, `isValidAmountCents`, `sanitizeTextInput` | 1'er (`statement_upload_sheet.dart:177,182`; `quick_entry_sheet.dart:82,92,100`) |

- Etki: Bakım yükü + yanlış güvenlik algısı (bir denetçi/ajan `isDatabaseEncrypted()==true` veya "ALL_SECURITY_CONTROLS_VERIFIED" çıktısına güvenebilir).
- Dar düzeltme: Kullanılan 5 metodu bırak, kalanını sil (özellikle `isDatabaseEncrypted`, `runSelfSecurityDiagnostics`). `validatePdfFile` zaten taramayı içerdiği için `:177`'deki ayrı `scanPdfForMalware` çağrısı tekrar (bkz. PERF-06).

### ARCH-06 — P2 — Global hata yakalayıcı ve çökme raporlama yok
- Kanıt: `lib/main.dart:27-63` — `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded` yok (grep boş). Analitik/çökme SDK'sı yok (pubspec.lock). `--split-debug-info` sembolleri yalnız CI artifact'ı (90 gün).
- Etki: Sahada çökme/istisna görünürlüğü yalnız Play Console Android Vitals'a bağlı; Dart istisnaları (özellikle `unawaited` başlatma işleri, `main.dart:52-63`) sessizce kaybolur. PIN kilidi siyah ekran olayı (hafıza notu) bunun pratik sonucuna örnek.
- Dar düzeltme: Gizlilik ilkesine uygun, PII içermeyen yerel bir hata halkası (`FlutterError.onError` + `PlatformDispatcher.onError` → dosyaya son N hata, Ayarlar > "Hata raporunu paylaş"). Üçüncü taraf SDK şart değil.

### ARCH-07 — P2 — Ham istisna metni kullanıcıya gösteriliyor
- Kanıt: `analysis_screen.dart:124` (`'Masraflar yüklenemedi: $e'`), `:652`, `payslip_view.dart:106`, `transaction_detail_sheet.dart:86,150`, `quick_entry_sheet.dart:119`, `statement_upload_sheet.dart:160-161,609` (`'Veritabanına kaydedilirken hata: $e'`).
- Etki: `DatabaseException(...)` gibi İngilizce/teknik metinler ve olası SQL parçaları ekranda; güven hissini zedeler.
- Dar düzeltme: Kullanıcıya sabit metin + `debugPrint(e)`; ARCH-06'daki yerel hata halkasına yaz.

### ARCH-08 — P3 — Sessiz `catch`
- Kanıt: `lib/` içinde 122 `catch`, 43'ü `catch (_)`, 12'si tamamen boş gövde: `live_market_service.dart:96`, `market_news_service.dart:240`, `notification_service.dart:27,160`, `push_service.dart:25,104,252,256`, `dashboard_screen.dart:107`, `user_profile_service.dart:~739` vb.
- Dar düzeltme: Boş gövdelere en azından `debugPrint` ekle; davranış değişmez.

### ARCH-09 — P3 — Modülerlik: dev dosyalar ve tekil servisler
- Kanıt: `assets_screen.dart` 2401, `statement_upload_sheet.dart` 1296 (UI + kota + kayıt + toplu iş orkestrasyonu aynı `State` içinde, `:174-330`), `dashboard_screen.dart` 1227, `transaction_repository.dart` 1003, `user_profile_service.dart` 813 satır. Tüm servisler `static final instance` tekilleri; bağımlılık enjeksiyonu yalnız `forTesting` fabrikalarıyla (`backup_service.dart:47-57`).
- Değerlendirme: `core/parser` katmanı iyi ayrılmış (saf, test edilebilir; `statement_orchestrator.dart` UI'dan bağımsız). Sorun UI dosyalarında iş mantığı birikmesi.
- Dar düzeltme (yeniden yazım değil): `statement_upload_sheet.dart`'taki `_prepareDocument`/`_consumeAndSave`/`_processBatch` mantığını aynı klasördeki `services/` altına (zaten `batch_upload_tally.dart` var) taşı; davranış testleri `batch_upload_tally_test.dart` yanında yazılabilir.

### ARCH-10 — P3 — `DataChanges` yayını birleştirilmiyor
- Kanıt: 7 dinleyici (`backup_service.dart:79`, `analysis_screen.dart:49`, `payslip_view.dart:78`, `assets_screen.dart:79`, `cashflow_screen.dart:39`, `dashboard_screen.dart:124`, `goals_screen.dart:37`); 16 `notify()` çağrısı. Toplu yüklemede her belge kaydı ayrı bildirim → her belge için 6 ekran yeniden sorgu (`IndexedStack` içinde hepsi canlı).
- Dar düzeltme: `DataChanges.notify`'ı mikro-görev/kısa süreli birleştirme ile (`scheduleMicrotask` veya 100-200 ms) tek yayına indir.

### ARCH-11 — P2 — Yerelleştirme (tr/en) kısmi; biçimlendirme dilden bağımsız
- Kanıt: `AppStrings` tr/en sabit sözlük + CMS geçersiz kılma (`app_strings.dart:5-60`). `lib/features` + `lib/core/widgets` içinde **179** `Text('…')` sabit literal vs **130** `AppStrings.` referansı; 23 sunum dosyasından yalnız **7**'si `AppStrings` kullanıyor (grep). Para `CurrencyNormalizer.formatCents` her dilde `₺1.250,50` (`currency_normalizer.dart:52-66`); tarih yardımcıları elle Türkçe ay adlarıyla (`transaction_repository.dart:~640 'OCA','ŞUB'…`).
- Etki: İngilizce seçen kullanıcı karışık dil görür (tasarım ajanının "İngilizce-Türkçe karışık metin" işaretine denk).
- Dar düzeltme: Ya EN'i "beta" diye işaretle ya ekran ekran literal → anahtar taşı; `localization_en_screens_test.dart` kapsamını genişlet. Ay adlarını `AppStrings`'e al.

### ARCH-12 — P3 — Tarih biçimlendirme kopyaları
- Kanıt: ayrı özel yardımcılar: `assets_screen.dart:1132`, `credit_card_action_sheet.dart:95`, `market_news_section.dart:70`, `cashflow_screen.dart:87`, `dashboard_screen.dart:60`, `family_screen.dart:139`, `fee_period.dart:79`, `add_goal_sheet.dart:61`, `goal_detail_sheet.dart:43`, `uploaded_statements_screen.dart:26,29`. Para biçimlendirme ise merkezi (`CurrencyNormalizer.formatCents`) — iyi.
- Para tamsayı kuruş: DOĞRULANDI (şema `billing_amount_cents INTEGER`, `v1_create_schema.sql:47`; ücret hesabı `.round()` ile, `fee_report_service.dart:148`). `/100.0` double dönüşümleri yalnız gösterim/animasyon (`dashboard_screen.dart:750,795,843`, `payslip_view.dart:360,451`). İstisna: `profile_screen.dart:38` bütçeyi `.toInt()` ile TL'ye keser (kuruş düşer) — P4.
- Dar düzeltme: `lib/core/utils/date_format.dart` tek yardımcı.

### ARCH-13 — P3 — Erişilebilirlik
- Kanıt: `Semantics(` / `semanticLabel` / `tooltip:` toplam 18 kullanım (grep, tüm `lib/`). Metin ölçekleme bazı bileşenlerde dikkate alınmış (`sliding_overlay_card.dart:138`, `morphing_segmented_bar.dart:51`, `payslip_view.dart:340-358`); `accessible_tour_card.dart` var.
- Ekran okuyucu (TalkBack) ile gerçek test: DOĞRULANMADI.
- Dar düzeltme: İkon-yalnız düğmelere `tooltip`, grafiklere (`fl_chart`) `Semantics(label: özet)`.

### ARCH-14 — P3 — Ortam ayrımı (dev/prod) yok
- Kanıt: `SupabaseConfig.url/publishableKey/googleWebClientId` `String.fromEnvironment` ile ezilebilir ama varsayılan **prod** (`supabase_config.dart:9-28`); `projectRef` sabit (`:19`, kullanılmıyor). Flavor yok (`build.gradle`). Tek Supabase projesi; `supabase/config.toml` yalnız yerel CLI için. Test hesabı prod'da (hafıza notu).
- Etki: Geliştirme/test sırasında prod veritabanına yazılır; göç denemesi prod'da yapılır.
- Dar düzeltme: Supabase branching veya ikinci ücretsiz proje + `--dart-define-from-file=env/dev.json`; CI yalnız prod değerleriyle derlesin.

### ARCH-15 — P3 — Bağımlılık güncelliği (`flutter pub outdated`, 2026-10-03)

| Paket | Mevcut | Çözülebilir/En son | Not |
|---|---|---|---|
| file_picker | 8.3.7 | 13.1.0 | 5 ana sürüm geride |
| fl_chart | 0.68.0 | 1.2.0 | 1.x API değişikliği |
| flutter_secure_storage | 10.3.4 | 11.2.0 | |
| google_fonts | 6.3.3 | 9.0.0 | |
| share_plus | 10.1.4 | 13.3.1 | |
| supabase_flutter | 2.17.2 | 2.18.0 | aynı ana sürüm, kilitte bekliyor |
| url_launcher | 6.3.2 | 6.3.3 | |
| flutter_lints (dev) | 4.0.0 | 6.0.0 | |
| in_app_purchase_android | 0.5.3 | (sabitlenmiş, `^` yok) | gerekçe pubspec'te yazılı değil |

Özet: "19 upgradable dependencies are locked… 11 dependencies are constrained to versions that are older than a resolvable version." Güvenlik açığı taraması (OSV) yapılmadı → DOĞRULANMADI.
- Dar düzeltme: Önce aynı ana sürüm içindekiler (`flutter pub upgrade`), sonra tek tek ana sürüm; `in_app_purchase_android` sabitlemesinin nedenini pubspec'e yorum olarak yaz.

### ARCH-16 — P2 — Supabase göç sürümleri uyumsuz
- Kanıt: sunucu `20260928181206_free_tier_type_quota`, `20260928222251_app_content_cms`; yerel `supabase/migrations/20260928120000_free_tier_type_quota.sql`, `20260929120000_app_content_cms.sql`. İlk 6 göç eşleşiyor.
- Etki: `supabase db push`/`migration repair` kullanıldığında yerel dosyalar "uygulanmamış" görünür → yeniden uygulama denemesi/çakışma.
- Dar düzeltme: Yerel dosyaları sunucudaki sürüm numaralarıyla yeniden adlandır (içerik aynıysa) veya `supabase migration repair` (yazma işlemi — kullanıcı onayı gerekir).

### ARCH-17 — P4 — pubspec ortam kısıtı yanıltıcı
- `pubspec.yaml:6-8` `sdk >=3.0.0`, `flutter >=3.10.0`; `pubspec.lock:1277-1279` gerçekte `dart >=3.13.0`, `flutter >=3.47.0`. Kısıtı gerçeğe çek.

### ARCH-18 — P3 — Kullanılmayan sunucu tabloları
- `key_envelopes` (0 satır) ve `document_uploads` (0 satır): `moneytrace/lib`, `supabase/functions`, `Web_Yonetici_Paneli` içinde referans yok (grep; yalnız `delete-account/index.ts:3` yorumu). Kaldırma yazma işlemidir → yalnız öneri.

### ARCH-19 — P4 — Çelişkili ajan yönergeleri
- `AGENTS.md` var olmayan `ci_cd_quality_gate.yml` kapısına, "Shakuro / Dynamic Island / radar nabız dalgaları" tasarım standardına ve "hiçbir veri buluta gönderilemez" ilkesine atıf yapıyor; gerçek mimaride şifreli bulut yedeği var, tasarım ajanı (`.claude/agents/finscout-tasarim.md`) bu süsleri "yapay zekâ görünümü" sayıyor.
- Dar düzeltme: AGENTS.md'yi `.claude/agents/` ile hizala.

### ARCH-20 — P3 — `admin-update-content` kimlik doğrulama
- Kanıt: `verify_jwt=false` (canlı liste), sır karşılaştırması `body.admin_secret !== adminSecret` (`supabase/functions/admin-update-content/index.ts:42`) — sabit zamanlı değil, deneme sayısı sınırı yok, CORS `*` (`:18`).
- Not: Güvenlik ayrıntısı 2-5/5 denetim parçalarından birinin kapsamı olabilir → çapraz referans. Dar düzeltme: sabit-zamanlı karşılaştırma + başarısız denemede gecikme; uzun vadede `is_admin()` ile JWT tabanlı doğrulamaya geç (send-push zaten öyle).

---

## Async / yarış koşulları — ek notlar
- `BackupService.backupNow` zinciri (`_chain`) eşzamanlı yüklemeleri sıralıyor (`backup_service.dart:136-142`) — DOĞRULANDI. Sorun sıralamada değil, ne yüklendiğinde (ARCH-03).
- `consume_upload`/`refund_upload` advisory lock — DOĞRULANDI (ARCH-04).
- `join_family` `FOR UPDATE` ile davet/ailede satır kilidi (`20260924064137_billing_quota_family.sql:296,302`) — DOĞRULANDI.
- Açılışta `reconcileOwnTransfers` tüm DB'yi tarayan tek SQLite işlemi; `unawaited` (`main.dart:55`) — kullanıcı aynı anda yükleme yaparsa sqflite tek bağlantıda işlemleri sıralar; kilitlenme gözlenmedi → DOĞRULANMADI.
- Abonelik: açılışta `restorePurchases()` `isPurchasingNotifier.value = true` yapıyor (`subscription_service.dart:282`) — açılışta 8 sn'ye kadar "satın alma sürüyor" durumu UI'da görünebilir → DOĞRULANMADI.

## Tip / null güvenliği
- Dart null-safety açık (SDK ≥3). `!` operatörü yoğun ama analizör temiz. Veritabanı satırları `Map<String, dynamic>` olarak UI'a kadar taşınıyor ve `as int`/`as String` ile dökülüyor (ör. `analysis_screen.dart:426` `(topCat['percentage'] as int)`), şema değişikliği derleme zamanında yakalanmaz. Öneri (P3): sık kullanılan sorgular için küçük tipli kayıt sınıfları; `analysis_options.yaml`'a `strict-casts: true`.

## Boş / hata durumları
- Ekranlarda `_isLoading` + try/catch deseni var (ör. `dashboard_screen.dart:134-215`); boş durumlar için ayrı görünümler var (`goals_locked_view.dart`, ekstre yoksa yükleme çağrısı). Kapsamlı UI denetimi tasarım parçasının kapsamı → KAPSAM DIŞI.
