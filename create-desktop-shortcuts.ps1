[CmdletBinding()]
param(
    # Kisayollarin olusturulacagi masaustu klasoru (varsayilan: mevcut kullanicinin masaustu).
    [string]$DesktopPath
)

# Comptario Local masaustu kisayollarini olusturur.
# Olusturulan kisayollar:
#   - Comptario Local Baslat
#   - Comptario Local Ac
#   - Comptario Local Durdur
#   - Comptario Local Yedek Al
#   - Comptario Local Geri Yukle
#   - Comptario Local Guncelle

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
}

if (-not (Test-Path -LiteralPath $DesktopPath)) {
    throw "Masaustu klasoru bulunamadi: $DesktopPath"
}

$powershell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

function New-AppShortcut {
    param(
        [string]$Name,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$Description
    )
    $shell = New-Object -ComObject WScript.Shell
    $linkPath = Join-Path $DesktopPath ("$Name.lnk")
    $shortcut = $shell.CreateShortcut($linkPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $Root
    $shortcut.Description = $Description
    $shortcut.WindowStyle = 1
    # Docker simgesi varsa onu kullan, yoksa varsayilan kalir.
    $dockerIcon = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    if (Test-Path -LiteralPath $dockerIcon) {
        $shortcut.IconLocation = "$dockerIcon,0"
    }
    $shortcut.Save()
    Write-Host "Olusturuldu: $linkPath"
}

# Bir .ps1 betigini calistiran ve bittikten sonra pencereyi acik tutan argumanlar.
function Get-ScriptArguments {
    param([string]$ScriptName, [switch]$KeepOpen)
    $scriptPath = Join-Path $Root $ScriptName
    if ($KeepOpen) {
        return "-NoProfile -ExecutionPolicy Bypass -Command ""& '$scriptPath'; Read-Host 'Kapatmak icin Enter tusuna basin'"""
    }
    return "-NoProfile -ExecutionPolicy Bypass -File ""$scriptPath"""
}

# Baslat ve Ac: kullanici dostu .bat dosyalarini kullanir (pencere kendi yonetir).
New-AppShortcut -Name 'Comptario Local Baslat' `
    -TargetPath (Join-Path $Root 'launch-local-app.bat') `
    -Arguments '' `
    -Description 'Comptario Local uygulamasini baslatir ve tarayicida acar.'

New-AppShortcut -Name 'Comptario Local Ac' `
    -TargetPath (Join-Path $Root 'open-local-app.bat') `
    -Arguments '' `
    -Description 'Calisan Comptario Local uygulamasini tarayicida acar.'

# Durdur, Yedek Al, Geri Yukle: PowerShell betikleri, pencere acik kalir.
New-AppShortcut -Name 'Comptario Local Durdur' `
    -TargetPath $powershell `
    -Arguments (Get-ScriptArguments -ScriptName 'stop-local.ps1' -KeepOpen) `
    -Description 'Comptario Local uygulamasini durdurur. Veriler korunur.'

New-AppShortcut -Name 'Comptario Local Yedek Al' `
    -TargetPath $powershell `
    -Arguments (Get-ScriptArguments -ScriptName 'backup-local.ps1' -KeepOpen) `
    -Description 'Veritabaninin yedegini local-backups klasorune alir.'

New-AppShortcut -Name 'Comptario Local Geri Yukle' `
    -TargetPath $powershell `
    -Arguments (Get-ScriptArguments -ScriptName 'restore-local.ps1' -KeepOpen) `
    -Description 'En son yedekten veritabanini geri yukler.'

# Guncelle: yeni surum kopyalandiktan sonra (genellikle destek tarafindan) calistirilir.
# Pencereyi kendi yonetir (.bat) ve bittikten sonra Enter bekler.
New-AppShortcut -Name 'Comptario Local Guncelle' `
    -TargetPath (Join-Path $Root 'update-local-app.bat') `
    -Arguments '' `
    -Description 'Yeni surumu guvenle kurar. Veritabani, yedekler ve ayarlar korunur.'

Write-Host ''
Write-Host 'Masaustu kisayollari olusturuldu.' -ForegroundColor Green
