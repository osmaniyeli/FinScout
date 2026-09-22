# Paraİz Otomasyon & Entegrasyon Araçları (`tools/`)

Bu klasör, Paraİz (MoneyTrace) projesinin sürekli entegrasyon (CI), sürekli dağıtım (CD), kalite denetimi ve yapılandırma senkronizasyonunu otomatikleştiren PowerShell betiklerini içerir.

---

## 🛠️ Araçlar

### 1. `setup_hooks.ps1` — Git Hook Kurulumu
Geliştirici ortamına yerel Git `pre-push` kancasını kurar. Bu kanca sayesinde `git push` komutu verildiğinde 100 noktalı test süiti (`verify_parsers.ps1`) otomatik çalıştırılır ve testler başarısız olursa sunucuya hatalı kod gönderilmesi engellenir.

```powershell
.\tools\setup_hooks.ps1
```

---

### 2. `sync_config.ps1` — Remote Config Şema Doğrulama & Senkronizasyon
Web Yönetici Paneli (`Web_Yonetici_Paneli/remote_config.json`) ile Flutter mobil uygulaması (`moneytrace/assets/config/remote_config.json`) arasındaki yapılandırma dosyalarını denetler, doğrular ve senkronize eder.

- **Şema Doğrulaması:** 6 temel kök anahtar, `#RRGGBB` renk regexi, 12 modül kill-switch listesi ve dinamik entity listelerini denetler.
- **Parametreler:**
  - `-CheckOnly`: Dosyaları değiştirmeden yalnızca doğruluk ve senkronizasyon durumunu kontrol eder.
  - `-Source Web`: Web konsolu konfigürasyonunu mobil uygulamaya aktarır.
  - `-Source App`: Mobil uygulama konfigürasyonunu web konsoluna aktarır.
  - `-Format`: JSON dosyalarını standart 2-boşluklu UTF-8 formatında yeniden yazar.

```powershell
# Yalnızca durum ve şema kontrolü (CI/CD dostu)
.\tools\sync_config.ps1 -CheckOnly

# Web panelindeki değişiklikleri mobil uygulamaya aktar
.\tools\sync_config.ps1 -Source Web

# Mobil uygulamadaki değişiklikleri web paneline aktar
.\tools\sync_config.ps1 -Source App
```

---

### 3. `release.ps1` — Semantik Sürümleme & Otomatik Dağıtım
Paraİz mobil uygulamasının yeni bir sürümünü hazırlamak, doğrulamak ve GitHub Actions üzerinden dağıtıma göndermek için kullanılan uçtan uca sürümleme aracıdır.

- **İşlem Adımları:**
  1. `moneytrace/pubspec.yaml` dosyasından mevcut sürümü (`x.y.z+build`) okur.
  2. Semantik kurallara (SemVer) göre sürüm ve artan build numarasını hesaplar.
  3. 100 noktalı `verify_parsers.ps1` test süitini koşturur; tek bir hata varsa sürümlemeyi iptal eder (Fail-Safe).
  4. `pubspec.yaml` dosyasını günceller.
  5. Git commit oluşturur ve açıklamalı `vX.Y.Z` etiketini (annotated tag) basar.
  6. `-Push` parametresi ile GitHub'a push ederek GitHub Actions APK/AAB derlemesini başlatır.

```powershell
# Simülasyon modu (Dosyalara ve Git'e dokunmaz)
.\tools\release.ps1 -DryRun

# Yama (Patch) sürümü artışı (Örn: 3.5.1+2 -> 3.5.2+3)
.\tools\release.ps1 -Type patch

# Minör sürüm artışı (Örn: 3.5.1+2 -> 3.6.0+3)
.\tools\release.ps1 -Type minor

# Sürümü hazırla, test et, etiketle ve doğrudan GitHub Actions'a gönder
.\tools\release.ps1 -Type patch -Push
```
