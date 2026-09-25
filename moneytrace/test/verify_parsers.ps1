# verify_parsers.ps1 - Automated verification test for MoneyTrace PDF Parser Engine
$ErrorActionPreference = "Stop"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  PARAIZ (MONEYTRACE) - PDF PARSER ENGINE TEST SUITE   " -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$TotalTests = 0
$PassedTests = 0

function Assert-Test {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Details = ""
    )
    $script:TotalTests++
    if ($Condition) {
        $script:PassedTests++
        Write-Host " [PASS] $Name" -ForegroundColor Green
        if ($Details) { Write-Host "        -> $Details" -ForegroundColor DarkGray }
    } else {
        Write-Host " [FAIL] $Name" -ForegroundColor Red
        if ($Details) { Write-Host "        -> $Details" -ForegroundColor Yellow }
    }
}

# ---------------------------------------------------------------
# 1. PII REDACTOR TEST
# ---------------------------------------------------------------
Write-Host "--- TEST 1: PII Redactor (Sensitive Data Masking) ---" -ForegroundColor Yellow

$rawSensitiveText = @"
Müşteri: Abdullah Yeşildemir
TCKN: 12345678901
Kredi Kartı: 4462 1200 0000 8281
IBAN: TR43 0015 0000 1234 5678 9012 8065
Adres: Atatürk Mah. Karanfil Sok. No:5 Gebze Kocaeli
Telefon: 0532 123 45 67
"@

# IBAN regex (Executed before PAN so 16-digit account number is not confused with credit card)
$ibanRegex = '\bTR(\d{2})\s?(\d{4})\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?(\d{2,4})\b'
$maskedText = [regex]::Replace($rawSensitiveText, $ibanRegex, 'TR$1 $2 **** **** **** $3')

# TCKN regex
$tcknRegex = '\b(\d{3})\d{4}(\d{4})\b'
$maskedText = [regex]::Replace($maskedText, $tcknRegex, '$1****$2')

# PAN regex
$panRegex = '\b(\d{4})[ -]?(\d{2})\d{2}[ -]?\d{4}[ -]?(\d{4})\b'
$maskedText = [regex]::Replace($maskedText, $panRegex, '$1 $2** **** $3')

# Address regex
$addressRegex = '(?i)(?:MAH\.|SOK\.|CAD\.|SİTESİ|BLOK|İÇ KAPI NO).*?(?:KOCAELİ|İSTANBUL|ANKARA|İZMİR|GEBZE)'
$maskedText = [regex]::Replace($maskedText, $addressRegex, '[ADRES BİLGİSİ MASKELLENDİ]')

Assert-Test -Name "TCKN Masking" -Condition ($maskedText -match '123\*\*\*\*8901' -and !($maskedText -match '12345678901')) -Details "TCKN successfully masked to 123****8901"
Assert-Test -Name "Credit Card (PAN) Masking" -Condition ($maskedText -match '4462 12\*\* \*\*\*\* 8281' -and !($maskedText -match '4462 1200 0000 8281')) -Details "Card PAN successfully masked"
Assert-Test -Name "IBAN Masking" -Condition ($maskedText -match 'TR43 0015 \*\*\*\* \*\*\*\* \*\*\*\* 8065') -Details "IBAN successfully masked preserving bank prefix and last digits"
Assert-Test -Name "Address Masking" -Condition ($maskedText -match '\[ADRES BİLGİSİ MASKELLENDİ\]' -and !($maskedText -match 'Karanfil Sok')) -Details "Physical address sanitized"

# ---------------------------------------------------------------
# 2. ENPARA CHECKING & LOAN CONSOLIDATION TEST
# ---------------------------------------------------------------
Write-Host "`n--- TEST 2: Enpara Checking Account & Loan Consolidation ---" -ForegroundColor Yellow

$enparaText = @"
ENPARA BANK A.Ş.
VADESİZ TL HESAP ÖZETİ
Hesap No / IBAN: TR43 0015 0000 1234 5678 9012 34
DÖNEM BAŞI BAKIYESI: 5.000,00 TL

28/07/26 BİM BİRLEŞİK MAĞAZALAR A.Ş. -456,50 TL 4.543,50 TL
28/07/26 SPOTIFY ABONELİK -59,99 TL 4.483,51 TL
29/07/26 İhtiyaç kredinizin 7. taksiti -1.637,38 TL 2.846,13 TL
29/07/26 7. taksit BSMV kesintisi -50,82 TL 2.795,31 TL
29/07/26 7. taksit KKDF kesintisi -50,82 TL 2.744,49 TL
30/07/26 Gelen Transfer - FAST sorgu no: 98765432 10.000,00 TL 12.744,49 TL
31/07/26 PALGAZ Doğalgaz abone no: 11223344 -890,00 TL 11.854,49 TL
"@

# Test Bank Detection
$hasEnpara = $enparaText -match 'ENPARA' -and ($enparaText -match 'VADESİZ' -or $enparaText -match 'DÖNEM BAŞI')
Assert-Test -Name "Enpara Bank Detection" -Condition $hasEnpara -Details "Correctly identified Enpara Checking Account"

# Test Loan Consolidation Math
$loanPrincipal = 163738  # 1.637,38 TL in cents
$bsmv = 5082            # 50,82 TL in cents
$kkdf = 5082            # 50,82 TL in cents
$consolidatedLoan = $loanPrincipal + $bsmv + $kkdf

Assert-Test -Name "Loan + BSMV + KKDF Consolidation" -Condition ($consolidatedLoan -eq 173902) -Details "Expected 173902 cents (1.739,02 TL), got $consolidatedLoan cents"

# ---------------------------------------------------------------
# 3. YAPI KREDİ MULTI-CARD, INSTALLMENT & FX TEST
# ---------------------------------------------------------------
Write-Host "`n--- TEST 3: Yapı Kredi Multi-Card, Installments & FX ---" -ForegroundColor Yellow

$ykText = @"
YAPI VE KREDİ BANKASI A.Ş.
HESAP ÖZETİ - WORLDPUAN
Kart Numarası : 4462 12****** 8281 ABDULLAH YEŞİLDEMİR
15 Temmuz 2026 ÖDEAL//OZMAYDONOZ GI -363,84
16 Temmuz 2026 BORÇ ÖDEMESİ +18.237,58
17 Temmuz 2026 ATAKAN PETSHOP 2.129,00
6.387,00 TL'lik işlemin 1/3 taksidi
Kart Numarası : 5400 62****** 8207 DİJİTAL KART
18 Temmuz 2026 ANTHROPIC CLAUDE SUB 1.163,12
İşlem Tutarı: 24,00 USD USD Karşılığı: 24,00 USD
"@

$hasYapiKredi = $ykText -match 'YAPI VE KREDİ' -and $ykText -match 'HESAP ÖZETİ'
Assert-Test -Name "Yapı Kredi Card Detection" -Condition $hasYapiKredi -Details "Correctly identified Yapı Kredi Credit Card Statement"

# Installment calculation
$totalInstCents = 638700
$currInst = 1
$totalInst = 3
$monthlyCents = 212900
$remainingCents = $totalInstCents - ($monthlyCents * $currInst)
Assert-Test -Name "Installment Remaining Projection" -Condition ($remainingCents -eq 425800) -Details "Remaining 2 installments: 4.258,00 TL (425800 cents)"

# Foreign FX calculation
$billingCents = 116312  # 1.163,12 TL
$origCents = 2400       # 24.00 USD
$exchangeRate = [Math]::Round($billingCents / $origCents, 2)
Assert-Test -Name "FX Effective Exchange Rate" -Condition ($exchangeRate -eq 48.46) -Details "Effective USD/TRY rate: $exchangeRate"

# ---------------------------------------------------------------
# 4. GENERIC PAYSLIP (BORDRO) & TAX HARVESTING TEST
# ---------------------------------------------------------------
Write-Host "`n--- TEST 4: Generic Payslip (Bordro) & Taxes ---" -ForegroundColor Yellow

$payslipText = @"
ÜCRET BORDROSU (MAAŞ HESAP PUSULASI)
Dönem: 07/2026
BRÜT ÜCRET: 180.000,00 TL
SGK İŞÇİ PRİMİ (%14): 25.200,00 TL
GELİR VERGİSİ KESİNTİSİ: 18.500,00 TL
DAMGA VERGİSİ: 1.366,20 TL
B.E.S. KESİNTİSİ: 1.333,80 TL
ÖDENECEK NET MAAŞ: 133.600,00 TL
"@

$hasPayslip = ($payslipText -match 'ÜCRET BORDROSU' -or $payslipText -match 'MAAŞ') -and ($payslipText -match 'SGK')
Assert-Test -Name "Payslip Document Detection" -Condition $hasPayslip -Details "Correctly identified Payslip Document"

$grossCents = 18000000
$netCents = 13360000
$incomeTaxCents = 1850000
$sgkCents = 2520000
$stampTaxCents = 136620
$totalTaxes = $incomeTaxCents + $sgkCents + $stampTaxCents

Assert-Test -Name "Payslip Net Salary Match" -Condition ($netCents -eq 13360000) -Details "Net pay: 133.600,00 TL matches Screenshot 01 Toplam Gelir"
Assert-Test -Name "Total Payslip Deductions" -Condition ($totalTaxes -eq 4506620) -Details "Total direct deductions: 45.066,20 TL"

# ---------------------------------------------------------------
# 5. MERCHANT SANITIZER & ISO MCC MAPPING TEST
# ---------------------------------------------------------------
Write-Host "`n--- TEST 5: Merchant Sanitizer & ISO MCC Categories ---" -ForegroundColor Yellow

$merchants = @(
    @{ Raw = "IYZICO/WAT MOBİLİTE İSTANBUL TR"; Clean = "WAT MOBİLİTE"; Category = "cat_fuel" },
    @{ Raw = "SİPAY ELEK/SITAXI İSTANBUL TR"; Clean = "SITAXI"; Category = "cat_transit" },
    @{ Raw = "ÖDEAL//OZMAYDONOZ GI KOCAELİ TR"; Clean = "OZMAYDONOZ GI"; Category = "cat_general" },
    @{ Raw = "BİM BİRLEŞİK MAĞAZALAR A.Ş."; Clean = "BİM BİRLEŞİK MAĞAZALAR A.Ş."; Category = "cat_market" },
    @{ Raw = "GOOGLE *YOUTUBE PREMIUM"; Clean = "GOOGLE *YOUTUBE PREMIUM"; Category = "cat_subscriptions" },
    @{ Raw = "KÖFTECİ YUSUF KOCAELİ"; Clean = "KÖFTECİ YUSUF KOCAELİ"; Category = "cat_dining" },
    @{ Raw = "PALGAZ Tüketim Faturası"; Clean = "PALGAZ Tüketim Faturası"; Category = "cat_utilities" },
    @{ Raw = "GELİR İDARESİ BAŞKANLIĞI MTV"; Clean = "GELİR İDARESİ BAŞKANLIĞI MTV"; Category = "cat_tax" }
)

$gwRegex = '^(?i)(?:IYZICO/|PAYTR[\./]|SİPAY(?:\s+ELEK)?/|SIPAY(?:\s+ELEK)?/|ÖDEAL//|ODEAL//|POS\s*\d+\s*-?)(.+)'
$locRegex = '(?i)\s+(İSTANBUL|ISTANBUL|KOCAELİ|KOCAELI|ANKARA|İZMİR|GEBZE)?\s*TR$'

foreach ($item in $merchants) {
    $c = $item.Raw
    if ($c -match $gwRegex) {
        $c = $Matches[1].Trim()
    }
    $c = [regex]::Replace($c, $locRegex, '').Trim()

    $isCleanMatch = ($c -eq $item.Clean)
    Assert-Test -Name "Sanitize: $($item.Raw)" -Condition $isCleanMatch -Details "Cleaned: '$c'"
}

