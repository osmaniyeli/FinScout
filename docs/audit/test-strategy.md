# FinScout — Test Stratejisi ve Boşluk Analizi (Denetim 3/5: Test altyapısı & QA)

- Tarih: 2026-10-03 · Kapsam: `moneytrace/` (Flutter, Android) · Taban commit: `b7aa9fb` (çalışma ağacında paralel ajan değişiklikleri olabilir)
- Durum etiketleri: **DOĞRULANDI / BAŞARISIZ / GİDERİLDİ / DOĞRULANMADI / KAPSAM DIŞI / KABUL EDİLEN RİSK**
- Komut çıktıları ve sayılar: [`test-results.md`](test-results.md)

---

## 1. Mevcut test envanteri (denetim öncesi)

Denetim öncesi `flutter test`: **387 test (386 geçti, 1 atlandı — korpus testi `PDF_CORPUS_DIR` yokken atlanır), 0 başarısız.** 28 Dart test dosyası + 1 PowerShell kapısı. (Statik `test(`/`testWidgets(` sayımı 172'dir; fark, döngüyle üretilen testlerden gelir — ör. `adaptive_layout_test` ekran boyutu × ekran.)

| Dosya | Katman | Ne kapsıyor |
|---|---|---|
| `statement_pipeline_test.dart` | unit | Ekstre boru hattı (PDF'siz): YK kart okuyucu, bordro okuyucu, TransactionClassifier, MerchantSanitizer, StatementReconciler, TR tutar/tarih metni |
| `checking_vs_card_hint_fallback_test.dart` | unit | Tanınmayan vadesiz belge varsayılan "kart" ipucuyla yanlış okunmasın (BankDetector + Orchestrator) |
| `pdf_corpus_probe_test.dart` | korpus (yerel) | 22 gerçek belge uçtan uca ayrıştırma + bankanın dönem toplamıyla mutabakat (doğruluk kahini); PII maskeli çıktı |
| `category_dictionary_load_test.dart` | unit | Üye işyeri sözlüğünün isolate'te yüklenmesi = eşzamanlı yükleme |
| `own_transfer_reconciliation_test.dart` | repo (SQLite FFI) | Kendi hesaplar arası transfer çift sayımı (OWNTRANSFER eşleştirme) |
| `upcoming_payments_dedup_test.dart` | repo | Taksit planı tekilleştirme, CARD_DUE listelenmesi |
| `uploaded_statements_test.dart` | repo | Profil "Yüklediğim belgeler" sorgusu |
| `payslip_duplicate_rule_test.dart` | repo/unit | Bordro mükerrer kuralı (yalnız aynı dosya) |
| `payslip_analytics_test.dart` | unit | Bordro aylık seri, yıllık toplam, efektif oran, zam tespiti |
| `credit_card_payment_flow_test.dart` | widget+repo | "Borç ödemesini tamamla" kaydı gerçekten oluşuyor (FK hatası regresyonu) |
| `wallet_card_payments_test.dart` | unit | Cüzdan kart ödemesi çift sayım dağıtımı |
| `fee_report_test.dart` | unit | Masraf raporu sınıflandırma, BSMV dahil faiz ayrıştırma |
| `batch_upload_tally_test.dart` | unit | Toplu yükleme özeti: hiçbir belge sessizce kaybolmaz |
| `app_database_migration_test.dart` | unit | SQL asset bölme kuralı / göçler |
| `backup_service_test.dart` | unit | Şifreli yedek round-trip (AES), yedek tetikleme |
| `app_content_service_test.dart` | unit | CMS: önbellek → sabit sözlük fallback |
| `free_tier_quota_test.dart` | unit | `checkUploadQuota` istemci ön kontrolü |
| `free_tier_bank_lock_test.dart` | unit | `checkFreeTierBankLock` tek banka kilidi |
| `bank_selection_sheet_test.dart` | widget | Banka seçici: aktif/pasif bankalar |
| `subscription_plan_comparison_test.dart` | widget | Plan karşılaştırma rakamları = kota kodu; kupon → Play |
| `upload_consent_flag_test.dart` | unit | İlk yükleme onayı bayrağının kalıcılığı |
| `onboarding_tour_test.dart` | widget | Tanıtım turu, Atla, erişilebilir mod |
| `localization_en_screens_test.dart` | widget | Ayarlar/gezinme/giriş/yükleme ekranları İngilizce |
| `theme_mode_test.dart` | widget+unit | Koyu tema kalıcılığı ve render |
| `adaptive_layout_test.dart` | widget | Ekran boyutu/büyük yazı taşma testleri (tüm ana ekranlar) |
| `pin_system_keyboard_test.dart` | widget | PIN ekranları sistem klavyesi |
| `market_calculator_test.dart` | widget | Piyasa hesaplayıcısı gerçek kur ile |
| `fade_through_indexed_stack_test.dart` | widget | Sekme geçiş bileşeni |
| `test/verify_parsers.ps1` | statik kapı | 94 `Assert-Test` çağrısı (bazıları döngüde; çıktı 107 kontrol): kaynak kodda desen/regex kontrolleri — **Dart testi çalıştırmaz** |

## 2. Boşluk analizi (öncelik listesine göre)

| Alan | Denetim öncesi | Denetim sonrası | Not |
|---|---|---|---|
| Ekstre ayrıştırma | İyi (pipeline + korpus + kapı) | aynı | Korpus yalnız yerelde; CI'da yok |
| Normalizasyon (tutar/metin) | Kısmi (TR hücre regex'i) | **Kapatıldı** — `audit_qa_money_rounding_test` | `CurrencyNormalizer` doğrudan test edilmiyordu |
| Kategori kuralları | Kısmi (sözlük yükleme, classifier) | aynı | `learnCategory` / kullanıcı kuralı / `updateTransactionCategory` **test yok** → TEST-06 |
| Gelir/gider hesapları | Kısmi (own-transfer) | **Kapatıldı** — `audit_qa_income_expense_totals_test` | Kaynak işlemlerden bağımsız yeniden hesap |
| Taksit/borç | İyi (dedup, kart ödemesi, cüzdan) | aynı | |
| Tarih / son ödeme | Yok (bildirim) | **Kapatıldı** — `audit_qa_payment_reminder_test` | 2 gün önce 10:00, ay/yıl/artık yıl sınırı, geçmiş tarih |
| Para / yuvarlama | Yok | **Kapatıldı** — `audit_qa_money_rounding_test`, hedef yuvarlaması | |
| Mükerrer tespiti | Kısmi (bordro) | **Kapatıldı** — `audit_qa_duplicate_import_test` | Çakışan dönemler, SHA, aynı dönem |
| Bütçe / hedef | Yok (yalnız render) | **Kapatıldı** — `audit_qa_goal_calculations_test` | Uygulamada ayrı "bütçe" modülü yok; hedefler var |
| Bildirim zamanlaması | Yok | **Kapatıldı** | `syncPaymentReminders` (main.dart) ince sarmalayıcı, doğrudan test edilmedi |
| Kota (`checkUploadQuota`) | Var | aynı | Sunucu tarafı atomik düşüm (Supabase RPC) test edilmiyor → TEST-08 |
| Banka kilidi | Var (istemci) | aynı | Sunucu tarafı kilit yok (bkz. handoff notu) |
| Yedekleme | Var (round-trip) | aynı | `restoreVaultBackup` / `clearAllUserData` **test yok** → TEST-07 |
| CMS fallback | Var | aynı | |
| Onboarding turu | Var | aynı | |
| Vergi özeti (`getVatAndTaxSummary`) | Yok | aynı | TEST-09 |
| Hesap/oturum (`AccountService`, Google giriş), `PushService`, Billing | Yok | aynı | Platform eklentisi ağır; sahte katman gerekir |
| AI çıktı doğrulaması | — | **KAPSAM DIŞI** | Uygulamada AI/LLM çağrısı yok (`lib/` taraması: yalnız `merchant_sanitizer`'da "OPENAI/ANTHROPIC" abonelik üye işyeri adları) |

## 3. Test katmanları

| Katman | Araç | Durum |
|---|---|---|
| Unit (saf Dart) | `flutter_test` | Var, yaygın |
| Repository (gerçek şema) | `sqflite_common_ffi` + sahte `PathProviderPlatform` | Var; denetimde 4 dosya daha eklendi |
| Platform kanalı sahteleme | `TestDefaultBinaryMessenger.setMockMethodCallHandler` | **Yeni desen** (`audit_qa_payment_reminder_test`): eklentinin gerçek Dart kodu çalışır, yalnız native kanal sahte |
| Widget | `testWidgets` | Var (ekran düzeyi, taşma, i18n, tema, tur) |
| Integration / E2E | `integration_test` | **YOK** — paket `pubspec.yaml`'da yok, `integration_test/` dizini yok, cihaz/emülatör yok → **DOĞRULANMADI** |
| Korpus (gerçek PDF) | `pdf_corpus_probe_test` + `PDF_CORPUS_DIR` | Yalnız yerel (kişisel PDF'ler repoda yok) |
| Statik kapı | `verify_parsers.ps1` (pre-push hook) | Var; Dart testleri/analyze çalıştırmaz |

### E2E: kullanıcı akışları ↔ mevcut widget-seviyesi karşılıklar

Gerçek E2E **DOĞRULANMADI** (paket ve cihaz yok). Aşağıdaki eşleştirme, brief'teki 10 akışa en yakın okunuşla yapılmıştır; "kısmi" = akışın bir adımı widget/repo düzeyinde test ediliyor, uçtan uca zincir değil.

| # | Akış | Widget/repo karşılığı | Kapsam |
|---|---|---|---|
| 1 | Kayıt / giriş (e-posta kodu, Google) | `localization_en_screens_test` (giriş ekranı metinleri), `adaptive_layout_test` (onboarding render) | Kısmi — kimlik doğrulama yok |
| 2 | İlk açılış: banka seçimi + tanıtım turu | `bank_selection_sheet_test`, `onboarding_tour_test` | İyi |
| 3 | Ekstre yükleme (onay → PDF → ayrıştırma → kayıt) | `upload_consent_flag_test`, `checking_vs_card_hint_fallback_test`, `statement_pipeline_test`, korpus, `batch_upload_tally_test`, `audit_qa_duplicate_import_test` | Kısmi — FilePicker/PDFium zinciri ekran üzerinden yok |
| 4 | Ücretsiz plan sınırları (kota, banka kilidi) | `free_tier_quota_test`, `free_tier_bank_lock_test` | İstemci iyi; sunucu yok |
| 5 | Panoda gelir/gider/kategori | `audit_qa_income_expense_totals_test`, `adaptive_layout_test` (dashboard render) | Sayı doğruluğu repo düzeyinde iyi; ekrana bağlama yok |
| 6 | Yaklaşan ödemeler + hatırlatma | `upcoming_payments_dedup_test`, `audit_qa_payment_reminder_test`, `credit_card_payment_flow_test` | İyi |
| 7 | Hedef oluştur / katkı ekle | `audit_qa_goal_calculations_test` (repo+hesap), `adaptive_layout_test` (render) | Kısmi — diyalog akışı yok |
| 8 | Abonelik / plan karşılaştırma / kupon | `subscription_plan_comparison_test` | Kısmi — Play Billing yok |
| 9 | Ayarlar: dil, tema, PIN | `localization_en_screens_test`, `theme_mode_test`, `pin_system_keyboard_test` | İyi (PIN kilidi zorlaması kapalı: `_kPinLockEnforced=false`) |
| 10 | Yedekleme / geri yükleme / veri silme | `backup_service_test` | Kısmi — geri yükleme ve silme yok |

## 4. Otomatik kalite kontrolleri envanteri

| Kontrol | Nerede | Durum |
|---|---|---|
| Lint | `analysis_options.yaml`: yalnız `package:flutter_lints/flutter.yaml` (ek kural yok) | Yerelde `flutter analyze` temiz; **CI'da çalışmıyor** |
| Type-check | `flutter analyze` | Yerelde temiz; **CI'da yok** |
| Format | `dart format` | **BAŞARISIZ** — 137 dosyanın 109'u biçimsiz (kod tabanı hiç `dart format`'tan geçmemiş; satır genişliği tutarsız). CI'da yok |
| Birim/widget testleri | `flutter test` | Yerelde geçiyor; **CI'da ve pre-push hook'ta çalışmıyor** |
| Statik ayrıştırıcı kapısı | `verify_parsers.ps1` | Yalnız yerel pre-push hook (atlanabilir: PowerShell yoksa `exit 0`) |
| Bağımlılık güvenliği | — | **YOK**: `.github/dependabot.yml` yok; Dart için yerleşik `audit` yok; `flutter pub outdated` elle |
| Secret scanning | — | **CI'da YOK** (gitleaks/trufflehog adımı yok). GitHub'ın yerleşik secret scanning/push protection ayarı repo ayarından doğrulanamadı → DOĞRULANMADI |
| CI iş akışları | `build.yml`: checkout → Java 17 → Flutter stable → `pub get` → sürüm → imza → **release APK + AAB → Play internal**; `pages.yml`: website deploy | **Hiçbir test/analyze kapısı yok** — kırık kod doğrudan Play dahili kanalına gidebilir |
| SAST/CodeQL | — | Yok (Dart için CodeQL desteği yok; Semgrep alternatif) |

## 5. Öneriler (öncelikli)

| Kimlik | Öncelik | Öneri |
|---|---|---|
| TEST-01 | **P1** | `build.yml`'a derlemeden ÖNCE kalite kapısı ekle: `flutter analyze` + `flutter test` (başarısızsa APK/AAB ve Play yüklemesi çalışmasın). Ayrı bir `pull_request`/`push` iş akışı da olabilir. Bugün main'e her push doğrudan Play dahili kanalına gidiyor ve testsiz. |
| TEST-02 | P1 | Pre-push hook'a `flutter test` ekle (veya `verify_parsers.ps1` içinden çağır); "PowerShell yoksa `exit 0`" geçişini uyarıya çevir. |
| TEST-03 | P2 | Denetimde bulunan hataları düzelt ve `skip:`'leri kaldır: QA-P2-01 (hedef özeti), QA-P3-01..05 (bkz. test-results.md). Her düzeltmede ilgili test yeşile dönmeli. |
| TEST-04 | P2 | Secret scanning: CI'a `gitleaks/gitleaks-action` (ya da GitHub push protection'ı aç). Repo geçmişinde `.env`, keystore, `key.properties` taraması. |
| TEST-05 | P2 | `.github/dependabot.yml`: `pub` (moneytrace/) + `github-actions` ekosistemleri, haftalık. Aylık `flutter pub outdated` raporu. |
| TEST-06 | P2 | Kategori öğrenme testleri: `learnCategory` → sonraki içe aktarımda kullanıcı kuralı önceliği; `updateTransactionCategory`. |
| TEST-07 | P2 | `restoreVaultBackup` tur-dönüşü (dışa aktar → temizle → geri yükle → tüm tablolar ve toplamlar aynı) ve `clearAllUserData` (bildirimler dahil her şey silinir). |
| TEST-08 | P2 | Supabase kota RPC'si için sunucu tarafı test (yerel `supabase start` + SQL testleri / pgTAP): eşzamanlı iki yüklemede kota bir kez düşmeli. |
| TEST-09 | P3 | `getVatAndTaxSummary` ve `TaxAnalysisService` toplamlarını kaynak `tax_deductions`'tan yeniden hesaplayan test. |
| TEST-10 | P3 | `integration_test` paketi + 3 duman akışı (açılış → banka seç → örnek PDF yükle → panoda toplam); Firebase Test Lab ya da yerel emülatörde haftalık. |
| TEST-11 | P3 | `dart format` tek seferlik toplu biçimleme commit'i (paralel işler bitince) + CI'da `--set-exit-if-changed`. Şimdi zorunlu kılınırsa her PR gürültülü olur. |
| TEST-12 | P3 | Lint sıkılaştırma: `flutter_lints` üstüne `prefer_const_constructors` dışı anlamlı kurallar (`avoid_dynamic_calls`, `unawaited_futures`, `always_declare_return_types`); yeni uyarıları kademeli kapat. |
| TEST-13 | P3 | Korpus testini CI'a taşımanın güvenli yolu: PII'si temizlenmiş sentetik/anonim PDF alt kümesi ya da korpusun yalnız yerel "release öncesi zorunlu" adımı olarak kontrol listesine yazılması. |
