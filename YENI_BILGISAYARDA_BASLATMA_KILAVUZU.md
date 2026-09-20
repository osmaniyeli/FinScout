# Paraİz (MoneyTrace) - Yeni Bilgisayarda VS Code ile Başlatma Kılavuzu

Bu belge, projeyi başka bir bilgisayara taşıdığınızda **Visual Studio Code (VS Code)** üzerinde sorunsuz şekilde açıp geliştirmeye devam edebilmeniz için hazırlanmıştır.

---

## 1. Yeni Bilgisayarda Gereksinimler
Yeni bilgisayarda şu araçların kurulu olduğundan emin olun:
1. **Flutter SDK**: [flutter.dev](https://flutter.dev) (En az Flutter 3.10+, tavsiye edilen: Flutter 3.24+ / stable)
2. **Java JDK 17**: Temurin veya Oracle OpenJDK 17
3. **Android Studio** (Android SDK, Platform-tools ve Android Build Tools için)
4. **Visual Studio Code**:
   - `Flutter` eklentisi (Dart eklentisi otomatik kurulur)
   - İsteğe bağlı: `GitLens` eklentisi

---

## 2. Projeyi Açma & İlk Kurulum Adımları
1. ZIP dosyasını yeni bilgisayarınızda istediğiniz bir klasöre çıkartın (Ör: `C:\Projeler\Ev Ekonomisi` veya Masaüstü).
2. **VS Code** uygulamasını açın:
   - `File` -> `Open Folder` (Klasör Aç) seçeneğine tıklayın.
   - Çıkarttığınız **`Ev Ekonomisi`** klasörünü seçin.
3. VS Code içinde dahili terminali açın (`Ctrl + \`` veya `Terminal` -> `New Terminal`).
4. `moneytrace` dizinine geçip paket bağımlılıklarını indirin:
   ```bash
   cd moneytrace
   flutter pub get
   ```
5. Test süitini çalıştırıp 70/70 doğrulamayı teyit edin:
   ```powershell
   powershell -ExecutionPolicy Bypass -File test\verify_parsers.ps1
   ```

---

## 3. Uygulamayı Çalıştırma (Run / Debug)
- VS Code sağ alt köşesinden test cihazınızı seçin (Android Emulator, Fiziksel Telefon veya Chrome).
- Klavyeden `F5` tuşuna basın veya `Run -> Start Debugging` menüsüne tıklayın.

---

## 4. Google Play İmzalı Release Derlemesi
Proje hem yerel hem de GitHub Actions bulut ortamında derlenmeye hazır haldedir:
- **GitHub Actions ile (Tavsiye Edilen):**
  Kodlarınızı `git push origin main` ile GitHub'a gönderdiğinizde, GitHub Actions (`.github/workflows/build.yml`) otomatik olarak imzalı APK ve Google Play AAB paketini üretir.
- **Yerel Release Derlemesi İçin:**
  Root klasördeki `upload-keystore.jks` dosyasını `moneytrace/android/` klasörüne kopyalayıp:
  ```bash
  cd moneytrace
  flutter build appbundle --release
  ```

---

## 5. Önemli Klasör ve Dosyalar
- **`moneytrace/`**: Tüm Flutter mobil uygulama kaynak kodları (`lib/`), testler (`test/`) ve Android yapılandırması (`android/`).
- **`Web_Yonetici_Paneli/`**: Tarayıcıda doğrudan açılabilen bağımsız Web Yönetici Paneli (`index.html`).
- **`Sistem_Dokumantasyonu/`**: 8 bölümlük teknik mimari ve animasyon laboratuvarı.
- **`upload-keystore.jks`**: Google Play imzalı release keystore anahtarı (Lütfen güvenli saklayınız).
