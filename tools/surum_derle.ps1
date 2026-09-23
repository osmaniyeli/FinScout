<#
.SYNOPSIS
  Paraİz test (APK) veya yayın (AAB) paketini derler, Surumler/ klasörüne adlandırıp koyar ve sürüm defterine işler.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\surum_derle.ps1            # test APK
  powershell -ExecutionPolicy Bypass -File tools\surum_derle.ps1 -Yayin     # Play Console için imzalı AAB

.NOTES
  -Yayin: pubspec versionCode, Surumler\SURUM_DEFTERI.md'de "Play'e yüklendi" olan en yüksek koddan büyük olmalı;
  ayrıca moneytrace\android\key.properties bulunmalı (debug imzalı AAB Play'e yüklenemez).
#>
param([switch]$Yayin)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'moneytrace'
$outDir = Join-Path $root 'Surumler'
$ledger = Join-Path $outDir 'SURUM_DEFTERI.md'

# 1. Sürüm bilgisi (pubspec tek doğruluk kaynağı)
$pubspec = Get-Content (Join-Path $app 'pubspec.yaml') -Encoding UTF8 -Raw
$m = [regex]::Match($pubspec, '(?m)^version:\s*([\d\.]+)\+(\d+)')
if (-not $m.Success) { throw 'pubspec.yaml içinde "version: X.Y.Z+KOD" bulunamadı.' }
$versionName = $m.Groups[1].Value
$versionCode = [int]$m.Groups[2].Value

$gradle = Get-Content (Join-Path $app 'android\app\build.gradle') -Encoding UTF8 -Raw
if ($gradle -notmatch "flutterVersionCode = '$versionCode'" -or $gradle -notmatch "flutterVersionName = '$([regex]::Escape($versionName))'") {
  throw "build.gradle yedek sürüm değerleri pubspec ($versionName+$versionCode) ile aynı değil."
}

# 2. Play sürüm kodu sırası kontrolü
$ledgerText = Get-Content $ledger -Encoding UTF8 -Raw
$uploaded = [regex]::Matches($ledgerText, "(?m)^\|\s*[\d\.]+\s*\|\s*(\d+)\s*\|[^|]*\|\s*Play'e yüklendi") | ForEach-Object { [int]$_.Groups[1].Value }
$maxUploaded = ($uploaded | Measure-Object -Maximum).Maximum
if ($Yayin) {
  if ($versionCode -le $maxUploaded) {
    throw "Sürüm kodu $versionCode, Play'e yüklenmiş en yüksek koddan ($maxUploaded) büyük değil. pubspec.yaml'da +KOD değerini artır."
  }
  if (-not (Test-Path (Join-Path $app 'android\key.properties'))) {
    throw 'android\key.properties yok: Play yüklemesi için yükleme anahtarıyla imzalanmalı.'
  }
} elseif ($versionCode -le $maxUploaded) {
  Write-Warning "Test paketi: kod $versionCode Play'e zaten yüklenmiş ($maxUploaded). Bu paket Play'e yüklenemez, yalnızca cihaz testi içindir."
}

# 3. Derleme (JDK 17 — Android Studio'nun JDK 25'i Gradle 8.14 ile uyumsuz)
$env:JAVA_HOME = 'D:\dev\jdk-17'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Push-Location $app
try {
  if ($Yayin) { flutter build appbundle --release } else { flutter build apk --release }
  if ($LASTEXITCODE -ne 0) { throw "flutter build başarısız (çıkış kodu $LASTEXITCODE)." }
} finally { Pop-Location }

# 4. Adlandır, kopyala, deftere işle
$date = Get-Date -Format 'yyyy-MM-dd'
$signed = Test-Path (Join-Path $app 'android\key.properties')
$sign = if ($signed) { 'yükleme-anahtarı' } else { 'debug' }
if ($Yayin) {
  $src = Join-Path $app 'build\app\outputs\bundle\release\app-release.aab'
  $name = "ParaIz_v${versionName}_kod${versionCode}_yayin_${date}.aab"
  $kind = 'AAB (Play)'
} else {
  $src = Join-Path $app 'build\app\outputs\flutter-apk\app-release.apk'
  $name = "ParaIz_v${versionName}_kod${versionCode}_test_${sign}-imzali_${date}.apk"
  $kind = 'APK (test)'
}
$dest = Join-Path $outDir $name
Copy-Item $src $dest -Force
$sha = (Get-FileHash $dest -Algorithm SHA256).Hash.Substring(0, 16).ToLower()

$row = "| $name | $versionName | $versionCode | $kind | $sign | $date | ``$sha`` |"
$lines = Get-Content $ledger -Encoding UTF8 | Where-Object { $_ -notmatch [regex]::Escape("| $name |") }
($lines + $row) | Set-Content $ledger -Encoding UTF8

Write-Host "Hazır: $dest"
if ($Yayin) { Write-Host "Play'e yükledikten sonra SURUM_DEFTERI.md'de $versionName / $versionCode satırını 'Play'e yüklendi' yap." }
