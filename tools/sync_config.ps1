<#
.SYNOPSIS
    Paraİz Remote Config Şema Doğrulama ve Çift Yönlü Senkronizasyon Otomasyonu.
.DESCRIPTION
    Web Yönetici Paneli (Web_Yonetici_Paneli/remote_config.json) ile
    Flutter mobil uygulaması (moneytrace/assets/config/remote_config.json) arasındaki
    yapılandırma dosyalarını şema kontrolünden geçirir, doğrular ve senkronize eder.
.PARAMETER Source
    Senkronizasyonun kaynak tarafı: 'Web' (Web -> Mobil) veya 'App' (Mobil -> Web).
.PARAMETER CheckOnly
    Dosyaları değiştirmeden yalnızca şema geçerliliğini ve senkronizasyon durumunu denetler.
.PARAMETER Force
    Onay sormadan senkronizasyonu gerçekleştirir.
.PARAMETER Format
    JSON içeriğini standart 2-boşluk girintili ve temiz UTF-8 formatında yeniden yazar.
.EXAMPLE
    .\tools\sync_config.ps1 -CheckOnly
    .\tools\sync_config.ps1 -Source Web
    .\tools\sync_config.ps1 -Source App -Force
#>
param (
    [ValidateSet('Web', 'App')]
    [string]$Source,

    [switch]$CheckOnly,
    [switch]$Force,
    [switch]$Format
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  PARAIZ REMOTE CONFIG ŞEMA & SENKRONİZASYON MOTORU     " -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$webConfigPath = Join-Path $repoRoot "Web_Yonetici_Paneli/remote_config.json"
$appConfigPath = Join-Path $repoRoot "moneytrace/assets/config/remote_config.json"

$requiredModules = @(
    'dashboard_summary',
    'statement_upload',
    'cashflow_projection',
    'goals_module',
    'assets_portfolio',
    'market_rates',
    'quick_entry',
    'family_budget',
    'tax_analytics',
    'scout_ai_coach',
    'newsletter_subscription',
    'market_news'
)

function Test-RemoteConfigSchema {
    param (
        [string]$FilePath,
        [string]$Label
    )

    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ [$Label] Dosya bulunamadı: $FilePath" -ForegroundColor Red
        return $false
    }

    try {
        $rawText = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
        $json = $rawText | ConvertFrom-Json
    } catch {
        Write-Host "❌ [$Label] Geçersiz JSON sözdizimi: $_" -ForegroundColor Red
        return $false
    }

    $errors = [System.Collections.Generic.List[string]]::new()

    # 1. Kök Düzey Anahtarlar
    $topKeys = @('clean_data_mode', 'theme', 'menu', 'button', 'modules', 'dynamic_lists')
    foreach ($key in $topKeys) {
        if ($null -eq $json.$key) {
            $errors.Add("Eksik kök anahtar: '$key'")
        }
    }

    # 2. Tema Kontrolleri
    if ($json.theme) {
        $hexRegex = '^#[0-9A-Fa-f]{6}$'
        if ($json.theme.primary_hex -notmatch $hexRegex) {
            $errors.Add("theme.primary_hex geçersiz hex renk: '$($json.theme.primary_hex)'")
        }
        if ($json.theme.income_hex -notmatch $hexRegex) {
            $errors.Add("theme.income_hex geçersiz hex renk: '$($json.theme.income_hex)'")
        }
        if ($json.theme.expense_hex -notmatch $hexRegex) {
            $errors.Add("theme.expense_hex geçersiz hex renk: '$($json.theme.expense_hex)'")
        }
        if ([string]::IsNullOrWhiteSpace($json.theme.palette_name)) {
            $errors.Add("theme.palette_name boş olamaz.")
        }
    }

    # 3. Menü Kontrolleri
    if ($json.menu) {
        if (-not ($json.menu.tab_order -is [System.Collections.IEnumerable])) {
            $errors.Add("menu.tab_order bir dizi (array) olmalıdır.")
        }
        if ($null -eq $json.menu.visible_tabs) {
            $errors.Add("menu.visible_tabs nesnesi eksik.")
        }
    }

    # 4. Buton Kontrolleri
    if ($json.button) {
        $validPositions = @('endFloat', 'centerDocked', 'hidden')
        if ($validPositions -notcontains $json.button.fab_position) {
            $errors.Add("button.fab_position geçersiz: '$($json.button.fab_position)'. Beklenen: endFloat, centerDocked veya hidden")
        }
    }

    # 5. Modül Şalterleri (12 Zorunlu Modül)
    if ($json.modules) {
        foreach ($modKey in $requiredModules) {
            $modObj = $json.modules.$modKey
            if ($null -eq $modObj) {
                $errors.Add("Eksik modül tanımı: modules.$modKey")
            } else {
                if ($null -eq $modObj.enabled) {
                    $errors.Add("modules.$modKey 'enabled' boolean alanı eksik.")
                }
            }
        }
    }

    # 6. Dinamik Listeler
    if ($json.dynamic_lists) {
        $listKeys = @('banks', 'vehicle_brands_models', 'housing_types', 'payment_methods', 'expense_categories', 'goal_types')
        foreach ($lKey in $listKeys) {
            if ($null -eq $json.dynamic_lists.$lKey) {
                $errors.Add("dynamic_lists.$lKey listesi eksik.")
            }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "❌ [$Label] Şema Doğrulama Hataları ($($errors.Count) hata):" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "   • $err" -ForegroundColor Yellow
        }
        return $false
    }

    Write-Host "✅ [$Label] Şema geçerli ve tüm gereksinimler karşılandı." -ForegroundColor Green
    return $true
}