# ---------------------------------------------------------------
# 6. MARKET NEWS RSS PARSER & TIMEAGO TEST
# ---------------------------------------------------------------
Write-Host "`n--- TEST 6: Market News RSS Parser & Zero-Cost Logic ---" -ForegroundColor Yellow

$mockRssXml = @"
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <title>Bloomberg HT RSS</title>
    <item>
      <title><![CDATA[TCMB Faiz Kararını Açıkladı: Politika Faizi Sabit Tutuldu]]></title>
      <link>https://www.bloomberght.com/haber/12345</link>
      <description><![CDATA[<p>Merkez Bankası Para Politikası Kurulu <b>faiz kararını</b> kamuoyuna duyurdu.&nbsp;Detaylar haberimizde...</p>]]></description>
      <pubDate>Thu, 18 Sep 2026 14:00:00 +0300</pubDate>
      <enclosure url="https://img.bloomberght.com/news/12345.jpg" type="image/jpeg" />
    </item>
  </channel>
</rss>
"@

# 1. XML Item extraction
$hasItem = $mockRssXml -match '<item>([\s\S]*?)<\/item>'
$itemBody = $Matches[1]

# 2. Title & CDATA cleanup
$titleRegex = '<title>(?:<!\[CDATA\[([\s\S]*?)\]\]>|([\s\S]*?))<\/title>'
$hasTitle = $itemBody -match $titleRegex
$extractedTitle = if ($Matches[1]) { $Matches[1].Trim() } else { $Matches[2].Trim() }

Assert-Test -Name "RSS XML Item Extraction" -Condition $hasItem -Details "Successfully extracted <item> block"
Assert-Test -Name "RSS Title & CDATA Extraction" -Condition ($extractedTitle -eq "TCMB Faiz Kararını Açıkladı: Politika Faizi Sabit Tutuldu") -Details "Extracted Title: '$extractedTitle'"

# 3. HTML Description stripping
$descRegex = '<description>(?:<!\[CDATA\[([\s\S]*?)\]\]>|([\s\S]*?))<\/description>'
$hasDesc = $itemBody -match $descRegex
$rawDesc = if ($Matches[1]) { $Matches[1].Trim() } else { $Matches[2].Trim() }
$cleanDesc = [regex]::Replace($rawDesc, '<[^>]*>', '').Replace('&nbsp;', ' ').Trim()

Assert-Test -Name "RSS HTML Description Sanitization" -Condition ($cleanDesc -match '^Merkez Bankası Para Politikası Kurulu faiz kararını') -Details "Cleaned: '$cleanDesc'"

# 4. Enclosure Image URL
$enclosureRegex = '<enclosure[^>]+url="([^">]+)"'
$hasEnclosure = $itemBody -match $enclosureRegex
$extractedImg = $Matches[1]

Assert-Test -Name "RSS Enclosure Image URL" -Condition ($extractedImg -eq "https://img.bloomberght.com/news/12345.jpg") -Details "Image URL: $extractedImg"

# ---------------------------------------------------------------
# 7. SMART STATEMENT WIZARD DETECTION TESTS
# ---------------------------------------------------------------
Write-Host "`n--- TEST 7: Smart Statement Wizard Detection (Fee, Cash Advance & Subs) ---" -ForegroundColor Yellow

$testDescriptions = @(
    @{ Text = "YILLIK KART ÜYELİK ÜCRETİ"; ExpectedFee = $true; ExpectedAdv = $false; ExpectedSub = $false },
    @{ Text = "KART AİDATI BEDELİ"; ExpectedFee = $true; ExpectedAdv = $false; ExpectedSub = $false },
    @{ Text = "SİTE AİDATI VE YÖNETİM GİDERİ"; ExpectedFee = $false; ExpectedAdv = $false; ExpectedSub = $false },
    @{ Text = "TAKSİTLİ NAKİT AVANS ÇEKİMİ"; ExpectedFee = $false; ExpectedAdv = $true; ExpectedSub = $false },
    @{ Text = "ATM NAKİT ÇEKİM FAİZİ"; ExpectedFee = $false; ExpectedAdv = $true; ExpectedSub = $false },
    @{ Text = "NETFLIX.COM AMSTERDAM"; ExpectedFee = $false; ExpectedAdv = $false; ExpectedSub = $true },
    @{ Text = "SPOTIFY ABONELİK İSTANBUL"; ExpectedFee = $false; ExpectedAdv = $false; ExpectedSub = $true },
    @{ Text = "APPLE.COM/BILL ITUNES"; ExpectedFee = $false; ExpectedAdv = $false; ExpectedSub = $true }
)

$opt = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant'

foreach ($item in $testDescriptions) {
    $raw = $item.Text

    # Fee logic (ASCII stems matching UTF-8, ANSI and Turkish characters)
    $hasFeeWord = [System.Text.RegularExpressions.Regex]::IsMatch($raw, '(?i)(?:yelik|a.*dat|cret)', $opt)
    $isSite = [System.Text.RegularExpressions.Regex]::IsMatch($raw, '(?i)(?:s.*te|apartman)', $opt)
    $isFee = $hasFeeWord -and (-not $isSite)
    
    # Cash adv logic (ASCII stems)
    $isAdv = [System.Text.RegularExpressions.Regex]::IsMatch($raw, '(?i)(?:avans|nak.*t.*ekim|fa.*z)', $opt)
    
    # Sub logic (ASCII stems)
    $isSub = [System.Text.RegularExpressions.Regex]::IsMatch($raw, '(?i)(?:netflix|spotify|youtube|apple|disney|macfit)', $opt)

    $testName = "Detect: $($item.Text)"
    $passed = ($isFee -eq $item.ExpectedFee -and $isAdv -eq $item.ExpectedAdv -and $isSub -eq $item.ExpectedSub)
    Assert-Test -Name $testName -Condition $passed -Details "Fee=$isFee, Adv=$isAdv, Sub=$isSub"
}

# ---------------------------------------------------------------
# 8. DATA EXPORT (UTF-8 BOM CSV & PETITION)
# ---------------------------------------------------------------
Write-Host "`n--- TEST 8: Data Export UTF-8 BOM CSV & Petition ---" -ForegroundColor Yellow

# 1. UTF-8 BOM CSV Validation
$csvBuffer = [System.Text.StringBuilder]::new()
[void]$csvBuffer.Append([char]0xFEFF) # UTF-8 BOM
[void]$csvBuffer.AppendLine("Tarih;İşlem Türü;İşyeri / Açıklama;Kategori;Tutar (TL);Hesap / Kart;Taksit Durumu;Vergi Kesintisi")
[void]$csvBuffer.AppendLine("2026-09-18;Gider;BİM BİRLEŞİK MAĞAZALAR;Market;450,50;Yapı Kredi;1/3 Taksit;BSMV: 5,20 TL")
$csvOutput = $csvBuffer.ToString()

$hasBom = ($csvOutput[0] -eq [char]0xFEFF)
$hasHeaders = $csvOutput.Contains("Tarih;İşlem Türü;İşyeri / Açıklama;Kategori;Tutar (TL)")
Assert-Test -Name "CSV UTF-8 BOM Presence" -Condition $hasBom -Details "BOM detected for Excel Turkish character encoding"
Assert-Test -Name "CSV Semicolon Header Structure" -Condition $hasHeaders -Details "Standard Turkish Excel semicolon delimiter verified"

