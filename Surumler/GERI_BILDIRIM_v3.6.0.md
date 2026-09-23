# FinScout 3.6.0 — Test geri bildirimleri (23 Eylül 2026)

Kaynak: kullanıcı cihaz testi (3.6.0, kod 4). Her madde için kök neden koddan incelendi.
Durum: ⬜ yapılacak · ⏳ sürüyor · ✅ bitti · ❓ karar bekliyor

## A. Hatalar (kök neden bulundu)

| # | Geri bildirim | Kök neden | Çözüm | Durum |
|---|---|---|---|---|
| A1 | PDF yükleyemiyorum; dosya izni istemiyor, dosya seçtirmiyor. Kart ekstresi / hesap ekstresi / bordro eklenemiyor | Ücretsiz planda **ayda 1 belge kotası** var ve kota kontrolü dosya seçiciden **önce** çalışıyor. Haziran bordrosu yüklendikten sonra seçici hiç açılmıyor. Not: Android'in sistem dosya seçici izin istemez, bu normal. | Test sürümü premium (E6) + kota uyarısını görünür yap; kota dolunca seçici yerine net mesaj ve plan ekranı | ✅ |
| A2 | Premium paketler tek tıkla alınabiliyor | `RadarCheckoutButton` işlem sonucundan bağımsız olarak **"doğrulandı" animasyonunu** oynatıyor; arkada "ürün mağazada bulunamadı" dönse de satın alınmış gibi görünüyor | Düğme animasyonu yalnızca gerçek satın alma onayında (purchaseStream) başarıya geçsin | ✅ |
| A3 | Gram / çeyrek altın fiyatları yanlış | Kur API'si anahtarları değiştirmiş (`gram-altin`→`GRA`, `ceyrek-altin`→`CEYREKALTIN`, `ChangeRate`→`Change`). Altın hiç güncellenmiyor, koddaki **2024'ten kalma sabit değerler** (3.045 / 5.010 TL) gösteriliyor. Güncel: 6.776 / 11.057 TL | Yeni anahtarlar; sabit sahte fiyatları kaldır, veri yoksa "fiyat alınamadı" + son güncelleme zamanı | ✅ |
| A4 | Ekstre ekranında hem ortada hem üstte dosya seçme var | İki ayrı seçici bileşeni | Tek seçici kalsın | ✅ |
| A5 | Dekont indir yalnızca görsel olarak "indirildi" diyor | Sahte animasyon | Dekont indirme özelliği **kaldırılacak** | ✅ |

## B. Kaldırılacaklar

| # | Ne | Nerede | Durum |
|---|---|---|---|
| B1 | "Sistem sağlığı ve modüller" alanı | `settings_screen.dart` | ✅ |
| B2 | Ekran görüntüsü engeli (`FLAG_SECURE`) — gizlilik kalkanı (arka plan önizleme karartması) da değerlendirilecek | `MainActivity.kt`, `main.dart` | ✅ |
| B3 | Yüz tanıma (doğru çalışmıyor, parmak izine yönlendiriyor) — yalnızca parmak izi + PIN kalsın | ayarlar, kilit ekranı, onboarding, `security_auth_service.dart` | ✅ |
| B4 | Sesli giriş + mikrofon izni (`RECORD_AUDIO`), `speech_to_text` paketi; gizlilik politikası güncellenecek | quick entry, manifest, pubspec, `PRIVACY_POLICY.md` | ✅ |
| B5 | TCMB veri kaynağı ve tüm kalıntıları | ayarlar (veri kaynağı seçimi), remote config, gizlilik politikası, haber servisi | ✅ |
| B6 | Ana sayfa üstündeki "Ev tasarruf" bildirimi; **ekranın hiçbir yerinde sabit bildirim olmayacak** | `dashboard_screen.dart`, `compact_smart_insight_banner.dart`, `assets_screen.dart` | ✅ |
| B7 | "CANLI KASA PROJEKSİYONU" yazısı / gereksiz animasyonlar | `cashflow_screen.dart` | ✅ |
| B8 | Aylık değişimlerdeki "NET FARK" alanı | `dashboard_screen.dart` | ✅ |
| B9 | Onboarding'de banka seçimi ve bütçe hedefi seçimi | `onboarding_screen.dart`, `profile_screen.dart` | ✅ |
| B10 | Birikim hedefi motivasyon cümlelerinde marka/model (ör. "Chery Omoda 5'in direksiyonuna…") — yalnızca motive edici cümle | `add_goal_sheet.dart`, `goal_preset_data.dart` | ✅ |

