[CmdletBinding()]
param(
    # Etkilesimsiz calistirma (ornegin kurulum sirasinda): pencereyi acik tutmaz,
    # Read-Host beklemez ve is bitince hemen cikar.
    [switch]$NoPause
)

# Comptario Local Guncelle
# Yeni bir surum mevcut kuruluma kopyalandiginda/kurulduğunda kullanilir.
# Uygulamayi guvenli sekilde yeniden insa edip baslatir.
# MUSTERI VERILERINI SILMEZ:
#   - Docker volume'lari silinmez.
#   - Mevcut .env dosyalari degistirilmez.
#   - local-backups klasorune dokunulmaz.
# Bu betik birden cok kez guvenle calistirilabilir.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$AppUrl = 'http://localhost:3000'
$HealthUrl = 'http://localhost:3000/api/health'
$DockerDesktopPath = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'

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
    if (-not $NoPause) {
        Read-Host 'Devam etmek için Enter tuşuna basın'
    }
    exit 1
}

Write-Host ''
Write-Host '   Comptario Local guncelleniyor...' -ForegroundColor White
Write-Host ''
Write-Note 'Verileriniz korunur: veritabani, yedekler ve ayarlar silinmez.'
Write-Host ''

# 1) Env dosyalari mevcut mu? Guncelleme yalnizca kurulu bir sistem icindir.
if ((-not (Test-Path -LiteralPath '.env.local')) -or (-not (Test-Path -LiteralPath 'backend\.env.local'))) {
    Stop-WithMessage @"
Bu bilgisayarda henuz bir Comptario Local kurulumu bulunamadi.

Guncelleme yalnizca daha once kurulmus bir sistem icin calisir.
Lutfen once 'Comptario Local Baslat' kisayolu ile ilk kurulumu tamamlayin.
"@
}

# 2) Docker motorunu kontrol et / gerekirse Docker Desktop'i baslat
Write-Step 'Docker Desktop kontrol ediliyor...'
if (Test-DockerEngine) {
    Write-Ok 'Docker zaten calisiyor.'
} else {
    if (-not (Test-Path -LiteralPath $DockerDesktopPath)) {
        Stop-WithMessage @"
Docker Desktop bu bilgisayarda bulunamadi.

Beklenen konum:
  $DockerDesktopPath

Lutfen Docker Desktop'in kurulu ve calisir oldugundan emin olun,
ardindan 'Comptario Local Guncelle' kisayoluna tekrar tiklayin.
"@
    }

    Write-Note 'Docker calismiyor. Docker Desktop baslatiliyor (bu islem birkac dakika surebilir)...'
    try {
        Start-Process -FilePath $DockerDesktopPath | Out-Null
    } catch {
        Stop-WithMessage @"
Docker Desktop baslatilamadi.

Lutfen Docker Desktop'i elle acin, motor hazir olana kadar bekleyin
ve ardindan 'Comptario Local Guncelle' kisayoluna tekrar tiklayin.
"@
    }

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
'Comptario Local Guncelle' kisayoluna tekrar tiklayin.
"@
        }
        Write-Host '    .' -NoNewline -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Ok 'Docker motoru hazir.'
}

# 3) Yeni surumu insa et (veriye dokunmadan)
Write-Step 'Yeni surum hazirlaniyor (bu islem birkac dakika surebilir)...'
& docker compose --env-file .env.local -f docker-compose.local.yml build --no-cache app
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage @"
Yeni surum hazirlanamadi.

Docker Desktop'in calistigindan emin olun ve 'Comptario Local Guncelle'
kisayoluna tekrar tiklayin. Sorun devam ederse destek ekibiyle iletisime gecin.
Mevcut verileriniz bu islemden etkilenmez.
"@
}

# 4) Guncellenmis uygulamayi baslat (volume'lar korunur)
Write-Step 'Guncellenmis uygulama baslatiliyor...'
& docker compose --env-file .env.local -f docker-compose.local.yml up -d
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage @"
Guncellenmis uygulama baslatilamadi.

Docker Desktop'in calistigindan emin olun ve 'Comptario Local Guncelle'
kisayoluna tekrar tiklayin. Sorun devam ederse destek ekibiyle iletisime gecin.
"@
}

# 5) Uygulama saglikli olana kadar bekle (HTTP 200)
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
        # Henuz hazir degil — beklemeye devam et
    }
    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds $pollIntervalSec
        if (($attempt % 3) -eq 0) { Write-Host '    .' -NoNewline -ForegroundColor Yellow }
    }
}
Write-Host ''

if (-not $healthy) {
    Stop-WithMessage @"
Uygulama guncellemeden sonra beklenen surede acilmadi.

Lutfen birkac dakika sonra 'Comptario Local Ac' kisayoluna tiklayin.
Sorun devam ederse destek ekibiyle iletisime gecin.
Verileriniz guvende; guncelleme verilerinizi silmez.
"@
}

Write-Ok 'Guncelleme tamamlandi. Uygulama hazir.'

# 6) Tarayicida ac
Write-Step "Tarayici aciliyor: $AppUrl"
Start-Process $AppUrl

Write-Host ''
Write-Host 'Comptario Local guncellendi ve calisiyor. Bu pencereyi kapatabilirsiniz.' -ForegroundColor Green
if (-not $NoPause) {
    Read-Host 'Kapatmak için Enter tuşuna basın'
}
