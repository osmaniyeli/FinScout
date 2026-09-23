# Paraİz — Sürüm Defteri

Tüm test ve yayın paketleri bu klasörde tutulur. Paketler (`.apk` / `.aab`) git'e girmez; bu defter girer.

## Kural: Play Console sürüm kodu sırası

Google Play, daha önce **yüklenmiş** (yayınlanmasa bile, herhangi bir kanala) bir `versionCode`'u bir daha kabul etmez.
Her Play yüklemesinde kod, aşağıdaki tabloda **"Play'e yüklendi"** olan en yüksek koddan **büyük** olmalıdır.

- Kod `moneytrace/pubspec.yaml` → `version: X.Y.Z+KOD` satırındaki `+KOD` kısmıdır.
- `moneytrace/android/app/build.gradle` içindeki `flutterVersionCode` / `flutterVersionName` yedek değerleri pubspec ile aynı tutulur.
- `tools/surum_derle.ps1`, pubspec kodu defterdeki en yüksek Play kodundan büyük değilse **yayın (AAB) derlemesini durdurur**.
- Play'e yükleme yaptıktan sonra ilgili satırın **Durum** sütununu `Play'e yüklendi (<kanal>)` olarak güncelle.

## Otomatik yükleme (GitHub Actions → Dahili test)

`main`'e her push'ta CI, AAB'yi yükleme anahtarıyla imzalar ve Play **Dahili test** kanalına yükler.
- Kod otomatik: **`1000 + GitHub çalışma numarası`** (ör. çalışma #20 → kod 1020). Her derlemede kendiliğinden artar.
- Sürüm adı `pubspec.yaml`'dan gelir (`3.6.0`); `+KOD` kısmı yalnızca yerel/elle derlemeler içindir.
- Elle yüklenen sürümler 999'un altında kalır; otomatik kodlarla çakışmaz.
- Kapalı test / üretime geçiş: Play Console'da dahili test sürümünü **"Sürümü tanıt" (Promote)** ile ilerlet — yeniden yükleme yok.
- Koşul: GitHub secret'ları `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`.
  `PLAY_SERVICE_ACCOUNT_JSON` yoksa yükleme adımı atlanır, paketler yine Artifacts'ta olur.

## Play Console geçmişi

| Sürüm | Kod | Tarih | Durum | Not |
|---|---|---|---|---|
| 3.5.1 | 2 | 2026-09-21 | Play'e yüklendi (Dahili test) | commit 88fe63a — Play Console ile doğrulandı |
| 3.5.2 | 3 | 2026-09-23 | Play'e yüklendi (Kapalı test - Alpha) | commit cb9049e — Play Console ile doğrulandı |
| 3.6.0 | 4 | 2026-09-23 | Play'e yüklendi (Kapalı test - Alpha) | PDFium ekstre motoru, gerçek biyometri, Play Billing — Play API ile doğrulandı |
| 3.6.1 | 1021 | 2026-09-23 | Play'e yüklendi (Dahili test) | CI çalışma #21, commit 9b43b04 — FinScout adı, hesap (e-posta kodu / Google), hesap silme, abonelikler — Play API ile doğrulandı, **en yüksek kod** |

> Play Console'da bu tablodan daha yüksek bir kod görürsen (ör. elle yüklenmiş bir sürüm), satır ekle ve pubspec kodunu ondan büyük yap.

## Sonraki sürümde yapılacaklar

Play Console'un 3.6.0 (kod 4) yüklemesinde verdiği uyarılar — bir sonraki sürümden önce kapatılacak:

- [ ] **Reklam kimliği beyanı (AD_ID):** Play Console → Uygulama içeriği → Reklam kimliği → **"Hayır"** (Paraİz reklam
      kimliği kullanmıyor; manifest'e izin EKLENMEYECEK). Kodda: `AndroidManifest.xml`'e
      `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>` ekle ki bir
      kütüphane izni gizlice getiremesin.
- [ ] **Paket boyutu uyarısı:** artışın ana kaynağı PDFium (pdfrx). Derlemeye `--split-debug-info` (+ `--obfuscate`)
      ekle; `bundletool get-size total` ile cihaz başı indirme boyutunu ölç; gerekirse x86_64 ABI'yi çıkar.

## Paketler

Satırları `tools/surum_derle.ps1` otomatik ekler.

| Dosya | Sürüm | Kod | Tür | İmza | Tarih | SHA-256 (ilk 16) |
|---|---|---|---|---|---|---|
| ParaIz_v3.6.0_kod4_test_debug-imzali_2026-09-23.apk | 3.6.0 | 4 | APK (test) | debug | 2026-09-23 | `ff6186fafe2b2034` |
