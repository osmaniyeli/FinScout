# ParaIz / MoneyTrace - Eksiksiz Tam Proje Yedekleme Scripti
$ErrorActionPreference = "Stop"

$root = (Get-Item "$PSScriptRoot\..").FullName
$backupDate = Get-Date -Format "yyyy-MM-dd"
$desktopPath = (Get-Item "$root\..").FullName
$destinationZip = Join-Path $desktopPath "ParaIz_Moneytrace_TAM_YEDEK_$backupDate.zip"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   ParaIz (MoneyTrace) - Eksiksiz Tam Proje Yedekleme     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Kaynak Dizin      : $root" -ForegroundColor Yellow
Write-Host "Hedef ZIP Dosyasi : $destinationZip" -ForegroundColor Yellow

if (Test-Path $destinationZip) {
    Write-Host "Mevcut eski yedek kaldiriliyor..." -ForegroundColor Gray
    Remove-Item $destinationZip -Force
}

# Kok dizindeki tum dosya ve klasorleri (gizli olanlar dahil) topla
Push-Location $root
try {
    $items = Get-ChildItem -Force | ForEach-Object { $_.Name }
    Write-Host "`nArsivlenecek ana ogeler ($($items.Count) adet):" -ForegroundColor Cyan
    foreach ($item in $items) {
        Write-Host "  + $item" -ForegroundColor Gray
    }

    Write-Host "`ntar.exe ile sikistirma baslatildi, lutfen bekleyin..." -ForegroundColor Cyan
    
    # tar komutunu calistir
    $tarArgs = @("-a", "-cf", $destinationZip) + $items
    & tar.exe @tarArgs

    if ($LASTEXITCODE -ne 0) {
        throw "tar.exe $LASTEXITCODE hata kodu ile sonlandi."
    }

    $zipItem = Get-Item $destinationZip
    $zipSizeMB = [math]::Round($zipItem.Length / 1MB, 2)
    $hash = (Get-FileHash -Path $destinationZip -Algorithm SHA256).Hash

    Write-Host "`nArsiv basariyla olusturuldu!" -ForegroundColor Green
    Write-Host "Dosya Adi    : $($zipItem.Name)" -ForegroundColor Green
    Write-Host "Boyut        : $zipSizeMB MB ($($zipItem.Length) bayt)" -ForegroundColor Green
    Write-Host "SHA-256 Hash : $hash" -ForegroundColor Yellow

    Write-Host "`nKritik dosya kontrolleri gerceklestiriliyor..." -ForegroundColor Cyan
    
    $archiveList = & tar.exe -tf $destinationZip
    $criticalFiles = @(
        "upload-keystore.jks",
        "Oturum bilgileri.txt",
        "YENI_BILGISAYARDA_BASLATMA_KILAVUZU.md",
        ".git/config",
        ".github/workflows/build.yml",
        "moneytrace/lib/main.dart",
        "moneytrace/pubspec.yaml",
        "moneytrace/android/app/build.gradle",
        "Web_Yonetici_Paneli/index.html",
        "Sistem_Dokumantasyonu/README.md"
    )

    $allPassed = $true
    foreach ($file in $criticalFiles) {
        $matched = $archiveList | Where-Object { $_ -replace '\\', '/' -like "*$file*" }
        if ($matched) {
            Write-Host "  [OK] $file" -ForegroundColor Green
        } else {
            Write-Host "  [HATA] $file eksik!" -ForegroundColor Red
            $allPassed = $false
        }
    }

    Write-Host "`nToplam Arsivlenen Dosya/Klasor Sayisi: $($archiveList.Count)" -ForegroundColor Cyan

    if ($allPassed) {
        Write-Host "`n==========================================================" -ForegroundColor Green
        Write-Host "  TEBRIKLER: TUM PROJE EKSIKSIZ YEDEKLENDI!               " -ForegroundColor Green
        Write-Host "  Konum: $destinationZip" -ForegroundColor Green
        Write-Host "==========================================================" -ForegroundColor Green
    } else {
        Write-Host "`nUYARI: Bazi kritik dosyalar arsivde bulunamadi!" -ForegroundColor Red
    }
}
finally {
    Pop-Location
}
