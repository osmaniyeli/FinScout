# Paraİz — Görev Dağılımı (Claude ↔ Gemini)

Bu dosya iki ajanın aynı repoda çakışmadan çalışması için tek doğruluk kaynağıdır.
Her ajan yalnızca **kendi sahip olduğu dosyalara** yazar. Başka bir dosyaya dokunman gerekiyorsa
dokunma; aşağıdaki "Notlar / Talepler" bölümüne yaz.

Genel kurallar (`AGENTS.md` ile aynı):
- Sıfır-bilgi: Hiçbir kullanıcı verisi cihaz dışına çıkmaz. Sunucu, bulut DB, analitik SDK **eklenmez**.
- `pubspec.yaml`, `android/`, `ios/` dosyalarına **yalnızca Claude** dokunur. Paket gerekiyorsa talep et.
- Bitirdiğin her görevden sonra `cd moneytrace; flutter analyze` çalıştır; yeni **error** bırakma.
- Commit atma; kullanıcı inceleyip commit edecek.
- `dart format` / `dart fix --apply` komutlarını **repo geneline çalıştırma**; yalnızca kendi dosyalarına ver
  (ör. `dart format lib/features/quick_entry`). Aksi halde diğer ajanın üzerinde çalıştığı dosyalar ezilir.
- Görev bitince aşağıdaki tabloda durumu `✅` yap ve 1-2 cümle not düş.

Gerekli paketler **zaten kurulu**: `local_auth`, `flutter_secure_storage`, `speech_to_text`,
`flutter_local_notifications`, `timezone`, `flutter_timezone`, `file_picker`, `url_launcher`, `in_app_purchase`.
Android izinleri (RECORD_AUDIO, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED) ve bildirim receiver'ları
manifest'e **eklendi**.

---

## Dosya sahipliği

| Alan | Sahip |
|---|---|
| `lib/core/parser/**`, `lib/core/database/**`, `assets/sql/**` | Claude |
| `lib/features/statement_upload/**` | Claude |
| `lib/core/services/security_auth_service.dart`, `lib/main.dart` | Claude |
| `pubspec.yaml`, `android/**`, `ios/**`, `test/pdf_*` | Claude |
| `assets/dictionaries/merchant_sectors_tr.json` (+ testi) | **Gemini** |
| `lib/features/quick_entry/**`, `lib/core/services/voice_expense_parser_service.dart` | **Gemini** |
| `lib/core/services/notification_service.dart` (yeni), `lib/features/subscriptions_bills/**`, `lib/features/notifications/**`, `lib/core/widgets/in_app_notification_sheet.dart` | **Gemini** |
| `lib/features/subscription/**` | **Gemini** |
| `lib/features/family_budget/**`, `lib/features/newsletter/**` | **Gemini** |
| `lib/features/settings/presentation/settings_screen.dart` → yalnızca `_restoreFromJsonBackup` fonksiyonu | **Gemini** |

---

## Gemini görevleri

### G1 — Türkiye üye işyeri → sektör sözlüğü (EN ÖNCELİKLİ)
PDF'ten okunan işlem açıklamalarını kategoriye eşlemek için veri dosyası.
Dosya: `moneytrace/assets/dictionaries/merchant_sectors_tr.json`

Format (tam olarak bu şema):
```json
{
  "version": 1,
  "entries": [
    { "pattern": "MIGROS", "brand": "Migros", "sector": "Süpermarket", "category": "cat_market" },
    { "pattern": "MICROSOFT*XBOX", "brand": "Xbox", "sector": "Dijital Oyun", "category": "cat_subscriptions" }
  ]
}
```
- `pattern`: BÜYÜK HARF, Türkçe karakterli ve karaktersiz iki varyant ayrı giriş olarak (ör. `MİGROS`, `MIGROS`).
  Banka ekstresinde göründüğü gibi yaz (ör. `TRENDYOL`, `HEPSIBURADA`, `A101`, `BIM`, `SHELL`, `ALLIANZ`, `TURKCELL`, `IYZICO` gibi aracıları **yazma**).
- `category` yalnızca şu kimliklerden biri olabilir:
  `cat_market, cat_fuel, cat_transit, cat_dining, cat_subscriptions, cat_utilities, cat_tax, cat_home, cat_pet,
  cat_kids, cat_investment, cat_clothing, cat_health, cat_salary, cat_general, cat_insurance, cat_shopping,
  cat_education, cat_travel, cat_transfer, cat_card_payment, cat_fees, cat_cash, cat_electronics, cat_personal_care`
