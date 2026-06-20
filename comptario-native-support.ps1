[CmdletBinding()]
param()

# Comptario Local Native - Destek Menusu
# Destek/yonetici kullanimi icindir. Gunluk musteri kullanimi icin DEGILDIR.
# Tek pencerede baslatma, yedekleme, geri yukleme ve durdurma islemlerini sunar.
# Hicbir secenek config\native-runtime.env dosyasini veya musteri verisini siler.

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
    Write-Host '   Comptario Local Native - Destek Menusu' -ForegroundColor White
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  1) Uygulamayi Ac / Baslat'
    Write-Host '  2) Yedek Al'
    Write-Host '  3) Geri Yukle'
    Write-Host '  4) Durdur'
    Write-Host '  5) Cikis'
    Write-Host ''
    $choice = Read-Host 'Seciminiz (1-5)'

    switch ($choice.Trim()) {
        '1' { Invoke-SupportScript 'comptario-native.ps1' }
        '2' { Invoke-SupportScript 'backup-native.ps1' }
        '3' { Invoke-SupportScript 'restore-native.ps1' }
        '4' { Invoke-SupportScript 'stop-native.ps1' }
        '5' {
            Write-Host ''
            Write-Host 'Cikiliyor...' -ForegroundColor Gray
            return
        }
        default {
            Write-Host ''
            Write-Host 'Gecersiz secim. Lutfen 1-5 arasinda bir sayi girin.' -ForegroundColor Yellow
        }
    }
}
