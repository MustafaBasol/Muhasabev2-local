[CmdletBinding()]
param()

# Comptario Local
# Musteri dostu ana baslatici. Tek masaustu simgesi budur.
#   - Docker Desktop'i kontrol eder, gerekirse baslatir.
#   - Uygulamayi calistirir (docker compose up -d).
#   - Hazir olunca tarayicida acar.
# Bu betik birden cok kez guvenle calistirilabilir.
# VERI GUVENLIGI:
#   - Uygulama imajini yeniden insa etmez (gunluk kullanim hizlidir).
#   - Docker volume'larini silmez.
#   - .env.local / backend\.env.local dosyalarini degistirmez.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$AppUrl = 'http://localhost:3000'
$HealthUrl = 'http://localhost:3000/api/health'
$DockerDesktopPath = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$DockerDownloadUrl = 'https://www.docker.com/products/docker-desktop/'
$WingetDockerCommand = 'winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements'

function Write-Step    { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok      { param([string]$Message) Write-Host "    $Message" -ForegroundColor Green }
function Write-Note    { param([string]$Message) Write-Host "    $Message" -ForegroundColor Yellow }

function Test-DockerEngine {
    # Docker motoru calisiyorsa $true doner.
    try {
        docker info *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Stop-WithMessage {
    param([string]$Message)
    Write-Host ''
    Write-Host '------------------------------------------------------------' -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
    Write-Host '------------------------------------------------------------' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Bu pencereyi kapatabilirsiniz.' -ForegroundColor Gray
    Read-Host 'Devam etmek icin Enter tusuna basin'
    exit 1
}

function Show-DockerMissingHelp {
    $wingetAvailable = $null -ne (Get-Command 'winget.exe' -ErrorAction SilentlyContinue)

    Write-Host ''
    Write-Host '------------------------------------------------------------' -ForegroundColor Red
    Write-Host 'Docker Desktop bu bilgisayarda bulunamadi.' -ForegroundColor Red
    Write-Host '------------------------------------------------------------' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Comptario Local calismadan once Docker Desktop bir kez kurulmalidir.'
    Write-Host "Indirme adresi: $DockerDownloadUrl"
    Write-Host ''
    Write-Host '[D] Docker Desktop indirme sayfasini ac' -ForegroundColor Cyan
    if ($wingetAvailable) {
        Write-Host '[W] Docker Desktop kurulumunu winget ile baslat' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'Winget komutu:' -ForegroundColor Yellow
        Write-Host "  $WingetDockerCommand" -ForegroundColor Yellow
    }
    Write-Host '[Enter] Pencereyi kapat' -ForegroundColor Gray
    Write-Host ''
    Write-Note 'Kurulum yonetici onayi isteyebilir. Kurulumdan sonra Windows yeniden baslatilabilir.'

    $choice = (Read-Host 'Seciminiz').Trim().ToUpperInvariant()
    if ($choice -eq 'D') {
        try {
            Start-Process $DockerDownloadUrl
            Write-Ok 'Docker Desktop indirme sayfasi tarayicida acildi.'
        } catch {
            Write-Note "Tarayici acilamadi. Adresi elle acin: $DockerDownloadUrl"
        }
    } elseif ($choice -eq 'W' -and $wingetAvailable) {
        Write-Host ''
        Write-Note 'Docker Desktop kurulumu yonetici onayi isteyebilir ve Windows yeniden baslatma gerektirebilir.'
        $confirm = (Read-Host 'Winget kurulumunu baslatmak icin E yazin').Trim().ToUpperInvariant()
        if ($confirm -eq 'E') {
            & winget.exe install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Ok 'Winget islemi tamamlandi.'
            } else {
                Write-Note "Winget islemi tamamlanamadi (cikis kodu: $LASTEXITCODE)."
                Write-Note "Docker Desktop'i su adresten elle kurabilirsiniz: $DockerDownloadUrl"
            }
        } else {
            Write-Note 'Winget kurulumu iptal edildi.'
        }
    }

    Write-Host ''
    Write-Host "Docker Desktop kurulduktan sonra gerekirse Windows'u yeniden baslatin." -ForegroundColor Yellow
    Write-Host "Ardindan 'Comptario Local' kisayoluna tekrar tiklayin." -ForegroundColor Yellow
    Read-Host 'Pencereyi kapatmak icin Enter tusuna basin'
    exit 1
}

Write-Host ''
Write-Host '   Comptario Local baslatiliyor...' -ForegroundColor White
Write-Host ''

# 1) Docker motorunu kontrol et / gerekirse Docker Desktop'i baslat
Write-Step 'Docker Desktop kontrol ediliyor...'
if (Test-DockerEngine) {
    Write-Ok 'Docker zaten calisiyor.'
} else {
    if (-not (Test-Path -LiteralPath $DockerDesktopPath)) {
        Show-DockerMissingHelp
    }

    Write-Note 'Docker calismiyor. Docker Desktop baslatiliyor (bu islem birkac dakika surebilir)...'
    try {
        Start-Process -FilePath $DockerDesktopPath | Out-Null
    } catch {
        Stop-WithMessage @"
Docker Desktop baslatilamadi.

Lutfen Docker Desktop'i elle acin, motor hazir olana kadar bekleyin
ve ardindan 'Comptario Local' kisayoluna tekrar tiklayin.
"@
    }

    # Motor hazir olana kadar bekle (en fazla ~3 dakika)
    $maxWaitSec = 180
    $waited = 0
    Write-Note 'Docker motorunun hazir olmasi bekleniyor...'
    while (-not (Test-DockerEngine)) {
        Start-Sleep -Seconds 5
        $waited += 5
        if ($waited -ge $maxWaitSec) {
            Stop-WithMessage @"
Docker Desktop beklenen surede hazir olmadi.

Lutfen ekranin sag alt kosesindeki Docker (balina) simgesinin
'Docker Desktop is running' durumuna gelmesini bekleyin ve
'Comptario Local' kisayoluna tekrar tiklayin.
"@
        }
        Write-Host '    .' -NoNewline -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Ok 'Docker motoru hazir.'
}

# 2) Uygulamayi baslat
# Ilk kurulumda env dosyalari ve imajlar yoksa tam kurulum (start-local.ps1) calistirilir.
$envMissing = (-not (Test-Path -LiteralPath '.env.local')) -or (-not (Test-Path -LiteralPath 'backend\.env.local'))

if ($envMissing) {
    Write-Step 'Ilk kurulum yapiliyor (bu yalnizca ilk seferde uzun surer)...'
    try {
        & (Join-Path $Root 'start-local.ps1')
    } catch {
        Stop-WithMessage @"
Ilk kurulum tamamlanamadi.

Hata: $($_.Exception.Message)

Docker Desktop'in calistigindan emin olun ve tekrar deneyin.
Sorun devam ederse destek ekibiyle iletisime gecin.
"@
    }
} else {
    Write-Step 'Uygulama baslatiliyor...'
    & docker compose --env-file .env.local -f docker-compose.local.yml up -d
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage @"
Uygulama baslatilamadi.

Docker Desktop'in calistigindan emin olun ve 'Comptario Local'
kisayoluna tekrar tiklayin. Sorun devam ederse destek ekibiyle iletisime gecin.
"@
    }
}

# 3) Uygulama saglikli olana kadar bekle (HTTP 200)
Write-Step 'Uygulamanin hazir olmasi bekleniyor...'
$healthy = $false
$maxAttempts = 90
$pollIntervalSec = 5
Start-Sleep -Seconds 5
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            break
        }
    } catch {
        # Henuz hazir degil - beklemeye devam et
    }
    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds $pollIntervalSec
        if (($attempt % 3) -eq 0) { Write-Host '    .' -NoNewline -ForegroundColor Yellow }
    }
}
Write-Host ''

if (-not $healthy) {
    Stop-WithMessage @"
Uygulama beklenen surede acilmadi.

Lutfen birkac dakika sonra 'Comptario Local' kisayoluna tekrar tiklayin.
Sorun devam ederse destek ekibiyle iletisime gecin.
"@
}

Write-Ok 'Uygulama hazir.'

# 4) Tarayicida ac
Write-Step "Tarayici aciliyor: $AppUrl"
Start-Process $AppUrl

Write-Host ''
Write-Host 'Comptario Local calisiyor. Bu pencereyi kapatabilirsiniz.' -ForegroundColor Green
Start-Sleep -Seconds 3
