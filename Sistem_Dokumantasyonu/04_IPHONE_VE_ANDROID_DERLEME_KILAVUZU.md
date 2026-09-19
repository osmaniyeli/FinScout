# Paraİz (MoneyTrace) - iPhone & Android Derleme ve Test Kılavuzu

Paraİz, tek bir Flutter kod tabanı üzerinden hem **Android (APK)** hem de **Apple iPhone (iOS)** platformları için eşzamanlı olarak geliştirilmiş ve tam uyumlu hale getirilmiştir.

---

## 1. Android APK Derleme ve Telefona Yükleme

Android projesinin `AndroidManifest.xml`, `build.gradle`, `settings.gradle` ve `MainActivity.kt` yapılandırmaları dosya depolama (`READ_EXTERNAL_STORAGE`) ve internet (`INTERNET`) izinleriyle eksiksiz hazırlanmıştır.

### APK Üretme Adımları:
1. Terminal veya komut istemcisinde `moneytrace` klasörüne gidin:
   ```powershell
   cd "d:\Users\26075759\OneDrive - ARÇELİK A.Ş\Desktop\Ev Ekonomisi\moneytrace"
   ```
2. Bağımlılıkları çekin:
   ```powershell
   flutter pub get
   ```
3. İmzalanmış Temiz Test APK'sını derleyin:
   ```powershell
   flutter build apk --release --no-tree-shake-icons
   ```
4. Oluşan APK Dosyasının Konumu:
   ```text
   moneytrace/build/app/outputs/flutter-apk/app-release.apk
   ```
5. **Telefona Yükleme**:
   - Oluşan `app-release.apk` dosyasını WhatsApp, Google Drive veya USB kablosuyla Android telefonunuza gönderip doğrudan dokunarak kurabilirsiniz.

---

## 2. iPhone (iOS) Derleme ve TestFlight / Cihaza Yükleme

iOS projesinin `Podfile`, `Info.plist` ve `AppDelegate.swift` yapılandırmaları tamamlanmıştır.

### iPhone İzinleri ve Ekstre Paylaşımı:
- **Dosyalar (Files) ve AirDrop Desteği**: `UIFileSharingEnabled` ve `LSSupportsOpeningDocumentsInPlace` anahtarları açılmıştır. iPhone'unuzda banka uygulamasından indirdiğiniz PDF ekstresini doğrudan "Paraİz ile Paylaş" diyerek veya Dosyalar uygulamasından seçerek içe aktarabilirsiniz.
- **Biyometrik Güvenlik**: `NSFaceIDUsageDescription` ile iPhone FaceID kilidi entegre edilmiştir.

### iPhone İçin Derleme Adımları (macOS veya CI/CD):
1. Pod bağımlılıklarını kurun:
   ```bash
   cd ios && pod install && cd ..
   ```
2. iOS paketini oluşturun:
   ```bash
   flutter build ipa --release
   ```
3. Xcode üzerinden TestFlight veya USB ile doğrudan iPhone'unuza aktarın.

---

## 3. Kullanıcı Verisi Olmayan Temiz Test Yönergesi

Uygulama açıldığında gerçek banka dökümlerinizi sıfırdan test edebilmeniz için:
1. **Temiz Test Modu Varsayılan Olarak Açıktır**:
   - Ana Sayfa ₺0,00 ile başlar, geçmiş sahte işlem görünmez.
2. **Örnek PDF Ekstrelerini Yükleme**:
   - Ekrandaki **"PDF Ekstre Yükle"** butonuna dokunun.
   - Telefonunuzdaki Enpara, Yapı Kredi, Garanti, VakıfBank veya İş Bankası ekstrelerini seçin.
   - Saniyeler içinde aidat tespiti, taksit dağılımı ve kategorilendirme cihazınızda tamamlanacaktır.
3. **İstediğiniz Zaman Sıfırlama**:
   - Ayarlar -> **Uzaktan Kontrol Masası** -> **Veri & Test** sekmesine giderek dilediğiniz an tek tuşla tüm veritabanını tekrar sıfırlayabilirsiniz.