- Hedef: **en az 600 giriş**, Türkiye'de yaygın zincirler: market, akaryakıt, e-ticaret, giyim, elektronik,
  restoran/kafe zincirleri, yemek siparişi, ulaşım (HGS/OGS, İstanbulkart, Kentkart, THY, Pegasus, AJet, BiTaksi, Martı),
  telekom/fatura (Turkcell, Vodafone, Türk Telekom, İGDAŞ, Enerjisa, CK Enerji, İSKİ, ASKİ ...), sigorta/BES
  (Allianz, Anadolu Sigorta, Axa, Mapfre, Anadolu Hayat ...), eğitim, sağlık (eczane, hastane zincirleri), kuyum/yatırım,
  dijital abonelikler (Netflix, Spotify, YouTube, Google One, Apple, Microsoft, Xbox, PlayStation, Exxen, BluTV/Max,
  Disney+, Amazon Prime, ChatGPT/OpenAI, Claude/Anthropic ...), kişisel bakım (Gratis, Watsons, Rossmann), ev/yapı market.
- Kısa ve belirsiz kalıplardan kaçın (`PET`, `ISU`, `GAIN`, `TOTAL` tek başına yanlış eşleşir → `TOTAL ENERGIES`, `GAIN MEDYA` gibi yaz).
- Aynı `pattern` iki kez olmasın.
- Test: `moneytrace/test/merchant_dictionary_test.dart` → JSON geçerli, kategoriler izinli listede, tekrar yok, ≥600 giriş.

### G2 — Gerçek sesli harcama girişi
Şu an sesli giriş yalnızca sabit örnek cümle çipleri gösteriyor, mikrofon hiç açılmıyor.
- `speech_to_text` ile `tr_TR` dinleme: `quick_entry_sheet.dart` içindeki sesli giriş diyaloğunu gerçek mikrofona bağla.
  Canlı transkript göster, bitince mevcut `VoiceExpenseParserService.parseTurkishVoiceInput(...)` ile formu doldur.
- İzin reddedilir veya cihaz desteklemezse anlaşılır bir mesaj göster. Sabit çipler "örnek" olarak kalabilir.
- `VoiceExpenseParserService`'i sözlü sayılar ("üç bin beş yüz", "iki buçuk") için güçlendir + birim testi yaz.

### G3 — Yerel bildirimler (fatura/abonelik hatırlatıcı)
- Yeni `lib/core/services/notification_service.dart` (singleton). **Bu API'yi aynen sağla**, Claude kredi kartı son ödeme hatırlatıcılarını buradan çağıracak:
  ```dart
  class NotificationService {
    static final NotificationService instance;
    Future<void> initialize();                       // tz + kanal kurulumu
    Future<bool> requestPermission();                // Android 13+ POST_NOTIFICATIONS
    Future<void> scheduleOneShot({required int id, required String title, required String body, required DateTime when});
    Future<void> cancel(int id);
  }
  ```
  `flutter_local_notifications` + `timezone` + `flutter_timezone`; `AndroidScheduleMode.inexactAllowWhileIdle`
  kullan (tam zamanlı alarm izni istemiyoruz).
- `subscriptions_bills` modülünde her faturanın ödeme gününden 2 gün önce 10:00'a hatırlatıcı kur, silinince iptal et.
- `initialize()` çağrısını `main.dart`'a eklemeyi Claude yapacak — "Notlar" bölümüne yaz.
- Kredi kartı son ödeme tarihleri ve ekstrelerdeki planlı talimatlar hazır:
  `TransactionRepository().getUpcomingPayments()` → `[{due_date, description, amount_cents, minimum_cents, kind}]`.
  Bunlar için de ödeme gününden 2 gün önce hatırlatıcı kur (bildirim id'si için `due_date+description` hash'i kullan).

### G4 — Abonelik (Google Play Billing) sahte başarıyı kaldır
`lib/features/subscription/services/subscription_service.dart` şu an mağaza erişilemezse veya ürün bulunamazsa
kullanıcıya **bedava premium veriyor**. Bunu kaldır:
- `InAppPurchase.instance.purchaseStream` dinle; `purchased/restored` durumunda tier'ı aç, `completePurchase` çağır,
  durumu `flutter_secure_storage`'a yaz ve açılışta geri yükle.
