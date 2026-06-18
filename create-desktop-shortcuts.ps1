[CmdletBinding()]
param(
    # Kisayollarin olusturulacagi masaustu klasoru (varsayilan: mevcut kullanicinin masaustu).
    [string]$DesktopPath,
    # Destek araclarini masaustune de ekler (varsayilan: yalnizca Baslat menusu).
    [switch]$IncludeSupportShortcuts
)

# GERIYE DONUK UYUMLULUK KATMANI
# Eski ad "create-desktop-shortcuts.ps1" korunur; ancak artik alti ayri masaustu
# simgesi (ve Docker simgesi) OLUSTURMAZ. Bunun yerine yeni, sade musteri
# kisayol duzenini olusturan create-customer-shortcuts.ps1'e yonlendirir:
#   - Masaustunde tek simge: "Comptario Local" (Comptario uygulama simgesiyle)
#   - Destek araclari Baslat menusunde "Comptario Local\Support Tools" altinda

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$forward = @{}
if (-not [string]::IsNullOrWhiteSpace($DesktopPath)) { $forward['DesktopPath'] = $DesktopPath }
if ($IncludeSupportShortcuts) { $forward['IncludeSupportShortcuts'] = $true }

& (Join-Path $Root 'create-customer-shortcuts.ps1') @forward
