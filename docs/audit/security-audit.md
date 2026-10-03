# FinScout — Güvenlik Denetimi (Uçtan uca denetim 2/5)

Tarih: 2026-10-03 · Kapsam: `moneytrace/` (Flutter, com.moneytrace.app), Supabase `oudxswtadqurmlnvcjyc`, `supabase/functions/*`, `Web_Yonetici_Paneli/`.
Yöntem: kaynak okuma (dosya:satır), Supabase salt-okunur SQL (`pg_policies`, `pg_get_functiondef`, `information_schema`, `has_table_privilege`), `get_advisors(security)`, dağıtılmış Edge Function kaynağının repo ile karşılaştırılması, birim testler. Supabase'e hiçbir yazma yapılmadı.

Durum etiketleri: DOĞRULANDI / BAŞARISIZ / GİDERİLDİ / DOĞRULANMADI / KAPSAM DIŞI / KABUL EDİLEN RİSK.
Öncelik: P0 (hemen) … P4 (bilgi).

## Özet tablo

| Kimlik | Başlık | Öncelik | Durum |
|---|---|---|---|
| SEC-01 | Farklı hesapla girişte "vazgeç" → önceki hesabın verisi yeni hesabın bulut yedeğine yükleniyordu | P1 | GİDERİLDİ (istemci) |
| SEC-02 | Tek sürümlü bulut yedeği: başarısız geri yüklemeden sonra eksik/boş veriyle ezilebilir | P1 | DOĞRULANDI (açık) |
| SEC-03 | Yedek anahtarı sunucuda türetiliyor; "uçtan uca şifreli" değil | P2 | DOĞRULANDI (açık) |
| SEC-04 | Ücretsiz plan banka kilidi ve "geçmiş dönem" muafiyeti yalnız istemcide | P2 | DOĞRULANDI (SQL taslağı) |
| SEC-05 | `admin-update-content`: JWT'siz, paylaşılan sır, hız sınırı yok; panelde saklı XSS | P2 | DOĞRULANDI (açık) |
| SEC-06 | Cihazdaki SQLite ve JSON dosyaları şifresiz (F2-27) | P2 | DOĞRULANDI (açık) — yanıltıcı `isDatabaseEncrypted()` GİDERİLDİ |
| SEC-07 | PIN kilidi kapalı (`_kPinLockEnforced=false`) | P2 | DOĞRULANDI (açık) |
| SEC-08 | Seçilen PDF'lerin `file_picker` önbellek kopyaları silinmiyor; boyut kontrolü okumadan sonra | P2 | DOĞRULANMADI (cihaz) / kod kanıtı var |
| SEC-09 | Oturum belirteçleri `shared_prefs` içinde düz metin | P3 | DOĞRULANDI |
| SEC-10 | Release loglarında finansal veri sızıntısı (sqflite argümanları, FormatException kesitleri) | P3 | GİDERİLDİ (10 satır) |
| SEC-11 | `security_guard.dart`'ta çağrılmayan/sahte "güvenlik" fonksiyonları; script yalnız metin arıyor | P3 | DOĞRULANDI (açık) |
| SEC-12 | Elle yazılmış AES/PBKDF2: doğruluk testleri; MAC karşılaştırması ve `iter` sınırı | P3 | GİDERİLDİ (2 kusur), elle yazılmış kripto açık |
| SEC-13 | `authenticated` rolüne TRUNCATE yetkisi (RLS'i atlar) | P3 | DOĞRULANDI (SQL taslağı) |
| SEC-14 | `vault_blobs` boyut/blob_id sınırı yok | P3 | DOĞRULANDI (SQL taslağı) |
| SEC-15 | PiiRedactor fazla maskeliyor (referans/sipariş no) ve adresleri eksik yakalıyor | P3 | DOĞRULANDI (açık) |
| SEC-16 | "PDF malware tarayıcı" yalnız düz imza arıyor, ad gizlemeyle atlatılıyor | P3 | DOĞRULANDI (açık) |
| SEC-17 | `register_device` aynı FCM jetonunu başka kullanıcıya taşıyabiliyor | P3 | DOĞRULANDI |
| SEC-18 | Supabase Auth "Leaked Password Protection" kapalı | P4 | DOĞRULANDI |
| SEC-19 | Ekran görüntüsü engeli yok (FLAG_SECURE) | P4 | KABUL EDİLEN RİSK |
| SEC-20 | Manifest/derleme küçükleri: READ_EXTERNAL_STORAGE, release'te debug imzaya düşme | P4 | DOĞRULANDI |
| SEC-21 | RLS, RPC yetki kontrolleri, IDOR, hesap silme cascade | — | DOĞRULANDI (sorun yok) |
| SEC-22 | Repoda sır taraması | — | DOĞRULANDI (sır yok) |
| SEC-23 | Edge Function kimlik doğrulama | — | DOĞRULANDI |
| SEC-24 | AI/LLM güvenliği | — | KAPSAM DIŞI |

---

## SEC-01 — Hesap değişiminde "vazgeç" önceki hesabın verisini yeni hesabın kasasına yüklüyordu (P1, GİDERİLDİ)

- **Açıklama:** A hesabının verisi telefondayken B ile giriş yapılırsa `_saveLocalProfile` `DifferentAccountDataException` fırlatır; bu anda Supabase oturumu zaten **B**'dir. Kullanıcı "vazgeç" derse `cancelAccountSwitch()` → `signOut()` → `BackupService.backupNow(force: true)` çalışır ve telefondaki **A** verisini B'nin anahtarıyla şifreleyip B'nin `vault_blobs` satırına upsert eder. Onay ekranı açıkken tetiklenen her `DataChanges` debounce'u da aynısını yapar.
- **Etki:** (1) A'nın tüm finansal geçmişi B hesabına (çoğunlukla aynı telefonu kullanan aile bireyi/başka kişi) sızar; B başka cihazda girişte A'nın verisini görür. (2) B'nin gerçek yedeği ezilir — kalıcı veri kaybı.
- **Olasılık:** Orta (aile cihazı, hesap değiştirme denemesi).
- **Kanıt:** `moneytrace/lib/core/services/account_service.dart:246` (`cancelAccountSwitch() => signOut()`), `:251-258` (oturum B iken istisna), `:334` (koşulsuz `backupNow(force: true)`); `backup_service.dart` eski `_backupNowInner` sahiplik kontrolü yapmıyordu.
- **Uygulanan çözüm:** `moneytrace/lib/core/services/backup_service.dart:109-110` `mayUploadFor()` + `:155-163` — yerel veri sahibi (`UserProfileService.localDataOwnerId()`) biliniyor ve oturumdaki kullanıcıdan farklıysa yükleme yapılmaz. Sahip bilinmiyorsa (eski kurulum) davranış değişmez.
- **Test:** `moneytrace/test/audit_security_crypto_test.dart` grup "SEC-01".
- **Açık risk:** Kural sahip dosyasına dayanır; dosya silinip `_profile` de boşsa (ör. `wipeLocalData` ile `setLocalDataOwner` arası) kontrol "bilinmiyor" sayar — o anda yerel veri de boş olduğundan sızıntı yok, ama bkz. SEC-02.

## SEC-02 — Tek sürümlü yedek, eksik veriyle ezilebilir (P1, açık)

- **Açıklama:** Yedek tek satırdır (`blob_id='full_backup'`, `onConflict: 'user_id,blob_id'`) ve her değişiklikte 9 sn debounce ile **tamamı** üzerine yazılır. `restoreIfEmpty()` her hatayı yutup `false` döner. Geri yükleme başarısız olursa (ağ kesintisi, çözme hatası) sonraki ilk yerel değişiklik — ya da hesap değişiminde `wipeLocalData`'nın tetiklediği debounce — buluttaki tam geçmişi eksik/boş veriyle ezer.
- **Etki:** Kalıcı finansal veri kaybı (sunucuda önceki sürüm tutulmuyor).
- **Olasılık:** Düşük-orta (yeni telefon + zayıf bağlantı senaryosu).
- **Kanıt:** `backup_service.dart:189-198` (upsert, tek blob), `:226-237` (hatalar yutuluyor), `account_service.dart:283-290`; `vault_blobs_pkey` tek benzersiz anahtar (SQL: `pg_index`).
- **Önerilen çözüm:** (a) Sunucuda sürüm geçmişi (aşağıdaki SQL taslağı #3: `vault_blob_history` + tetikleyici, son 5 sürüm). (b) İstemcide cihaz başına "bu hesapla senkronize oldu" işareti: geri yükleme başarısız olduysa otomatik yükleme yapmadan önce yeniden dene; uzak yedek yerelden çok büyükse kullanıcıya sor. Bu davranış değişikliği gerçek cihaz testi gerektirdiği için uygulanmadı.
- **Test:** Yok (öneri).

## SEC-03 — Yedek anahtarı sunucuda türetiliyor; "uçtan uca şifreli" değil (P2)

- **Açıklama:** Anahtar = `HMAC-SHA256(BACKUP_KEY_SECRET, user.id)`; geçerli JWT'si olan herkes `backup-key`'den alır. Dolayısıyla (1) `BACKUP_KEY_SECRET` + veritabanı erişimi olan kişi (proje sahibi, service_role sızıntısı) tüm yedekleri çözebilir; (2) çalınan bir erişim/yenileme jetonu (SEC-09) tüm finansal geçmişi verir. Bu, "sunucu tarafından yönetilen anahtarla şifreleme"dir, uçtan uca değildir.
- **Etki:** Gizlilik iddiası ile gerçek tehdit modeli arasında fark (bkz. PRIV-02). Sır sızarsa tüm kullanıcılar etkilenir; sır döndürülürse eski yedekler çözülemez (anahtar sürümleme yok).
- **Kanıt:** `supabase/functions/backup-key/index.ts:37-57`; `moneytrace/lib/core/services/backup_service.dart:15-24` ("uçtan uca şifreli" yorumu).
- **Önerilen çözüm:** Metinleri düzelt ("sunucu tarafından yönetilen anahtarla şifreli"); anahtara sürüm ekle (`kid`) ve döndürme planı yaz; isteğe bağlı gerçek E2E için kullanıcı parolası/kurtarma anahtarı (`key_envelopes` tablosu mevcut, 0 satır).

## SEC-04 — Ücretsiz plan banka kilidi ve geçmiş dönem muafiyeti yalnız istemcide (P2)

- **Açıklama (a, tekrar doğrulandı):** `checkFreeTierBankLock` yalnız yerel profildeki `lockedInstitution`'a bakar; `consume_upload` kurum parametresi almaz. Ek bulgu: `p_is_backfill=true` gönderen yeni hesap (ilk 30 gün) belgenin dönemi doğrulanmadan **sınırsız** kotasız yükleme yapar; istemci tarafı karar da cihaz saatine (`DateTime.now()`) dayanır.
- **Etki:** Gelir kaybı/abonelik atlatma. PDF cihazda işlendiği için değiştirilmiş APK `consume_upload`'u hiç çağırmayabilir; sunucu kotası yalnız değiştirilmemiş istemciye karşı etkilidir.
- **Kanıt:** `moneytrace/lib/core/services/user_profile_service.dart:587-600`, `:322-325`; SQL `pg_get_functiondef(consume_upload)`: backfill dalında yalnız `auth.users.created_at > now()-30 days` kontrolü var, kurum yok.
- **Önerilen çözüm:** SQL taslağı #1 (aşağıda). Uzun vadede Play Integrity API ile istemci bütünlüğü.
- **Durum:** Kullanıcı onayı bekliyor — UYGULANMADI.

## SEC-05 — `admin-update-content` ve yönetim paneli (P2)

- **Açıklama:** Fonksiyon `verify_jwt=false` olarak dağıtılmış; tek koruma gövdedeki `admin_secret`'ın `ADMIN_PANEL_SECRET` ile `!==` karşılaştırması. Hız sınırı, IP kısıtı, denetim kaydı yok; CORS `*`. Sır ele geçerse `app_content` üzerinden uygulamadaki **her** metin değiştirilebilir (ör. "IBAN'ınızı şu numaraya gönderin" gibi oltalama metni). Panel `index.html` kimlik doğrulamasız ve `app_content` satırlarını `innerHTML` ile kaçışsız basıyor (saklı XSS; yalnız sır sahibi yazabildiği için düşük). Dosya başındaki "DEPLOY EDİLMEDİ" yorumu eski: canlıda sürüm 2 aktif. `admin_roles` tablosunda 0 satır var (send-push / bildirim.html şu an kimse için çalışmaz).
- **Kanıt:** `list_edge_functions` → `admin-update-content verify_jwt:false, version 2`; `supabase/functions/admin-update-content/index.ts:42`; `Web_Yonetici_Paneli/index.html:3042-3050` (innerHTML), `:3058-3070`; SQL `select count(*) from admin_roles` → 0. `ADMIN_PANEL_SECRET`'ın ayarlı olup olmadığı: DOĞRULANMADI (secrets okunmadı).
- **Önerilen çözüm:** bildirim.html'deki gibi OTP oturumu + `admin_roles` kontrolüne geç (`verify_jwt=true`, `getUser` + `is_admin`); geçişe kadar sırrı ≥32 rastgele bayt yap, sabit zamanlı karşılaştır, başarısız denemeleri logla; panelde `textContent`/escape kullan; `app_content` değerlerine uzunluk ve URL içerme kuralı koy.

## SEC-06 — Cihazda şifresiz veri (P2)

- **Açıklama:** `sqflite` ile açılan veritabanı şifresiz (SQLCipher yok). Profil (`paraiz_profile...json`), varlıklar ve cüzdan JSON dosyaları belgeler dizininde düz metin. Koruma yalnız Android sandbox'ı; root'lu/adli erişimde tüm geçmiş okunur. F2-27 kararı: üretim öncesi şifrelenecek — henüz yapılmadı.
- **Olumlu:** `android:allowBackup="false"`, `fullBackupContent="false"`, `data_extraction_rules.xml` bulut yedeği ve cihaz aktarımında tüm alanları hariç tutuyor (`AndroidManifest.xml:19-21`, `res/xml/data_extraction_rules.xml`). DOĞRULANDI.
- **Kanıt:** `moneytrace/lib/core/database/app_database.dart:46` (`openDatabase`, parola yok); `pubspec.yaml` (sqflite, sqlcipher yok); `user_profile_service.dart:774-795` (JSON dosyaları).
- **Uygulanan çözüm (dürüstlük):** `moneytrace/lib/core/security/security_guard.dart` `isDatabaseEncrypted()` artık `false` döner (önceden koşulsuz `true`; çağıran yok). Test: "SEC-06".
- **Önerilen çözüm:** `sqflite_sqlcipher` + anahtar Android Keystore'da (flutter_secure_storage), JSON dosyalarını aynı anahtarla şifrele; göç testi.

## SEC-07 — PIN kilidi kapalı (P2, (d) tekrar doğrulandı)

- **Kanıt:** `moneytrace/lib/main.dart:233` `_kPinLockEnforced = false`; `settings_screen.dart:37-70`. PIN özeti PBKDF2 ile Keystore destekli depoda (`security_auth_service.dart:233-245`).
- **Etki:** Kilidi açık telefonu eline alan herkes tüm finansal veriyi görür. PIN ayarlanabiliyor ama uygulanmıyor — kullanıcı korunduğunu sanabilir.
- **Önerilen çözüm:** Gerçek cihazda siyah ekran tekrar üretimi, ardından yeniden açma; o zamana kadar PIN ayar ekranında "şu an devre dışı" uyarısı.

## SEC-08 — PDF önbellek kopyaları ve boyut kontrolü sırası (P2)

- **Açıklama:** `FilePicker.pickFiles(withData: kIsWeb)` mobilde yol döndürür; Android'de eklenti seçilen dosyayı uygulama önbelleğine (`cache/file_picker/`) kopyalar. Kodda `FilePicker.platform.clearTemporaryFiles()` hiç çağrılmıyor → banka ekstreleri/bordrolar (şifreliler dahil, parola olmadan değil ama dosya olarak) diskte kalır. Ayrıca 15 MB sınırı (`security_guard.dart:249-251`) dosya **tamamen belleğe okunduktan sonra** uygulanıyor (`statement_upload_sheet.dart:165-169`), çok büyük dosyada bellek baskısı.
- **Kanıt:** `moneytrace/lib/features/statement_upload/presentation/statement_upload_sheet.dart:101-107`, `:165-169`; `grep clearTemporaryFiles lib` → sonuç yok. Kopyalama davranışı eklentinin Android uygulamasına dayanır — cihazda DOĞRULANMADI. Analiz raporu da önbelleğe `harcama_ve_masraf_raporu.txt` yazıp silmiyor (`analysis_screen.dart:640-647`).
- **Önerilen çözüm:** Yükleme bitince/iptalde `clearTemporaryFiles()`; `PlatformFile.size > 15 MB` ise okumadan reddet. (Dosya izinli küme dışında olduğu için uygulanmadı.)

## SEC-09 — Oturum jetonları düz `shared_prefs` (P3)

- **Kanıt:** `account_service.dart:36-39` `Supabase.initialize` özel `localStorage` vermiyor → supabase_flutter v2 varsayılanı SharedPreferences (düz XML, sandbox içinde). Yenileme jetonu ile SEC-03 gereği yedek anahtarı da alınabilir.
- **Önerilen çözüm:** `FlutterAuthClientOptions(localStorage: <SecureStorage tabanlı LocalStorage>)`. Göç sırasında mevcut oturumun okunması test edilmeli.

## SEC-10 — Release loglarında hassas veri (P3, GİDERİLDİ)

- **Açıklama:** Flutter `debugPrint` release'te de logcat'e yazar. `sqflite` `DatabaseException.toString()` SQL argümanlarını (tutar, kart adı, açıklama) içerir; `jsonDecode` `FormatException`'ı kaynak metinden kesit içerir (çözülmüş yedek JSON'u ya da varlık dosyası).
- **Uygulanan çözüm (yalnız log satırları):** `backup_service.dart:125` (`$data` → `runtimeType`; anahtarlı yanıt loga düşmesin), `:202`, `:235`; `account_service.dart:288`; `user_profile_service.dart:507`, `:810`; `assets_repository.dart:35`, `:46` (release'te yalnız hata türü, debug'da tam); `credit_card_action_sheet.dart:130`, `add_goal_sheet.dart:113` (yalnız tür — bu dosyalarda `kDebugMode` import'u yok, import eklemek kapsam dışıydı).
- **Açık risk:** Kalan ~40 `debugPrint('...: $e')` ağ/plugin hataları; işlem açıklaması basan log bulunmadı (grep). Kalıcı çözüm: tek bir `safeLog` yardımcısı.

## SEC-11 — Sahte/çağrılmayan güvenlik fonksiyonları ((c) tekrar doğrulandı, P3)

- **Kanıt:** `security_guard.dart` içindeki `generateCsrfToken`, `isOriginAllowed`, `checkRecordOwnership`, `containsSqlInjectionPayload`, `canAccessAdminConsole`, `verifyNoHardcodedSecrets`, `getRecommendedSecurityHeaders`, `runSelfSecurityDiagnostics` (`:382-410`, koşulsuz "20/20 OK") için `lib/` ve `test/` içinde çağıran yok (grep). `test/verify_parsers.ps1:542-546` ve `:832-834` yalnız bu dizgilerin dosyada **var olduğunu** kontrol ediyor; dolayısıyla "20-Point Security Guard Checklist" testi gerçek bir güvenlik özelliğini doğrulamıyor.
- **Neden kaldırılmadı:** Script dizgilere bağımlı (107/107 kırılır) ve `test/verify_parsers.ps1` bu görevin düzenleme kapsamı dışında.
- **Önerilen çözüm:** Ölü fonksiyonları sil, script'teki ilgili iki assert'i davranış testleriyle (bu dosyadaki `audit_security_*` testleri gibi) değiştir.

## SEC-12 — Elle yazılmış AES-256-CBC / PBKDF2 (P3)

- **Doğrulandı:** FIPS-197 Ek C.3 AES-256 vektörü ve PBKDF2-HMAC-SHA256 (c=1, c=2) bilinen çıktıları geçiyor; Encrypt-then-MAC (salt+iv+ct üzerinde HMAC-SHA256), ayrı enc/mac anahtarları, `Random.secure()` ile salt/IV.
- **Giderilen kusurlar:** (1) MAC `!=` ile karşılaştırılıyordu (yorum "sabit zamanlı" diyordu) → `aes_cipher.dart:385-392` `constantTimeEquals`, `:428`. (2) PBKDF2 yinelenme sayısı zarftan sınırsız okunuyordu (2·10⁹ değeri geri yüklemeyi kilitler) → `:380-381`, `:409-413` aralık 1.000–1.000.000.
- **Test:** `test/audit_security_crypto_test.dart` "SEC-12" grupları (6 test).
- **Açık risk:** Tablo tabanlı, elle yazılmış AES yan kanal açısından denetlenmiş bir kütüphane değil; CBC+HMAC doğru kurulmuş olsa da bakım riski. Sonraki zarf sürümünde (`V3`) denetlenmiş kütüphaneye (ör. `cryptography` paketi AES-GCM) geçiş önerilir.

## SEC-13 — `authenticated` rolüne TRUNCATE (P3)

- **Kanıt (SQL):** `has_table_privilege('authenticated', …, 'TRUNCATE')` = true: `admin_roles`, `profiles`, `vault_blobs`, `key_envelopes`. TRUNCATE RLS'e tabi değildir; PostgREST/pg_graphql TRUNCATE sunmadığından bugün dışarıdan istismar yolu bulunamadı — derinlemesine savunma eksiği.
- **Önerilen çözüm:** SQL taslağı #2.

## SEC-14 — `vault_blobs` sınırları (P3)

- **Kanıt:** `vault_blobs` için CHECK kısıtı yok (SQL `pg_constraint`); `blob_id` serbest metin, `ciphertext` boyutsuz; politika `ALL` (`own vault`). Bir kullanıcı sınırsız sayıda/boyutta satır yazabilir (depolama maliyeti).
- **Önerilen çözüm:** SQL taslağı #3 (blob_id kısıtı, boyut sınırı, geçmiş tablosu).

## SEC-15 — PiiRedactor doğruluğu (P3)

- **Açıklama:** Açıklama, karşı taraf ve hesap kimliği kaydedilmeden önce maskeleniyor (`statement_orchestrator.dart:140`, `:184-186`). Prob sonuçları: `FAST REF:2026051234567890` → `2026 05** **** 7890` (16 haneli referans kart sanıldı); `SIPARIS 15123456789` → `151****6789` (TCKN sağlama kontrolü yok); `ISLEM NO 9905321234567` içinde telefon yakalandı (öncesinde `\b`/`(?<!\d)` yok). Adres kalıbı yalnız 9 il/ilçe adıyla bitiyorsa çalışıyor (`pii_redactor.dart:19-22`).
- **Etki:** Veri bütünlüğü (referans numarası kaybı), eksik maskeleme. Gerçek PII'nin maskelendiği testlerle DOĞRULANDI ("SEC-15" grubu).
- **Neden değiştirilmedi:** Maskelenmiş açıklama/hesap kimliği mükerrer ve hesap anahtarlarına giriyor (`transaction_repository.dart:29-35`); kural değişikliği mevcut kullanıcıların yeniden yüklemelerinde anahtar uyuşmazlığı yaratabilir — göç planıyla yapılmalı.
- **Önerilen çözüm:** PAN için Luhn, TCKN için resmi sağlama algoritması, telefon için `(?<!\d)`; değişikliği yeni bir sürüm bayrağıyla yalnız yeni kayıtlara uygula.

## SEC-16 — PDF "malware tarayıcı" (P3)

- **Kanıt:** `pdf_malware_scanner.dart:42-118` yalnız düz `/JavaScript`, `/OpenAction` vb. arıyor. `/J#61vaScript`, `/O#70enAction` (PDF ad kaçışı) içeren dosya `isSafe=true` döndü (prob testi). Sıkıştırılmış nesne akışlarındaki (`/ObjStm`, Flate) belirteçler de görünmez.
- **Etki:** Düşük — asıl koruma, PDF'in JS çalıştırmayan PDFium (pdfrx) ile yalnız metin çıkarımı için açılması (pdfrx'in JS'yi kapalı derlendiği: DOĞRULANMADI). Ancak "derin zararlı yazılım taraması" ifadesi yanıltıcı.
- **Önerilen çözüm:** Metinlerde "basit içerik kontrolü" de; isterse ad kaçışlarını çözerek tara. Gerçek antivirüs iddiası yapılmamalı.

## SEC-17 — `register_device` jeton devralma (P3)

- **Kanıt:** `register_device` `on conflict (fcm_token) do update set user_id = excluded.user_id` (SQL `pg_get_functiondef`). Başkasının FCM jetonunu bilen kullanıcı o cihazı kendi hesabına bağlar; hedefli duyurular yanlış kişiye gider/kurbana gitmez. FCM jetonu gizli sayıldığından olasılık düşük.
- **Önerilen çözüm:** Çakışmada `user_id` farklıysa yalnız aynı kullanıcının oturumunda güncelle ya da eski satırı silip yeni ekle (jeton cihaz yeniden kurulumunda değişir).

## SEC-18 — Leaked Password Protection kapalı ((b) tekrar doğrulandı, P4)

- **Kanıt:** `get_advisors(security)` → `auth_leaked_password_protection` WARN. Uygulama parola kullanmıyor (e-posta OTP + Google: `account_service.dart:73-77`, `:159`), ancak Auth API'nin e-posta+parola kaydı açık olabilir; yerel `config.toml:181` `minimum_password_length = 6` (uzak ayar DOĞRULANMADI).
- **Önerilen çözüm:** Panelden aç; parola girişi kullanılmıyorsa parola ile kaydı kapat.

## SEC-19 — Ekran görüntüsü (P4, KABUL EDİLEN RİSK)

- **Kanıt:** `test/verify_parsers.ps1:818-819` "Screenshots Allowed by Product Decision (no FLAG_SECURE)… removed in v3.6.1 at user request". Son uygulamalar ekranında finansal veri görünür.

## SEC-20 — Manifest / derleme küçükleri (P4)

- `AndroidManifest.xml:6` `READ_EXTERNAL_STORAGE` `maxSdkVersion` olmadan; dosya seçici SAF kullanıyor, gizlilik metni "yalnız sistem dosya seçici" diyor → izin gereksiz görünüyor (cihazda DOĞRULANMADI).
- `android/app/build.gradle:70` `key.properties` yoksa release `signingConfigs.debug` ile imzalanıyor — yanlışlıkla debug imzalı paket üretilebilir; release'te keystore yoksa derlemeyi başarısız kıl.
- `usesCleartextTraffic="false"` DOĞRULANDI; `AD_ID` izni `tools:node="remove"` DOĞRULANDI; R8 `minifyEnabled true` DOĞRULANDI.

## SEC-21 — RLS, RPC, IDOR, hesap silme (DOĞRULANDI)

- **RLS:** `public` şemasındaki 13 tablonun tamamında `relrowsecurity=true`. Politikalar: `admin_notifications` (is_admin SELECT), `admin_roles`/`devices`/`document_uploads`/`families`/`family_invites`/`family_members`/`key_envelopes`/`profiles`/`subscriptions`/`upload_consumptions`/`vault_blobs` → `auth.uid() = user_id|owner_id|created_by`; `app_content` herkese SELECT (CMS, tasarım gereği). `anon` yalnız `app_content` SELECT yetkisine sahip.
- **Sütun yetkileri:** `profiles` için `authenticated` yalnız `display_name` UPDATE (plan vb. değiştirilemez). `vault_blobs.user_id` UPDATE yetkisi var ama `WITH CHECK auth.uid()=user_id` başkasına taşımayı engeller.
- **RPC'ler:** `consume_upload`, `refund_upload`, `entitlement`, `create_family_invite`, `join_family`, `leave_family`, `my_family`, `remove_family_member`, `register_device` — hepsi `SECURITY DEFINER`, `search_path=''`, ilk satırda `auth.uid() is null → raise`, tüm sorgular `v_uid` ile sınırlı. `refund_upload` sahiplik + 15 dk + ayda 3 iade; aile davet kodu 8 karakter/32 harf (40 bit, 48 saat). `admin_user_id_by_email` ve `handle_new_user` yalnız `service_role` çalıştırabiliyor. `private` şemasına `authenticated` USAGE yok. Advisor WARN 0029 (imzalı kullanıcı SECURITY DEFINER çalıştırabilir) bu RPC'ler için bilinçli.
- **Hesap silme:** `delete-account` yalnız JWT'deki kullanıcıyı siler (`index.ts:26-31`); tüm kullanıcı FK'leri `ON DELETE CASCADE` (profiles, key_envelopes, vault_blobs, devices, admin_roles, subscriptions, document_uploads, upload_consumptions, families→family_members/family_invites); `family_invites.used_by` ve `admin_notifications.sent_by` `SET NULL`. İstemci önce sunucuyu siler, başarısızsa cihaz verisini korur (`settings_screen.dart:846-860`).
- **IDOR:** Kullanıcının başka satırına erişebileceği bir yol bulunamadı.

## SEC-22 — Sır taraması (DOĞRULANDI)

- `git ls-files` (375 dosya) + desen taraması (`service_role`, `sk_live|sk_test`, `SECRET=`, özel anahtar, JWT, `AIza…`): bulgular yalnız (1) `Web_Yonetici_Paneli/index.html:2985` anon JWT (`role: anon`) ve `bildirim.html:160` publishable key — istemci için normal; (2) `moneytrace/android/app/google-services.json:18` Firebase Android API anahtarı — tasarım gereği herkese açık, GCP'de paket+SHA-1 kısıtı DOĞRULANMADI.
- `upload-keystore.jks`, `Oturum bilgileri.txt`, `supabase/.env`, `android/key.properties` git tarafından yok sayılıyor (`.gitignore:27,35,43`, `moneytrace/.gitignore:54`) ve izlenmiyor. İçerikleri okunmadı.

## SEC-23 — Edge Function kimlik doğrulama (DOĞRULANDI)

- `backup-key`, `delete-account`, `verify-purchase`, `send-push`: `verify_jwt=true` ve `admin.auth.getUser(jwt)`; işlemler yalnız `user.id` üzerinde. `send-push` ayrıca `admin_roles` kontrolü yapıyor. `verify-purchase` paket ürün listesi, `obfuscatedExternalAccountId` eşlemesi ve `purchase_token` UNIQUE indeksi (`subscriptions_purchase_token_key`) ile başka hesabın satın almasını devralmayı engelliyor. Dağıtılmış `admin-update-content` ve `delete-account` kaynağı repo ile aynı (yorum satırı farkı hariç).

## SEC-24 — AI/LLM güvenliği (KAPSAM DIŞI)

- Uygulamada LLM çağrısı yok: `moneytrace/lib`, `pubspec.yaml`, `android/app/src`, `supabase/functions`, `supabase/migrations` içinde `anthropic|openai|gemini|generativeai|generativelanguage|firebase_ai|llm|chatgpt` kelime-sınırlı aramasında tek eşleşme `merchant_sanitizer.dart:47-48` (abonelik **satıcı adı** listesi: 'CLAUDE', 'OPENAI', 'CHATGPT'). Uygulamanın dış uç noktaları: Supabase, `finans.truncgil.com`, `bloomberght.com/rss`, `dunya.com/rss`.
- `ask_gemini.py` / `ai_dialogue.py` repo kökünde geliştirici araçları; anahtarı `GEMINI_API_KEY` ortam değişkeninden okuyor (`ask_gemini.py:8`), uygulamaya paketlenmiyor.

---

## SQL taslakları (UYGULANMADI — kullanıcı onayı gerekir)

### #1 Ücretsiz plan banka kilidi + geçmiş dönem doğrulaması (SEC-04)

```sql
-- TASLAK. Önce istemci yeni parametreleri gönderecek şekilde güncellenmeli; eski imza bir sürüm boyunca kalabilir.
alter table public.profiles add column if not exists locked_institution text;
-- profiles sütun yetkisi zaten yalnız display_name UPDATE: locked_institution istemciden yazılamaz.

create or replace function public.consume_upload_v2(
  p_doc_type text, p_is_backfill boolean default false,
  p_institution text default null, p_period_end date default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_plan text;
  v_lock text;
  v_month_start date := date_trunc('month', now() at time zone 'Europe/Istanbul')::date;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select plan into v_plan from private.entitlement_for(v_uid);

  if v_plan = 'free' and p_doc_type in ('credit_card', 'checking') then
    if coalesce(trim(p_institution), '') = '' then
      raise exception 'institution_required' using errcode = '22023';
    end if;
    select locked_institution into v_lock from public.profiles where user_id = v_uid for update;
    if v_lock is null then
      update public.profiles set locked_institution = trim(p_institution) where user_id = v_uid;
    elsif v_lock <> trim(p_institution) then
      return jsonb_build_object('allowed', false, 'counted', false, 'reason', 'bank_locked',
                                'locked_institution', v_lock, 'plan', v_plan);
    end if;
  end if;

  -- Geçmiş dönem muafiyeti yalnız belge dönemi bu aydan önceyse
  if coalesce(p_is_backfill, false) and (p_period_end is null or p_period_end >= v_month_start) then
    p_is_backfill := false;
  end if;

  return public.consume_upload(p_doc_type, p_is_backfill);  -- mevcut sayaç/kilit mantığı
end; $$;
revoke all on function public.consume_upload_v2(text, boolean, text, date) from public, anon;
grant execute on function public.consume_upload_v2(text, boolean, text, date) to authenticated;
-- Banka değiştirme için ayrı, sınırlı RPC (ör. 30 günde bir) — Ayarlar > Banka akışı buna bağlanmalı.
-- İstemci güncellendikten sonra: revoke execute on function public.consume_upload(text, boolean) from authenticated;
```

### #2 TRUNCATE yetkilerini geri al (SEC-13)

```sql
revoke truncate on public.admin_roles, public.profiles, public.vault_blobs, public.key_envelopes
  from authenticated, anon;
```

### #3 Yedek sınırları ve sürüm geçmişi (SEC-02, SEC-14)

```sql
alter table public.vault_blobs
  add constraint vault_blobs_blob_id_check check (blob_id = 'full_backup'),
  add constraint vault_blobs_size_check check (octet_length(ciphertext) <= 20 * 1024 * 1024);

create table if not exists private.vault_blob_history (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  blob_id text not null, ciphertext text not null, size_bytes int,
  replaced_at timestamptz not null default now());

create or replace function private.keep_vault_history() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into private.vault_blob_history (user_id, blob_id, ciphertext, size_bytes)
  values (old.user_id, old.blob_id, old.ciphertext, old.size_bytes);
  delete from private.vault_blob_history h
   where h.user_id = old.user_id and h.id not in (
     select id from private.vault_blob_history where user_id = old.user_id order by id desc limit 5);
  return new;
end; $$;
create trigger vault_blobs_history before update on public.vault_blobs
  for each row when (old.ciphertext is distinct from new.ciphertext)
  execute function private.keep_vault_history();
-- Not: geçmiş tablosu hesap silmede cascade ile silinir; gizlilik metninde "son 5 sürüm" belirtilmeli.
```

## Doğrulama komutları

Değişikliklerden sonra (`D:\FinScout\moneytrace`, 2026-10-03; aynı dizinde başka ajanlar da test ekliyordu):

| Komut | Sonuç |
|---|---|
| `flutter analyze` | No issues found (çıkış 0) |
| `flutter test` | +433 geçti, ~7 atlandı, 0 hata (değişiklik öncesi taban: +403 ~4) |
| `flutter test test/audit_security_crypto_test.dart` | 16/16 geçti |
| `powershell -ExecutionPolicy Bypass -File test\verify_parsers.ps1` | 107 / 107 PASSED |
| `flutter build apk --debug` | `build\app\outputs\flutter-apk\app-debug.apk` üretildi |

Gerçek cihazda doğrulanmayanlar: SEC-01 akışının uçtan uca davranışı (birim testle mantık doğrulandı), SEC-08 önbellek kopyası, SEC-20 izin gereksinimi.
