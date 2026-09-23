# Paraİz — Sürüm Defteri

Tüm test ve yayın paketleri bu klasörde tutulur. Paketler (`.apk` / `.aab`) git'e girmez; bu defter girer.

## Kural: Play Console sürüm kodu sırası

Google Play, daha önce **yüklenmiş** (yayınlanmasa bile, herhangi bir kanala) bir `versionCode`'u bir daha kabul etmez.
Her Play yüklemesinde kod, aşağıdaki tabloda **"Play'e yüklendi"** olan en yüksek koddan **büyük** olmalıdır.

- Kod `moneytrace/pubspec.yaml` → `version: X.Y.Z+KOD` satırındaki `+KOD` kısmıdır.
- `moneytrace/android/app/build.gradle` içindeki `flutterVersionCode` / `flutterVersionName` yedek değerleri pubspec ile aynı tutulur.
- `tools/surum_derle.ps1`, pubspec kodu defterdeki en yüksek Play kodundan büyük değilse **yayın (AAB) derlemesini durdurur**.
- Play'e yükleme yaptıktan sonra ilgili satırın **Durum** sütununu `Play'e yüklendi (<kanal>)` olarak güncelle.

## Play Console geçmişi

| Sürüm | Kod | Tarih | Durum | Not |
|---|---|---|---|---|
| 3.5.1 | 2 | 2026-09-21 | Play'e yüklendi (Dahili test) | commit 88fe63a — Play Console ile doğrulandı |
| 3.5.2 | 3 | 2026-09-23 | Play'e yüklendi (Kapalı test - Alpha) | commit cb9049e — Play Console ile doğrulandı, en yüksek kod |
| 3.6.0 | 4 | — | Sıradaki yükleme | PDFium ekstre motoru, gerçek biyometri, Play Billing, sesli giriş, hatırlatıcılar |

> Play Console'da bu tablodan daha yüksek bir kod görürsen (ör. elle yüklenmiş bir sürüm), satır ekle ve pubspec kodunu ondan büyük yap.

## Paketler

Satırları `tools/surum_derle.ps1` otomatik ekler.

| Dosya | Sürüm | Kod | Tür | İmza | Tarih | SHA-256 (ilk 16) |
|---|---|---|---|---|---|---|
| ParaIz_v3.6.0_kod4_test_debug-imzali_2026-09-23.apk | 3.6.0 | 4 | APK (test) | debug | 2026-09-23 | `ff6186fafe2b2034` |
