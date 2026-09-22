<#
.SYNOPSIS
    Paraİz Semantik Sürümleme & Otomatik Dağıtım (Release) Aracı.
.DESCRIPTION
    1. moneytrace/pubspec.yaml dosyasından sürüm numarasını okur.
    2. Semantik kurallara göre (patch, minor, major) sürüm ve build numarasını hesaplar.
    3. 100 noktalı otomatik test süitini (verify_parsers.ps1) çalıştırır; testlerden biri bile başarısız olursa işlemi derhal iptal eder.
    4. pubspec.yaml ve CHANGELOG.md dosyalarını günceller.
    5. Git commit oluşturur ve açıklamalı bir sürüm etiketi (vX.Y.Z) basar.
    6. -Push parametresi ile uzaktaki GitHub Actions pipeline'ını tetikler.
.PARAMETER Type
    Sürüm artış tipi: 'patch' (varsayılan), 'minor' veya 'major'.
.PARAMETER TargetVersion
    Özel sürüm numarası belirtmek için (Örn: '3.6.0+5').
.PARAMETER DryRun
    Dosyaları değiştirmeden ve Git işlemi yapmadan simülasyon çıktısı verir.
.PARAMETER Push
    İşlem sonunda 'git push origin main --tags' komutunu çalıştırarak GitHub Actions derlemesini başlatır.
.PARAMETER SkipTests
    Acil durumlar için testleri atlar (Önerilmez).
.EXAMPLE
    .\tools\release.ps1 -DryRun
    .\tools\release.ps1 -Type patch
    .\tools\release.ps1 -Type minor -Push
#>
param (
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Type = 'patch',

    [string]$TargetVersion,
    [switch]$DryRun,
    [switch]$Push,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  PARAIZ (MONEYTRACE) - SURUM & DAGITIM OTOMASYONU      " -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$pubspecPath = Join-Path $repoRoot "moneytrace/pubspec.yaml"
$changelogPath = Join-Path $repoRoot "CHANGELOG.md"
$testScriptPath = Join-Path $repoRoot "moneytrace/test/verify_parsers.ps1"

if (-not (Test-Path $pubspecPath)) {
    Write-Host "pubspec.yaml bulunamadi: $pubspecPath" -ForegroundColor Red
    Exit 1
}

# 1. Mevcut Sürümü Oku
$pubspecContent = [System.IO.File]::ReadAllText($pubspecPath, [System.Text.Encoding]::UTF8)
$versionMatch = [regex]::Match($pubspecContent, 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)')

if (-not $versionMatch.Success) {
    Write-Host "pubspec.yaml icinde gecerli bir version satiri bulunamadi! (Beklenen: major.minor.patch+build)" -ForegroundColor Red
    Exit 1
}

$curMajor = [int]$versionMatch.Groups[1].Value
$curMinor = [int]$versionMatch.Groups[2].Value
$curPatch = [int]$versionMatch.Groups[3].Value
$curBuild = [int]$versionMatch.Groups[4].Value

$currentVersionStr = "$($curMajor).$($curMinor).$($curPatch)+$($curBuild)"
Write-Host "Mevcut Surum : $currentVersionStr (SemVer: $($curMajor).$($curMinor).$($curPatch) | Build: $curBuild)" -ForegroundColor Cyan

# 2. Yeni Sürümü Hesapla
if ($TargetVersion) {
    $targetMatch = [regex]::Match($TargetVersion, '^(\d+)\.(\d+)\.(\d+)\+(\d+)$')
    if (-not $targetMatch.Success) {
        Write-Host "Gecersiz TargetVersion formati: $TargetVersion. (Orn: 3.5.2+3)" -ForegroundColor Red
        Exit 1
    }
    $newMajor = [int]$targetMatch.Groups[1].Value
    $newMinor = [int]$targetMatch.Groups[2].Value
    $newPatch = [int]$targetMatch.Groups[3].Value
    $newBuild = [int]$targetMatch.Groups[4].Value
} else {
    $newBuild = $curBuild + 1
    switch ($Type) {
        'patch' {
            $newMajor = $curMajor
            $newMinor = $curMinor
            $newPatch = $curPatch + 1
        }
        'minor' {
            $newMajor = $curMajor
            $newMinor = $curMinor + 1
            $newPatch = 0
        }
        'major' {
            $newMajor = $curMajor + 1
            $newMinor = 0
            $newPatch = 0
        }
    }
}

$newSemVer = "$($newMajor).$($newMinor).$($newPatch)"
$newFullVersion = "$($newSemVer)+$($newBuild)"
$newTag = "v$newSemVer"

Write-Host "Hedef Surum  : $newFullVersion (Git Tag: $newTag)`n" -ForegroundColor Green

if ($DryRun) {
    Write-Host "[DRY RUN] Simulasyon modu aktif. Dosyalarda ve Git uzerinde degisiklik yapilmadi." -ForegroundColor Yellow
    Write-Host "   Planlanan Surum    : $newFullVersion"
    Write-Host "   Olusturulacak Tag  : $newTag"
    Write-Host "   Calistirilacak Test: $testScriptPath`n"
    Exit 0
}

# 3. Otomatik Test Doğrulaması (Fail-Safe Quality Gate)
if (-not $SkipTests) {
    Write-Host "Adim 1/4: 100 Noktali Kalite Kapisi Test Suiti Kosturuluyor..." -ForegroundColor Cyan
    & powershell -ExecutionPolicy Bypass -File $testScriptPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nHATA: Dogrulama testleri BASARISIZ oldu!" -ForegroundColor Red
        Write-Host "   Surumleme islemi durduruldu. Hicbir dosya degistirilmedi.`n" -ForegroundColor Red
        Exit 1
    }
    Write-Host "`nKalite Kapisi Testleri Basariyla Gecti!`n" -ForegroundColor Green
} else {
    Write-Host "Testler kullanici istegiyle atlandi (-SkipTests).`n" -ForegroundColor Yellow
}

