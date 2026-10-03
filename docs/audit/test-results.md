# FinScout — Test Sonuçları (Denetim 3/5: Test altyapısı & QA)

- Tarih: **2026-10-03** (saatler +03:00) · Makine: Windows 11, yerel Flutter (`D:\dev\flutter`), JDK 17
- Çalışma dizini: `D:\FinScout\moneytrace` · Taban commit `b7aa9fb`; aynı dizinde paralel ajanlar çalışıyordu (ör. `test/audit_security_crypto_test.dart` başka ajana ait ve suite'e dahil oldu)
- Strateji ve boşluk analizi: [`test-strategy.md`](test-strategy.md)
- `lib/` altında hiçbir üretim kodu değiştirilmedi. Yalnız 5 yeni `test/audit_qa_*.dart` dosyası eklendi (ve yalnız bu 5 dosya `dart format` ile biçimlendirildi).

## 1. Komut sonuçları

| # | Komut | Zaman | Sonuç | Durum |
|---|---|---|---|---|
| 1 | `flutter analyze` | 04:10 (yeni testlerle), 04:2x yeniden | `No issues found!` (çıkış 0) | **DOĞRULANDI** |
| 2 | `dart format --output=none --set-exit-if-changed lib test` | 04:00 (denetim öncesi) | **137 dosyanın 109'u biçimsiz**, çıkış 1. (04:10'daki tekrar: 143/116 — paralel ajan dosyaları + biçimlenmemiş yeni dosyalarım dahil; kendi 5 dosyam sonra biçimlendi, `0 changed`) | **BAŞARISIZ** (mevcut kod tabanı; değişiklik yapılmadı) |
| 3a | `flutter test` (denetim öncesi taban) | 04:03–04:05 | **387 test: 386 geçti, 1 atlandı, 0 başarısız** (atlanan: korpus, `PDF_CORPUS_DIR` yok) | **DOĞRULANDI** |
| 3b | `flutter test` (yeni testlerle, tüm suite) | 04:10–04:12 | **440 test: 433 geçti, 7 atlandı, 0 başarısız** (atlananlar: korpus + denetimin 6 bulgu testi). Artışın 37'si `audit_qa_*`, kalanı paralel ajanın `audit_security_crypto_test`'i | **DOĞRULANDI** |
| 3c | `flutter test test/audit_qa_*.dart` (5 dosya, biçimlendirme sonrası) | 04:2x | 31 geçti, 6 atlandı | **DOĞRULANDI** |
| 3d | Aynı 5 dosya `--run-skipped` | 04:2x | 31 geçti, **6 başarısız** — tam olarak `skip:` ile işaretlenen 6 bulgu; hatalar gerçek ve yeniden üretilebilir | **BAŞARISIZ** (beklenen; bkz. §3) |
| 4 | `powershell -ExecutionPolicy Bypass -File test\verify_parsers.ps1` | 04:12 | **107 / 107 PASSED** | **DOĞRULANDI** |
| 5 | `$env:PDF_CORPUS_DIR="D:/FinScout/Örnek PDF"; flutter test test/pdf_corpus_probe_test.dart` | 04:12–04:13 | **22/22 belge OK** (Enpara vadesiz, YK kart, Garanti kart, bordro), toplam 429 işlem, kategorisiz 35 (%8,2); test geçti | **DOĞRULANDI** |
| 6 | `flutter pub outdated` | 04:13 | 19 paket kilitli eski sürümde yükseltilebilir; 11 paket kısıt yüzünden eski. Doğrudan bağımlılıklarda büyük sürüm geride: `file_picker` 8→13, `fl_chart` 0.68→1.2, `flutter_secure_storage` 10→11, `google_fonts` 6→9, `share_plus` 10→13, `flutter_lints` 4→6; küçük: `supabase_flutter` 2.17.2→2.18.0, `url_launcher` 6.3.2→6.3.3 | Bilgi (güvenlik açığı veritabanı taraması YOK → **DOĞRULANMADI**) |
| 7a | `flutter build apk --debug` (ilk deneme) | 04:13–04:17 | **BUILD FAILED**: `install_code_assets` → `PathExistsException` `build\app\intermediates\flutter\debug\native_assets\jniLibs\lib\armeabi-v7a\libpdfium.so` (errno 183, dosya zaten var) | Geçici (aynı `build/` dizininde eşzamanlı derleme/eski çıktı yarışı) |
| 7b | `flutter build apk --debug` (bir kez yeniden) | 04:17–04:19 | `√ Built build\app\outputs\flutter-apk\app-debug.apk` (çıkış 0). Uyarılar: AGP sürüm doğrulaması (`--android-skip-build-dependency-validation` önerisi; CI bu bayrağı kullanıyor), SDK XML v4 uyarısı | **DOĞRULANDI** |
| 8 | E2E (`integration_test`) | — | Paket kurulu değil, `integration_test/` dizini yok, cihaz/emülatör yok | **DOĞRULANMADI** |
| 9 | CI'da test/analyze | — | `.github/workflows/build.yml` yalnız derleyip Play'e yüklüyor; test/analyze adımı yok | **BAŞARISIZ** (kapı yok) → TEST-01 |
| 10 | Secret scanning / Dependabot | — | `.github/dependabot.yml` yok, CI'da gitleaks vb. yok; GitHub repo ayarları erişilemedi | **DOĞRULANMADI** |
| 11 | AI çıktı doğrulaması | — | Uygulamada AI/LLM çağrısı yok | **KAPSAM DIŞI** |

