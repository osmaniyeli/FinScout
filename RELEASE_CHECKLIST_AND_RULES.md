# Paraİz (MoneyTrace) - Kesin Sürüm Dağıtım & Derleme Kuralları (Release Protocol)

Bu belge, Paraİz projesinde her yeni sürüm (release), Google Play Console yüklemesi ve GitHub push işlemi öncesinde **eksiksiz ve sırasıyla uygulanması gereken zorunlu kontrol protokolüdür**.

---

## 🛑 KURAL 1: Google Play Sürüm Kodu (VersionCode) Asla Tekrar Edilemez!

> **Sürüm defteri:** Play'e yüklenen her kod `Surumler/SURUM_DEFTERI.md` içinde tutulur. Paketler `tools/surum_derle.ps1` ile derlenir
> (`-Yayin` ile imzalı AAB); betik, sürüm kodu defterdeki en yüksek Play kodundan büyük değilse yayın derlemesini durdurur.

Google Play Console, daha önce yüklenmiş veya yayında olan bir sürüm kodunun (`versionCode`) tekrar yüklenmesine **kesinlikle izin vermez**.
- **Kontrol Dosyası 1**: `moneytrace/pubspec.yaml`
  - `version: 3.5.X+Y` $\rightarrow$ Her yeni Play Store dağıtımında `+Y` (versionCode) en az 1 artırılmalıdır.
- **Kontrol Dosyası 2**: `moneytrace/android/app/build.gradle`
  - `flutterVersionCode = 'Y'` fallback değeri `pubspec.yaml` ile birebir senkronize edilmelidir.

---

## 🛠️ KURAL 2: Derleme Öncesi Kaynak Kod Hijyen Kontrol Sırası

Derleme işlemine (`flutter build apk --release` veya `flutter build appbundle --release`) geçmeden önce şu 6 bileşen mutlaka doğrulanmalıdır:

1. **`app_theme.dart`**:
   - `import 'package:flutter/material.dart';` importu bulunmalıdır.
   - `numericStyle` metodu `GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600, letterSpacing: -0.5)` çağırmalıdır.

2. **`pdf_malware_scanner.dart`**:
   - `Stopwatch()..start();` cascade operatörüyle başlatılmalıdır (`Stopwatch().start()` void döner ve tip hatası üretir).
   - Regex escape deseni `RegExp('${RegExp.escape(token)}[\\s/<>\\[\\(\\{]')` şeklinde güvenli olmalıdır.

3. **`custom_field_mapping_service.dart`**:
   - `ParsedRecord` kurucusu güncel parametreleriyle çağrılmalıdır:
     - `billingAmountCents`
     - `date`
     - `billingCurrency: 'TRY'`
     - `cardOrAccountMask: 'CUSTOM_TEMPLATE'`

4. **`assets_screen.dart`**:
   - Kart borç ödeme ve işlem kayıtlarında `_repository.saveManualTransaction(...)` kullanılmalıdır (asla `insertTransaction` kullanılmaz).

5. **`quick_entry_sheet.dart`**:
   - Dinamik kategori listesi çekilirken `final categories = _currentCategories;` kullanılmalıdır (`_categories` yoktur).

6. **`statement_orchestrator.dart`**:
   - `if (rawRecords.isEmpty)` ve `switch (detection.institution)` süslü parantez dengesi (`{ ... }`) ve tüm `case` gövdelerinin girintileri (indentation) kusursuz hizalanmalıdır.

---

## 🧪 KURAL 3: Otomatik Test Doğrulaması (Pre-Push Gate)
Git push yapılmadan önce yerel test paketi zorunlu olarak çalıştırılmalı ve %100 başarı sağlanmalıdır:
```powershell
powershell -ExecutionPolicy Bypass -File moneytrace\test\verify_parsers.ps1
```
- Test 22 (**Pre-Release Compilation Hygiene & Version Code Guard**), yukarıdaki tüm kuralları ve `versionCode >= 3` şartını otomatik olarak denetler. Testten geçmeyen hiçbir kod `git push` ile depoya gönderilemez.

---

## 🚀 KURAL 4: Standart Derleme & Temizlik Sırası
Yerel geliştirme ortamında derleme yapılacağı zaman sırasıyla:
```bash
flutter clean
flutter pub get
dart format lib
flutter analyze
flutter build apk --release --android-skip-build-dependency-validation
flutter build appbundle --release
```
komutları işletilmelidir.