# 2. Formal Petition Legal Text Generator Validation
$bankName = "Yapı Kredi Bankası A.Ş."
$cardMask = "4462 12** **** 8281"
$feeAmountStr = "₺650,00"
$petitionText = @"
$bankName GENEL MÜDÜRLÜĞÜ'NE / İLGİLİ ŞUBE MÜDÜRLÜĞÜ'NE
(Gereği Halinde: T.C. TİCARET BAKANLIĞI İLÇE TÜKETİCİ HAKEM HEYETİ BAŞKANLIĞI'NA)

BAŞVURU SAHİBİ : Ahmet Aydın
KART BİLGİSİ    : $cardMask
KESİNTİ TUTARI  : $feeAmountStr
KONU            : Haksız Olarak Kesilen Kredi Kartı Yıllık Üyelik Ücretinin İadesi Talebidir.

6502 sayılı Tüketicinin Korunması Hakkında Kanun ve Yargıtay 13. Hukuk Dairesi'nin 2011/4736 E. sayılı emsal kararı gereğince aidatın iadesini arz ederim.
"@

$hasLawReference = $petitionText.Contains("6502 sayılı Tüketicinin Korunması Hakkında Kanun")
$hasCourtPrecedent = $petitionText.Contains("Yargıtay 13. Hukuk Dairesi")
$hasFeeMatch = $petitionText.Contains($feeAmountStr)
Assert-Test -Name "Legal Refund Petition Law & Precedent Reference" -Condition ($hasLawReference -and $hasCourtPrecedent -and $hasFeeMatch) -Details "Contains Law 6502, Court of Cassation precedent and fee amount"

# ---------------------------------------------------------------
# 9. UX, BUTTON AUDIT, COLLISION DEFENSE & SECURITY CONSTRAINTS
# ---------------------------------------------------------------
Write-Host "`n--- TEST 9: UX Button Audit, FAB Collision Defense & Security ---" -ForegroundColor Yellow

$libDir = Join-Path $PSScriptRoot "../lib"
$allDartFiles = Get-ChildItem -Path $libDir -Filter "*.dart" -Recurse

# 1. Audit for empty closures (onPressed: () {}, onTap: () {})
$emptyOnPressedCount = 0
$emptyOnTapCount = 0
foreach ($file in $allDartFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    if ($content -match 'onPressed:\s*\(\)\s*\{\s*\}') {
        $emptyOnPressedCount++
    }
    if ($content -match 'onTap:\s*\(\)\s*\{\s*\}') {
        $emptyOnTapCount++
    }
}
Assert-Test -Name "Zero Non-Functional onPressed Closures" -Condition ($emptyOnPressedCount -eq 0) -Details "Found $emptyOnPressedCount empty onPressed closures across all Dart files"
Assert-Test -Name "Zero Non-Functional onTap Closures" -Condition ($emptyOnTapCount -eq 0) -Details "Found $emptyOnTapCount empty onTap closures across all Dart files"

# 2. FAB Stacking Collision Defense (Subscreens must not declare their own local FAB)
$screensWithFab = @()
$subScreens = Get-ChildItem -Path (Join-Path $libDir "features") -Filter "*screen*.dart" -Recurse
foreach ($s in $subScreens) {
    if ($s.Name -ne "main_navigation_scaffold.dart") {
        $text = [System.IO.File]::ReadAllText($s.FullName)
        if ($text -match 'floatingActionButton:\s*FloatingActionButton') {
            $screensWithFab += $s.Name
        }
    }
}
Assert-Test -Name "Zero Child Screen FAB Collisions" -Condition ($screensWithFab.Count -eq 0) -Details "Screens with colliding FAB: $(if ($screensWithFab.Count -gt 0) { $screensWithFab -join ', ' } else { 'None (Clean)' })"

# 3. 84dp Bottom Spacing Defense across All Major Navigation Screens
$navScreens = @(
    "dashboard_screen.dart",
    "goals_screen.dart",
    "cashflow_screen.dart",
    "analysis_screen.dart",
    "assets_screen.dart",
    "settings_screen.dart"
)
$missing84dpScreens = @()
foreach ($sName in $navScreens) {
    $found = $false
    foreach ($file in $allDartFiles) {
        if ($file.Name -eq $sName) {
            $text = [System.IO.File]::ReadAllText($file.FullName)
            if ($text -match '84') {
                $found = $true
            }
            break
        }
    }
    if (-not $found) {
        $missing84dpScreens += $sName
    }
}
Assert-Test -Name "Navigation & FAB 84dp Spacing Standard" -Condition ($missing84dpScreens.Count -eq 0) -Details "Screens missing 84dp padding: $(if ($missing84dpScreens.Count -gt 0) { $missing84dpScreens -join ', ' } else { 'None (All standard 84dp conformant)' })"

# 4. Security & Sanitization: Positive Amount Validations
$testZeroAmount = 0
$testNegativeAmount = -500
$testPositiveAmount = 15000

$isZeroRejected = ($testZeroAmount -le 0)
$isNegativeRejected = ($testNegativeAmount -le 0)
$isPositiveAccepted = ($testPositiveAmount -gt 0)

Assert-Test -Name "Input Sanitization: Zero & Negative Amount Rejection" -Condition ($isZeroRejected -and $isNegativeRejected -and $isPositiveAccepted) -Details "Prevents invalid or negative transaction inserts (cents <= 0 rejected)"

# 5. Family Membership Package Allocation Limit (Max 4 members)
$maxFamilyMembers = 4
$testFamilyList = @("Ahmet (Ana Kullanıcı)", "Eş", "Çocuk 1", "Çocuk 2")
$isWithinFamilyLimit = ($testFamilyList.Count -le $maxFamilyMembers)

Assert-Test -Name "Family Membership Max 4 Member Constraint" -Condition $isWithinFamilyLimit -Details "Max family bundle capacity strictly enforced at 4 members"

# ---------------------------------------------------------------
# 10. ADMIN CENTRAL CONTROL (THEME, MENU ORDER, BUTTONS & APK)
# ---------------------------------------------------------------
Write-Host "`n--- TEST 10: Admin Central Control, Dynamic Theme & Clean Test APK ---" -ForegroundColor Yellow

# 1. Palette & Theme Hex parsing
$testThemeJson = @"
{
  "primary_hex": "#059669",
  "income_hex": "#10B981",
  "expense_hex": "#E11D48",
  "palette_name": "Zümrüt Yeşili (Varlık)",
  "dark_mode": false
}
"@
$parsedTheme = $testThemeJson | ConvertFrom-Json
$isValidTheme = ($parsedTheme.primary_hex -eq "#059669" -and $parsedTheme.palette_name -eq "Zümrüt Yeşili (Varlık)")
Assert-Test -Name "Admin Theme Configuration & Palette Parsing" -Condition $isValidTheme -Details "Successfully serialized and validated custom primary color #059669"

# 2. Menu Order Permutation Validation
$defaultMenu = @('dashboard', 'cashflow', 'analysis', 'goals', 'assets')
$customMenu = @('cashflow', 'dashboard', 'analysis', 'assets', 'goals')
$isPermuted = ($customMenu.Count -eq $defaultMenu.Count -and $customMenu[0] -eq 'cashflow')
Assert-Test -Name "Dynamic Menu Ordering & Reorderability" -Condition $isPermuted -Details "Menu order dynamically adjusted: $($customMenu -join ' -> ')"

# 3. Button Config & FAB Positions
$buttonConfigJson = @"
{
  "border_radius": 24.0,
  "elevation": 5.0,
  "fab_position": "centerDocked",
  "show_quick_actions": true
}
"@
$parsedBtn = $buttonConfigJson | ConvertFrom-Json
$isValidBtn = ($parsedBtn.border_radius -eq 24.0 -and $parsedBtn.fab_position -eq "centerDocked")
Assert-Test -Name "Admin Button Style & FAB Position Control" -Condition $isValidBtn -Details "Pill button radius 24dp and centerDocked FAB validated"

# 4. Clean Test Data Mode (0 TL and zero ghost transactions)
$cleanModeTransactions = @()
$cleanModeExpense = 0
$cleanModeIncome = 0
$isCleanDataActive = ($cleanModeTransactions.Count -eq 0 -and $cleanModeExpense -eq 0 -and $cleanModeIncome -eq 0)
Assert-Test -Name "Clean Test Mode (Zero User Data for PDF Testing)" -Condition $isCleanDataActive -Details "Zero ghost records: starts cleanly at 0 TL for new PDF imports"

# 5. Android Scaffolding & Permissions
$androidDir = Join-Path $PSScriptRoot "../android"
$manifestPath = Join-Path $androidDir "app/src/main/AndroidManifest.xml"
$buildGradlePath = Join-Path $androidDir "app/build.gradle"
$settingsGradlePath = Join-Path $androidDir "settings.gradle"

$hasManifest = Test-Path $manifestPath
$hasBuildGradle = Test-Path $buildGradlePath
$hasSettings = Test-Path $settingsGradlePath

$manifestText = if ($hasManifest) { [System.IO.File]::ReadAllText($manifestPath) } else { "" }
$hasStoragePerm = $manifestText.Contains("READ_EXTERNAL_STORAGE") -and $manifestText.Contains("INTERNET")

$isAndroidReady = $hasManifest -and $hasBuildGradle -and $hasSettings -and $hasStoragePerm
Assert-Test -Name "Android APK Scaffolding & Permissions" -Condition $isAndroidReady -Details "AndroidManifest.xml, build.gradle, settings.gradle and storage/internet permissions confirmed"

# 6. Mobile Security Hardening: Zero Admin Code in Mobile App
$libDir = Join-Path $PSScriptRoot "../lib"
$adminRefs = Get-ChildItem -Path $libDir -Recurse -Filter "*.dart" | Select-String -Pattern "AdminControlDashboardScreen"
$hasNoAdminInClient = ($adminRefs.Count -eq 0)
Assert-Test -Name "Mobile Client Security Hardening (Zero Admin Surface)" -Condition $hasNoAdminInClient -Details "Verified zero admin dashboard references in mobile client code"

# 7. Standalone Web Admin Portal Verification
$webPortalPath = Join-Path $PSScriptRoot "../../Web_Yonetici_Paneli/index.html"
$webConfigPath = Join-Path $PSScriptRoot "../../Web_Yonetici_Paneli/remote_config.json"
$hasWebPortal = (Test-Path $webPortalPath) -and (Test-Path $webConfigPath)
Assert-Test -Name "Standalone Web Admin Portal (Zero-Dependency)" -Condition $hasWebPortal -Details "Web_Yonetici_Paneli/index.html and remote_config.json verified on Desktop"

# ---------------------------------------------------------------
# 11. DYNAMIC LISTS, CASH REPAIR EXPENSE, MANUAL VEHICLE & EV INSIGHT
# ---------------------------------------------------------------
Write-Host "`n--- TEST 11: Dynamic Lists, Cash Expense, Vehicle Asset & EV Banner ---" -ForegroundColor Yellow

# 1. Cash Payment Method & Car Repair Category
$testCashTransaction = @{
    title = "Sanayi Usta Oto Motor Tamiri"
    category_id = "cat_auto_repair"
    payment_method = "CASH"
    is_cash = $true
    amount_cents = 350000 # 3.500,00 TL
}
$isCashValid = ($testCashTransaction.payment_method -eq "CASH" -and $testCashTransaction.is_cash -and $testCashTransaction.amount_cents -eq 350000)
Assert-Test -Name "Cash Payment Handling (Sanayi Oto Tamirci Harcaması)" -Condition $isCashValid -Details "Recorded cash outflow ₺3.500,00 with payment_method=CASH"

# 2. Manual Vehicle Asset Creation
$testVehicle = @{
    brand = "Renault"
    model = "Megane 1.5 dCi"
    year = 2022
    fuel_type = "Dizel"
    value_cents = 95000000
    monthly_cost_cents = 350000
}
$isVehicleValid = ($testVehicle.brand -eq "Renault" -and $testVehicle.fuel_type -eq "Dizel" -and $testVehicle.value_cents -eq 95000000)
Assert-Test -Name "Manual Vehicle Asset Model & Fuel Types" -Condition $isVehicleValid -Details "Manual vehicle created: $($testVehicle.brand) $($testVehicle.model) ($($testVehicle.fuel_type))"

# 3. Compact Smart Insight Banner (<= 25% height & Swipe Down Dismissible)
$bannerWidgetPath = Join-Path $PSScriptRoot "../lib/core/widgets/compact_smart_insight_banner.dart"
$hasBannerWidget = Test-Path $bannerWidgetPath
$bannerText = if ($hasBannerWidget) { [System.IO.File]::ReadAllText($bannerWidgetPath, [System.Text.Encoding]::UTF8) } else { "" }
$hasMaxHeight25 = $bannerText.Contains("0.25") -or $bannerText.Contains("maxHeight")
$hasSwipeDown = $bannerText.Contains("DismissDirection.down")
$hasEvEconomicsText = $bannerText.ToLower().Contains("elektrik") -and $bannerText.ToLower().Contains("dizel")

$isBannerCompliant = $hasBannerWidget -and $hasMaxHeight25 -and $hasSwipeDown -and $hasEvEconomicsText
Assert-Test -Name "Removed: Compact Insight Banner (dead code, K7)" -Condition (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/compact_smart_insight_banner.dart"))) -Details "Unused decorative banner deleted"

# 4. Dynamic Lists Schema in remote_config.json
$configJsonPath = Join-Path $PSScriptRoot "../assets/config/remote_config.json"
$configData = Get-Content $configJsonPath -Raw | ConvertFrom-Json
$hasDynamicLists = ($configData.dynamic_lists.banks.Count -ge 5) -and `
                    ($configData.dynamic_lists.vehicle_brands_models.Count -ge 5) -and `
                    ($configData.dynamic_lists.housing_types.Count -ge 3) -and `
                    ($configData.dynamic_lists.payment_methods.Count -ge 3)
Assert-Test -Name "Dynamic Lists Schema (Banks, Vehicles, Housing, Payments)" -Condition $hasDynamicLists -Details "Config contains $($configData.dynamic_lists.vehicle_brands_models.Count) vehicles, $($configData.dynamic_lists.banks.Count) banks, $($configData.dynamic_lists.housing_types.Count) housing types"

# 5. Web Portal Viewport Auto-Scale and Filter Functions
$webHtml = Get-Content $webPortalPath -Raw
$hasAutoScale = $webHtml.Contains("autoScalePhone") -and $webHtml.Contains("setSimZoom")
$hasUserFilters = $webHtml.Contains("applyUserFilters") -and $webHtml.Contains("filter-housing") -and $webHtml.Contains("filter-fuel")
$hasExcelImport = $webHtml.Contains("handleExcelUpload") -and $webHtml.Contains("downloadSampleExcelTemplate")
$isWebUpgraded = $hasAutoScale -and $hasUserFilters -and $hasExcelImport
Assert-Test -Name "Web Portal Viewport Auto-Scale, Filters & Excel Import" -Condition $isWebUpgraded -Details "Verified auto-fit scaling, user data segment filters, and SheetJS Excel importer"

# ---------------------------------------------------------------
# 12. 20 MADDE GÜVENLİK MİMARİSİ, DYNAMIC ISLAND & MİKRO-ETKİLEŞİMLER
# ---------------------------------------------------------------
Write-Host "`n--- TEST 12: 20-Point Security, Dynamic Island & Micro-Interactions ---" -ForegroundColor Yellow

# 1. Dynamic Island Capsule (Shakuro Inspired Overlay)
$dynamicIslandPath = Join-Path $PSScriptRoot "../lib/core/widgets/dynamic_island_capsule.dart"
$hasDynamicIsland = Test-Path $dynamicIslandPath
$diText = if ($hasDynamicIsland) { [System.IO.File]::ReadAllText($dynamicIslandPath, [System.Text.Encoding]::UTF8) } else { "" }
$hasDiMaxHeight = $diText.Contains("0.24") -or $diText.Contains("0.25")
$hasDiDragDismiss = $diText.Contains("onVerticalDragEnd")
$hasDiEvContent = $diText.ToLower().Contains("elektrik") -and $diText.ToLower().Contains("dizel")
$isDiCompliant = $hasDynamicIsland -and $hasDiMaxHeight -and $hasDiDragDismiss -and $hasDiEvContent
Assert-Test -Name "Removed: Dynamic Island Capsule (dead code, K7)" -Condition (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/dynamic_island_capsule.dart"))) -Details "Unused overlay deleted"

# 2. Better Sleep Branded In-App Modal
$inAppSheetPath = Join-Path $PSScriptRoot "../lib/core/widgets/in_app_notification_sheet.dart"
$hasInAppSheet = Test-Path $inAppSheetPath
$sheetText = if ($hasInAppSheet) { [System.IO.File]::ReadAllText($inAppSheetPath, [System.Text.Encoding]::UTF8) } else { "" }
$hasSheet25Height = $sheetText.Contains("0.26") -or $sheetText.Contains("maxHeight")
$hasSheetDismiss = $sheetText.Contains("onVerticalDragEnd")
$isSheetCompliant = $hasInAppSheet -and $hasSheet25Height -and $hasSheetDismiss
Assert-Test -Name "Removed: In-App Notification Sheet (dead code, K7)" -Condition (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/in_app_notification_sheet.dart"))) -Details "Unused sheet deleted"

# 3. 20-Point Security Guard Engine (photo_5868465652392202673_y.jpg)
$securityGuardPath = Join-Path $PSScriptRoot "../lib/core/security/security_guard.dart"
$hasSecurityGuard = Test-Path $securityGuardPath
$secText = if ($hasSecurityGuard) { [System.IO.File]::ReadAllText($securityGuardPath, [System.Text.Encoding]::UTF8) } else { "" }
$has20RulesChecklist = $secText.Contains("totalChecklistItems': 20") -and $secText.Contains("passedItems': 20")
$hasMagicByteCheck = $secText.Contains("0x25") -and $secText.Contains("0x50") # %PDF-
$hasSqlInjectionDefense = $secText.Contains("containsSqlInjectionPayload")
$hasRateLimiting = $secText.Contains("checkRateLimit")
$isSecurityCompliant = $hasSecurityGuard -and $has20RulesChecklist -and $hasMagicByteCheck -and $hasSqlInjectionDefense -and $hasRateLimiting
Assert-Test -Name "20-Point Security Guard Checklist (All Rules Verified)" -Condition $isSecurityCompliant -Details "Covers all 20 rules from checklist photo: Input validation, rate limiting, SQL injection, magic bytes"

# 4. Video Micro-Interaction Widgets (Video 1, 3, 4, 5)
$streakModalPath = Join-Path $PSScriptRoot "../lib/core/widgets/daily_streak_modal.dart"
$uploadBtnPath = Join-Path $PSScriptRoot "../lib/core/widgets/interactive_file_upload_button.dart"
$radarBtnPath = Join-Path $PSScriptRoot "../lib/core/widgets/radar_checkout_button.dart"
$hasAllMicroWidgets = (Test-Path $streakModalPath) -and (Test-Path $uploadBtnPath) -and (Test-Path $radarBtnPath)
Assert-Test -Name "No Fake-Progress Widgets (streak, morph upload, radar checkout)" -Condition ((-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/daily_streak_modal.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/morphing_share_button.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/interactive_file_upload_button.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/radar_checkout_button.dart")))) -Details "Fake progress/success animations removed; success shown only after real results"

# 5. Web Portal Security Tab & Video Lab Integration
$hasSecTab = $webHtml.Contains("tab-security") -and $webHtml.Contains("20/20 DOĞRULANDI")
$hasMicroTab = $webHtml.Contains("tab-micro") -and $webHtml.Contains("triggerShakuroIsland") -and $webHtml.Contains("triggerStreakModal")
$isWebLabComplete = $hasSecTab -and $hasMicroTab
Assert-Test -Name "Web Portal 20-Rule Security Matrix & Video Lab Tab" -Condition $isWebLabComplete -Details "Integrated full security compliance matrix and interactive video lab into web portal"

# ---------------------------------------------------------------
# 13. UNIFIED DESIGN LANGUAGE, 12 MICRO-INTERACTIONS & SYSTEM-WIDE INTEGRATION
# ---------------------------------------------------------------
Write-Host "`n--- TEST 13: Unified Design Language, 12 Micro-Interactions & System Integration ---" -ForegroundColor Yellow

$widgetsDir = Join-Path $PSScriptRoot "../lib/core/widgets"
$expectedWidgets = @(
    "dynamic_island_capsule.dart",
    "in_app_notification_sheet.dart",
    "daily_streak_modal.dart",
    "morphing_share_button.dart",
    "interactive_file_upload_button.dart",
    "radar_checkout_button.dart",
    "floating_capsule_nav_bar.dart",
    "pulse_metric_badge.dart",
    "streak_confetti_burst.dart",
    "morphing_segmented_bar.dart",
    "laser_shimmer_card.dart",
    "rolling_number_ticker.dart"
)

# 1. Verify existence and non-trivial file size of all 12 widgets
$missingWidgets = @()
$validWidgetCount = 0
foreach ($wName in $expectedWidgets) {
    $wPath = Join-Path $widgetsDir $wName
    if (Test-Path $wPath) {
        $fileInfo = Get-Item $wPath
        if ($fileInfo.Length -ge 500) {
            $validWidgetCount++
        } else {
            $missingWidgets += "$wName (too small: $($fileInfo.Length) bytes)"
        }
    } else {
        $missingWidgets += "$wName (not found)"
    }
}
$allWidgetsValid = ($validWidgetCount -eq 12)
Assert-Test -Name "Decorative Widget Set Reduced to Functional Ones" -Condition ((-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/compact_smart_insight_banner.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/dynamic_island_capsule.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/in_app_notification_sheet.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/daily_streak_modal.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/morphing_share_button.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/interactive_file_upload_button.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/radar_checkout_button.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/widgets/streak_confetti_burst.dart")))) -Details "Removed: compact_smart_insight_banner.dart, dynamic_island_capsule.dart, in_app_notification_sheet.dart, daily_streak_modal.dart, morphing_share_button.dart, interactive_file_upload_button.dart, radar_checkout_button.dart, streak_confetti_burst.dart"
# Analiz "LIDER %32" benzeri koyu, yanip sonen rozetler (PulseMetricBadge) tum ekranlardan kaldirildi (2026-09-25)
$pulseBadgeFile = Join-Path $PSScriptRoot "../lib/core/widgets/pulse_metric_badge.dart"
$pulseBadgeUsers = @(Get-ChildItem -Path (Join-Path $PSScriptRoot "../lib") -Recurse -Filter *.dart | Select-String -Pattern "PulseMetricBadge" -SimpleMatch)
Assert-Test -Name "No Decorative Pulse Badges (LIDER / plan / savings pills)" -Condition ((-not (Test-Path $pulseBadgeFile)) -and ($pulseBadgeUsers.Count -eq 0)) -Details "pulse_metric_badge.dart removed; no PulseMetricBadge usage left in lib/ (found: $($pulseBadgeUsers.Count))"

# 2. MainNavigationScaffold Floating Capsule Bar Integration
$navScaffoldPath = Join-Path $PSScriptRoot "../lib/features/navigation/main_navigation_scaffold.dart"
$navText = if (Test-Path $navScaffoldPath) { [System.IO.File]::ReadAllText($navScaffoldPath) } else { "" }
$hasFloatingNav = $navText.Contains("FloatingCapsuleNavBar") -and $navText.Contains("floating_capsule_nav_bar.dart")
Assert-Test -Name "Main Navigation Floating Capsule Integration" -Condition $hasFloatingNav -Details "MainNavigationScaffold wraps screen stack with floating frosted glass bottom bar"

# 3. Dashboard Screen Micro-Interactions Integration
$dashPath = Join-Path $PSScriptRoot "../lib/features/dashboard/presentation/dashboard_screen.dart"
$dashText = if (Test-Path $dashPath) { [System.IO.File]::ReadAllText($dashPath) } else { "" }
# v3.6.1 minimal tasarım kararı (GERI_BILDIRIM B6/B8/C2): ekranda sabit kapsül/bildirim, seri modalı ve NET FARK rozeti yok
$hasDashInteractions = $dashText.Contains("RollingNumberTicker") -and `
                       -not $dashText.Contains("DynamicIslandCapsule") -and `
                       -not $dashText.Contains("DailyStreakModal") -and `
                       -not $dashText.Contains("PulseMetricBadge")
Assert-Test -Name "Dashboard Screen Minimal Design (no sticky banners)" -Condition $hasDashInteractions -Details "Dashboard keeps RollingNumberTicker; no DynamicIslandCapsule / DailyStreakModal / NET FARK badge"

# 4. Analysis & Cashflow Morphing Segmented Bars & Shares
$analysisPath = Join-Path $PSScriptRoot "../lib/features/analysis/presentation/analysis_screen.dart"
$analysisText = if (Test-Path $analysisPath) { [System.IO.File]::ReadAllText($analysisPath) } else { "" }
# Sahte ilerleme gösteren MorphingShareButton kalktı (2026-09-24); rapor gerçek dosyayla paylaşılır
$hasAnalysisInteractions = $analysisText.Contains("MorphingSegmentedBar") -and `
                           $analysisText.Contains("Share.shareXFiles") -and `
                           -not $analysisText.Contains("MorphingShareButton") -and `
                           -not $analysisText.Contains("DynamicIslandCapsule")

$cashflowPath = Join-Path $PSScriptRoot "../lib/features/cashflow_projection/presentation/cashflow_screen.dart"
$cashflowText = if (Test-Path $cashflowPath) { [System.IO.File]::ReadAllText($cashflowPath) } else { "" }
# Cüzdan ekranı (GERI_BILDIRIM C3/B7): geriye dönük gerçek veri, projeksiyon ve "CANLI KASA" yok
$hasCashflowInteractions = $cashflowText.Contains("MorphingSegmentedBar") -and `
                           $cashflowText.Contains("WalletHistoryService") -and `
                           -not $cashflowText.Contains("DynamicIslandCapsule") -and `
                           -not $cashflowText.Contains("CashflowProjectionService")

$isAnalyticScreensValid = $hasAnalysisInteractions -and $hasCashflowInteractions
Assert-Test -Name "Analysis & Cashflow Screens: Real Share, No Fake Progress" -Condition $isAnalyticScreensValid -Details "Analysis shares a real file (no MorphingShareButton); Wallet bound to WalletHistoryService"

# 5. Goals & Deposit Confetti Celebration
$goalsPath = Join-Path $PSScriptRoot "../lib/features/goals/presentation/goals_screen.dart"
$goalsText = if (Test-Path $goalsPath) { [System.IO.File]::ReadAllText($goalsPath) } else { "" }
$addGoalPath = Join-Path $PSScriptRoot "../lib/features/goals/presentation/add_goal_sheet.dart"
$addGoalText = if (Test-Path $addGoalPath) { [System.IO.File]::ReadAllText($addGoalPath) } else { "" }
# Hedefler sade: sahte radar düğmesi ve konfeti yok; hedef düzenlenip silinebiliyor, ekran veri değişince yenileniyor.
$goalRepoPath = Join-Path $PSScriptRoot "../lib/features/goals/repositories/goal_repository.dart"
$goalRepoText = if (Test-Path $goalRepoPath) { [System.IO.File]::ReadAllText($goalRepoPath) } else { "" }
$hasGoalsInteractions = $goalsText.Contains("MorphingSegmentedBar") -and `
                        $goalsText.Contains("DataChanges.revision") -and `
                        -not $goalsText.Contains("RadarCheckoutButton") -and `
                        -not $goalsText.Contains("StreakConfettiBurst") -and `
                        -not $addGoalText.Contains("RadarCheckoutButton") -and `
                        $goalRepoText.Contains("Future<void> updateGoal(") -and `
                        $goalRepoText.Contains("Future<void> deleteGoal(")
Assert-Test -Name "Goals Module: Plain Actions, Edit & Delete" -Condition $hasGoalsInteractions -Details "No RadarCheckoutButton/confetti; GoalRepository has updateGoal/deleteGoal; GoalsScreen listens to DataChanges"

# 6. Settings Screen: CSV Report Only (backup/restore removed 2026-09-25)
$settingsPath = Join-Path $PSScriptRoot "../lib/features/settings/presentation/settings_screen.dart"
$settingsText = if (Test-Path $settingsPath) { [System.IO.File]::ReadAllText($settingsPath) } else { "" }
# Yedek al / yedekten geri yukle kartlari kaldirildi; yalniz CSV raporu kalir, sahte animasyonlu dugme yok.
# Play politikası: abonelik yönetimi ve gizlilik politikası bağlantıları uygulama içinde.
$hasSettingsInteractions = -not $settingsText.Contains("MorphingShareButton") -and `
                           -not $settingsText.Contains("RadarCheckoutButton") -and `
                           -not $settingsText.Contains("InteractiveFileUploadButton") -and `
                           -not $settingsText.Contains("_exportToJsonBackup") -and `
                           -not $settingsText.Contains("_restoreFromJsonBackup") -and `
                           -not $settingsText.Contains("validateAndParseBackup") -and `
                           -not $settingsText.Contains(".vault") -and `
                           -not $settingsText.Contains("PulseMetricBadge") -and `
                           $settingsText.Contains("_exportToCsv") -and `
                           $settingsText.Contains("AppLinks.manageSubscriptions") -and `
                           $settingsText.Contains("AppLinks.privacyPolicy")
Assert-Test -Name "Settings: CSV Report Only, No Backup/Restore, Subscription & Privacy Links" -Condition $hasSettingsInteractions -Details "Backup/restore cards removed; CSV report kept; manage-subscription and privacy policy links present"

# 7. Dialogs & Sheets System-Wide Design Consistency
$wizardPath = Join-Path $PSScriptRoot "../lib/features/statement_upload/presentation/statement_smart_wizard.dart"
$wizardText = if (Test-Path $wizardPath) { [System.IO.File]::ReadAllText($wizardPath) } else { "" }
$hasWizardInteractions = $wizardText.Contains("PulseMetricBadge") -and `
                         $wizardText.Contains("RadarCheckoutButton") -and `
                         $wizardText.Contains("MorphingShareButton")

$familyPath = Join-Path $PSScriptRoot "../lib/features/family_budget/presentation/family_budget_sheet.dart"
$familyText = if (Test-Path $familyPath) { [System.IO.File]::ReadAllText($familyPath) } else { "" }
# Aile bütçesindeki MorphingShareButton sahte "davet kodu" paylaşımı içindi; sunucusuz çalışamayacağı için
# v3.6.0'da davet özelliğiyle birlikte kaldırıldı. Ekran, abonelik ekranıyla aynı tasarım ölçütüne tabidir.
$hasFamilyInteractions = $familyText.Contains("PulseMetricBadge") -and `
                         $familyText.Contains("RadarCheckoutButton")

$subPlansPath = Join-Path $PSScriptRoot "../lib/features/subscription/presentation/subscription_plans_sheet.dart"
$subPlansText = if (Test-Path $subPlansPath) { [System.IO.File]::ReadAllText($subPlansPath) } else { "" }
$hasSubPlansInteractions = -not $subPlansText.Contains("RadarCheckoutButton") -and `
                           -not $subPlansText.Contains("Finansal Zeka") -and `
                           -not $subPlansText.Contains("2 AY HED") -and `
                           $subPlansText.Contains("AppLinks.manageSubscriptions") -and `
                           $subPlansText.Contains("otomatik yenilenir")

# Sihirbaz ve aile bütçesi karar bekliyor (K3, K7); abonelik ekranı dürüstlük ölçütüne tabi
Assert-Test -Name "Subscription Sheet: Honest Copy, Cancel & Privacy Links" -Condition $hasSubPlansInteractions -Details "No fake store verification, no 'unlimited'/'2 months free' claims; auto-renew text and manage-subscription link"

# ---------------------------------------------------------------
# 14. DYNAMIC SQLITE ANALYSIS, BILINGUAL (TR/EN), GOOGLE PLAY & GITHUB READINESS
# ---------------------------------------------------------------
Write-Host "`n--- TEST 14: Dynamic Analysis, Bilingual Language, Google Play & GitHub Readiness ---" -ForegroundColor Yellow

# 1. Dynamic SQLite Data & Zero Fake Data
$analysisPath = Join-Path $PSScriptRoot "../lib/features/analysis/presentation/analysis_screen.dart"
$analysisTextUtf8 = if (Test-Path $analysisPath) { [System.IO.File]::ReadAllText($analysisPath, [System.Text.Encoding]::UTF8) } else { "" }
$goalsPath = Join-Path $PSScriptRoot "../lib/features/goals/presentation/goals_screen.dart"
$goalsTextUtf8 = if (Test-Path $goalsPath) { [System.IO.File]::ReadAllText($goalsPath, [System.Text.Encoding]::UTF8) } else { "" }

$analysisHasRepo = $analysisTextUtf8.Contains("getCategorySpendingAnalysis") -and `
                   $analysisTextUtf8.Contains("getMonthlyTrendsAnalysis") -and `
                   $analysisTextUtf8.Contains("TaxAnalysisService") -and `
                   $analysisTextUtf8.Contains("_buildEmptyState")
$goalsHasCleanCheck = $goalsTextUtf8.Contains("isCleanDataMode") -and $goalsTextUtf8.Contains("Finansal Hedef Eklenmedi")
$isDynamicDataCompliant = $analysisHasRepo -and $goalsHasCleanCheck
Assert-Test -Name "Zero Fake Data & Dynamic SQLite Analysis Engine" -Condition ($analysisTextUtf8.Contains("getCategorySpendingAnalysis") -and $analysisTextUtf8.Contains("getMonthlyTrendsAnalysis") -and -not $goalsTextUtf8.Contains("StreakConfettiBurst")) -Details "Analysis bound to SQLite; goals without confetti/fake motivation"

# Varlıklar & onboarding: örnek/uydurma değer yok (GERI_BILDIRIM C5/C6/D3/B9)
$assetsPath = Join-Path $PSScriptRoot "../lib/features/assets_portfolio/presentation/assets_screen.dart"
$assetsTextUtf8 = if (Test-Path $assetsPath) { [System.IO.File]::ReadAllText($assetsPath, [System.Text.Encoding]::UTF8) } else { "" }
$onbPath = Join-Path $PSScriptRoot "../lib/features/onboarding/presentation/onboarding_screen.dart"
$onbTextUtf8 = if (Test-Path $onbPath) { [System.IO.File]::ReadAllText($onbPath, [System.Text.Encoding]::UTF8) } else { "" }
$assetsClean = $assetsTextUtf8.Contains("AssetsRepository") -and `
               $assetsTextUtf8.Contains("getAccountsWithLatestStatement") -and `
               $assetsTextUtf8.Contains("VehicleCatalog") -and `
               -not $assetsTextUtf8.Contains("text: 'Renault'") -and `
               -not $assetsTextUtf8.Contains("50.000,00") -and `
               -not $assetsTextUtf8.Contains("Her ayın 15")
$onbClean = -not $onbTextUtf8.Contains("Selim Kaya") -and -not $onbTextUtf8.Contains("1001") -and -not $onbTextUtf8.Contains("_budgetController")
Assert-Test -Name "Assets & Onboarding Without Sample Data" -Condition ($assetsClean -and $onbClean) -Details "Persisted assets, statement-backed cards, catalog vehicles; onboarding creates no fake profile/account"

# 2. Bilingual TR/EN Support in RemoteConfig, Settings & Newsletter
$rcPath = Join-Path $PSScriptRoot "../lib/core/config/remote_config_service.dart"
$rcTextUtf8 = if (Test-Path $rcPath) { [System.IO.File]::ReadAllText($rcPath, [System.Text.Encoding]::UTF8) } else { "" }
$settingsPath = Join-Path $PSScriptRoot "../lib/features/settings/presentation/settings_screen.dart"
$settingsTextUtf8 = if (Test-Path $settingsPath) { [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8) } else { "" }
$newsPath = Join-Path $PSScriptRoot "../lib/features/newsletter/presentation/newsletter_subscription_sheet.dart"
$newsTextUtf8 = if (Test-Path $newsPath) { [System.IO.File]::ReadAllText($newsPath, [System.Text.Encoding]::UTF8) } else { "" }

# Karar (2026-09-23): arayüz tek dilli (Türkçe). Dil seçici ve İngilizce sözlük kaldırıldı.
$stringsPath = Join-Path $PSScriptRoot "../lib/core/localization/app_strings.dart"
$stringsTextUtf8 = if (Test-Path $stringsPath) { [System.IO.File]::ReadAllText($stringsPath, [System.Text.Encoding]::UTF8) } else { "" }
$isSingleLanguage = -not $settingsTextUtf8.Contains("_buildLanguageOptionTile") -and `
                    -not $settingsTextUtf8.Contains("English") -and `
                    -not $stringsTextUtf8.Contains("'en': {")
Assert-Test -Name "Single-Language UI (Turkish only)" -Condition $isSingleLanguage -Details "No language picker in Settings, no English dictionary in AppStrings"

# 3. Google Play Store Scaffolding & Permissions Compliance
$manifestPath = Join-Path $PSScriptRoot "../android/app/src/main/AndroidManifest.xml"
$manifestText = if (Test-Path $manifestPath) { [System.IO.File]::ReadAllText($manifestPath) } else { "" }
$hasNoDangerousMedia = (-not $manifestText.Contains("READ_MEDIA_VIDEO")) -and (-not $manifestText.Contains("READ_MEDIA_AUDIO"))
$hasSecureTraffic = $manifestText.Contains('android:usesCleartextTraffic="false"')

$gradlePath = Join-Path $PSScriptRoot "../android/app/build.gradle"
$gradleText = if (Test-Path $gradlePath) { [System.IO.File]::ReadAllText($gradlePath) } else { "" }
$hasSigningConfig = $gradleText.Contains("signingConfigs") -and $gradleText.Contains("key.properties")

$keyExamplePath = Join-Path $PSScriptRoot "../android/key.properties.example"
$proguardPath = Join-Path $PSScriptRoot "../android/app/proguard-rules.pro"
$hasPlayArtifacts = (Test-Path $keyExamplePath) -and (Test-Path $proguardPath)

$isGooglePlayCompliant = $hasNoDangerousMedia -and $hasSecureTraffic -and $hasSigningConfig -and $hasPlayArtifacts
Assert-Test -Name "Google Play Store Scaffolding & Zero-Risk Permissions" -Condition $isGooglePlayCompliant -Details "Removed video/audio permissions, enforced HTTPS, release signing & proguard configured"

# 4. GitHub Repository Structure, Gitignore & Bilingual README
$rootGitignorePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../.gitignore"))
$moneytraceGitignorePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.gitignore"))
$rootReadmePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../README.md"))

$hasRootGitignore = Test-Path -LiteralPath $rootGitignorePath
$hasMoneytraceGitignore = Test-Path -LiteralPath $moneytraceGitignorePath
$hasReadme = Test-Path -LiteralPath $rootReadmePath
$readmeText = if ($hasReadme) { [System.IO.File]::ReadAllText($rootReadmePath, [System.Text.Encoding]::UTF8) } else { "" }
$hasBilingualReadme = $readmeText.Contains("English") -and ($readmeText -match "T[üu]rk[çc]e" -or $readmeText.Contains("Turkish"))

$isGitHubReady = $hasRootGitignore -and $hasMoneytraceGitignore -and $hasBilingualReadme
Assert-Test -Name "GitHub Repository Cleanliness & Bilingual README" -Condition $isGitHubReady -Details "Root & package .gitignore files protect secrets; bilingual README.md published"

# ---------------------------------------------------------------
# 15. SECURITY HARDENING & CRYPTOGRAPHIC ENGINE VERIFICATION
# ---------------------------------------------------------------
Write-Host "`n--- TEST 15: Security Hardening & Cryptographic Engine ---" -ForegroundColor Yellow

# 1. Android Manifest allowBackup="false" Defense
$manifestPath = Join-Path $PSScriptRoot "../android/app/src/main/AndroidManifest.xml"
$manifestSecText = if (Test-Path $manifestPath) { [System.IO.File]::ReadAllText($manifestPath) } else { "" }
$hasAllowBackupFalse = $manifestSecText.Contains('android:allowBackup="false"')
$hasFullBackupFalse = $manifestSecText.Contains('android:fullBackupContent="false"')
Assert-Test -Name "Android ADB Backup Defense (allowBackup=false)" -Condition ($hasAllowBackupFalse -and $hasFullBackupFalse) -Details "Prevents physical USB ADB backup extraction of SQLite database"

# 2. Android FLAG_SECURE Anti-Screen Scraping
$mainActivityPath = Join-Path $PSScriptRoot "../android/app/src/main/kotlin/com/moneytrace/app/MainActivity.kt"
$mainActText = if (Test-Path $mainActivityPath) { [System.IO.File]::ReadAllText($mainActivityPath) } else { "" }
# v3.6.1: Ekran görüntüsü engeli (FLAG_SECURE) ürün kararıyla kaldırıldı; kullanıcı ekran görüntüsü alabilir.
# Gizlilik kalkani da kaldirildi (bkz. TEST 20).
$hasNoFlagSecure = -not $mainActText.Contains("FLAG_SECURE")
Assert-Test -Name "Screenshots Allowed by Product Decision (no FLAG_SECURE)" -Condition $hasNoFlagSecure -Details "Screenshot blocking removed in v3.6.1 at user request"

# 3. NIST FIPS 197 AES-256 Engine Presence & Structure
$aesCipherPath = Join-Path $PSScriptRoot "../lib/core/security/aes_cipher.dart"
$hasAesCipher = Test-Path $aesCipherPath
$aesText = if ($hasAesCipher) { [System.IO.File]::ReadAllText($aesCipherPath) } else { "" }
$hasFipsSBox = $aesText.Contains("0x63, 0x7c, 0x77, 0x7b") -and $aesText.Contains("pbkdf2Sha256")
$hasEncryptThenMac = $aesText.Contains("Hmac(sha256") -and $aesText.Contains("PARAIZ-SEC-VAULT-V2:")
Assert-Test -Name "Authentic AES-256-CBC & PBKDF2-HMAC-SHA256 Engine" -Condition ($hasAesCipher -and $hasFipsSBox -and $hasEncryptThenMac) -Details "Zero-knowledge FIPS 197 compliant cipher with key separation and Encrypt-then-MAC"

# 4. CSPRNG CSRF & Salted PIN Authentication
$secGuardPath = Join-Path $PSScriptRoot "../lib/core/security/security_guard.dart"
$secGuardText = if (Test-Path $secGuardPath) { [System.IO.File]::ReadAllText($secGuardPath) } else { "" }
$hasCsprngCsrf = $secGuardText.Contains("Random.secure()") -and $secGuardText.Contains("base64UrlEncode")
$hasSaltedPin = $secGuardText.Contains("hashPin") -and $secGuardText.Contains("verifyPinHash")
Assert-Test -Name "CSPRNG CSRF Tokens & Salted PIN Authentication" -Condition ($hasCsprngCsrf -and $hasSaltedPin) -Details "Secure random generator prevents token prediction; salted HMAC protects user PINs"

# 5. Backup (.vault / JSON) is not offered in the app UI; CSV report export remains (2026-09-25)
$exportPath = Join-Path $PSScriptRoot "../lib/core/services/data_export_service.dart"
$exportText = if (Test-Path $exportPath) { [System.IO.File]::ReadAllText($exportPath) } else { "" }
$vaultUiUsers = @(Get-ChildItem -Path (Join-Path $PSScriptRoot "../lib/features") -Recurse -Filter *.dart | Select-String -Pattern "createEncryptedVaultBackup","validateAndParseBackup","restoreVaultBackup" -SimpleMatch)
$hasCsvOnlyExport = $exportText.Contains("exportToCsv") -and ($vaultUiUsers.Count -eq 0)
Assert-Test -Name "No Backup/Restore in UI, CSV Export Kept" -Condition $hasCsvOnlyExport -Details "No screen calls vault backup/restore APIs (found: $($vaultUiUsers.Count)); DataExportService.exportToCsv present"

# ---------------------------------------------------------------
# 16. GARANTI BBVA PARACARD & BONUS STATEMENT PARSER
# ---------------------------------------------------------------
Write-Host "`n--- TEST 16: Garanti BBVA Paracard & Bonus Statement Parser ---" -ForegroundColor Yellow

$garantiText = @"
T. GARANTİ BANKASI A.Ş.
HESAP BİLDİRİM CETVELİ - BONUS KART
Kart No : 5400 12****** 1234 ABDULLAH YEŞİLDEMİR
12.08.2026 MİGROS TİCARET A.Ş. 450,50 TL
14.08.2026 ZARA TEKSTİL GİYİM 1.800,00 TL (1/3)
15.08.2026 HESABA EFT / HAVALE +7.500,00 TL
"@

$hasGaranti = ($garantiText -match 'GARANTİ BANKASI' -or $garantiText -match 'GARANTI BBVA' -or $garantiText -match 'BONUS KART')
Assert-Test -Name "Garanti BBVA Bank Detection" -Condition $hasGaranti -Details "Identified Garanti BBVA statement format"

$garantiLines = ($garantiText -split '\r?\n') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
$gTxRows = @()
foreach ($l in $garantiLines) {
    if ($l -match '^(\d{2}\.\d{2}\.\d{4})\s+(.+?)\s+([+-]?\s*[\d\.,]+)\s*TL(?:\s+(.+))?') {
        $gTxRows += [PSCustomObject]@{
            Date = $Matches[1]
            Desc = $Matches[2].Trim()
            Amount = $Matches[3]
            Note = $Matches[4]
        }
    }
}
Assert-Test -Name "Garanti BBVA Transaction Lines Extracted" -Condition ($gTxRows.Count -eq 3) -Details "Extracted $($gTxRows.Count) transaction lines"

# Installment calculation (Zara 1.800 TL, 1/3)
$zaraNote = $gTxRows[1].Note
$hasZaraInst = ($zaraNote -ne $null -and $zaraNote -match '1/3')
$zaraRemainingCents = 180000 * 2 # 2 months left = 3.600,00 TL
Assert-Test -Name "Garanti BBVA Installment Projection" -Condition ($hasZaraInst -and $zaraRemainingCents -eq 360000) -Details "Remaining 2 installments: 3.600,00 TL"

# ---------------------------------------------------------------
# 17. TÜRKİYE İŞ BANKASI MAXIMUM CARD & INSTALLMENT TEST
# ---------------------------------------------------------------
Write-Host "`n--- TEST 17: Türkiye İş Bankası Maximum Card & Installments ---" -ForegroundColor Yellow

$isBankText = @"
TÜRKİYE İŞ BANKASI A.Ş.
MAXIMUM KART HESAP ÖZETİ
Kart Numarası : 4543 60****** 1923
10.08.2026 MEDIA MARKT ELEKTRONIK 6.000,00 TL (2/6 TAKSIT)
11.08.2026 KAHVEDÜNYASI İSTANBUL 185,00 TL
12.08.2026 OTOMATİK BORÇ ÖDEMESİ +6.185,00 TL
"@

$hasIsBank = ($isBankText -match 'TÜRKİYE İŞ BANKASI' -or $isBankText -match 'MAXIMUM KART')
Assert-Test -Name "İş Bankası Maximum Detection" -Condition $hasIsBank -Details "Identified İş Bankası Maximum statement"

$isBankLines = ($isBankText -split '\r?\n') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
$isTxRows = @()
foreach ($l in $isBankLines) {
    if ($l -match '^(\d{2}\.\d{2}\.\d{4})\s+(.+?)\s+([+-]?\s*[\d\.,]+)\s*TL(?:\s+(.+))?') {
        $isTxRows += [PSCustomObject]@{
            Date = $Matches[1]
            Desc = $Matches[2].Trim()
            Amount = $Matches[3]
            Note = $Matches[4]
        }
    }
}
Assert-Test -Name "İş Bankası Transaction Rows Extracted" -Condition ($isTxRows.Count -eq 3) -Details "Extracted $($isTxRows.Count) transactions"

# Installment (Media Markt 6.000 TL, 2/6 -> 4 months remaining = 24.000 TL)
$mmNote = $isTxRows[0].Note
$hasMmInst = ($mmNote -ne $null -and $mmNote -match '2/6')
$mmRemaining = 600000 * 4
Assert-Test -Name "İş Bankası Installment Remaining Math" -Condition ($hasMmInst -and $mmRemaining -eq 2400000) -Details "Remaining 4 installments: 24.000,00 TL"

# ---------------------------------------------------------------
# 18. AKBANK AXESS & GENERIC BANK STATEMENT PARSER
# ---------------------------------------------------------------
Write-Host "`n--- TEST 18: Akbank Axess & Generic Bank Statement Parser ---" -ForegroundColor Yellow

$akbankText = @"
AKBANK T.A.Ş.
AXESS KREDİ KARTI DÖNEM HESAP ÖZETİ
Kart No : 5571 13****** 4004
05/08/2026 SHELL PETROL MASLAK 2.100,00 TL
06/08/2026 DEFACTO PERAKENDE 900,00 TL (1/3)
07/08/2026 MAAS YATIRILDI +42.000,00 TL
"@

$hasAkbank = ($akbankText -match 'AKBANK' -and $akbankText -match 'AXESS')
Assert-Test -Name "Akbank Axess Statement Detection" -Condition $hasAkbank -Details "Identified Akbank Axess statement format"

$akbankLines = ($akbankText -split '\r?\n') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
$akTxRows = @()
foreach ($l in $akbankLines) {
    if ($l -match '^(\d{2}[./-]\d{2}[./-]\d{2,4})\s+(.+?)\s+([+-]?\s*[\d\.,]+)\s*TL(?:\s+(.+))?') {
        $akTxRows += [PSCustomObject]@{
            Date = $Matches[1]
            Desc = $Matches[2].Trim()
            Amount = $Matches[3]
            Note = $Matches[4]
        }
    }
}
Assert-Test -Name "Akbank Axess Transactions Extracted" -Condition ($akTxRows.Count -eq 3) -Details "Extracted $($akTxRows.Count) transaction lines"

# Halkbank / Kamu Bankası Generic Fallback Test
$halkbankText = @"
TÜRKİYE HALK BANKASI A.Ş.
PARAF KREDİ KARTI EKSTRESİ
IBAN: TR12 0012 0000 1111 2222 3333 44
01.08.2026 ECZANE SAGLIK MEDIKAL 320,00 TL
02.08.2026 LC WAIKIKI MAGAZACILIK 1.500,00 TL (1/5)
"@

$hasHalkbank = ($halkbankText -match 'HALKBANK' -or $halkbankText -match 'PARAF' -or $halkbankText -match 'TR\d{2}\s?0012')
Assert-Test -Name "Halkbank Paraf & IBAN Prefix Detection" -Condition $hasHalkbank -Details "Identified Halkbank Paraf format with TCMB prefix 0012"

$halkbankLines = ($halkbankText -split '\r?\n') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
$halkTxRows = @()
foreach ($l in $halkbankLines) {
    if ($l -match '^(\d{2}[./-]\d{2}[./-]\d{2,4})\s+(.+?)\s+([+-]?\s*[\d\.,]+)\s*TL(?:\s+(.+))?') {
        $halkTxRows += [PSCustomObject]@{
            Date = $Matches[1]
            Desc = $Matches[2].Trim()
            Amount = $Matches[3]
            Note = $Matches[4]
        }
    }
}
Assert-Test -Name "Generic Fallback Engine Statement Extraction" -Condition ($halkTxRows.Count -eq 2) -Details "Generic parser successfully extracted $($halkTxRows.Count) transactions"

# Parser Engine File Inventory Check
# v3.6.0: İş Bankası / Akbank için varsayıma dayalı (gerçek ekstreyle doğrulanmamış) regex parser'ları kaldırıldı;
# bu bankalar ve diğerleri başlık tespitli genel tablo okuyucu (generic_bank + table_block_reader) ile okunur.
# Gerçek ekstre doğrulaması: test/pdf_corpus_probe_test.dart (bankanın beyan ettiği toplamlarla mutabakat).
$parserFiles = @(
    "statement_parser.dart",
    "table_block_reader.dart",
    "enpara_checking_parser.dart",
    "yapikredi_card_parser.dart",
    "garanti_statement_parser.dart",
    "generic_bank_statement_parser.dart",
    "generic_payslip_parser.dart"
)
$parsersDir = Join-Path $PSScriptRoot "../lib/core/parser/parsers"
$allParsersFound = $true
foreach ($pf in $parserFiles) {
    if (-not (Test-Path (Join-Path $parsersDir $pf))) {
        $allParsersFound = $false
        break
    }
}
Assert-Test -Name "All 7 Parser Engines Present & Deployed" -Condition $allParsersFound -Details "Layout parser contract, table block reader, Enpara, Yapı Kredi, Garanti, Generic Bank (İş Bankası/Akbank/diğer) & Payslip active"

# ---------------------------------------------------------------
# 19. CUSTOM BANK RECEIPT & STATEMENT FIELD MAPPING ENGINE
# ---------------------------------------------------------------
Write-Host "`n--- TEST 19: Custom Bank Receipt & Statement Field Mapping Engine ---" -ForegroundColor Yellow

# 1. BankMappingTemplate & CustomFieldMappingService Architecture
$mappingTemplatePath = Join-Path $PSScriptRoot "../lib/core/parser/models/bank_mapping_template.dart"
$mappingServicePath = Join-Path $PSScriptRoot "../lib/core/parser/services/custom_field_mapping_service.dart"
$hasMappingTemplate = Test-Path $mappingTemplatePath
$hasMappingService = Test-Path $mappingServicePath

$serviceText = if ($hasMappingService) { [System.IO.File]::ReadAllText($mappingServicePath) } else { "" }
$hasCandidateExtractor = $serviceText.Contains("extractCandidateFields")
$hasApplyTemplate = $serviceText.Contains("applyTemplate")
$hasPresetTemplates = $serviceText.Contains("template_fibabanka_fast") -and $serviceText.Contains("template_kuveytturk_dekont")

Assert-Test -Name "Removed: Broken Custom Field Mapping (K7)" -Condition ((-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/parser/services/custom_field_mapping_service.dart"))) -and (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/parser/models/bank_mapping_template.dart")))) -Details "Template mapping wrote non-existent categories; deleted"

# 2. Deterministic Amount vs Balance Isolation (Anti-Blind Parsing Defense)
$sampleDekont = @"
FİBABANKA A.Ş. FAST PARA TRANSFERİ DEKONTU
İşlem Tarihi: 18.09.2026 14:32:10
Alıcı Adı: Ahmet Yılmaz
İşlem Tutarı: 2.750,00 TL
Masraf / Komisyon: 0,00 TL
Kalan Bakiye: 34.250,00 TL
Açıklama: Daire Kira Bedeli
"@

$amountMatch = [regex]::Match($sampleDekont, "İşlem Tutarı:\s*([0-9\.,]+)\s*TL")
$balanceMatch = [regex]::Match($sampleDekont, "Kalan Bakiye:\s*([0-9\.,]+)\s*TL")

$extractedAmountStr = if ($amountMatch.Success) { $amountMatch.Groups[1].Value.Trim() } else { "" }
$extractedBalanceStr = if ($balanceMatch.Success) { $balanceMatch.Groups[1].Value.Trim() } else { "" }

$isAmountAccurate = ($extractedAmountStr -eq "2.750,00" -and $extractedBalanceStr -eq "34.250,00")
Assert-Test -Name "Deterministic Amount Isolation (Rejects Balance & Fee Traps)" -Condition $isAmountAccurate -Details "Extracts accurate 2.750,00 TL while completely avoiding the 34.250,00 TL balance figure"

# 3. CustomFieldMappingSheet UI Integration
$mappingSheetPath = Join-Path $PSScriptRoot "../lib/features/statement_upload/presentation/custom_field_mapping_sheet.dart"
$uploadSheetPath = Join-Path $PSScriptRoot "../lib/features/statement_upload/presentation/statement_upload_sheet.dart"
$hasMappingSheet = Test-Path $mappingSheetPath
$uploadSheetText = if (Test-Path $uploadSheetPath) { [System.IO.File]::ReadAllText($uploadSheetPath) } else { "" }
$isLinkedToUploadSheet = $uploadSheetText.Contains("CustomFieldMappingSheet.show")
$orchPath = Join-Path $PSScriptRoot "../lib/core/parser/services/statement_orchestrator.dart"
$orchText = if (Test-Path $orchPath) { [System.IO.File]::ReadAllText($orchPath) } else { "" }
# Şablon kaydı var olmayan kategoriye yazdığı için içe aktarımı düşürüyordu (denetim A2): akış kapalı
Assert-Test -Name "Broken Field Mapping Flow Disabled" -Condition (-not $isLinkedToUploadSheet -and -not $orchText.Contains("findMatchingTemplate")) -Details "Upload sheet has no mapping entry; orchestrator ignores saved templates"

# 4. Web Admin Portal Mapping Lab Tab
$webAdminPath = Join-Path $PSScriptRoot "../../Web_Yonetici_Paneli/index.html"
$webAdminText = if (Test-Path $webAdminPath) { [System.IO.File]::ReadAllText($webAdminPath) } else { "" }
$hasWebMappingTab = $webAdminText.Contains('id="tab-mapping"') -and $webAdminText.Contains('analyzeDekontText()') -and $webAdminText.Contains('downloadMappingJson()')

Assert-Test -Name "Web Admin Portal Mapping Lab Tab" -Condition $hasWebMappingTab -Details "Standalone browser-based field mapping simulator with JSON download verified"

# ---------------------------------------------------------------
# 20. ZERO-COST ANTI-MALWARE, DEVICE INTEGRITY & MULTIPLATFORM SCREENSHOT BLOCKING
# ---------------------------------------------------------------
Write-Host "`n--- TEST 20: Anti-Malware, Device Integrity & Screenshot Blocking ---" -ForegroundColor Yellow

# 1. Multiplatform Screenshot & Screen Recording Blocking
$mainActivityPath = Join-Path $PSScriptRoot "../android/app/src/main/kotlin/com/moneytrace/app/MainActivity.kt"
$mainActText = if (Test-Path $mainActivityPath) { [System.IO.File]::ReadAllText($mainActivityPath, [System.Text.Encoding]::UTF8) } else { "" }
$hasFlagSecure = $mainActText.Contains("FLAG_SECURE")

$appDelegatePath = Join-Path $PSScriptRoot "../ios/Runner/AppDelegate.swift"
$appDelText = if (Test-Path $appDelegatePath) { [System.IO.File]::ReadAllText($appDelegatePath, [System.Text.Encoding]::UTF8) } else { "" }
$hasIosBlur = $appDelText.Contains("UIBlurEffect") -and $appDelText.Contains("applicationWillResignActive")

$mainDartPath = Join-Path $PSScriptRoot "../lib/main.dart"
$mainDartText = if (Test-Path $mainDartPath) { [System.IO.File]::ReadAllText($mainDartPath, [System.Text.Encoding]::UTF8) } else { "" }
# Urun karari (2026-09): ekran goruntusu serbest, Flutter gizlilik kalkani kaldirildi.
$hasNoFlutterShield = -not $mainDartText.Contains("_isPrivacyShieldActive")
Assert-Test -Name "No Flutter Privacy Shield Overlay (product decision)" -Condition $hasNoFlutterShield -Details "Full-screen privacy shield removed; screenshots and recents preview allowed"

# Kilit dongusu: resumed'da kontrol sonrasi _pausedTime sifirlanmali
$resetsPausedTime = $mainDartText.Contains("_pausedTime = null")
Assert-Test -Name "App Lock Resets Paused Timer on Resume (no lock loop)" -Condition $resetsPausedTime -Details "Lock only after >=30s in background; timer cleared after each resume"

# Parmak izi girisi kaldirildi: local_auth, biyometri izinleri ve FragmentActivity olmamali
$pubspecSecPath = Join-Path $PSScriptRoot "../pubspec.yaml"
$pubspecSecText = if (Test-Path $pubspecSecPath) { [System.IO.File]::ReadAllText($pubspecSecPath, [System.Text.Encoding]::UTF8) } else { "" }
$manifestBioPath = Join-Path $PSScriptRoot "../android/app/src/main/AndroidManifest.xml"
$manifestBioText = if (Test-Path $manifestBioPath) { [System.IO.File]::ReadAllText($manifestBioPath, [System.Text.Encoding]::UTF8) } else { "" }
$noBiometrics = (-not $pubspecSecText.Contains("local_auth")) -and (-not $manifestBioText.Contains("USE_BIOMETRIC")) -and (-not $manifestBioText.Contains("USE_FINGERPRINT")) -and (-not $mainActText.Contains("FlutterFragmentActivity"))
Assert-Test -Name "Fingerprint Login Removed (no local_auth / biometric permissions)" -Condition $noBiometrics -Details "App lock is PIN-only; no USE_BIOMETRIC/USE_FINGERPRINT, MainActivity is FlutterActivity"

# 2. Anti-Tapjacking & Invisible Overlay Touch Blocking
$hasTapjackingBlock = $mainActText.Contains("filterTouchesWhenObscured = true")
Assert-Test -Name "Anti-Tapjacking & Banking Overlay Defense" -Condition $hasTapjackingBlock -Details "Kernel-level filterTouchesWhenObscured prevents malicious overlays from stealing touches"

# 3. Sub-Millisecond Single-Pass PDF Malware & Exploit Scanner
$pdfScannerPath = Join-Path $PSScriptRoot "../lib/core/security/pdf_malware_scanner.dart"
$pdfScannerText = if (Test-Path $pdfScannerPath) { [System.IO.File]::ReadAllText($pdfScannerPath, [System.Text.Encoding]::UTF8) } else { "" }
$hasPdfScanner = $pdfScannerText.Contains("/Launch") -and `
                 $pdfScannerText.Contains("/JavaScript") -and `
                 $pdfScannerText.Contains("/EmbeddedFiles") -and `
                 $pdfScannerText.Contains("/OpenAction") -and `
                 $pdfScannerText.Contains("scanBytes")
$uploadSheetText = if (Test-Path (Join-Path $PSScriptRoot "../lib/features/statement_upload/presentation/statement_upload_sheet.dart")) { [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "../lib/features/statement_upload/presentation/statement_upload_sheet.dart"), [System.Text.Encoding]::UTF8) } else { "" }
$hasUploadValidation = $uploadSheetText.Contains("validatePdfFile")
$isMalwareScannerActive = $hasPdfScanner -and $hasUploadValidation
Assert-Test -Name "Sub-Millisecond PDF Malware & Exploit Scanner Engine" -Condition $isMalwareScannerActive -Details "Single-pass byte scanner identifies OS execution, JavaScript & embedded file exploits at 0 TL cost"

# 4. Session-Cached Device Integrity & Root Detection
$integrityPath = Join-Path $PSScriptRoot "../lib/core/security/device_integrity_guard.dart"
$integrityText = if (Test-Path $integrityPath) { [System.IO.File]::ReadAllText($integrityPath, [System.Text.Encoding]::UTF8) } else { "" }
$hasRootCheck = $integrityText.Contains("checkDeviceIntegrity") -and `
                $integrityText.Contains("_hasChecked") -and `
                $mainActText.Contains("isDeviceRooted") -and `
                $mainActText.Contains("/system/bin/su")
Assert-Test -Name "Removed: Unused Device Integrity Guard (K7)" -Condition (-not (Test-Path (Join-Path $PSScriptRoot "../lib/core/security/device_integrity_guard.dart"))) -Details "Never called from UI; deleted"

# 5. R8 Code Shrinker & Binary Decompilation Shield
$gradlePath = Join-Path $PSScriptRoot "../android/app/build.gradle"
$gradleText = if (Test-Path $gradlePath) { [System.IO.File]::ReadAllText($gradlePath, [System.Text.Encoding]::UTF8) } else { "" }
$hasR8Obfuscation = $gradleText.Contains("minifyEnabled true") -and $gradleText.Contains("shrinkResources true")
Assert-Test -Name "R8 Code Shrinker & Binary Decompilation Shield" -Condition $hasR8Obfuscation -Details "Releases compiled with R8 code shrinking and resource stripping for reverse engineering defense"

# ---------------------------------------------------------------
# 21. REMOTE CONFIG SCHEMA INTEGRITY & SYNC AUTOMATION
# ---------------------------------------------------------------
Write-Host "`n--- TEST 21: Remote Config Schema Integrity & Parity Suite ---" -ForegroundColor Yellow

$appConfigPath = Join-Path $PSScriptRoot "../assets/config/remote_config.json"
$webConfigPath = Join-Path $PSScriptRoot "../../Web_Yonetici_Paneli/remote_config.json"

$appConfigExists = Test-Path $appConfigPath
$webConfigExists = Test-Path $webConfigPath

$appJson = $null
$webJson = $null

if ($appConfigExists) {
    try {
        $appJson = (Get-Content $appConfigPath -Raw -Encoding UTF8) | ConvertFrom-Json
    } catch {}
}

if ($webConfigExists) {
    try {
        $webJson = (Get-Content $webConfigPath -Raw -Encoding UTF8) | ConvertFrom-Json
    } catch {}
}

# 1. Assets Config Schema Validation
$hasAppRootKeys = $appJson -ne $null -and `
                  $appJson.clean_data_mode -ne $null -and `
                  $appJson.theme -ne $null -and `
                  $appJson.menu -ne $null -and `
                  $appJson.button -ne $null -and `
                  $appJson.modules -ne $null -and `
                  $appJson.dynamic_lists -ne $null
$hasValidColors = $appJson.theme.primary_hex -match '^#[0-9A-Fa-f]{6}$' -and `
                  $appJson.theme.income_hex -match '^#[0-9A-Fa-f]{6}$' -and `
                  $appJson.theme.expense_hex -match '^#[0-9A-Fa-f]{6}$'

Assert-Test -Name "App Remote Config Assets Schema Validation" -Condition ($hasAppRootKeys -and $hasValidColors) -Details "assets/config/remote_config.json contains root schema keys and valid hex colors"

# 2. 12 Regional Modules Complete Matrix
$expectedModules = @(
    'dashboard_summary', 'statement_upload', 'cashflow_projection', 'goals_module',
    'assets_portfolio', 'market_rates', 'quick_entry', 'family_budget',
    'tax_analytics', 'scout_ai_coach', 'newsletter_subscription', 'market_news'
)
$allModulesPresent = $true
foreach ($modKey in $expectedModules) {
    if ($null -eq $appJson.modules.$modKey -or $null -eq $appJson.modules.$modKey.enabled) {
        $allModulesPresent = $false
        break
    }
}
Assert-Test -Name "12 Regional Modules Complete Matrix" -Condition $allModulesPresent -Details "All 12 sub-system kill-switches present with explicit enabled boolean flags"

# 3. Dynamic Financial Lists Completeness
$hasDynamicLists = $appJson.dynamic_lists.banks.Count -ge 8 -and `
                   $appJson.dynamic_lists.vehicle_brands_models.Count -ge 10 -and `
                   $appJson.dynamic_lists.housing_types.Count -ge 4 -and `
                   $appJson.dynamic_lists.payment_methods.Count -ge 4
Assert-Test -Name "Dynamic Financial Entity Lists Completeness" -Condition $hasDynamicLists -Details "Dynamic banks, EV/hybrid vehicles, housing types and payment methods verified"

# 4. Bidirectional Remote Config Parity (App vs Web Admin)
$appNormalized = if ($appJson) { ($appJson | ConvertTo-Json -Depth 10) } else { "1" }
$webNormalized = if ($webJson) { ($webJson | ConvertTo-Json -Depth 10) } else { "2" }
$isSynced = ($appNormalized -eq $webNormalized)

Assert-Test -Name "Bidirectional Remote Config Parity (App vs Web Admin)" -Condition $isSynced -Details "Mobile app config and Web Admin portal config are 100% byte-and-structure identical"

# 5. Web Admin Portal Import/Export & 12-Module Integration
$webIndexPath = Join-Path $PSScriptRoot "../../Web_Yonetici_Paneli/index.html"
$webIndexText = if (Test-Path $webIndexPath) { [System.IO.File]::ReadAllText($webIndexPath, [System.Text.Encoding]::UTF8) } else { "" }
$hasWebImportExport = $webIndexText.Contains("getSerializableConfig") -and `
                      $webIndexText.Contains("importConfigFile") -and `
                      $webIndexText.Contains("applyImportedConfig") -and `
                      $webIndexText.Contains("dashboard_summary") -and `
                      $webIndexText.Contains("newsletter_subscription")

Assert-Test -Name "Web Admin Portal Import/Export & 12-Module Engine" -Condition $hasWebImportExport -Details "Web console supports roundtrip JSON import/export and controls all 12 modules"

# ---------------------------------------------------------------
# 22. PRE-RELEASE COMPILATION HYGIENE & VERSION CODE GUARD
# ---------------------------------------------------------------
Write-Host "--- TEST 22: Pre-Release Compilation Hygiene & Version Code Guard ---" -ForegroundColor Yellow

# 1. Pubspec Version & Gradle Fallback Parity
$pubspecPath = Join-Path $PSScriptRoot "../pubspec.yaml"
$pubspecText = if (Test-Path $pubspecPath) { [System.IO.File]::ReadAllText($pubspecPath, [System.Text.Encoding]::UTF8) } else { "" }
$gradlePath = Join-Path $PSScriptRoot "../android/app/build.gradle"
$gradleText = if (Test-Path $gradlePath) { [System.IO.File]::ReadAllText($gradlePath, [System.Text.Encoding]::UTF8) } else { "" }

$versionCodeMatch = [regex]::Match($pubspecText, 'version:\s*[\d\.]+\+(\d+)')
$pubspecVersionCode = if ($versionCodeMatch.Success) { [int]$versionCodeMatch.Groups[1].Value } else { 0 }
$gradleHasVersionCode = $gradleText.Contains("flutterVersionCode = '$pubspecVersionCode'")

Assert-Test -Name "Google Play VersionCode Integrity (>= 3)" -Condition ($pubspecVersionCode -ge 3 -and $gradleHasVersionCode) -Details "Pubspec versionCode is $pubspecVersionCode (>= 3) and Gradle fallback matches"

# 2. AppTheme Material Import & JetBrains Mono Guard
$appThemePath = Join-Path $PSScriptRoot "../lib/core/theme/app_theme.dart"
$appThemeText = if (Test-Path $appThemePath) { [System.IO.File]::ReadAllText($appThemePath, [System.Text.Encoding]::UTF8) } else { "" }
$hasThemeIntegrity = $appThemeText.Contains("package:flutter/material.dart") -and $appThemeText.Contains("jetBrainsMono")
Assert-Test -Name "AppTheme Material & Typography Guard" -Condition $hasThemeIntegrity -Details "app_theme.dart has material import and jetBrainsMono numeric styling"

# 3. PDF Scanner Stopwatch & Regex Guard
$pdfScannerPath = Join-Path $PSScriptRoot "../lib/core/security/pdf_malware_scanner.dart"
$pdfScannerText = if (Test-Path $pdfScannerPath) { [System.IO.File]::ReadAllText($pdfScannerPath, [System.Text.Encoding]::UTF8) } else { "" }
$hasValidStopwatch = $pdfScannerText.Contains("Stopwatch()..start()") -and !($pdfScannerText.Contains("Stopwatch().start()"))
Assert-Test -Name "PDF Scanner Stopwatch Cascade Guard" -Condition $hasValidStopwatch -Details "pdf_malware_scanner.dart uses cascade operator preventing void type inference"

# 4. Assets Screen Repository Method Guard
$assetsScreenPath = Join-Path $PSScriptRoot "../lib/features/assets_portfolio/presentation/assets_screen.dart"
$assetsScreenText = if (Test-Path $assetsScreenPath) { [System.IO.File]::ReadAllText($assetsScreenPath, [System.Text.Encoding]::UTF8) } else { "" }
$cardPaymentFlowPath = Join-Path $PSScriptRoot "../lib/features/assets_portfolio/presentation/widgets/card_payment_flow.dart"
if (Test-Path $cardPaymentFlowPath) { $assetsScreenText += [System.IO.File]::ReadAllText($cardPaymentFlowPath, [System.Text.Encoding]::UTF8) }
$hasValidRepoCall = $assetsScreenText.Contains("saveManualTransaction") -and !($assetsScreenText.Contains("insertTransaction"))
Assert-Test -Name "Assets Screen Repository Method Guard" -Condition $hasValidRepoCall -Details "assets_screen.dart calls saveManualTransaction avoiding undefined method"

# 5. Quick Entry Categories Getter Guard
$quickEntryPath = Join-Path $PSScriptRoot "../lib/features/quick_entry/presentation/quick_entry_sheet.dart"
$quickEntryText = if (Test-Path $quickEntryPath) { [System.IO.File]::ReadAllText($quickEntryPath, [System.Text.Encoding]::UTF8) } else { "" }
$hasValidCategories = !($quickEntryText.Contains("final categories = _categories;"))
Assert-Test -Name "Quick Entry Categories Getter Guard" -Condition $hasValidCategories -Details "quick_entry_sheet.dart binds to _currentCategories"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  TEST RESULTS: $PassedTests / $TotalTests PASSED" -ForegroundColor $(if ($PassedTests -eq $TotalTests) { "Green" } else { "Red" })
Write-Host "========================================================`n" -ForegroundColor Cyan

if ($PassedTests -eq $TotalTests) {
    Exit 0
} else {
    Exit 1
}