## 2. Eklenen testler (5 dosya, 37 test: 31 geçen + 6 bulgu `skip:`)

| Dosya | Test | Ne kanıtlıyor |
|---|---|---|
| `test/audit_qa_payment_reminder_test.dart` | 9 (8 geçti, 1 skip) | `NotificationService.syncUpcomingPayments` gerçek eklenti Dart kodu üzerinden (yalnız native MethodChannel sahte): vadeye ≥2 gün → **son ödemeden 2 gün önce 10:00**; vadeye 1 gün → vade günü 09:00; vade bugün → 09:00 geçmediyse kurulur, geçtiyse kurulmaz; geçmiş vade kurulmaz ve eklenti "geçmiş tarih" hatası fırlatmaz; **ay/yıl/artık yıl sınırı** (1 Mart → 27/28 Şubat, 1 Ocak → 30 Aralık, 31 Mayıs → 29 Mayıs); saat dilimi `Europe/Istanbul`, zaman ANLIK olarak `DateTime(y,m,d,10)` ile eşit (makinenin diliminden bağımsız); bildirim gövdesi biçimi + asgari ödeme; bozuk `due_date` diğerlerini bozmaz; tekrar senkron aynı kimlik (çift bildirim yok) |
| `test/audit_qa_goal_calculations_test.dart` | 11 (9 geçti, 2 skip) | Kalan tutar/ilerleme/kalan ay/aylık öneri sınır durumları (bu ay, geçmiş tarih, bugün, tamamlanmış); özet toplamlarının kaynak hedeflerden yeniden hesabı; duraklatılmış hedefin mevcut davranışı belgelendi; **GoalRepository (gerçek SQLite): biriken tutar = katkı geçmişi toplamı** değişmezi ekle/sil/başlangıç birikiminde korunuyor; hedef güncellemesi katkıları silmiyor; hedef silinince yetim katkı kalmıyor |
| `test/audit_qa_income_expense_totals_test.dart` | 6 (5 geçti, 1 skip) | Gerçekçi bir ay (YK kart + YK vadesiz + Enpara + bordro + nakit) gerçek şemaya yazılır; **gelir/gider repository'den bağımsız bir kahinle kaynak işlemlerden yeniden hesaplanır** ve `getMonthlySummary` ile kuruşu kuruşuna eşleşir (gider 2.646,42 TL, gelir 45.200,00 TL); kart borcu ödemesi, kendi transferi (OWNTRANSFER, hesaplar arası otomatik eşleşme) ve vadesizde de görünen bordro maaşı çift sayılmaz; iade giderden düşer; ay sınırları sızmaz; trend grafiği = aylık özet; kategori dağılımı brüt borç toplamıyla eşleşir, nötr kategoriler girmez |
| `test/audit_qa_duplicate_import_test.dart` | 5 (4 geçti, 1 skip) | **Çakışan dönemli iki vadesiz ekstre**: çakışan 3 işlem atlanır, 2 yeni eklenir, aynı gün meşru tekrarlar (metro geçişi ×3) korunur, boşluk/büyük-küçük harf farkı aynı işlem sayılır, ay toplamı şişmez; SHA-256 ile aynı dosya ve kesim tarihine göre aynı dönem (kart maskesi boşluklu/boşluksuz) tespit edilir, aynı bankanın başka kartı mükerrer sayılmaz; kesim tarihi yoksa dönem başı+sonu; aynı SHA ikinci kayıtta UNIQUE ile reddedilir ve transaction geri alınır (kısmi veri yok) |
| `test/audit_qa_money_rounding_test.dart` | 6 (5 geçti, 1 skip) | `formatCents` TR biçimi/işaret/sıfır; `toMinorUnits` ekstre ve elle giriş biçimleri; 0,01–9,99 arası tüm kuruşlar ve 0,29/1,13/4,35 gibi kayan nokta tuzakları kayıpsız; **formatCents → toMinorUnits tur-dönüşü ±10 milyar TL'ye kadar ~2000 örnekte kayıpsız**; `ThousandsInputFormatter` ile tuş tuş yazılan tutar doğru kuruşa çevrilir |

Kullanılan yeni desen: platform eklentisini (flutter_local_notifications) değiştirmeden test etmek için `AndroidFlutterLocalNotificationsPlugin.registerWith()` + `TestDefaultBinaryMessenger.setMockMethodCallHandler` ile `zonedSchedule` argümanlarının yakalanması. Diğer platform servisleri (Billing, Push, Google giriş) için aynı yaklaşım kullanılabilir.

## 3. Bulunan gerçek hatalar (üretim kodu düzeltilmedi; testler `skip:` ile işaretli, `--run-skipped` ile kırmızı)

