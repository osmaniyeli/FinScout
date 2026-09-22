# tools/setup_hooks.ps1 - Paraİz Git Hook Kurulum Otomasyonu
$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$hooksDir = Join-Path $repoRoot ".git/hooks"

if (-not (Test-Path $hooksDir)) {
    Write-Host "❌ .git/hooks dizini bulunamadı! Bu betik sadece bir Git deposu içinde çalıştırılabilir." -ForegroundColor Red
    Exit 1
}

$prePushHookPath = Join-Path $hooksDir "pre-push"

$hookScriptContent = @"
#!/bin/sh
# 🛡️ Paraİz Otomatik Kalite Kapısı - Git Pre-Push Hook
echo ""
echo "========================================================"
echo "  🛡️ PARAIZ - GIT PRE-PUSH KALİTE KAPISI DOĞRULAMASI    "
echo "========================================================"

if command -v pwsh >/dev/null 2>&1; then
    pwsh -ExecutionPolicy Bypass -File moneytrace/test/verify_parsers.ps1
elif command -v powershell >/dev/null 2>&1; then
    powershell -ExecutionPolicy Bypass -File moneytrace/test/verify_parsers.ps1
else
    echo "⚠️ PowerShell bulunamadı. Testler atlandı."
    exit 0
fi

RESULT=`$?
if [ `$RESULT -ne 0 ]; then
    echo ""
    echo "❌ HATA: Doğrulama testleri BAŞARISIZ oldu!"
    echo "   Sunucuya hatalı kod gönderilmesi engellendi (Push iptal edildi)."
    echo "   Lütfen test sonuçlarını inceleyip hataları giderin."
    echo ""
    exit 1
fi

echo ""
echo "✅ TÜM TESTLER GEÇTİ! Push işlemi devam ediyor..."
echo ""
exit 0
"@

# Write with Unix (LF) line endings for Git Bash compatibility
$unixContent = $hookScriptContent -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($prePushHookPath, $unixContent, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "`n✅ Paraİz Git Pre-Push kancası başarıyla kuruldu: $prePushHookPath" -ForegroundColor Green
Write-Host "   Artık 'git push' komutu verildiğinde 75 testlik doğrulama süiti otomatik koşturulacak.`n" -ForegroundColor Cyan
