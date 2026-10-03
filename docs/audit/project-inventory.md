# FinScout — Proje Envanteri (Denetim 1/5)

Tarih: 2026-10-03 · Kapsam: salt-okunur inceleme, kaynak koda dokunulmadı · Commit: `b7aa9fb` (çalışma ağacı başlangıçta temiz)

Durum etiketleri: DOĞRULANDI / BAŞARISIZ / GİDERİLDİ / DOĞRULANMADI / KAPSAM DIŞI / KABUL EDİLEN RİSK

---

## 1. Dil, framework, sürümler

| Öğe | Değer | Kanıt |
|---|---|---|
| Uygulama paketi | `moneytrace`, sürüm `3.13.0+16` | `moneytrace/pubspec.yaml:4` |
| Android applicationId | `com.moneytrace.app` | `android/app/build.gradle:51` |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 | `android/app/build.gradle:52-53,33` |
| AGP / Kotlin / google-services | 8.11.1 / 2.3.20 / 4.4.3 | `android/settings.gradle:24-27` |
| R8 küçültme | `minifyEnabled true`, `shrinkResources true` | `android/app/build.gradle:72-73` |
| Yerel Flutter | 3.47.5 stable, Dart 3.13.4 (`flutter --version`) | DOĞRULANDI |
| pubspec ortam kısıtı | `sdk: '>=3.0.0 <4.0.0'`, `flutter: ">=3.10.0"` | `pubspec.yaml:6-8` — ama `pubspec.lock:1277-1279` fiilen `dart >=3.13.0`, `flutter >=3.47.0` istiyor (bkz. ARCH-17) |
| Lint | `flutter_lints` 4.0.0 (`include: package:flutter_lints/flutter.yaml`), ek kural yok | `analysis_options.yaml` |
| Kod hacmi | `lib/` altında 109 Dart dosyası, 30.570 satır (`wc -l`) | DOĞRULANDI |
| iOS klasörü | `moneytrace/ios` var; dağıtım yalnız Android | KAPSAM DIŞI |

### Doğrudan bağımlılıklar (çözülmüş sürüm — `pubspec.lock`)
sqflite 2.4.4 · pdfrx 2.6.5 · pdfrx_engine 0.6.1 · supabase_flutter 2.17.2 · in_app_purchase 3.3.1 · in_app_purchase_android **0.5.3 (sabitlenmiş, `^` yok — pubspec.yaml:42)** · firebase_core 4.15.0 · firebase_messaging 16.7.0 · flutter_local_notifications 22.3.1 · flutter_secure_storage 10.3.4 · google_sign_in 7.2.0 · fl_chart 0.68.0 · file_picker 8.3.7 · crypto 3.0.7 · google_fonts 6.3.3 · share_plus 10.1.4 · url_launcher 6.3.2 · path_provider · path · timezone · flutter_timezone.
Dev: flutter_test, flutter_lints 4.0.0, sqflite_common_ffi, path_provider_platform_interface.

`intl` paketi YOK — para/tarih biçimlendirme elle yazılmış (`lib/core/utils/currency_normalizer.dart:52`).

### Lisans notu
- Uygulama içi lisans ekranı var: `lib/features/settings/presentation/licenses_screen.dart`.
- PDFium (pdfrx üzerinden, BSD-3/Apache-2.0 karışık), Supabase istemcileri (MIT), Firebase (Apache-2.0) — hepsi ticari kullanıma uygun izinli lisanslar. Paket bazında tek tek lisans taraması yapılmadı → DOĞRULANMADI.
- Repo kökünde `iBank - Banking & E-Money Management App ... UI Kit (Community)` klasörü var (Figma topluluk kiti). Lisans koşulu incelenmedi → DOĞRULANMADI (tasarım ajanına devredilebilir).

---

## 2. Klasör yapısı ve katmanlar

