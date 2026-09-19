# Gizlilik Politikası (Privacy Policy) — Paraİz (MoneyTrace)

**Son Güncelleme / Last Updated:** 20 Eylül 2026

Paraİz (MoneyTrace) olarak kişisel verilerinizin ve finansal gizliliğinizin korunmasına azami önem veriyoruz. Bu Gizlilik Politikası, uygulamamızı kullandığınızda verilerinizin nasıl (ve neden yalnızca cihazınızda) işlendiğini açıklar.

---

## 1. Sıfır Bilgi Mimarisi (Zero-Knowledge & 100% On-Device)
Paraİz, **"Zero-Knowledge" (Sıfır Bilgi)** prensibiyle inşa edilmiştir:
- **Sunucu Yoktur:** Uygulamanın verilerinizi gönderdiği herhangi bir uzak sunucu, bulut veritabanı veya harici analitik sistemi bulunmamaktadır.
- **Tüm Veriler Cihazınızda Kalır:** Gelir, gider, varlık, hedef ve bütçe kayıtlarınız yalnızca telefonunuzun yerel şifrelenmiş SQLite veritabanında saklanır.
- **Banka Ekstreleri (PDF/CSV):** İçe aktardığınız kredi kartı ve hesap ekstreleri yalnızca cihazınızın RAM belleğinde anlık olarak ayrıştırılır (parse edilir). Hiçbir üçüncü tarafa ya da harici sunucuya iletilmez.

## 2. Toplanan ve İşlenen Veriler
Uygulama geliştiricisi veya üçüncü şahıslar tarafından **hiçbir kişisel veri toplanmaz, saklanmaz veya satılmaz**.
Cihazınızda yerel olarak tutulan veriler:
- Kullanıcı tarafından girilen harcama, gelir ve bütçe tutarları.
- Kullanıcı tarafından yüklenen ekstrelerden elde edilen işlem satırları (üye işyeri adı, tutar, tarih).
- Uygulama tercihleri (dil seçimi, tema, para birimi).

## 3. Uygulama İzinleri (Permissions)
Paraİz yalnızca temel işlevler için minimum düzeyde izin kullanır:
- **Depolama / Dosya Erişimi (`READ_MEDIA_DOCUMENTS` / File Picker):** Yalnızca kullanıcının kendi rızasıyla seçtiği PDF veya CSV ekstrelerini okumak ve yedekleme (JSON/CSV) dosyalarını dışa aktarmak için kullanılır. Arka planda genel dosya taraması yapılmaz.
- **İnternet İzni (`INTERNET`):** Yalnızca Merkez Bankası (TCMB) / BloombergHT açık RSS haber akışını çekmek için kullanılır. Hiçbir kullanıcı verisi internet üzerinden dışarı aktarılmaz.
- **Kamera, Mikrofon, Konum:** Uygulama bu izinleri **kesinlikle talep etmez**.

## 4. Üçüncü Taraf Hizmetleri ve Reklamlar
- Paraİz içinde üçüncü taraf reklam ağları (Google AdMob, Unity Ads vb.) veya kullanıcı davranışlarını takip eden harici takipçiler (Facebook SDK, AppsFlyer vb.) **bulunmaz**.
- Kullanıcı profillemesi veya hedefli reklamcılık yapılmaz.

## 5. Veri Güvenliği ve Silme
- Tüm verileriniz cihazınızda SQLite veritabanında tutulduğu için verilerinizin kontrolü tamamen sizdedir.
- Uygulama içindeki **Ayarlar > Verileri Sıfırla** seçeneğiyle veya uygulamayı cihazınızdan kaldırarak tüm verilerinizi kalıcı olarak silebilirsiniz.
- Cihaz değişikliği durumunda **Kasa Yedeği (JSON)** özelliği ile verilerinizi güvenli bir şekilde kendiniz taşıyabilirsiniz.

## 6. Çocukların Gizliliği
Uygulamamız 13 yaşın (veya ilgili yargı alanındaki asgari yaşın) altındaki çocuklara yönelik değildir ve bilerek çocuklardan veri toplamaz.

## 7. İletişim
Gizlilik Politikamız veya veri güvenliği uygulamalarımız hakkında sorularınız varsa, lütfen GitHub depomuz üzerinden veya aşağıdaki adresten bizimle iletişime geçin:
- **E-posta:** support@paraiz.app
- **GitHub:** https://github.com/osmaniyeli/Moneytrace

---

# English Summary
Paraİz (MoneyTrace) operates under a strict **Zero-Knowledge Architecture**. All your financial records, bank statements, and transactions are processed and stored exclusively on your local device. No personal or financial data is ever collected, transmitted to remote servers, or shared with third parties.
