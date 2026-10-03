# FinScout — Gizlilik İncelemesi (Uçtan uca denetim 2/5)

Tarih: 2026-10-03 · Karşılaştırılan metinler: `PRIVACY_POLICY.md` (28 Eylül 2026), `DATA_DELETION.md` (28 Eylül 2026), `website/gizlilik.html` (25 Eylül 2026), `website/kullanim-sartlari.html` (26 Eylül 2026), uygulama içi metinler (`lib/core/localization/app_strings.dart` vb.) ↔ gerçek kod ve Supabase şeması.

> Bu belge hukuki görüş değildir ve hiçbir metni "KVKK/GDPR uyumlu" ilan etmez. Yalnız kodla çelişen ifadeleri ve görülen eksik/riskleri listeler. Nihai değerlendirme hukukçuya aittir (F2-14).

Durum etiketleri: DOĞRULANDI / BAŞARISIZ / GİDERİLDİ / DOĞRULANMADI / KAPSAM DIŞI / KABUL EDİLEN RİSK.

## Özet tablo

| Kimlik | Başlık | Öncelik | Durum |
|---|---|---|---|
| PRIV-01 | Metinler birbiriyle ve kodla çelişiyor: "finansal kayıtlar internete gönderilmez / yalnız bu telefonda" | P1 | BAŞARISIZ |
| PRIV-02 | "Yalnızca siz erişebilirsiniz" / "uçtan uca şifreli" iddiası anahtar modeline uymuyor | P1 | BAŞARISIZ |
| PRIV-03 | Sunucuda tutulan bazı veri kategorileri politikada yok | P2 | BAŞARISIZ |
| PRIV-04 | PDF'ler "yalnız RAM'de" deniyor; seçici önbellek kopyası kalıyor olabilir | P2 | DOĞRULANMADI (cihaz) |
| PRIV-05 | "İletişim izni" yalnız cihazda; sunucu duyuruyu herkese gönderiyor | P2 | DOĞRULANDI |
| PRIV-06 | KVKK eksikleri: aydınlatma metni, veri sorumlusu, yurt dışı aktarım, saklama süreleri, VERBİS | P2 | DOĞRULANDI (eksik) |
| PRIV-07 | Özel nitelikli veri ihtimali (bordro kesintileri, işlem açıklamaları) | P3 | DOĞRULANMADI |
| PRIV-08 | Hesap silme metni eksik kalemler içeriyor; abonelik iptali uyarısı yok | P3 | DOĞRULANDI |
| PRIV-09 | Üçüncü taraf uç noktalara IP/zaman bilgisi gidiyor; sağlayıcılar adlandırılmıyor | P3 | DOĞRULANDI |
| PRIV-10 | Yaş sınırı yalnız beyan; çocuk koruması mekanizması yok | P4 | DOĞRULANDI |
| PRIV-11 | Politikayla uyumlu doğrulanan noktalar | — | DOĞRULANDI |

---

## PRIV-01 — Çelişen "veri cihazdan çıkmaz" ifadeleri (P1)

- **Açıklama:** Oturum açık kullanıcının tüm ayrıştırılmış finansal verisi (hesaplar, ekstreler, işlemler, taksitler, vergiler, hedefler, kurallar) her değişiklikte sunucuya yedekleniyor. Buna rağmen:
  1. `PRIVACY_POLICY.md` Bölüm 3, İnternet izni: "**Finansal kayıtlarınız internet üzerinden gönderilmez.**" — aynı belgenin Bölüm 1'iyle çelişiyor. Aynı cümle `website/gizlilik.html` Bölüm 3'te de var.
  2. `website/gizlilik.html` İngilizce özet: "All your financial records… are processed and stored **only on your device and are never sent to a server**." — repo'daki `PRIVACY_POLICY.md` İngilizce özeti ise yedeklemeyi anlatıyor; web sürümü eski (25 Eylül) ve farklı.
  3. Uygulama içi işlem detayı: "Saklandığı yer — **Yalnız bu telefonda**" (`moneytrace/lib/features/dashboard/presentation/widgets/transaction_detail_sheet.dart:380`).
  4. Kod yorumu `moneytrace/lib/core/services/account_service.dart:23` "Finansal veri buradan sunucuya GİTMEZ" (yanıltıcı ama kullanıcıya görünmez).