```
D:\FinScout
├─ moneytrace/                 Flutter uygulaması
│  ├─ lib/core/
│  │  ├─ config/               supabase_config, remote_config_service, app_links
│  │  ├─ database/             app_database (sqflite, şema v6) + repositories/transaction_repository (1003 satır)
│  │  ├─ parser/               layout → parsers → enrichment → services (orchestrator, reconciler, bank_detector, pdf_extractor)
│  │  ├─ security/             aes_cipher (elle yazılmış AES/PBKDF2), pdf_malware_scanner, pii_redactor, security_guard
│  │  ├─ services/             account, backup, push, notification, user_profile (813 satır), security_auth, market vb.
│  │  ├─ localization/         app_strings (tr/en sabit sözlük) + app_content_service (CMS)
│  │  ├─ theme/, layout/, widgets/, utils/, models/
│  ├─ lib/features/<özellik>/{presentation,services,repositories,models,widgets}
│  │     analysis, assets_portfolio, cashflow_projection, dashboard, family, fees, goals, navigation,
│  │     notifications, onboarding, profile, quick_entry, settings, statement_upload, subscription, tax_analytics
│  ├─ assets/sql/              v1…v6 SQL göç dosyaları
│  ├─ assets/dictionaries/     merchant_sectors_tr.json
│  ├─ assets/config/           remote_config.json
│  └─ test/                    28 Dart test dosyası + verify_parsers.ps1
├─ supabase/                   config.toml, migrations/ (8), functions/ (5), templates/
├─ website/                    GitHub Pages statik site (tr + en/)
├─ Web_Yonetici_Paneli/        statik yönetim paneli (index.html, bildirim.html)
├─ tools/                      release.ps1, surum_derle.ps1, setup_hooks.ps1, ci_cd_quality_gate.yml (KULLANILMIYOR), build_merchant_dictionary.py …
├─ .github/workflows/          build.yml, pages.yml
└─ .claude/agents/             4 alt-ajan tanımı
```

Katman yönü: `features/*/presentation` → `core/services` + `core/database/repositories` → `sqflite` / Supabase. Durum yönetimi kütüphanesi yok; tekil (singleton) servisler + `ValueNotifier` (`DataChanges.revision`, `lib/core/services/data_changes.dart:9`) + `setState`.

En büyük dosyalar: `assets_screen.dart` 2401, `statement_upload_sheet.dart` 1296, `dashboard_screen.dart` 1227, `transaction_repository.dart` 1003 satır.

---

## 3. Backend (Supabase `oudxswtadqurmlnvcjyc`, eu-central-1, Postgres 17.6) — salt-okunur doğrulandı

Organizasyon planı: **free** (`get_organization` → `plan: free`) — DOĞRULANDI. Proje durumu `ACTIVE_HEALTHY`.

### Tablolar (`list_tables`, hepsinde RLS açık) — DOĞRULANDI
| Tablo | Satır | Not |
|---|---|---|
| profiles | 8 | |
| key_envelopes | 0 | istemcide referans yok; yalnız `delete-account/index.ts:3` yorumunda geçiyor |
| vault_blobs | 2 | şifreli tam yedek (184 kB toplam) |
| devices | 5 | FCM jetonları |
| admin_roles | 0 | |
| subscriptions | 0 | |
| document_uploads | 0 | istemcide/Edge Function'larda referans yok (grep boş); kota `upload_consumptions` üzerinden |
| families / family_members / family_invites | 0 | |
| admin_notifications | 0 | |
| upload_consumptions | 0 | kota defteri |
| app_content | 133 | CMS metinleri |

