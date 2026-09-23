# Gizlilik Politikası (Privacy Policy) — Paraİz (MoneyTrace)

**Son Güncelleme / Last Updated:** 23 Eylül 2026

Paraİz (MoneyTrace) olarak kişisel verilerinizin ve finansal gizliliğinizin korunmasına azami önem veriyoruz. Bu Gizlilik Politikası, uygulamamızı kullandığınızda verilerinizin nasıl (ve neden yalnızca cihazınızda) işlendiğini açıklar.

---

## 1. Sıfır Bilgi Mimarisi (Zero-Knowledge & 100% On-Device)
Paraİz, **"Zero-Knowledge" (Sıfır Bilgi)** prensibiyle inşa edilmiştir:
- **Sunucu Yoktur:** Uygulamanın verilerinizi gönderdiği herhangi bir uzak sunucu, bulut veritabanı veya harici analitik sistemi bulunmamaktadır.
- **Tüm Veriler Cihazınızda Kalır:** Gelir, gider, varlık, hedef ve bütçe kayıtlarınız yalnızca telefonunuzda, uygulamanın diğer uygulamalarca erişilemeyen korumalı alanındaki (Android sandbox) SQLite veritabanında saklanır. Uygulama kilidi PIN'iniz Android Keystore ile korunan şifreli depoda tutulur.
- **Banka Ekstreleri (PDF/CSV):** İçe aktardığınız kredi kartı ve hesap ekstreleri yalnızca cihazınızın RAM belleğinde anlık olarak ayrıştırılır (parse edilir). Hiçbir üçüncü tarafa ya da harici sunucuya iletilmez.

## 2. Toplanan ve İşlenen Veriler
Uygulama geliştiricisi veya üçüncü şahıslar tarafından **hiçbir kişisel veri toplanmaz, saklanmaz veya satılmaz**.
Cihazınızda yerel olarak tutulan veriler:
- Kullanıcı tarafından girilen harcama, gelir ve bütçe tutarları.
- Kullanıcı tarafından yüklenen ekstrelerden elde edilen işlem satırları (üye işyeri adı, tutar, tarih).
- Uygulama tercihleri (dil seçimi, tema, para birimi).

## 3. Uygulama İzinleri (Permissions)
Paraİz yalnızca temel işlevler için minimum düzeyde izin kullanır:
- **Dosya Erişimi (sistem dosya seçici):** Yalnızca kullanıcının kendi seçtiği PDF ekstrelerini ve yedek (.vault / .json) dosyalarını okumak, yedekleri dışa aktarmak için kullanılır. Arka planda dosya taraması yapılmaz. Şifreli ekstreler için girilen PDF parolası kaydedilmez.
- **İnternet (`INTERNET`):** Yalnızca herkese açık döviz/altın kurlarını ve haber (RSS) akışlarını çekmek ile Google Play üzerinden abonelik işlemleri için kullanılır. Hiçbir finansal kayıt veya kişisel veri internet üzerinden gönderilmez.
- **Biyometri (`USE_BIOMETRIC`):** Uygulama kilidini parmak izi / yüz tanıma ile açmak için. Biyometrik veriniz uygulamaya hiç ulaşmaz; doğrulamayı telefonun işletim sistemi yapar.
- **Mikrofon (`RECORD_AUDIO`):** Yalnızca sesli harcama girişinde, siz mikrofon düğmesine bastığınızda kullanılır. Ses **yalnızca cihaz üzerinde** metne çevrilir; kaydedilmez ve hiçbir sunucuya gönderilmez. Cihazınızda çevrimdışı Türkçe tanıma paketi yoksa sesli giriş çalışmaz, yazarak giriş yapabilirsiniz.
- **Bildirimler (`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`):** Fatura, abonelik ve kredi kartı son ödeme hatırlatıcılarını göstermek için. Hatırlatıcılar cihazda zamanlanır, telefon yeniden başladığında korunur.
- **Kamera ve Konum:** Uygulama bu izinleri **talep etmez**.

## 4. Üçüncü Taraf Hizmetleri ve Reklamlar
- Paraİz içinde üçüncü taraf reklam ağları (Google AdMob, Unity Ads vb.) veya kullanıcı davranışlarını takip eden harici takipçiler (Facebook SDK, AppsFlyer vb.) **bulunmaz**.
- Kullanıcı profillemesi veya hedefli reklamcılık yapılmaz.
- **Ödemeler:** Premium abonelikler yalnızca **Google Play Faturalandırma** üzerinden satılır. Ödeme bilgileriniz (kart, Google Pay vb.) Google tarafından işlenir ve Paraİz'e hiçbir zaman ulaşmaz. Uygulama yalnızca Google'dan aboneliğinizin aktif olup olmadığı bilgisini alır ve bunu cihazınızda şifreli olarak saklar. Aboneliğinizi Google Play > Ödemeler ve abonelikler bölümünden yönetebilir veya iptal edebilirsiniz.

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
Paraİz (MoneyTrace) operates under a strict **Zero-Knowledge Architecture**. All your financial records, bank statements, and transactions are processed and stored exclusively on your local device. No personal or financial data is ever collected, transmitted to remote servers, or shared with third parties. Voice entry is transcribed on-device only. Premium subscriptions are sold exclusively through Google Play Billing; payment details are handled by Google and never reach the app.