- **Etki:** Kullanıcıya yanlış bilgilendirme; Google Play Veri Güvenliği beyanı bu metinlere dayanıyorsa beyan tutarsızlığı riski; KVKK aydınlatma yükümlülüğü açısından risk.
- **Kanıt (kod):** `moneytrace/lib/core/services/backup_service.dart:165-198` (tüm tablolar → `vault_blobs` upsert), `:93-98` (her `DataChanges` sonrası 9 sn debounce).
- **Önerilen çözüm:** Üç metni tek kaynaktan üret; Bölüm 3 cümlesini "Finansal kayıtlarınız yalnız hesabınıza bağlı, şifrelenmiş yedek olarak gönderilir" biçiminde düzelt; web sürümünü güncelle; uygulama içi "Saklandığı yer" satırını oturum durumuna göre "Bu telefonda + şifreli hesap yedeği" yap. (Dosyalar bu görevin düzenleme kapsamı dışında — uygulanmadı.)

## PRIV-02 — Erişim ve şifreleme iddiası (P1)

- **Açıklama:** Politika: "hesabınıza bağlı şifreli yedeğinize **yalnızca siz**, o hesapla oturum açarak erişebilirsiniz"; kod yorumu "uçtan uca şifreli". Gerçekte anahtar sunucudaki `BACKUP_KEY_SECRET` + kullanıcı kimliğinden türetiliyor; hizmet sağlayıcı (sır ve veritabanına erişimi olan) yedekleri teknik olarak çözebilir; geçerli oturum jetonu ele geçiren de çözebilir.
- **Kanıt:** `supabase/functions/backup-key/index.ts:43-57`; `PRIVACY_POLICY.md` Bölüm 1 ve 5; bkz. `security-audit.md` SEC-03.
- **Önerilen çözüm:** Metni gerçeğe uydur: "Yedeğiniz, sunucuda saklanan bir gizli anahtar ve hesap kimliğinizden türetilen anahtarla şifrelenir. Teknik olarak hizmet sağlayıcı bu anahtarı üretebilir; erişim yalnız hizmetin işletilmesi için ve yetkili kişilerle sınırlıdır." Gerçek E2E isteniyorsa kullanıcı tarafı anahtar (SEC-03).

## PRIV-03 — Politikada adı geçmeyen sunucu verileri (P2)

Politika Bölüm 2 sunucuda yalnız "ad, e-posta, hesap kimliği, oturum bilgileri, FCM jetonu/platform/son görülme, şifreli yedek" sayıyor. Supabase'de ayrıca (SQL `pg_class`, `pg_policies`):

| Tablo | İçerik | Gizlilik etkisi |
|---|---|---|
| `document_uploads`, `upload_consumptions` | ay bazında belge türü sayıları (kredi kartı / vadesiz / bordro), zaman damgası | Kullanıcının hangi tür finansal ürüne sahip olduğu ve yükleme alışkanlığı |
| `subscriptions` | Play ürün kimliği, `purchase_token`, durum, bitiş | Satın alma kaydı |
| `families`, `family_members`, `family_invites` | aile ilişkisi; `my_family()` üyelere birbirinin görünen adını ve maskeli e-postasını (`a***@alan.com`) gösterir | Hesaplar arası ilişki, diğer üyelere açıklanan veri |
| `profiles.display_name` | Google/e-posta adı | (politikada var) |
| `admin_notifications` | gönderilen duyurular, hedef | Hedefli duyuru e-posta ile seçilebiliyor (`send-push` `target.email`) |

