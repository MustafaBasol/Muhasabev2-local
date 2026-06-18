[CmdletBinding()]
param(
    # Sorulari atlayip Docker'i otomatik baslatmaya da ayarlamak icin: -StartDockerWithWindows
    [switch]$StartDockerWithWindows,
    # Hic soru sormadan yalnizca kisayollari olusturmak icin: -NoPrompt
    [switch]$NoPrompt
)

# Comptario Local kurulum yardimcisi.
#  1) Masaustu kisayollarini olusturur.
#  2) Istege bagli: Docker Desktop'in Windows ile birlikte otomatik baslamasini ayarlar.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '   Comptario Local kurulum yardimcisi' -ForegroundColor White
Write-Host ''

# 1) Musteri kisayollarini olustur
#    Masaustunde tek "Comptario Local" simgesi; destek araclari Baslat menusunde.
Write-Host '==> Kisayollar olusturuluyor (masaustu + Baslat menusu)...' -ForegroundColor Cyan
& (Join-Path $Root 'create-customer-shortcuts.ps1')

# 2) Docker'in otomatik baslamasi
$enableAutostart = $StartDockerWithWindows
if (-not $StartDockerWithWindows -and -not $NoPrompt) {
    Write-Host ''
    $answer = Read-Host 'Docker Desktop, bilgisayar acildiginda otomatik baslasin mi? (E/H)'
    if ($answer -match '^(e|E|y|Y)') {
        $enableAutostart = $true
    }
}

if ($enableAutostart) {
    $dockerDesktopPath = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    if (-not (Test-Path -LiteralPath $dockerDesktopPath)) {
        Write-Host ''
        Write-Host 'Docker Desktop bulunamadi; otomatik baslatma atlandi.' -ForegroundColor Yellow
        Write-Host "Beklenen konum: $dockerDesktopPath" -ForegroundColor Yellow
    } else {
        # En guvenilir yontem: Baslangic klasorune Docker Desktop kisayolu koymak.
        $startupFolder = [Environment]::GetFolderPath('Startup')
        $startupLink = Join-Path $startupFolder 'Docker Desktop.lnk'
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startupLink)
        $shortcut.TargetPath = $dockerDesktopPath
        $shortcut.WorkingDirectory = Split-Path -Parent $dockerDesktopPath
        $shortcut.Description = 'Docker Desktop (otomatik baslatma)'
        $shortcut.IconLocation = "$dockerDesktopPath,0"
        $shortcut.Save()
        Write-Host ''
        Write-Host 'Docker Desktop artik Windows ile birlikte otomatik baslayacak.' -ForegroundColor Green
        Write-Host "Kaldirmak icin su dosyayi silin: $startupLink" -ForegroundColor Gray
        Write-Host ''
        Write-Host 'Not: Ayrica Docker Desktop > Settings (Disli simgesi) > General icindeki' -ForegroundColor Gray
        Write-Host '     "Start Docker Desktop when you sign in" secenegini de isaretleyebilirsiniz.' -ForegroundColor Gray
    }
}

Write-Host ''
Write-Host 'Kurulum tamamlandi.' -ForegroundColor Green
Write-Host 'Artik masaustundeki "Comptario Local" kisayolunu kullanabilirsiniz.' -ForegroundColor Green
Write-Host ''
if (-not $NoPrompt) {
    Read-Host 'Kapatmak icin Enter tusuna basin'
}
