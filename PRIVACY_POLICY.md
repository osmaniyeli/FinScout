# Gizlilik Politikası (Privacy Policy) — FinScout

**Son Güncelleme / Last Updated:** 23 Eylül 2026

FinScout olarak kişisel verilerinizin ve finansal gizliliğinizin korunmasına azami önem veriyoruz. Bu Gizlilik Politikası, uygulamamızı kullandığınızda hangi verilerin nerede tutulduğunu ve nasıl işlendiğini açıklar.

---

## 1. Finansal Veriler Cihazınızda, Hesap Bilgileri Sunucuda
- **Hesap (sunucuda yalnızca kimlik):** Giriş yapabilmeniz için adınız ve e-posta adresiniz FinScout hesabınızda saklanır. Hesap altyapısı **Supabase** üzerindedir; veriler **Avrupa Birliği'nde (Frankfurt)** tutulur ve aktarım sırasında şifrelenir (HTTPS/TLS). Google ile giriş yaparsanız Google'dan yalnızca adınız ve e-posta adresiniz alınır. Giriş kodları e-postanıza Google (Gmail) e-posta altyapısı üzerinden gönderilir.
- **Finansal Veriler Cihazınızda Kalır:** Gelir, gider, varlık, hedef ve bütçe kayıtlarınız yalnızca telefonunuzda, uygulamanın diğer uygulamalarca erişilemeyen korumalı alanındaki (Android sandbox) SQLite veritabanında saklanır. Uygulama kilidi PIN'iniz Android Keystore ile korunan şifreli depoda tutulur.
- **Banka Ekstreleri (PDF/CSV):** İçe aktardığınız kredi kartı ve hesap ekstreleri yalnızca cihazınızın RAM belleğinde anlık olarak ayrıştırılır (parse edilir). Hiçbir üçüncü tarafa ya da harici sunucuya iletilmez.

## 2. Toplanan ve İşlenen Veriler
**Sunucuda (hesabınız için):** ad, e-posta adresi, hesap kimliği ve oturum bilgileri; oturum açtığınız cihazlar için ayrıca push bildirim cihaz jetonu (FCM token), platform ve son görülme zamanı (bkz. Bölüm 4, Push bildirimleri). Bu veriler yalnızca giriş yapmanızı sağlamak için kullanılır; satılmaz, reklam veya profilleme amacıyla kullanılmaz ve üçüncü taraflarla paylaşılmaz (yalnızca hizmeti sağlayan altyapı sağlayıcıları Supabase ve Google tarafından bizim adımıza işlenir).

**Yalnızca cihazınızda tutulan veriler:**
- Kullanıcı tarafından girilen harcama, gelir ve bütçe tutarları.
- Kullanıcı tarafından yüklenen ekstrelerden elde edilen işlem satırları (üye işyeri adı, tutar, tarih).
- Uygulama tercihleri (dil seçimi, tema, para birimi).

## 3. Uygulama İzinleri (Permissions)
FinScout yalnızca temel işlevler için minimum düzeyde izin kullanır:
- **Dosya Erişimi (sistem dosya seçici):** Yalnızca kullanıcının kendi seçtiği PDF ekstrelerini ve yedek (.vault / .json) dosyalarını okumak, yedekleri dışa aktarmak için kullanılır. Arka planda dosya taraması yapılmaz. Şifreli ekstreler için girilen PDF parolası kaydedilmez.
- **İnternet (`INTERNET`):** Hesaba giriş (e-posta kodu / Google), herkese açık döviz/altın kurları ve haber (RSS) akışları ile Google Play abonelik işlemleri için kullanılır. Finansal kayıtlarınız internet üzerinden gönderilmez.
- **Bildirimler (`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`):** Fatura, abonelik ve kredi kartı son ödeme hatırlatıcılarını göstermek için. Hatırlatıcılar cihazda zamanlanır, telefon yeniden başladığında korunur. Aynı izin, FinScout ekibinin gönderdiği duyuruları (push bildirimi) göstermek için de kullanılır.
- **Kamera, Mikrofon, Konum ve Biyometri (parmak izi / yüz):** Uygulama bu izinleri **talep etmez**.