## C. Arayüz değişiklikleri

| # | Ne | Durum |
|---|---|---|
| C1 | İşlem ekle: gelir/gider geçiş kartının yüksekliği daralsın; "Tahsilat işleyin, kasa artsın" / "Gider işleyin, bakiye düşsün" metinleri kalksın; karta **Birikim** eklensin (mavi uyumlu renk) | ✅ |
| C2 | "İzci'den bir not" ekranın ortasında sabit durmasın → **Bildirimler**e taşınsın (Cüzdan alanındaki not kalabilir, gerçek veriyle) | ✅ |
| C3 | "Kasa değişim trendi" → **"Cüzdan"**; veri **geriye dönük** ve **gerçek** (bakiyeler, taksitler), tahmin/sallama yok | ✅ |
| C4 | Hedef tutarı ve mevcut birikim binlik ayraçla (1.250.000) | ✅ |
| C5 | Araç & mülk: alanlar boş gelsin (örnek veri yok), marka/model **listeden** seçilsin; piyasa değeri alanı kalsın | ✅ |
| C6 | Manuel kart ekle: yalnızca **banka adı + limit** | ✅ |

## D. Yeni gerçek özellikler (sunucu gerektirmez)

| # | Ne | Not | Durum |
|---|---|---|---|
| D1 | Yüklenen bordronun dağılımını görme (brüt, net, SGK, gelir vergisi, damga, özel kesintiler) | Bordro verisi DB'de var (`tax_deductions`), ekranı yok | ✅ |
| D2 | **Ödenen toplam vergi** analizi: bordrodan (gelir vergisi, damga, SGK) + alışverişten (KDV tahmini, kategoriye göre oran) + ekstre vergileri (BSMV, KKDF, MTV); türe göre ayrıştırma | Analiz ekranına yeni bölüm | ✅ |
| D3 | Kredi kartı ekstresi geldiğinde Varlıklar → Kartlar'daki manuel kartla **otomatik eşleşme** (banka adına göre; manuel kartta son 4 hane istenmiyor) | Parser zaten kart maskesini ve kurumu çıkarıyor | ✅ |
| D4 | Araç için **6 ayda bir** "piyasa değeri ve km'yi güncelle" hatırlatıcısı | Yerel bildirim (G3 altyapısı) ile yapılabilir | ✅ |

## E. Mimari karar gerektirenler ❓

Bunlar **sunucu** gerektiriyor ve bugünkü "veri telefondan çıkmaz" vaadini ve gizlilik politikasını değiştiriyor.

| # | Ne | Gereken |
|---|---|---|
| E1 | Kayıt: ad-soyad + e-posta ile gerçek üyelik | Kimlik sunucusu |
| E2 | Google ile giriş (OTP yok) | Google OAuth; Play App Signing SHA-1 kaydı |
| E3 | Giriş yap: e-posta + e-postaya gelen OTP kodu | E-posta gönderen kimlik servisi |
| E4 | Mevcut hesapla yeni cihazda **eski verilerle** devam | Bulutta veri — önerilen: **uçtan uca şifreli** yedek/senkron |
| E5 | Yönetici panelinden manuel bildirim (ör. araç güncelleme) | Push servisi (FCM) + cihaz kaydı |
| E6 | Test sürümünde kullanıcının tüm özelliklere erişmesi (premium) | Seçenekler: Play "Lisans testi" (gerçek akış, ücretsiz test satın alması — ürünlerin Play'de tanımlanması gerekir) veya hesap bazlı test yetkisi (E1'e bağlı) |
| E7 | **Giriş aşamasının detaylı diyagramı** | Mimari seçildikten sonra çizilecek |
| E8 | Kredi teklifleri karşılaştırma (CollectAPI `credit/creditBid`: tutar, vade, tür → bankaların faiz/taksit teklifleri) — kullanıcı tarafından önerildi, kapsamı henüz tanımlanmadı | API anahtarı uygulamaya gömülemez (APK'dan çıkarılır): isteği yapan küçük bir sunucu fonksiyonu gerekir. Gönderilen veri kişisel değil (tutar/vade/tür) |
