[CmdletBinding()]
param(
    # Kisayollarin olusturulacagi masaustu klasoru (varsayilan: mevcut kullanicinin masaustu).
    [string]$DesktopPath,
    # Baslat menusu klasoru (varsayilan: mevcut kullanicinin Programs klasoru).
    [string]$StartMenuPath,
    # Destek araclarini (Yedek/Geri Yukle/Guncelle/Durdur) masaustune de ekler.
    # Varsayilan olarak bu araclar yalnizca Baslat menusunde bulunur.
    [switch]$IncludeSupportShortcuts
)

# Comptario Local musteri kisayollarini olusturur.
#
# Varsayilan davranis (profesyonel, sade):
#   - Masaustunde YALNIZCA bir simge olusturulur: "Comptario Local"
#   - Destek araclari Baslat menusunde "Comptario Local\Support Tools" altinda toplanir:
#       Yedek Al, Geri Yukle, Guncelle, Durdur, Uygulamayi Ac, Destek Menusu
#
# Tum musteriye yonelik kisayollar Comptario uygulama simgesini kullanir
# (assets\comptario.ico). Docker simgesi KULLANILMAZ.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
}
if (-not (Test-Path -LiteralPath $DesktopPath)) {
    throw "Masaustu klasoru bulunamadi: $DesktopPath"
}

if ([string]::IsNullOrWhiteSpace($StartMenuPath)) {
    $StartMenuPath = [Environment]::GetFolderPath('Programs')
}

$powershell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

# Comptario uygulama simgesi. Bulunamazsa Docker DEGIL, varsayilan simge kullanilir.
$IconPath = Join-Path $Root 'assets\comptario.ico'
$HasIcon = Test-Path -LiteralPath $IconPath
if (-not $HasIcon) {
    Write-Host "Uyari: Comptario simgesi bulunamadi ($IconPath). Varsayilan simge kullanilacak." -ForegroundColor Yellow
}

function New-AppShortcut {
    param(
        [string]$LinkPath,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$Description
    )
    $dir = Split-Path -Parent $LinkPath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($LinkPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $Root
    $shortcut.Description = $Description
    $shortcut.WindowStyle = 1
    if ($HasIcon) {
        $shortcut.IconLocation = "$IconPath,0"
    }
    $shortcut.Save()
    Write-Host "Olusturuldu: $LinkPath"
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

# --- 1) Ana masaustu kisayolu: yalnizca "Comptario Local" ---
New-AppShortcut `
    -LinkPath (Join-Path $DesktopPath 'Comptario Local.lnk') `
    -TargetPath (Join-Path $Root 'comptario-local.bat') `
    -Arguments '' `
    -Description 'Comptario Local uygulamasini baslatir ve tarayicida acar.'

# --- 2) Baslat menusu: "Comptario Local" klasoru ---
$menuRoot = Join-Path $StartMenuPath 'Comptario Local'
$supportRoot = Join-Path $menuRoot 'Support Tools'

# Ana giris (Baslat menusu)
New-AppShortcut `
    -LinkPath (Join-Path $menuRoot 'Comptario Local.lnk') `
    -TargetPath (Join-Path $Root 'comptario-local.bat') `
    -Arguments '' `
    -Description 'Comptario Local uygulamasini baslatir ve tarayicida acar.'

# Destek araclari tanimlari (Baslat menusu + istege bagli masaustu)
$supportTools = @(
    @{ Name = 'Uygulamayi Ac';   Target = (Join-Path $Root 'open-local-app.bat'); Arguments = '';                                                       Description = 'Calisan Comptario Local uygulamasini tarayicida acar.' }
    @{ Name = 'Yedek Al';        Target = $powershell;                            Arguments = (Get-ScriptArguments -ScriptName 'backup-local.ps1' -KeepOpen);  Description = 'Veritabaninin yedegini local-backups klasorune alir.' }
    @{ Name = 'Geri Yukle';      Target = $powershell;                            Arguments = (Get-ScriptArguments -ScriptName 'restore-local.ps1' -KeepOpen); Description = 'Secilen yedekten veritabanini geri yukler.' }
    @{ Name = 'Guncelle';        Target = (Join-Path $Root 'update-local-app.bat'); Arguments = '';                                                     Description = 'Yeni surumu guvenle kurar. Veritabani, yedekler ve ayarlar korunur.' }
    @{ Name = 'Durdur';          Target = $powershell;                            Arguments = (Get-ScriptArguments -ScriptName 'stop-local.ps1' -KeepOpen);    Description = 'Comptario Local uygulamasini durdurur. Veriler korunur.' }
    @{ Name = 'Destek Menusu';   Target = (Join-Path $Root 'comptario-local-support.bat'); Arguments = '';                                              Description = 'Tum destek islemlerini tek pencerede sunan menu.' }
)

foreach ($tool in $supportTools) {
    New-AppShortcut `
        -LinkPath (Join-Path $supportRoot ("$($tool.Name).lnk")) `
        -TargetPath $tool.Target `
        -Arguments $tool.Arguments `
        -Description $tool.Description
}

# --- 3) Istege bagli: destek araclarini masaustune de ekle ---
if ($IncludeSupportShortcuts) {
    Write-Host ''
    Write-Host 'Destek kisayollari masaustune de ekleniyor (-IncludeSupportShortcuts).' -ForegroundColor Yellow
    foreach ($tool in $supportTools) {
        New-AppShortcut `
            -LinkPath (Join-Path $DesktopPath ("Comptario Local - $($tool.Name).lnk")) `
            -TargetPath $tool.Target `
            -Arguments $tool.Arguments `
            -Description $tool.Description
    }
}

Write-Host ''
Write-Host 'Kisayollar olusturuldu.' -ForegroundColor Green
Write-Host '  Masaustu: "Comptario Local"' -ForegroundColor Green
Write-Host '  Baslat menusu: "Comptario Local" > "Support Tools" (Yedek/Geri Yukle/Guncelle/Durdur)' -ForegroundColor Green