Ayrıca planlanan `locked_institution` (security-audit SQL #1) eklenirse "hangi bankanın müşterisi" bilgisi sunucuya geçer — politikaya eklenmeli.

## PRIV-04 — PDF dosyalarının diskte kalması (P2)

- **İddia:** "PDF dosyalarının kendisi yalnızca cihazınızın RAM belleğinde anlık olarak ayrıştırılır" (Politika Bölüm 1).
- **Kod:** Mobilde `withData: kIsWeb` → dosya yoldan okunur (`statement_upload_sheet.dart:101-107`, `:165-169`); `file_picker` Android'de seçilen içeriği uygulama önbelleğine kopyalar ve kod `clearTemporaryFiles()` çağırmıyor. Kopyanın cihazda kaldığı: DOĞRULANMADI (gerçek cihazda `cache/file_picker/` kontrolü gerekli). Cihazdan ayrılmama iddiası (sunucuya yüklenmez) DOĞRULANDI: PDF baytlarını ağa gönderen kod yok (grep: Supabase `storage` kullanımı yok; yalnız `vault_blobs` JSON).
- **Önerilen çözüm:** Önbelleği temizle (security-audit SEC-08) ya da metni "geçici olarak cihazda işlenir, işlem bitince silinir" yap ve bunu sağla.

## PRIV-05 — İletişim izni ve ticari ileti (P2)

- **Açıklama:** Ayarlar > "İletişim izni" (Duyuru ve **kampanya** bildirimleri) yalnız cihazda saklanıyor; `register_device`/`send-push` bu tercihi bilmiyor; `send-push` `target: 'all'` ile tüm kayıtlı cihazlara gönderiyor. Metin bunu dürüstçe belirtiyor ("sunucu tarafı gönderim entegrasyonu henüz yok") ancak gönderim ucu canlıda mevcut (send-push v4 ACTIVE).
- **Kanıt:** `moneytrace/lib/core/services/push_service.dart:35-43` (TODO), `app_strings.dart:154-156`, `supabase/functions/send-push/index.ts` (`target === 'all'`).
- **Risk:** Kampanya/tanıtım içerikli push, 6563 sayılı Kanun kapsamında ticari elektronik ileti sayılabilir (önceden onay, İYS). Politika duyuruların "yeni sürüm, hizmet bilgisi" olduğunu söylüyor; kampanya gönderilirse metin ve onay mekanizması yetersiz kalır.
- **Önerilen çözüm:** Tercihi `devices` tablosuna yaz, `send-push` filtrelesin; kampanya içeriği için ayrı kanal ve açık onay; hukukçu görüşü.

## PRIV-06 — KVKK açısından eksikler ve riskler (P2)

Aşağıdakiler mevcut metinlerde bulunamadı (uyumluluk iddiası değildir):

1. **Veri sorumlusunun kimliği ve adresi** (KVKK m.10/1-a): metinlerde yalnız `pulcratechnology@gmail.com` ve GitHub; gerçek/tüzel kişi adı ve adres yok. F2-14 (hukukçu bekleniyor) — açık.
2. **İşleme amaçları ve hukuki sebepler** (m.5) veri kategorisi bazında eşleştirilmemiş (ör. yedek → sözleşmenin ifası; push → açık rıza/meşru menfaat ayrımı yok).
3. **Yurt dışına aktarım** (m.9): Supabase (AB, Frankfurt), Google/Firebase (FCM, Gmail SMTP, Google Sign-In — ABD), Google Play. Türkiye dışı sunuculara aktarım için öngörülen mekanizma (standart sözleşme vb.) ve bildirim metinde yok.
4. **Saklama süreleri:** hesap silinmeyen/etkin olmayan kullanıcı verisinin ne kadar tutulacağı, Supabase sağlayıcı yedek/log süreleri, `upload_consumptions` geçmişi belirtilmemiş.
5. **İlgili kişi hakları** (m.11): yalnız silme yolu anlatılıyor; erişim, düzeltme, itiraz, veri taşınabilirliği talep yolu tanımlı değil. Politika "dışa aktarma özelliği yok" diyor — erişim hakkı talebine nasıl yanıt verileceği belirsiz.
6. **Açık rıza / onay kaydı:** İlk yüklemedeki onay (`statement_upload_sheet.dart:450`) yalnız "PDF yalnız bu cihazda okunur" bilgisini onaylatıyor; yedeklemeye veya aydınlatma metnine onay/okundu kaydı yok; onay yalnız yerelde tutuluyor.
7. **VERBİS:** F2-15 kararı "hiç bakma" — KABUL EDİLEN RİSK olarak kayıtlı; kayıt yükümlülüğü değerlendirilmedi.
8. **Veri ihlali bildirimi** süreci (m.12/5) tanımlı değil; `SECURITY.md` yalnız açık bildirimi kapsıyor (DOĞRULANMADI içerik derinliği).

## PRIV-07 — Özel nitelikli veri ihtimali (P3, DOĞRULANMADI)

- Bordrolarda sendika aidatı (sendika üyeliği — KVKK m.6 özel nitelikli), engellilik indirimi, icra/nafaka kesintisi gibi kalemler bulunabilir; kart/hesap açıklamalarında sağlık (eczane, hastane) veya dernek/bağış bilgisi geçebilir. Bu veriler ayrıştırılıp sunucuya (şifreli) yedekleniyor. Kodda bu kalemler için özel işlem yok (grep `sendika|engelli|icra|nafaka` → yalnız ilgisiz eşleşmeler). Bordro ayrıştırıcının bu satırları kaydedip kaydetmediği gerçek bordro ile DOĞRULANMADI.
- **Öneri:** Hukukçuya sor; gerekirse bu kalemleri yalnız tutar olarak, açıklamasız sakla veya açık rıza al.

## PRIV-08 — Hesap silme metni (P3)

- **Doğrulanan:** Uygulama içi akış önce `delete-account` çağırıyor, başarısızsa cihaz verisini silmiyor (`settings_screen.dart:846-860`); sunucuda tüm kullanıcı tabloları `ON DELETE CASCADE` (security-audit SEC-21). Metindeki "ad, e-posta, cihaz ve yedek kayıtları" doğru ama eksik: abonelik kaydı, kota sayaçları ve aile üyeliği de silinir (sahipse aile dağılır, üyelerin aile planı biter) — kullanıcıya söylenmiyor.
- **Eksik:** Google Play aboneliği hesap silmeyle iptal olmaz; metinde uyarı yok. E-postayla silme talebinde kimlik doğrulama yalnız "kayıtlı adresten yaz" — kabul edilebilir ama süreç manuel ve kayıt tutulmuyor. Uygulamayı kaldırmanın PDF önbellek kopyalarını da sileceği doğru (uygulama verisi).
- **Öneri:** Silme metnine abonelik iptali ve aile etkisi; silme talepleri için iç kayıt.

## PRIV-09 — Üçüncü taraf uç noktalar (P3)

- Uygulama `finans.truncgil.com` (kurlar), `bloomberght.com/rss`, `dunya.com/rss` (haber) adreslerine doğrudan istek atıyor (`live_market_service.dart:58`, `market_news_service.dart:21-22`); bu sağlayıcılar kullanıcının IP adresini ve istek zamanını görür. Politika "herkese açık döviz/altın kurları ve haber akışları" diyor ama sağlayıcıları adlandırmıyor. `google_fonts` paketinin yazı tiplerini çalışma anında Google'dan indirip indirmediği DOĞRULANMADI (assets'e gömülü değilse IP Google'a gider).
- Finansal veri bu isteklere eklenmiyor: DOĞRULANDI (GET, parametresiz URL).

## PRIV-10 — Yaş sınırı (P4)

- Politika ve şartlar "13 yaş altı kullanamaz" diyor; kayıt akışında yaş beyanı/kontrolü yok (onboarding grep). Türk hukukunda reşit olmayanların sözleşme ehliyeti (abonelik) ayrıca değerlendirilmeli — hukukçu.

## PRIV-11 — Politikayla tutarlı doğrulanan noktalar (DOĞRULANDI)

- Reklam/izleme SDK'sı yok: `pubspec.yaml` bağımlılıklarında AdMob, Facebook, AppsFlyer, Analytics, Crashlytics yok; `AndroidManifest.xml:12` `AD_ID` izni kaldırılıyor.
- Android otomatik yedeği kapalı: `allowBackup="false"`, `data_extraction_rules.xml` her alanı hariç tutuyor.
- Kamera/mikrofon/konum/biyometri izni istenmiyor (`AndroidManifest.xml:5-12`).
- Abonelik bilgisi cihazda `flutter_secure_storage` ile tutuluyor (`subscription_service.dart:57`).
- PDF baytları sunucuya gönderilmiyor; yedekte PDF yok (`backup_service.dart:24-26`, `:165-176`).
- Hesap silme gerçekten tüm sunucu satırlarını siliyor (FK cascade, SQL).
- Push jetonu çıkışta silinmeye çalışılıyor (`account_service.dart:336`, `push_service.dart:145`) ve hesap silmede cascade ile siliniyor.

## Metin–kod karşılaştırma tablosu

| İfade (kaynak) | Kod gerçeği | Sonuç |
|---|---|---|
| "Finansal kayıtlarınız internet üzerinden gönderilmez" (Politika §3, web §3) | Her değişiklikte şifreli yedek yükleniyor | BAŞARISIZ |
| "never sent to a server" (web EN özet) | Aynı | BAŞARISIZ |
| "Saklandığı yer: Yalnız bu telefonda" (uygulama) | Oturum açıkken sunucuda da var | BAŞARISIZ |
| "yalnızca siz… erişebilirsiniz" (§5) | Sunucu anahtarı türetebiliyor | BAŞARISIZ |
| "PDF RAM'de işlenir, sunucuya yüklenmez" (§1) | Sunucuya yüklenmiyor; diskte önbellek kopyası olası | KISMEN — DOĞRULANMADI |
| "PDF parolası kaydedilmez" (§2, §3) | Parola yalnız toplu yüklemede bellekte tekrar deneniyor (`statement_upload_sheet.dart` `rememberedPassword`) | DOĞRULANDI |
| "Uygulama tercihleri yedeklenmez" (§2) | Yedek yalnız veritabanı tabloları (`backup_service.dart:165-176`) | DOĞRULANDI |
| "Reklam/izleme SDK'sı yok" (§4) | pubspec/manifest | DOĞRULANDI |
| "Dışa aktarma özelliği yok" (§5) | Toplu dışa aktarma UI'ı yok; yalnız özet rapor paylaşımı (`analysis_screen.dart:614-647`) | DOĞRULANDI (özet rapor metinde anılmalı) |
| "Hesabı sil → tüm sunucu kayıtları silinir" | FK cascade | DOĞRULANDI |
| Web politika tarihi 25 Eylül, md 28 Eylül | İki farklı sürüm yayında | BAŞARISIZ |
