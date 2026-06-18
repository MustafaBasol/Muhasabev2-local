[CmdletBinding()]
param()

# Comptario Local Ac
# Uygulama zaten calisiyorsa tarayicida acar.
# Calismiyorsa, musteriye "Comptario Local Baslat" kisayolunu kullanmasini soyler.

$ErrorActionPreference = 'Stop'

$AppUrl = 'http://localhost:3000'
$HealthUrl = 'http://localhost:3000/api/health'

$running = $false
try {
    $response = Invoke-WebRequest -Uri $HealthUrl -TimeoutSec 5 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        $running = $true
    }
} catch {
    $running = $false
}

if ($running) {
    Start-Process $AppUrl
    exit 0
}

Write-Host ''
Write-Host '------------------------------------------------------------' -ForegroundColor Yellow
Write-Host ' Comptario Local su anda calismiyor.' -ForegroundColor Yellow
Write-Host ''
Write-Host ' Lutfen masaustundeki' -ForegroundColor White
Write-Host '   "Comptario Local Baslat"' -ForegroundColor Cyan
Write-Host ' kisayoluna tiklayin ve tarayici acilana kadar bekleyin.' -ForegroundColor White
Write-Host '------------------------------------------------------------' -ForegroundColor Yellow
Write-Host ''
Read-Host 'Devam etmek icin Enter tusuna basin'