- Mağaza yok/ürün yoksa `false` dön ve UI'da hata göster. `debugPrint` dışında sahte başarı kalmasın.

### G5 — Küçük sahte akışlar
- `family_budget_sheet.dart`: üyeler sadece bellekte tutuluyor → yerel JSON'a (path_provider) kalıcı yaz.
  "Davet kodu" sunucu olmadan çalışamaz: kodu ve paylaşımı kaldır ya da "Yakında" olarak işaretle.
- `newsletter_subscription_sheet.dart`: 1 sn sonra sahte "abone oldunuz" diyor → `url_launcher` ile
  `mailto:support@paraiz.app?subject=Bülten Aboneliği` açsın, sahte başarı mesajını kaldır.
- `settings_screen.dart` → `_restoreFromJsonBackup`: kullanıcı yedeği metin olarak yapıştırmak zorunda →
  `FilePicker` ile `.vault` / `.json` dosyası seçtir, içeriğini oku, mevcut doğrulama/geri yükleme akışına ver.

---

## Claude görevleri (bilgi için)
- C1 ✅ Biyometrik kilit gerçek `local_auth` (BiometricPrompt), PIN → PBKDF2 + Keystore, sahte channel kaldırıldı.
- C2 ✅ PDF motoru: Syncfusion kaldırıldı → PDFium (pdfrx); koordinat tabanlı satır/sütun yeniden kurulumu.
- C3 ✅ Banka parser'ları (Yapı Kredi kart, Enpara, Garanti, bordro, genel tablo); 22 gerçek belgede 15/15 mutabakat.
- C4 ✅ İşlem türü sınıflandırıcı, karşı taraf çıkarıcı, kategori motoru (sözlük + öğrenen kullanıcı kuralları).
- C5 ✅ Ekstre özeti (dönem borcu, asgari, son ödeme), DB v2 migration, mükerrer koruması, çift sayım düzeltmesi.
- Yeni kategori id'leri (G2 sesli giriş eşlemesinde kullanılabilir): `cat_insurance, cat_shopping, cat_electronics,
  cat_education, cat_travel, cat_personal_care, cat_transfer, cat_card_payment, cat_fees, cat_cash, cat_loan`.
- C6 ⏳ Android release build doğrulaması (JDK 17, AGP 8.11.1, Kotlin 2.2.20, NDK 28.2).

---

## Durum tablosu

| Görev | Sahip | Durum | Not |
|---|---|---|---|
| G1 Sözlük | Gemini (API köprüsü) | ✅ | 993 işyeri, `tools/build_merchant_dictionary.py` ile üretildi ve doğrulandı. **Yan panel bu dosyayı elle düzenlemesin**; yalnızca `test/merchant_dictionary_test.dart` testini yazabilir. |
| G2 Sesli giriş | Gemini (API köprüsü) → Claude inceleme | ✅ | Gemini üretti (API köprüsü), Claude inceledi. Gerçek mikrofon (tr_TR), sözlü sayılar; 'bir' tanımlık ve 'ğ' hataları düzeltildi; Gemini'nin quick_entry tam dosya yeniden yazımı reddedildi, yalnızca diyalog bağlandı. |
| G3 Bildirimler | Gemini (API köprüsü) → Claude inceleme | ✅ | Gemini üretti, Claude inceledi. v22'de olmayan uydurma parametre çıkarıldı; hata dayanıklılığı + Android 13 izin isteği eklendi; kart son ödeme/talimat hatırlatıcıları main.dart ve ekstre içe aktarmaya bağlandı. |
| G4 Billing | Gemini (API köprüsü) → Claude inceleme | ✅ | Gemini üretti, Claude inceledi. Bedava premium kaldırıldı; iptal/süresi dolan aboneliği geri almayan açık kapatıldı (mağaza doğrulaması). |
| G5 Küçük akışlar | Gemini (API köprüsü) → Claude inceleme | ✅ | Gemini üretti, Claude inceledi. Aile üyeleri kalıcı, bülten mailto, yedek dosyadan geri yükleme (vazgeçilirse yapıştırma yolu). |

## Notlar / Talepler
(Buraya "X paketine ihtiyacım var", "main.dart'a şunu ekle" gibi talepleri yaz.)