### RPC'ler (`public` şeması, `pg_proc`) — DOĞRULANDI
`consume_upload(p_doc_type, p_is_backfill)` (SECURITY DEFINER, `pg_advisory_xact_lock` içeriyor), `refund_upload(p_consumption_id)` (advisory lock var), `entitlement()`, `create_family_invite()`, `join_family(p_code)`, `leave_family()`, `my_family()`, `remove_family_member(p_user_id)`, `register_device(p_token,p_platform,p_app_version)`, `is_admin()`, `admin_user_id_by_email(p_email)` (authenticated'a grant yok), `handle_new_user()` (trigger), `touch_updated_at()` (trigger).

### Edge Function'lar (`list_edge_functions`) — DOĞRULANDI
| Slug | Sürüm | verify_jwt | Yerel kaynak |
|---|---|---|---|
| delete-account | 5 | true | `supabase/functions/delete-account/index.ts` (38 satır) |
| verify-purchase | 4 | true | 208 satır |
| send-push | 4 | true | 266 satır |
| backup-key | 3 | true | 62 satır |
| admin-update-content | 2 | **false** (paylaşılan `ADMIN_PANEL_SECRET` ile) | 81 satır |

### Göçler
Sunucu (`list_migrations`) 8 göç gösteriyor; son ikisinin sürüm numarası yerel dosya adlarıyla **eşleşmiyor**: sunucu `20260928181206_free_tier_type_quota`, `20260928222251_app_content_cms`; yerel `20260928120000_free_tier_type_quota.sql`, `20260929120000_app_content_cms.sql`. `supabase db push` ile ileride çift uygulama/çakışma riski (bkz. ARCH-16).

pg_cron: `cron.job` tablosu yok → zamanlanmış sunucu işi YOK (DOĞRULANDI).

---

## 4. Dosya yükleme / ayrıştırma hattı

1. `FilePicker.pickFiles(type: custom, ['pdf'], allowMultiple: true, withData: kIsWeb)` — `statement_upload_sheet.dart:101-106`
2. `File.readAsBytes()` — tüm dosya belleğe; boyut kontrolü okumadan SONRA — `:169`
3. `SecurityGuard.scanPdfForMalware` + `validatePdfFile` (15 MB üst sınır, `%PDF-` imzası, imza taraması **iki kez**) — `:177`, `:182`; `security_guard.dart:249-278`
4. `PdfExtractorService.extract` → pdfrx/PDFium; PDFium çağrıları pdfrx'in kendi `BackgroundWorker` isolate'inde (`pdfrx_engine-0.6.1/lib/src/native/pdfrx_pdfium.dart:56,102,684`), ama `StatementLayout.fromFragments` ve SHA-256 ana isolate'te — `pdf_extractor_service.dart:46,90`
5. SHA-256 ile mükerrer kontrol → `StatementOrchestrator.processDocument` (tespit → banka parser'ı → genel tablo okuyucu yedeği → zenginleştirme → PII maskeleme → `StatementReconciler`) — `statement_orchestrator.dart:40-150`, ana isolate
6. Ücretsiz plan banka kilidi, aynı dönem mükerrer kontrolü — `statement_upload_sheet.dart:205-219`
7. `consume_upload` RPC (sunucu kotası) → `saveStatementResult` (tek SQLite işlemi) → hata olursa `refund_upload` — `:224-247`
8. `DataChanges.notify()` → 6 ekran + BackupService dinleyicisi tetiklenir

Desteklenen kurumlar: Yapı Kredi (kart), Enpara (vadesiz), Garanti BBVA, genel bordro; İş/Akbank/Ziraat/Vakıf/Halk/QNB tespit edilirse reddedilir (`statement_orchestrator.dart:52-64`).

---

## 5. AI / LLM varlığı — DOĞRULANDI: YOK

`grep -rniE "openai|anthropic|gemini|generativeai|genai|llm|chatgpt|claude"` → `moneytrace/lib`, `pubspec.yaml`, `supabase/functions` içinde yalnız "instal**lm**ent" eşleşmeleri; hiçbir AI SDK'sı/çağrısı yok. Ayrıştırma tamamen deterministik kural/koordinat tabanlı. Repo kökündeki `ask_gemini.py`, `ai_dialogue.py`, `tools/ask_gemini_file.py` yalnız geliştirici araçları, uygulamaya girmez.

## 6. Push ve zamanlanmış görevler
- FCM: `firebase_messaging` + `push_service.dart` (arka plan işleyici ayrı isolate, dosya tabanlı gelen kutusu `:236`); `register_device` RPC; gönderim yalnız yönetici `send-push` Edge Function'ı (20'şerli paralel, en fazla 10.000 cihaz — `send-push/index.ts:205,227`).
- Yerel bildirim: `flutter_local_notifications` `zonedSchedule` (`notification_service.dart:90`) — kart son ödeme/talimat hatırlatıcıları; açılışta `syncPaymentReminders()` ile yeniden kurulur (`main.dart:68-76`). WorkManager/AlarmManager yok.
- Sunucu tarafı zamanlanmış iş: YOK (pg_cron yok, zamanlanmış GitHub Actions yok). F2-28 "haftalık sağlık ping'i" uygulanmamış (bkz. PERF-01).

## 7. Abonelik (Play Billing)
`in_app_purchase` + `in_app_purchase_android 0.5.3`; makbuz `verify-purchase` Edge Function'ında Google Play Developer API ile doğrulanır; hak `entitlement()` RPC'sinden gelir (`subscription_service.dart:40,323,426`). Açılışta her seferinde `restorePurchases()` → Play + (varsa) `verify-purchase` + `entitlement` (`:166-171`). SKU/fiyatlar: ajan tanımlarında aylık ₺79,99 / yıllık ₺599,99 / aile ₺899,99 (`.claude/agents/finscout-finans.md`).

## 8. Analitik / hata izleme / reklam
- Analitik SDK'sı: YOK (pubspec/lock'ta firebase_analytics, sentry, crashlytics, appsflyer, adjust yok) — DOĞRULANDI.
- Çökme raporlama: YOK. `main.dart`'ta `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded` yok (grep boş) — DOĞRULANDI. CI `--split-debug-info` sembollerini yalnız 90 gün artifact olarak saklıyor (`build.yml`), herhangi bir servise yüklenmiyor.
- Reklam SDK'sı: YOK; `AD_ID` izni manifestte `tools:node="remove"` ile açıkça kaldırılmış (`AndroidManifest.xml:12`) — DOĞRULANDI.
- Sunucu logları: Edge Function'larda `console.log/error` (ör. `delete-account/index.ts:36` kullanıcı id'sini loglar).