| Kimlik | Önem | Yer | Hata | Kanıt |
|---|---|---|---|---|
| **QA-P2-01** | P2 | `lib/features/goals/services/goal_calculator_service.dart` `calculateSummary` | Kalan = max(Σhedef − Σbirikim, 0), ilerleme = Σbirikim/Σhedef. Bir hedefteki **fazla birikim başka hedefin açığını kapatıyor**: A (100 TL hedef, 200 TL birikim) + B (100 TL hedef, 0 birikim) → `GoalSummaryHeader` "**%100 Ulaşıldı**", kalan 0; B hiç fonlanmamış. Düzeltme: kalan = Σ`goal.remainingAmountCents`, ilerleme için birikim hedef başına `min(saved, target)` | Beklenen 10000, gerçek 0 |
| QA-P3-01 | P3 | `lib/core/services/notification_service.dart` `syncUpcomingPayments` | Bildirim kimliği `stableId('pay|due_date|description')`; `getUpcomingPayments` açıklamayı `institution_name || ' kart borcu'` ürettiği için **aynı bankanın iki kartı aynı son ödeme gününde aynı kimliği alır, ikinci bildirim birinciyi ezer** → kullanıcı tek hatırlatma görür. Kimliğe hesap/kart kimliği eklenmeli | İki çağrı da id 1933811256 |
| QA-P3-02 | P3 | `lib/features/goals/models/financial_goal.dart` `recommendedMonthlySavingsCents` | `.round()` kullanılıyor; öneriye uyan kullanıcı hedef tarihinde kuruşlar eksik kalabilir (100 TL / 3 ay → 33,33 × 3 = 99,99). Yukarı yuvarlama (`ceil`) beklenir | Beklenen ≥10000, gerçek 9999 |
| QA-P3-03 | P3 | `lib/core/database/repositories/transaction_repository.dart` `getCategorySpendingAnalysis` | `getMonthlySummary` ve `getMonthlyTrendsAnalysis` iadeyi giderden düşüyor, kategori analizi düşmüyor. **Tamamı iade edilen 899,90 TL giyim Analiz ekranında harcama olarak kalıyor**; kategori toplamı (3.546,32 TL) ay giderinden (2.646,42 TL) büyük | Beklenen 264642, gerçek 354632 |
| QA-P3-04 | P3 | `transaction_repository.dart` `saveStatementResult` | Tüm işlemler mükerrer çıksa da (inserted=0) yeni `statements` ve `scheduled_payments` satırları yazılıyor → `getUpcomingPayments` aynı kart borcunu ve talimatı **iki kez** listeliyor (hatırlatma/Yaklaşan ekranı çiftlenir). Bugün `statement_upload_sheet`'teki aynı-dönem kontrolü önlüyor; kesim tarihi bir ekstrede okunup diğerinde okunamazsa kontrol aşılır (savunma derinliği eksik) | CARD_DUE 2 satır |
| QA-P3-05 | P3 (düşük) | `lib/core/utils/currency_normalizer.dart` `toMinorUnits` | Doc yorumu "1,155.00" biçimini desteklediğini söylüyor; gerçekte **116 kuruş (1,16 TL) döndürüyor (1000 kat hata)**. TR ekstre regex'i ve `ThousandsInputFormatter` bu girdiyi üretmediğinden bugün etkisi düşük; USD ekstresi ya da biçimlendiricisiz alana yapıştırma ile gerçek hataya dönüşür | Beklenen 115500, gerçek 116 |

### Gözlemler (hata değil / açık karar / risk)

- **Açık ürün kararı:** Duraklatılmış (PAUSED) hedef özette "aktif" sayılıyor ve aylık birikim önerisine giriyor (test mevcut davranışı belgeliyor).
- **KABUL EDİLEN RİSK (doğrulanmadı):** `NotificationService.initialize` `FlutterTimezone` başarısız olursa `tz.local`'ı `Europe/Istanbul`'a sabitliyor; cihaz başka dilimdeyse hatırlatma duvar saati kayar (10:00 yerine farklı saat). Singleton tek kez başlatıldığı için aynı test sürecinde yeniden üretilemedi.
- **Risk:** `saveStatementResult` kimlikleri `stmt_<ms>` / `tx_<ms>_<i>` milisaniyeye bağlı; aynı milisaniyede iki kayıt PK çakışmasıyla başarısız olur. Testlerde gözlenmedi (DOĞRULANMADI), toplu yüklemede teorik.
- **Risk:** `syncUpcomingPayments` eski/silinen ödemelerin hatırlatmalarını iptal etmiyor (yalnız `cancelAll` veri silmede).
- Korpus: kategorisiz oranı %8,2 (35/429) — mutabakat tam, kategori kapsamı iyileştirilebilir.
- APK ilk derleme hatası paralel derleme yarışından kaynaklı geçici bir hata olarak değerlendirildi (yeniden denemede geçti); aynı `build/` dizininde iki ajanın eşzamanlı derlemesi tekrar edebilir.