# 4. pubspec.yaml Güncelle
Write-Host "Adim 2/4: pubspec.yaml surum numarasi guncelleniyor..." -ForegroundColor Cyan
$updatedPubspec = [regex]::Replace($pubspecContent, 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newFullVersion", 1)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($pubspecPath, $updatedPubspec, $utf8NoBom)
Write-Host "pubspec.yaml guncellendi: $newFullVersion" -ForegroundColor Green

# 5. Git Commit & Tag
Write-Host "`nAdim 3/4: Git Commit ve Etiket ($newTag) Olusturuluyor..." -ForegroundColor Cyan

# Git stage
& git add moneytrace/pubspec.yaml
if (Test-Path $changelogPath) {
    & git add CHANGELOG.md
}
& git add tools/ Web_Yonetici_Paneli/ moneytrace/test/

$commitMessage = "chore(release): bump version to $newTag (build $newBuild)"
& git commit -m "$commitMessage"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Git commit olusturulamadi (Degisiklik yok veya hata olustu)." -ForegroundColor Yellow
} else {
    Write-Host "Git commit olusturuldu: $commitMessage" -ForegroundColor Green
}

# Annotated Git Tag
& git tag -a "$newTag" -m "ParaIz Release $newTag (Build $newBuild)"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Git etiketi olusturuldu: $newTag" -ForegroundColor Green
} else {
    Write-Host "Git etiketi olusturulurken uyari veya hata olustu." -ForegroundColor Yellow
}

# 6. Uzak Depoya Push & GitHub Actions Tetikleme
if ($Push) {
    Write-Host "`nAdim 4/4: Degisiklikler ve Etiketler GitHub Deposuna Gonderiliyor..." -ForegroundColor Cyan
    & git push origin main
    & git push origin "$newTag"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nBASARILI: $newTag etiketi GitHub Deposuna gonderildi!" -ForegroundColor Green
        Write-Host "   GitHub Actions Pipeline otomatik olarak tetiklendi." -ForegroundColor Cyan
        Write-Host "   APK ve AAB paketleri derlenip GitHub Releases alanina yuklenecektir.`n" -ForegroundColor Cyan
    } else {
        Write-Host "Git push sirasinda bir sorun olustu. Lutfen ag baglantinizi ve izinlerinizi kontrol edin." -ForegroundColor Red
    }
} else {
    Write-Host "`nIPUCU: Degisiklikleri ve $newTag etiketini GitHub Deposuna gondermek icin:" -ForegroundColor Yellow
    Write-Host "   git push origin main --tags" -ForegroundColor White
    Write-Host "   veya: .\tools\release.ps1 -Push`n" -ForegroundColor White
}

Write-Host "Surumleme sureci tamamlandi: $newTag ($newFullVersion)`n" -ForegroundColor Green
Exit 0