# Web ve Mobil Config Doğrulama
$webValid = Test-RemoteConfigSchema -FilePath $webConfigPath -Label "Web Yönetici Paneli"
$appValid = Test-RemoteConfigSchema -FilePath $appConfigPath -Label "Mobil Uygulama (Assets)"

if (-not $webValid -or -not $appValid) {
    Write-Host "`n❌ Yapılandırma dosyalarından en az birinde şema hatası bulundu!" -ForegroundColor Red
    if ($CheckOnly) {
        Exit 1
    }
}

# Normalize ederek fark karşılaştırması
$webRaw = [System.IO.File]::ReadAllText($webConfigPath, [System.Text.Encoding]::UTF8)
$appRaw = [System.IO.File]::ReadAllText($appConfigPath, [System.Text.Encoding]::UTF8)

$webNormalized = ($webRaw | ConvertFrom-Json) | ConvertTo-Json -Depth 10
$appNormalized = ($appRaw | ConvertFrom-Json) | ConvertTo-Json -Depth 10

$isSynchronized = ($webNormalized -eq $appNormalized)

Write-Host ""
if ($isSynchronized) {
    Write-Host "✨ SENKRONİZASYON DURUMU: Tam Senkron (100% Uyumlu)" -ForegroundColor Green
} else {
    Write-Host "⚠️ SENKRONİZASYON DURUMU: Farklılık Algılandı (Senkronize Değil)" -ForegroundColor Yellow
}

if ($CheckOnly) {
    if ($isSynchronized -and $webValid -and $appValid) {
        Write-Host "`n✅ CheckOnly: Tüm kontroller başarılı, dosyalar senkron.`n" -ForegroundColor Green
        Exit 0
    } else {
        Write-Host "`n❌ CheckOnly: Şema hatası veya içerik uyumsuzluğu mevcut!`n" -ForegroundColor Red
        Exit 1
    }
}

# Senkronizasyon Akışı
if ($isSynchronized -and -not $Format) {
    Write-Host "`nHer iki dosya da zaten birebir aynı. Herhangi bir işlem gerekmiyor." -ForegroundColor Cyan
    Exit 0
}

if (-not $Source) {
    if (-not $isSynchronized) {
        Write-Host "`nLütfen senkronizasyon yönünü belirtin:" -ForegroundColor Yellow
        Write-Host "  -Source Web : Web Yönetici Paneli içeriğini Mobil Uygulamaya aktarır."
        Write-Host "  -Source App : Mobil Uygulama içeriğini Web Yönetici Paneline aktarır."
        Write-Host "Örnek: .\tools\sync_config.ps1 -Source Web"
        Exit 1
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if ($Source -eq 'Web') {
    if (-not $webValid) {
        Write-Host "❌ Web yapılandırması geçersiz olduğu için mobil uygulamaya aktarılamaz!" -ForegroundColor Red
        Exit 1
    }
    Write-Host "`n🔄 Senkronize ediliyor: Web -> Mobil Uygulama..." -ForegroundColor Cyan
    $formattedJson = ($webRaw | ConvertFrom-Json) | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($appConfigPath, $formattedJson, $utf8NoBom)
    Write-Host "✅ Mobil uygulama yapılandırması başarıyla güncellendi: $appConfigPath" -ForegroundColor Green
}
elseif ($Source -eq 'App') {
    if (-not $appValid) {
        Write-Host "❌ Mobil uygulama yapılandırması geçersiz olduğu için web paneline aktarılamaz!" -ForegroundColor Red
        Exit 1
    }
    Write-Host "`n🔄 Senkronize ediliyor: Mobil Uygulama -> Web..." -ForegroundColor Cyan
    $formattedJson = ($appRaw | ConvertFrom-Json) | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($webConfigPath, $formattedJson, $utf8NoBom)
    Write-Host "✅ Web Yönetici Paneli yapılandırması başarıyla güncellendi: $webConfigPath" -ForegroundColor Green
}
elseif ($Format) {
    Write-Host "`n🎨 JSON dosyaları biçimlendiriliyor..." -ForegroundColor Cyan
    $fmtWeb = ($webRaw | ConvertFrom-Json) | ConvertTo-Json -Depth 10
    $fmtApp = ($appRaw | ConvertFrom-Json) | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($webConfigPath, $fmtWeb, $utf8NoBom)
    [System.IO.File]::WriteAllText($appConfigPath, $fmtApp, $utf8NoBom)
    Write-Host "✅ Her iki dosya da standart formatta kaydedildi." -ForegroundColor Green
}

Write-Host "`n🎉 İşlem tamamlandı.`n" -ForegroundColor Green
Exit 0