## 9. Android izinleri (`AndroidManifest.xml`)
INTERNET, READ_EXTERNAL_STORAGE (**maxSdkVersion yok**), WRITE_EXTERNAL_STORAGE (maxSdk 32), POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED. `allowBackup=false`, `usesCleartextTraffic=false`, deep link `com.moneytrace.app://login-callback`.

## 10. CI/CD
| İş akışı | Tetik | Yaptığı | Eksik |
|---|---|---|---|
| `.github/workflows/build.yml` | main'e push (website hariç), manuel | pub get → APK + AAB (obfuscate) → artifact → secret varsa Play **internal** kanalına yükleme | **`flutter analyze` / `flutter test` YOK** — test geçmeden Play'e yükleniyor (ARCH-02) |
| `.github/workflows/pages.yml` | `website/**` push | GitHub Pages'e statik yayın | — |
| `tools/ci_cd_quality_gate.yml` | — | `.github/workflows` dışında; GitHub çalıştırmaz | AGENTS.md'de "kalite kapısı" diye anılıyor ama ölü |
| `tools/setup_hooks.ps1` | elle kurulum | pre-push hook → `verify_parsers.ps1`; PowerShell yoksa `exit 0` | hook yerelde kurulu mu bilinmiyor → DOĞRULANMADI |

## 11. Test ve build komutları (tam liste)

