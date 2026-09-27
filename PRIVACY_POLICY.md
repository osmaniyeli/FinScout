# Gizlilik Politikası (Privacy Policy) — FinScout

**Son Güncelleme / Last Updated:** 28 Eylül 2026

FinScout olarak kişisel verilerinizin ve finansal gizliliğinizin korunmasına azami önem veriyoruz. Bu Gizlilik Politikası, uygulamamızı kullandığınızda hangi verilerin nerede tutulduğunu ve nasıl işlendiğini açıklar.

---

## 1. Finansal Veriler Şifreli Olarak Hesabınıza Yedeklenir, Belge Asılları Cihazınızda Kalır
- **Hesap (sunucuda yalnızca kimlik):** Giriş yapabilmeniz için adınız ve e-posta adresiniz FinScout hesabınızda saklanır. Hesap altyapısı **Supabase** üzerindedir; veriler **Avrupa Birliği'nde (Frankfurt)** tutulur ve aktarım sırasında şifrelenir (HTTPS/TLS). Google ile giriş yaparsanız Google'dan yalnızca adınız ve e-posta adresiniz alınır. Giriş kodları e-postanıza Google (Gmail) e-posta altyapısı üzerinden gönderilir.
- **Finansal Verileriniz Otomatik ve Şifreli Olarak Yedeklenir:** Gelir, gider, hesap, varlık, hedef ve bütçe kayıtlarınız önce telefonunuzda (Android sandbox içindeki SQLite veritabanında) tutulur; her değişiklikte ayrıca **hesabınıza bağlı, şifrelenmiş bir kopyası** sunucuda (Supabase, Frankfurt) saklanır. Böylece çıkış yapıp aynı hesapla başka bir cihazdan girdiğinizde verileriniz kaybolmaz. Şifreleme anahtarı, ezberlemeniz gereken bir parola değildir: yalnızca sunucuda tutulan bir sırdan ve hesap kimliğinizden türetilir, hiçbir tabloda saklanmaz ve yalnızca siz oturum açtığınızda yeniden üretilir. Uygulama kilidi PIN'iniz ayrıca Android Keystore ile korunan şifreli depoda tutulur.
- **Banka Ekstreleri ve Bordro PDF'leri Cihazınızdan Hiç Ayrılmaz:** İçe aktardığınız kredi kartı, hesap ekstresi ve bordro PDF dosyalarının kendisi yalnızca cihazınızın RAM belleğinde anlık olarak ayrıştırılır (parse edilir); sunucuya hiçbir zaman yüklenmez. Sunucuya yedeklenen yalnızca PDF'ten çıkarılan işlem/tutar verileridir, PDF dosyasının kendisi değil.

## 2. Toplanan ve İşlenen Veriler
**Sunucuda (hesabınız için):** ad, e-posta adresi, hesap kimliği ve oturum bilgileri; oturum açtığınız cihazlar için ayrıca push bildirim cihaz jetonu (FCM token), platform ve son görülme zamanı (bkz. Bölüm 4, Push bildirimleri); ve Bölüm 1'de açıklanan, hesabınıza bağlı anahtarla şifrelenmiş finansal veri yedeğiniz. Bu veriler yalnızca giriş yapmanızı ve verilerinizi cihazlar arası korumanızı sağlamak için kullanılır; satılmaz, reklam veya profilleme amacıyla kullanılmaz ve üçüncü taraflarla paylaşılmaz (yalnızca hizmeti sağlayan altyapı sağlayıcıları Supabase ve Google tarafından bizim adımıza işlenir).

**Yalnızca cihazınızda tutulan veriler (yedeklenmez):**
- İçe aktardığınız PDF ekstre ve bordro dosyalarının kendisi (bkz. Bölüm 1).
- Şifreli ekstreler için girilen PDF parolası.
- Uygulama tercihleri (dil seçimi, tema, para birimi).

## 3. Uygulama İzinleri (Permissions)
FinScout yalnızca temel işlevler için minimum düzeyde izin kullanır:
- **Dosya Erişimi (sistem dosya seçici):** Yalnızca kullanıcının kendi seçtiği PDF ekstre ve bordro dosyalarını okumak için kullanılır. Arka planda dosya taraması yapılmaz. Şifreli ekstreler için girilen PDF parolası kaydedilmez.
- **İnternet (`INTERNET`):** Hesaba giriş (e-posta kodu / Google), herkese açık döviz/altın kurları ve haber (RSS) akışları ile Google Play abonelik işlemleri için kullanılır. Finansal kayıtlarınız internet üzerinden gönderilmez.
- **Bildirimler (`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`):** Fatura, abonelik ve kredi kartı son ödeme hatırlatıcılarını göstermek için. Hatırlatıcılar cihazda zamanlanır, telefon yeniden başladığında korunur. Aynı izin, FinScout ekibinin gönderdiği duyuruları (push bildirimi) göstermek için de kullanılır.
- **Kamera, Mikrofon, Konum ve Biyometri (parmak izi / yüz):** Uygulama bu izinleri **talep etmez**.

