[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppUrl = 'http://127.0.0.1:3000'
$HealthUrl = "$AppUrl/api/health"
$NodeExe = Join-Path $Root 'runtime\node\node.exe'
$BackendRoot = Join-Path $Root 'app\backend'
$BackendEntry = Join-Path $BackendRoot 'dist\src\main.js'
$BackendRunner = Join-Path $Root 'run-native-backend.ps1'
$ConfigDir = Join-Path $Root 'config'
$ConfigPath = Join-Path $ConfigDir 'native-runtime.env'
$DataDir = Join-Path $Root 'data'
$AssetsDir = Join-Path $DataDir 'assets'
$BlogAssetsDir = Join-Path $AssetsDir 'blog'
$LogsDir = Join-Path $Root 'logs'
$BackupsDir = Join-Path $Root 'backups'
$PidPath = Join-Path $LogsDir 'comptario-native.pid'
$StdoutLog = Join-Path $LogsDir 'backend.log'
$StderrLog = Join-Path $LogsDir 'backend-error.log'

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok { param([string]$Message) Write-Host "    $Message" -ForegroundColor Green }
function Write-Note { param([string]$Message) Write-Host "    $Message" -ForegroundColor Yellow }

function New-HexSecret {
    param([int]$Bytes = 48)
    $buffer = New-Object byte[] $Bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($buffer)
    } finally {
        $rng.Dispose()
    }
    return (($buffer | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Ensure-Directories {
    @($ConfigDir, $DataDir, $AssetsDir, $BlogAssetsDir, $LogsDir, $BackupsDir) |
        ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

function Ensure-RuntimeConfig {
    if (Test-Path -LiteralPath $ConfigPath) {
        return
    }

    $databasePath = Join-Path $DataDir 'comptario.db'
    $lines = @(
        'APP_EDITION=native-local'
        'DATABASE_TYPE=sqlite'
        "DATABASE_PATH=$databasePath"
        'NODE_ENV=production'
        'PORT=3000'
        'APP_VERSION=1.0.0'
        "FRONTEND_URL=$AppUrl"
        "APP_PUBLIC_URL=$AppUrl"
        "CORS_ORIGINS=$AppUrl"
        "BLOG_ASSETS_DIR=$BlogAssetsDir"
        "BACKUP_DIR=$BackupsDir"
        'MAIL_PROVIDER=log'
        'MAIL_FROM=Comptario Local <noreply@localhost.local>'
        'EMAIL_VERIFICATION_REQUIRED=false'
        'STRIPE_ENABLED=false'
        'TURNSTILE_SECRET_KEY='
        'TURNSTILE_DEV_BYPASS=true'
        'SECURITY_ENABLE_CSP_NONCE=false'
        "JWT_SECRET=$(New-HexSecret)"
        "JWT_REFRESH_SECRET=$(New-HexSecret)"
        "CSRF_SECRET=$(New-HexSecret)"
    )
    [System.IO.File]::WriteAllLines(
        $ConfigPath,
        $lines,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Ok 'Ilk calistirma ayarlari ve guvenli yerel anahtarlar olusturuldu.'
}

function Import-RuntimeConfig {
    foreach ($line in [System.IO.File]::ReadAllLines($ConfigPath)) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) {
            continue
        }
        $separator = $trimmed.IndexOf('=')
        if ($separator -le 0) {
            continue
        }
        $name = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1)
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}

function Get-NativeHealth {
    try {
        $response = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 3
        if (
            $response.status -eq 'ok' -and
            $response.appEdition -eq 'native-local' -and
            $response.databaseReachable -eq $true
        ) {
            return $response
        }
    } catch {
        return $null
    }
    return $null
}

function Test-NativeStaticAssets {
    $publicAssetsDir = Join-Path $BackendRoot 'public\assets'
    Write-Step 'Statik dosyalar dogrulaniyor (/assets)...'
    Write-Note "Frontend assets klasoru: $publicAssetsDir"
    Write-Note "Blog assets klasoru: $AssetsDir"
    try {
        $indexResponse = Invoke-WebRequest -Uri $AppUrl -TimeoutSec 5 -UseBasicParsing
        if ($indexResponse.StatusCode -ne 200) {
            Write-Note "Uyari: '/' beklenmeyen durum kodu dondurdu: $($indexResponse.StatusCode)"
        }
    } catch {
        Write-Note "Uyari: ana sayfa istegi basarisiz oldu: $($_.Exception.Message)"
        return
    }

    $jsFile = Get-ChildItem -LiteralPath $publicAssetsDir -Filter 'index-*.js' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $cssFile = Get-ChildItem -LiteralPath $publicAssetsDir -Filter 'index-*.css' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    foreach ($asset in @($jsFile, $cssFile)) {
        if (-not $asset) { continue }
        $assetUrl = "$AppUrl/assets/$($asset.Name)"
        try {
            $assetResponse = Invoke-WebRequest -Uri $assetUrl -TimeoutSec 5 -UseBasicParsing
            if ($assetResponse.StatusCode -eq 200) {
                Write-Ok "Dogrulandi: $assetUrl"
            } else {
                Write-Note "Uyari: $assetUrl beklenmeyen durum kodu dondurdu: $($assetResponse.StatusCode)"
            }
        } catch {
            Write-Note "Uyari: $assetUrl istegi basarisiz oldu: $($_.Exception.Message)"
        }
    }
}

Ensure-Directories
Ensure-RuntimeConfig
Import-RuntimeConfig

if (-not (Test-Path -LiteralPath $NodeExe -PathType Leaf)) {
    throw "Ozel Node.js calisma dosyasi bulunamadi: $NodeExe"
}
if (-not (Test-Path -LiteralPath $BackendEntry -PathType Leaf)) {
    throw "Comptario backend dosyasi bulunamadi: $BackendEntry"
}
if (-not (Test-Path -LiteralPath $BackendRunner -PathType Leaf)) {
    throw "Comptario backend baslatma dosyasi bulunamadi: $BackendRunner"
}

Write-Host ''
Write-Host '   Comptario Local baslatiliyor...' -ForegroundColor White
Write-Host ''

Write-Step 'Uygulama durumu kontrol ediliyor...'
$health = Get-NativeHealth
if ($health) {
    Write-Ok 'Comptario Local zaten calisiyor.'
} else {
    if (Test-Path -LiteralPath $PidPath) {
        $oldPidText = (Get-Content -LiteralPath $PidPath -Raw).Trim()
        if ($oldPidText -match '^\d+$') {
            $oldProcess = Get-Process -Id ([int]$oldPidText) -ErrorAction SilentlyContinue
            if ($oldProcess) {
                Write-Note 'Onceki uygulama islemi henuz hazir degil; bekleniyor...'
            } else {
                Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if (-not (Test-Path -LiteralPath $PidPath)) {
        Write-Step 'Yerel uygulama baslatiliyor...'
        $process = Start-Process `
            -FilePath 'powershell.exe' `
            -ArgumentList @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-File', "`"$BackendRunner`"",
                '-NodeExe', "`"$NodeExe`"",
                '-BackendRoot', "`"$BackendRoot`"",
                '-StdoutLog', "`"$StdoutLog`"",
                '-StderrLog', "`"$StderrLog`""
            ) `
            -WorkingDirectory $Root `
            -WindowStyle Hidden `
            -PassThru
        [System.IO.File]::WriteAllText($PidPath, [string]$process.Id)
    }

    Write-Step 'Uygulamanin hazir olmasi bekleniyor...'
    for ($attempt = 1; $attempt -le 90; $attempt++) {
        Start-Sleep -Seconds 1
        $health = Get-NativeHealth
        if ($health) {
            break
        }
        if (($attempt % 5) -eq 0) {
            Write-Host '    .' -NoNewline -ForegroundColor Yellow
        }
    }
    Write-Host ''

    if (-not $health) {
        Write-Host 'Comptario Local baslatilamadi.' -ForegroundColor Red
        Write-Host "Hata gunlugu: $StderrLog" -ForegroundColor Yellow
        Read-Host 'Pencereyi kapatmak icin Enter tusuna basin'
        exit 1
    }
    Write-Ok 'Uygulama hazir.'
}

Test-NativeStaticAssets

if ($env:COMPTARIO_NATIVE_NO_BROWSER -ne 'true') {
    Write-Step 'Tarayici aciliyor...'
    Start-Process $AppUrl
}

Write-Host ''
Write-Host 'Comptario Local calisiyor. Bu pencereyi kapatabilirsiniz.' -ForegroundColor Green
Start-Sleep -Seconds 2
