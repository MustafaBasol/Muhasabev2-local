[CmdletBinding()]
param()

# Comptario Local - Destek Menusu
# Destek/yonetici kullanimi icindir. Gunluk musteri kullanimi icin DEGILDIR.
# Tek pencerede yedekleme, geri yukleme, guncelleme ve durdurma islemlerini sunar.
# Hicbir secenek Docker volume'larini silmez veya .env dosyalarini degistirmez.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Invoke-SupportScript {
    param([string]$ScriptName)
    $path = Join-Path $Root $ScriptName
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host ''
        Write-Host "Betik bulunamadi: $ScriptName" -ForegroundColor Red
        return
    }
    Write-Host ''
    try {
        & $path
    } catch {
        Write-Host ''
        Write-Host "Islem sirasinda bir hata olustu: $($_.Exception.Message)" -ForegroundColor Red
    }
}

while ($true) {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '   Comptario Local - Destek Menusu' -ForegroundColor White
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  1) Uygulamayi Ac / Baslat'
    Write-Host '  2) Yedek Al'
    Write-Host '  3) Geri Yukle'
    Write-Host '  4) Guncelle (yeni surum)'
    Write-Host '  5) Durdur'
    Write-Host '  6) Cikis'
    Write-Host ''
    $choice = Read-Host 'Seciminiz (1-6)'

    switch ($choice.Trim()) {
        '1' { Invoke-SupportScript 'comptario-local.ps1' }
        '2' { Invoke-SupportScript 'backup-local.ps1' }
        '3' { Invoke-SupportScript 'restore-local.ps1' }
        '4' { Invoke-SupportScript 'update-local-app.ps1' }
        '5' { Invoke-SupportScript 'stop-local.ps1' }
        '6' {
            Write-Host ''
            Write-Host 'Cikiliyor...' -ForegroundColor Gray
            break
        }
        default {
            Write-Host ''
            Write-Host 'Gecersiz secim. Lutfen 1-6 arasinda bir sayi girin.' -ForegroundColor Yellow
        }
    }

    if ($choice.Trim() -eq '6') { break }

    Write-Host ''
    Read-Host 'Menuye donmek icin Enter tusuna basin'
}
