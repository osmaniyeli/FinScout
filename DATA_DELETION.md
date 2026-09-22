# Paraİz (MoneyTrace) - Hesap ve Veri Silme Politikası (Account & Data Deletion Policy)

**Son Güncelleme / Last Updated:** 22 Eylül 2026  
**Uygulama Adı / App Name:** Paraİz (MoneyTrace)  
**Geliştirici / Developer:** osmaniyeli  

---

## Türkçe

### 1. Sıfır Bilgi ve Yerel Mimari Bilgilendirmesi
Paraİz (MoneyTrace), **Zero-Knowledge (Sıfır Bilgi)** mimarisiyle çalışır. Uygulamamız kullanıcıların kişisel veya finansal verilerini harici bir bulut sunucusunda saklamaz. Tüm verileriniz (hesaplar, işlemler, ekstreler, bütçeler ve kategoriler) **yalnızca kendi cihazınızdaki şifrelenmiş yerel SQLite veritabanında** depolanır.

### 2. Uygulama İçinden Veri ve Hesap Silme Adımları
Kullanıcılar tüm verilerini ve yerel profil hesaplarını diledikleri zaman kalıcı olarak silebilirler:
1. **Paraİz** uygulamasını açın.
2. Sağ alt köşedeki menüden veya çekmeceden **Ayarlar (Settings)** sekmesine gidin.
3. **Güvenlik ve Veri Yönetimi** bölümüne kaydırın.
4. **"Tüm Verilerimi ve Hesabımı Kalıcı Olarak Sil"** (veya **"Veritabanını Sıfırla"**) butonuna dokunun.
5. Açılan onay iletişim kutusunda silme işlemini onaylayın.
6. Bu işlem sonucunda:
   - Tüm harcama, gelir ve bütçe hareketleri,
   - Tanımlı tüm hesap ve kart bilgileri,
   - Şifrelenmiş yerel veri tabanı tabloları ve önbellek,
   - Biyometrik ve PIN kimlik doğrulama anahtarları  
   **geri döndürülemez biçimde derhal ve kalıcı olarak yok edilir.**

### 3. Uygulamayı Kaldırarak Silme
Cihazınızda hiçbir uzak sunucu eşitlemesi bulunmadığından, Paraİz uygulamasını cihazınızdan kaldırmanız durumunda tüm yerel veriler işletim sistemi tarafından anında ve kalıcı olarak temizlenir.

### 4. Uzaktan Talep veya Destek
Hesap veya veri silme süreçleriyle ilgili herhangi bir sorunuz ya da manuel destek talebiniz için:
- **E-posta:** support@paraiz.app
- **GitHub Issue:** [https://github.com/osmaniyeli/Moneytrace/issues](https://github.com/osmaniyeli/Moneytrace/issues)

---

## English

### 1. Zero-Knowledge & Local-Only Architecture
Paraİz (MoneyTrace) is built on a strict **Zero-Knowledge Architecture**. We do not store, synchronize, or transmit your personal or financial records to any remote server or third-party cloud database. All your data resides exclusively within an encrypted SQLite database on your local device.

### 2. How to Delete Your Account and Data Within the App
You can permanently delete your local account and all associated financial data at any time:
1. Open the **Paraİz (MoneyTrace)** app.
2. Navigate to **Settings** from the bottom bar or drawer.
3. Scroll down to the **Security & Data Management** section.
4. Tap on **"Delete All Data & Account Permanently"** (or **"Reset Database"**).
5. Confirm the action in the prompt.
6. The app will immediately and irreversibly erase:
   - All income, expense, and budget transactions,
   - All configured bank and card profiles,
   - The encrypted SQLite database file and local caches,
   - Biometric and PIN authentication keys.

### 3. Deletion via App Uninstallation
Because no data is hosted on external servers, uninstalling the Paraİz app from your Android device immediately purges 100% of your data.

### 4. Contact & Manual Deletion Requests
For any inquiries regarding data deletion or privacy practices, you may reach out directly:
- **Email:** support@paraiz.app
- **GitHub Repository:** [https://github.com/osmaniyeli/Moneytrace](https://github.com/osmaniyeli/Moneytrace)
