# Değişiklik Günlüğü (Changelog)

FinScout projesindeki (eski adlarıyla Paraİz / MoneyTrace) tüm önemli değişiklikler, yeni özellikler, güvenlik sertleştirmeleri ve hata düzeltmeleri bu dosyada belgelenmektedir.

Format, [Keep a Changelog](https://keepachangelog.com/tr/1.0.0/) standardına dayanmaktadır ve bu proje [Semantic Versioning](https://semver.org/lang/tr/) (SemVer) kurallarına uyar.

---

## [3.13.0] - 2026-09-29

Rakip uygulama (Monay) incelemesinden alınan, kullanıcının onayladığı 6 somut iyileştirme.

### Yenilikler
- **Koyu tema** (ilk dilim: Ayarlar, Onboarding, Navigasyon, Ana Sayfa) + Ayarlar'da kompakt Tema/Dil kartı.
- **Kayıt sonrası tanıtım turu**: gerçek yükleme/hızlı işlem butonlarına ve alt sekmelere işaret eden 5 adım; TalkBack açıkken otomatik erişilebilir liste moduna geçer. Yalnız yeni hesaplarda, bir kez.
- **Abonelik ekranında paket karşılaştırma tablosu** (Ücretsiz/Bireysel/Aile — gerçek kota ve özellik farklarıyla).
- **Kupon kodu alanı** — Google Play'in kendi promosyon kodu sayfasına yönlendirir (kendi doğrulama sistemimiz yok, Play politikasına uygun).
- **Ekstre/bordro ilk yüklemede tek seferlik onay kutusu** (sonraki yüklemelerde bir daha sorulmaz).
- **Varlıklar ekranında hesaplama asistanı** — girilen miktarın (gram altın/çeyrek/USD/EUR) canlı kurla TL karşılığını gösterir.
- Ayarlar'a **Kullanım Şartları** bağlantısı ve **İletişim İzni** tercihi eklendi (İletişim İzni şu an yalnız cihazda saklanıyor; sunucu tarafı bildirim filtrelemesi henüz yok — ilerideki bir iş).

## [3.12.0] - 2026-09-29

### Yenilikler
- **Canlı içerik sistemi (CMS temeli):** yeni Supabase `app_content` tablosu (133 metin, tr+en), yönetim panelinden düzenlenebilir (yeni "İçerik/Metinler" sekmesi + `admin-update-content` Edge Function, parola korumalı). Uygulama açılışta bu tabloyu çekip önbelleğe alıyor; ağ yoksa sabit kodlu sözlüğe düşüyor.
- **İngilizce artık gerçekten çalışıyor:** Ayarlar, alt gezinme, Kayıt Ol/Giriş Yap ve belge yükleme ekranları dil seçimine göre değişiyor (~70 yeni anahtar). Kalan ekranlar (Varlıklar, Analiz, Hedefler, Cüzdan, bordro vb.) henüz Türkçe — sıradaki tur.
- Yönetim paneli artık uygulamada olmayan (K7 ile silinmiş) sahte özellikleri simüle etmiyor; güncellik tarihi eklendi.

### Düzeltmeler
- Ana sayfada kart ekstresi son ödeme borcu (CARD_DUE) artık "Yaklaşan Taksitler & Borçlar" listesinde görünüyor.
- Profil'deki e-posta alanı salt-okunur yapıldı (değiştirilse de hesapla senkron olmuyordu).
- `SecurityGuard`'daki APK'ya gömülü sabit yedek şifreleme anahtarları kaldırıldı (kullanılmıyordu, ama biri ileride çağırırsa güvenlik yanılsaması yaratabilirdi).

### Bilinen açık (üretime kadar karar bekliyor)
- Ücretsiz plan "tek banka" kuralı yalnız istemci tarafında uygulanıyor; sunucu tarafı (consume_upload) henüz kapsamıyor — taslak migration hazır, uygulama kararı bekleniyor.

## [3.11.0] - 2026-09-28

### Yenilikler
- **Ücretsiz plan artık gerçek bir ürün:** ayda 1 kredi kartı + 1 hesap ekstresi (bordro Premium'a özel), tek bankaya kilitli. İstemci ve sunucu (`private.plan_limit`) tutarlı.
- **Banka Seç ekranı** (yeni): Yapı Kredi, Garanti BBVA, Enpara seçilebilir; İş Bankası "Yakında" etiketiyle pasif. Onboarding'de (atlanabilir) ve Ayarlar'da.
- Ücretsiz kullanıcı kilitli bankasından farklı bir bankadan ekstre yüklemeye çalışırsa net bir mesajla reddedilir, kota düşmez.
- **Hedefler** sekmesi ücretsiz planda kilitli; kilit kartından doğrudan Premium'a geçiş açılır.

## [3.10.0] - 2026-09-28

3.8.0–3.9.3 arası commit'ler bu dosyaya işlenmemişti; bu sürüm hem o birikimi hem 26–28 Eylül'ün yeni işlerini kapsar.

### Yenilikler
- **Hesaba bağlı, ezberlenen şifresiz bulut yedekleme.** PDF'ler hariç tüm finansal veriler her değişiklikte otomatik şifrelenip hesaba yedekleniyor; çıkış yapıp başka bir cihazdan aynı hesapla girince geri geliyor. Şifreleme anahtarı sunucuda tutulan bir sırdan hesap kimliğinden türetiliyor (yeni Edge Function `backup-key`), hiçbir tabloda saklanmıyor.
- **Dil seçimi geri geldi.** Ayarlar'da gerçek bir Türkçe/English anahtarı; seçim kalıcı. Şimdilik yalnız Ana Sayfa, Profil ve Bildirimler ekranları bu dile geçiyor, geri kalanı Türkçe.
- Profil'e "Yüklediğim Belgeler" listesi (v3.9.3).
- Kredi kartı ve hesap ekstresinde, PDF'ten banka adı kesin olarak tanınıp okuyucusu olmayan bir bankaysa (İş Bankası, Akbank, Ziraat, VakıfBank, Halkbank, QNB) artık net bir mesajla reddediliyor ve kota düşülmüyor — genel okuyucuyla sessizce yanlış rakam üretme riski kapandı.
- Maaş bordrosu desteği "(deneme)" etiketiyle işaretlendi.

### Güvenlik
- **"Harcama raporu (Excel/CSV)" özelliği tamamen kaldırıldı.** Yetkisiz erişim (çalıntı/açık telefon) durumunda tüm finansal geçmişin tek dokunuşla dışarı çıkmasına izin veren bir açık kapıydı.
- **PIN ekranı yeniden yazıldı.** Özel dairesel tuş takımı ve karmaşık `IntrinsicHeight`/`Spacer`/titreşim animasyonu kombinasyonu (siyah ekranda kilitlenme hatasının olası kök nedeni) kaldırıldı; yerine telefonun kendi sistem klavyesiyle çalışan tek bir metin alanı geldi. Kilit zorunluluğu (`_kPinLockEnforced`) gerçek cihazda tekrar denenene kadar hâlâ kapalı.
- "Verilerin yalnız bu telefonda kalır" iddiası artık doğru olmadığı için uygulama, web sitesi ve mağaza metninden kaldırıldı; yalnız Gizlilik Politikası, Kullanım Şartları ve Hesap/Veri Silme belgesinde doğru açıklama olarak kaldı. PDF'in cihazdan hiç ayrılmadığı iddiası (hâlâ doğru) korundu.

### Düzeltmeler (birikmiş, 3.8.0–3.9.3)
- **Google girişi çözüldü** (kök neden: Android OAuth istemcisinde yanlış kayıtlı SHA-1).
- **Kendi hesaplar arası transfer artık çift gider sayılmıyor** (ör. Yapı Kredi → Enpara); hesap kartı ekstresi yanlışlıkla kredi kartı gibi okunmuyor.
- Çoklu PDF yükleme, Maaş/Vergi sekmesi, tablet düzenleri, aynı ayın farklı bordroları, kota iadesi.

### Web sitesi
- miralife.app'in birebir yapısal kopyası olarak yeniden kuruldu: [osmaniyeli.github.io/FinScout](https://osmaniyeli.github.io/FinScout/).

## [3.7.0] - 2026-09-24

Gece denetimi (310 öğe, 99 bulgu) ve kullanıcı kararları (K1–K18) uygulandı. İlke: az özellik, her rakam doğru; sahte/boş öğe yok.

### Düzeltmeler (rakamlar)
- İşlem silme gerçekten veritabanından siliyor (onaylı); toplamlar güncelleniyor.
- Bordro + vadesiz birlikte yüklenince maaş iki kez gelir sayılmıyor; vadesizden kart ödemesi gider sayılmıyor; iade gelir değil, harcamayı azaltıyor.
- Taksitler: aynı alışveriş her ay tekrar görünmüyor, biten taksit listeden kalkıyor.
- Cüzdan bakiyesi ve kart borcu son ekstrede bankanın yazdığı değerden; ekranlar veri değişince yenileniyor.
- CSV'de çok vergili işlem çoğalmıyor; rapordaki Damga Vergisi çakışması giderildi.

### Ekstre motoru
- EFT/FAST/havale ücreti, komisyon, KMH faizi masraf; stopaj vergi; eşleşme kelime başından.
- Kart özdeşliği (önceki borç + harcama − ödeme = dönem borcu) ve bordro (brüt − kesintiler = net) kontrolleri; bordroda SGK, damga vergisi ve TİS primi okuma hataları düzeltildi.
- Aynı hesabın aynı dönemi ikinci kez aktarılmıyor; mutabakat tutmazsa kayıttan önce onay.
- pdfrx 2.6.5 / engine 0.6.1.

### Yenilikler
- Analiz › Masraflar: banka maliyeti / ödenen vergi / prim ayrı; bu ay ve takvim yılı; kalem kalem döküm; "BSMV dahil" faiz payı oranla ayrılıp "hesaplanan" diye işaretli; tahmini KDV ayrı kartta.
- İşlem detayında kategori değiştirme (yalnız bu işlem / bu satıcının tümü).
- Kart için "Ödemeyi kaydet"; hedef düzenleme, silme ve katkı geçmişi.
- Aile paketi: sahip tek kullanımlık davet koduyla en fazla 3 kişiyi ekler; premium hakkı paylaşılır, veriler herkesin kendi telefonunda kalır.
- Abonelik makbuzu sunucuda (Google Play API) doğrulanıyor; aylık belge kotası sunucuda atomik tutuluyor.

### Güvenlik, mağaza, KVKK
- Abonelik yönetimi/iptal ve gizlilik politikası bağlantıları; açık kaynak lisansları.
- Kilit ekranı açık alt sayfaları da örtüyor; Android 12+ veri aktarımı kapalı.
- Cihazda tek hesap: farklı hesapla girişte uyarı ve yerel verinin silinmesi.
- "Tüm verileri sil" tüm dosyaları ve hatırlatmaları temizliyor; yedek ek tabloları da kapsıyor, geri yükleme birleştirmiyor.

### Kaldırılanlar
- İnceleme sihirbazı, alan eşleme, dil seçici (tek dil), sahte paylaşım/yedek animasyonları, sabit günlü hatırlatmalar, "Hesap Değiştir".
- Ölü kod: yerel aile bütçesi, bülten, fatura takibi, persona, cüzdan seçimi ve süs bileşenleri.
- Yanıltıcı ifadeler: "Sınırsız PDF", "2 ay hediye", "Kriptolu", "%100 güvenli", "Touch ID".

## [3.6.1] - Yayınlanmadı

Test kullanıcısı geri bildirimleri (Surumler/GERI_BILDIRIM_v3.6.0.md) uygulandı. İlke: ekranda görünen her şey gerçek veriyle çalışır, örnek/uydurma değer gösterilmez.

### 🐞 Düzeltmeler
- PDF seçici açılmıyordu: ücretsiz plan kotası doluyken artık net mesaj ve "Planları Gör" çıkıyor; ekstre ekranında tek dosya seçici kaldı.
- Premium tek tıkla alınmış görünüyordu: ödeme butonu yalnızca Google Play onayından sonra başarı gösteriyor.
- Gram/çeyrek altın fiyatları yanlıştı: güncel serbest piyasa verisi; bağlantı yoksa son gerçek değer ve saati, hiç yoksa "—".
- Kart borcu tutarları "₺" içeren metinden 0 okunuyordu (CurrencyNormalizer).

### 🧹 Kaldırılanlar
- Yüz tanıma (yalnızca parmak izi + PIN), sesli giriş ve mikrofon izni, ekran görüntüsü engeli.
- TCMB veri kaynağı seçimi ve sahte yedek haberler; "Sistem sağlığı" bölümü; dekont indirme.
- Ana sayfadaki sabit kapsül/banner'lar, seri modalı ve NET FARK rozeti; İzci notu Bildirimler'e taşındı.
- Onboarding'de banka ve bütçe seçimi; kayıtta oluşturulan örnek hesap ve PIN girişindeki örnek profil.

### ✨ Yenilikler
- **Cüzdan** (eski Kasa projeksiyonu): son 3/6/12 ayın gerçek gelir-gideri, süren taksitler, kategori değişimine dayalı İzci notu.
- **Vergi** sekmesi: bordrodan kesilen gelir vergisi/damga/SGK/işsizlik, ekstrelerdeki BSMV/KKDF/MTV ve kategori oranlarıyla tahmini KDV.
- **Bordro dökümü**: brüt → kesintiler → net, oranlarıyla.
- **Varlıklar**: altın/döviz/nakit, konut, araç ve kartlar cihazda kalıcı; kart borcu ve son ödeme tarihi son ekstreden; manuel kart (banka + limit) aynı bankanın ekstresi gelince otomatik eşleşir.
- **Araçlar**: marka/model listeden, km alanı, 6 ayda bir "değer ve km güncelle" hatırlatması.
- Hızlı girişte Birikim modu; hedef tutarlarında binlik ayraç; motivasyon cümlelerinde marka/model yok.

---

## [3.6.0] - 2026-09-23 · versionCode 4

### 🏦 Ekstre okuma motoru (yeniden yazıldı)
- PDF motoru Syncfusion'dan PDFium'a (pdfrx) taşındı; metin koordinatlarıyla satır/sütun olarak okunuyor.
- Yapı Kredi kredi kartı, Enpara vadesiz hesap, Garanti Paracard ve maaş bordrosu için sütun tabanlı parser'lar; bilinmeyen bankalar için genel tablo okuyucu.
- İşlem türü (harcama, iade, kart ödemesi, faiz, vergi, havale, kendi hesabı, fatura, kredi), karşı taraf ve sektör/kategori çıkarımı; 993 işyerilik sözlük.
- Bankanın beyan ettiği toplamlarla ve bakiye zinciriyle mutabakat; şifreli PDF desteği; mükerrer işlem koruması.
- Son ödeme tarihi, dönem borcu, asgari tutar ve planlı talimatların okunması.

### 🔐 Güvenlik
- Parmak izi / yüz tanıma gerçek Android BiometricPrompt ile (önceden her denemede açılıyordu).
- PIN PBKDF2 ile hash'lenip Android Keystore'da tutuluyor; PIN yokken her 4 haneyi kabul eden açık kapatıldı.

### 💳 Abonelik (Google Play Billing)
- Mağaza erişilemezken verilen bedava premium kaldırıldı; iptal edilen / süresi dolan abonelik premium'u kapatıyor.
- Ana plan teklifi seçimi ve plan değişikliğinde çift ödemeyi önleyen geçiş akışı.

### ✨ Özellikler
- Gerçek sesli harcama girişi (yalnızca cihaz içi Türkçe tanıma, sözlü sayılar).
- Fatura, abonelik ve kart son ödeme hatırlatıcıları (yerel bildirim).
- Aile üyeleri kalıcı; yedekten dosya seçerek geri yükleme; bülten gerçek e-posta ile.

### 🐞 Düzeltmeler
- Hızlı girişte 12 kategori veritabanında yoktu; bu kategorilerdeki kayıtlar sessizce kaydedilmiyordu (DB v3).
- Kart borcu ödemesi, kendi hesaplar arası aktarım ve birikim girişleri artık gelir/gider analizine girmiyor (çift sayım).

### 🔧 Altyapı
- minSdk 24, AGP 8.11.1, Kotlin 2.3.20, NDK 28.2; kullanılmayan CAMERA izni kaldırıldı; mikrofon ve bildirim izinleri eklendi.

---

## [3.5.2] - 2026-09-22

### 🛡️ Güvenlik & Kalite Kapısı (Quality Gate)
- **100-Nokta Otomatik Doğrulama Süiti**: CI/CD kalite kapısı (`quality_gate`) ve Git `pre-push` kancası ile entegre 21 süit ve 100 test.
- **Fail-Fast Dağıtım Modeli**: GitHub Actions üzerinde testleri geçmeyen hiçbir commit veya tag için APK/AAB derlemesi üretilmez.
- **R8 Obfuscation & Kod Küçültme**: Tersine mühendislik saldırılarına karşı derleme seviyesinde R8 kuralları aktif edildi.

### 🏦 Banka Ekstre Entegrasyonları
- **Garanti BBVA**: Paracard ve Bonus Kredi Kartı ekstre formatları, taksit projeksiyonu ve işlem ayrıştırma motoru eklendi.
- **Türkiye İş Bankası**: Maximum Kart ve Hesap Özeti formatları (`X/Y` taksit desenleri ve sektör etiketleri) eklendi.
- **Akbank**: Axess, Wings ve Neo hesap dökümleri ayrıştırıcı desteği getirildi.
- **Evrensel Hata Toleranslı Ayrıştırıcı (GenericBankStatementParser)**: Halkbank (Paraf), Ziraat (Bankkart), VakıfBank, TEB ve DenizBank gibi tüm yerli bankalar için fallback işlem kurtarma motoru devreye alındı.
- **Akıllı Banka & Belge Algılayıcı (BankDetector)**: 9 finans kurumunu ve TCMB IBAN kodlarını (0062, 0064, 0046, 0012, 0010, 0015 vb.) tanıyan kurum tanıma zekası eklendi.

### ⚙️ Yönetici Paneli & Remote Config
- **Çift Yönlü Senkronizasyon Aracı (`tools/sync_config.ps1`)**: Web Yönetici Paneli ile Flutter mobil uygulaması arasında şema korumalı ve tip güvenceli çift yönlü config senkronizasyonu.
- **12 Modül Kill-Switch**: Web arayüzünde eksik olan `dashboard_summary` ve `newsletter_subscription` modülleri eklenerek tüm alt sistemler merkezi şaltere bağlandı.
- **Web Paneli JSON İçe Aktar (Import)**: Var olan `remote_config.json` dosyasını sürükle-bırak veya dosya seçiciyle yükleyip simülatörde anında görme desteği.

### 🚀 Dağıtım & Sürüm Otomasyonu
- **Semantik Sürümleme Betiği (`tools/release.ps1`)**: `pubspec.yaml`, `CHANGELOG.md`, test doğrulama ve Git tag (`v*`) oluşturma otomasyonu.

---

## [3.5.1] - 2026-09-20

### ✨ Eklenen Özellikler
- **FIPS 197 Uyumlu AES-256-CBC & PBKDF2 Şifreleme Kasası**: Çevrimdışı `.vault` yedekleme ve parola korumalı içe/dışa aktarım.
- **12 Mikro-Etkileşim Bileşeni**: Shakuro Dynamic Island Kapsülü, Better Sleep tarzı bildirim sayfası, Radar Satın Alma butonu, günlük seri (streak) takibi ve laser card efektleri.
- **FinPay & iBank UI Tasarım Dili**: Yüzen buzlu cam (frosted glass) alt gezinti çubuğu ve modern finansal kart bileşenleri.

### 🔒 Güvenlik
- **Çoklu Platform Ekran Görüntüsü & Kayıt Engelleme**: Android `FLAG_SECURE`, iOS `UIBlurEffect` ve Flutter gizlilik kalkanı entegrasyonu.
- **Kernel Seviyesinde Anti-Tapjacking**: `filterTouchesWhenObscured` ile bankacılık katmanı kaplama saldırılarına karşı tam koruma.
- **Alt-Milisaniyelik PDF Zararlı Yazılım Tarayıcısı**: Sıfır maliyetle `/Launch`, `/JavaScript` ve gömülü dosya exploit'lerini engelleme.

---

## [3.5.0] - 2026-09-15

### 🚀 İlk Kararlı Sürüm
- Çevrimdışı öncelikli (Offline-first) ve sıfır-bilgi (Zero-knowledge) yerel mimari.
- Enpara ve Yapı Kredi PDF hesap dökümü ayrıştırma motoru.
- SQLite tabanlı yerel harcama, nakit akışı ve hedef takibi.
- Bağımsız Web Yönetici Paneli (`Web_Yonetici_Paneli`) ve telefon simülatörü.