```powershell
cd D:\FinScout\moneytrace
flutter pub get
flutter analyze                                   # bu denetimde: "No issues found! (ran in 13.2s)"
flutter pub outdated                              # bu denetimde çalıştırıldı, özet architecture-review.md ARCH-15
flutter test                                      # 28 test dosyası (bu denetimde ÇALIŞTIRILMADI: paralel ajanlar aynı build/.dart_tool'u kullanıyor)
$env:PDF_CORPUS_DIR="D:/FinScout/Örnek PDF"; flutter test test/pdf_corpus_probe_test.dart   # gerçek PDF korpusu (22 belge) — ÇALIŞTIRILMADI
powershell -File test/verify_parsers.ps1          # "107 kontrol" — Dart kodunu test ETMİYOR (ARCH-01)
flutter build apk --release --obfuscate --split-debug-info=build/symbols --android-skip-build-dependency-validation
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --android-skip-build-dependency-validation
# Yardımcı betikler: tools/release.ps1, tools/surum_derle.ps1, tools/sync_config.ps1, tools/backup_project.ps1
```
Yerel derleme ortamı (hafıza notu): JDK 17 `D:\dev\jdk-17`, NDK 28.2, yerelde keystore yok.

## 12. CLAUDE.md / ajan tanımları
- `D:\FinScout\CLAUDE.md`: Gemini danışman köprüsü (`python ask_gemini.py`).
- `.claude/agents/`: `finscout-arastirma`, `finscout-finans`, `finscout-pazarlama`, `finscout-tasarim` (hepsi "yeni özellik önermez, Türkçe, kaynaklı" kuralıyla).
- `AGENTS.md`: 4 kavramsal ajan (`flutter_engineer`, `qa_and_testing_agent`, …) — `.claude/agents` ile eşleşmiyor; var olmayan `ci_cd_quality_gate.yml`'e ve "Shakuro tasarım dili, Dynamic Island, radar nabız dalgaları" gibi tasarım ajanının açıkça "yapay zekâ görünümü" diye işaretlediği öğelere atıf yapıyor (çelişkili yönerge). Ayrıca "Sıfır-Bilgi: hiçbir veri buluta gönderilemez" diyor; oysa şifreli `vault_blobs` yedeği buluta gidiyor.
- `.claude/settings.json`: geçmiş tek seferlik komutlar için izin listesi (biri `git rm` + gradle düzenlemesi içeriyor) — temizlenebilir, P4.

## 13. Repo hijyeni
- `moneytrace/android/app/google-services.json` git'te izleniyor (Firebase istemci yapılandırması; Google'ın belgelerine göre gizli değil ama API anahtarı kısıtlaması doğrulanmalı → DOĞRULANMADI).
- `upload-keystore.jks` ve `Oturum bilgileri.txt` kökte duruyor ama `.gitignore:27,35` ile hariç — DOĞRULANDI (izlenmiyor).
- `SupabaseConfig` içinde publishable key + Google web client ID varsayılan değer olarak gömülü (`supabase_config.dart:9-28`) — tasarım gereği istemci anahtarı; KABUL EDİLEN RİSK.

## 14. Bilinen teknik borçlar (özet; ayrıntı architecture-review.md / performance-and-cost-review.md)
1. Kalite kapısı (`verify_parsers.ps1`) Dart kodunu değil PowerShell kopyası regex'leri test ediyor (ARCH-01).
2. CI test/analiz çalıştırmadan Play'e yüklüyor (ARCH-02).
3. Otomatik yedek boş veritabanını sunucudaki yedeğin üstüne yazabilir; bekleyen debounce zamanlayıcısı oturum değişiminde iptal edilmiyor (ARCH-03).
4. `SecurityGuard`'da çağrılmayan ve sabit "OK" dönen fonksiyonlar (ARCH-05).
5. Global hata yakalayıcı / çökme raporlama yok (ARCH-06).
6. Ayrıştırma + yedek şifreleme ana isolate'te (PERF-03, PERF-04).
7. Aylık filtreler `LIKE 'YYYY-MM%'` → indeks kullanılmıyor (PERF-05, EXPLAIN ile doğrulandı).
8. Supabase free plan uyku riski, F2-28 ping uygulanmamış (PERF-01).
9. Yerelleştirme kısmi: 179 sabit `Text('…')` literal vs 130 `AppStrings.` referansı (ARCH-11).
10. SQLCipher yok, `isDatabaseEncrypted()` her zaman `true` döner (`security_guard.dart:355-358`).