## 4. Üçüncü Taraf Hizmetleri ve Reklamlar
- FinScout içinde üçüncü taraf reklam ağları (Google AdMob, Unity Ads vb.) veya kullanıcı davranışlarını takip eden harici takipçiler (Facebook SDK, AppsFlyer vb.) **bulunmaz**.
- Kullanıcı profillemesi veya hedefli reklamcılık yapılmaz.
- **Push bildirimleri (Firebase Cloud Messaging):** Hesabınızla oturum açtığınızda, FinScout ekibinin duyurularını (yeni sürüm, hizmet bilgisi gibi) telefonunuza iletebilmek için cihazınızın **Firebase Cloud Messaging** (Google LLC) tarafından üretilen bildirim jetonu hesabınıza bağlı olarak sunucumuzda (Supabase, Frankfurt) saklanır. Bildirim içeriği Google'ın altyapısı üzerinden cihazınıza iletilir. Bu jeton reklam veya takip için kullanılmaz, reklam kimliği toplanmaz; finansal verileriniz bildirimlerle gönderilmez. Hesaptan çıkış yaptığınızda veya hesabınızı sildiğinizde jeton sunucudan silinir. Duyuruları almak istemezseniz telefonunuzun Ayarlar > Uygulamalar > FinScout > Bildirimler bölümünden "Duyurular" kanalını kapatabilirsiniz.
- **Ödemeler:** Premium abonelikler yalnızca **Google Play Faturalandırma** üzerinden satılır. Ödeme bilgileriniz (kart, Google Pay vb.) Google tarafından işlenir ve FinScout'a hiçbir zaman ulaşmaz. Uygulama yalnızca Google'dan aboneliğinizin aktif olup olmadığı bilgisini alır ve bunu cihazınızda şifreli olarak saklar. Aboneliğinizi Google Play > Ödemeler ve abonelikler bölümünden yönetebilir veya iptal edebilirsiniz.

## 5. Veri Güvenliği ve Silme
- Finansal verileriniz önce cihazınızdaki SQLite veritabanında tutulur; hesabınıza bağlı şifreli yedeği (Bölüm 1) yalnızca siz, o hesapla oturum açarak erişebilirsiniz.
- Uygulama içindeki **Ayarlar > "Tüm Verilerimi Sıfırla ve Hesabı Sil"** seçeneği FinScout hesabınızı, sunucudaki şifreli yedeğiniz dahil tüm kayıtlarınızı kalıcı olarak siler, ardından cihazınızdaki verileri temizler.
- Uygulamayı kaldırmak yalnızca cihazdaki verileri siler; hesabınız ve şifreli yedeğiniz sunucuda kalır, aynı hesapla tekrar giriş yaptığınızda geri gelir. Hesabınızı tamamen silmek isterseniz **pulcratechnology@gmail.com** adresine yazabilirsiniz; talepler en geç 30 gün içinde yerine getirilir. Ayrıntılar: [Hesap ve Veri Silme](https://github.com/osmaniyeli/FinScout/blob/main/DATA_DELETION.md)
- Telefonunuzu değiştirdiğinizde ya da uygulamayı silip tekrar kurduğunuzda, aynı hesapla giriş yaptığınızda verileriniz otomatik olarak geri yüklenir; ayrıca bir dışa/içe aktarma işlemi gerekmez. Uygulamada bir seferde tüm verileri dışa aktarma (CSV/Excel gibi) özelliği bulunmaz; bu, hesabınıza yetkisiz erişim halinde toplu veri sızıntısını önlemek için bilinçli bir tercihtir.

## 6. Çocukların Gizliliği
Uygulamamız 13 yaşın (veya ilgili yargı alanındaki asgari yaşın) altındaki çocuklara yönelik değildir ve bilerek çocuklardan veri toplamaz.

## 7. İletişim
Gizlilik Politikamız veya veri güvenliği uygulamalarımız hakkında sorularınız varsa, lütfen GitHub depomuz üzerinden veya aşağıdaki adresten bizimle iletişime geçin:
- **E-posta:** pulcratechnology@gmail.com
- **GitHub:** https://github.com/osmaniyeli/FinScout

---

# English Summary
Your bank statement and payslip PDF files are parsed only in your device's memory and are never uploaded anywhere. The financial records extracted from them (transactions, accounts, goals, assets, budgets) are kept on your device and are also automatically backed up, encrypted, to your FinScout account (Supabase, EU/Frankfurt) — so switching phones or signing in again after signing out does not lose your data. The encryption key is not a password you memorize: it is derived deterministically from a server-side secret and your account id, and is only computed when you are authenticated — it is never stored in any database table. To let you sign in, your name and email address are stored in your FinScout account, encrypted in transit, never sold and never used for advertising. You can delete your account and all server records, including your encrypted backup, in the app (Settings > "Tüm Verilerimi Sıfırla ve Hesabı Sil") or by emailing pulcratechnology@gmail.com. There is no bulk data-export (CSV/Excel) feature — a deliberate choice to reduce the impact of unauthorized device access. Premium subscriptions are sold exclusively through Google Play Billing; payment details are handled by Google and never reach the app. When you are signed in, your device's Firebase Cloud Messaging (Google) push token is stored with your account so the FinScout team can send you announcements; it is not used for advertising or tracking and is deleted when you sign out or delete your account.