## 4. Üçüncü Taraf Hizmetleri ve Reklamlar
- FinScout içinde üçüncü taraf reklam ağları (Google AdMob, Unity Ads vb.) veya kullanıcı davranışlarını takip eden harici takipçiler (Facebook SDK, AppsFlyer vb.) **bulunmaz**.
- Kullanıcı profillemesi veya hedefli reklamcılık yapılmaz.
- **Push bildirimleri (Firebase Cloud Messaging):** Hesabınızla oturum açtığınızda, FinScout ekibinin duyurularını (yeni sürüm, hizmet bilgisi gibi) telefonunuza iletebilmek için cihazınızın **Firebase Cloud Messaging** (Google LLC) tarafından üretilen bildirim jetonu hesabınıza bağlı olarak sunucumuzda (Supabase, Frankfurt) saklanır. Bildirim içeriği Google'ın altyapısı üzerinden cihazınıza iletilir. Bu jeton reklam veya takip için kullanılmaz, reklam kimliği toplanmaz; finansal verileriniz bildirimlerle gönderilmez. Hesaptan çıkış yaptığınızda veya hesabınızı sildiğinizde jeton sunucudan silinir. Duyuruları almak istemezseniz telefonunuzun Ayarlar > Uygulamalar > FinScout > Bildirimler bölümünden "Duyurular" kanalını kapatabilirsiniz.
- **Ödemeler:** Premium abonelikler yalnızca **Google Play Faturalandırma** üzerinden satılır. Ödeme bilgileriniz (kart, Google Pay vb.) Google tarafından işlenir ve FinScout'a hiçbir zaman ulaşmaz. Uygulama yalnızca Google'dan aboneliğinizin aktif olup olmadığı bilgisini alır ve bunu cihazınızda şifreli olarak saklar. Aboneliğinizi Google Play > Ödemeler ve abonelikler bölümünden yönetebilir veya iptal edebilirsiniz.

## 5. Veri Güvenliği ve Silme
- Finansal verileriniz cihazınızdaki SQLite veritabanında tutulduğu için kontrolü tamamen sizdedir.
- Uygulama içindeki **Ayarlar > "Tüm Verilerimi Sıfırla ve Hesabı Sil"** seçeneği FinScout hesabınızı ve sunucudaki tüm kayıtlarını kalıcı olarak siler, ardından cihazınızdaki verileri temizler.
- Uygulamayı kaldırmak yalnızca cihazdaki verileri siler; hesabınız sunucuda kalır. Uygulamaya erişemiyorsanız **pulcratechnology@gmail.com** adresine yazarak hesabınızın silinmesini isteyebilirsiniz; talepler en geç 30 gün içinde yerine getirilir. Ayrıntılar: [Hesap ve Veri Silme](https://github.com/osmaniyeli/FinScout/blob/main/DATA_DELETION.md)
- Cihaz değişikliği durumunda **Ayarlar > Yedek** özelliği (parolayla şifreli .vault ya da JSON dosyası) ile verilerinizi güvenli bir şekilde kendiniz taşıyabilirsiniz.

## 6. Çocukların Gizliliği
Uygulamamız 13 yaşın (veya ilgili yargı alanındaki asgari yaşın) altındaki çocuklara yönelik değildir ve bilerek çocuklardan veri toplamaz.

## 7. İletişim
Gizlilik Politikamız veya veri güvenliği uygulamalarımız hakkında sorularınız varsa, lütfen GitHub depomuz üzerinden veya aşağıdaki adresten bizimle iletişime geçin:
- **E-posta:** pulcratechnology@gmail.com
- **GitHub:** https://github.com/osmaniyeli/FinScout

---

# English Summary
All your financial records, bank statements and transactions are processed and stored only on your device and are never sent to a server. To let you sign in, your name and email address are stored in your FinScout account (Supabase, EU/Frankfurt), encrypted in transit, never sold and never used for advertising. You can delete your account and all server records in the app (Settings > "Tüm Verilerimi Sıfırla ve Hesabı Sil") or by emailing pulcratechnology@gmail.com. Premium subscriptions are sold exclusively through Google Play Billing; payment details are handled by Google and never reach the app. When you are signed in, your device's Firebase Cloud Messaging (Google) push token is stored with your account so the FinScout team can send you announcements; it is not used for advertising or tracking and is deleted when you sign out or delete your account.
