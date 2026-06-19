[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppUrl = 'http://127.0.0.1:3000'
$HealthUrl = "$AppUrl/api/health"
$NodeExe = Join-Path $Root 'runtime\node\node.exe'
$BackendRoot = Join-Path $Root 'app\backend'
$BackendEntry = Join-Path $BackendRoot 'dist\src\main.js'
$BackendRunner = Join-Path $Root 'run-native-backend.ps1'
$BackupScript = Join-Path $Root 'backup-native.ps1'
$BetterSqlite3Entry = Join-Path $BackendRoot 'node_modules\better-sqlite3'
$ConfigPath = Join-Path $Root 'config\native-runtime.env'
$DataDir = Join-Path $Root 'data'
$DbPath = Join-Path $DataDir 'comptario.db'
$AssetsDir = Join-Path $DataDir 'assets'
$LogsDir = Join-Path $Root 'logs'
$BackupsDir = Join-Path $Root 'backups'
$PidPath = Join-Path $LogsDir 'comptario-native.pid'
$StdoutLog = Join-Path $LogsDir 'backend.log'
$StderrLog = Join-Path $LogsDir 'backend-error.log'

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok { param([string]$Message) Write-Host "    $Message" -ForegroundColor Green }
function Write-Note { param([string]$Message) Write-Host "    $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "    $Message" -ForegroundColor Red }

function Get-FileSha256 {
    param([string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-SqliteIntegrity {
    param([string]$DbFile)
    $script = @'
const Database = require(process.argv[2]);
const db = new Database(process.argv[3], { readonly: true, fileMustExist: true });
const result = db.pragma('integrity_check');
db.close();
const ok = Array.isArray(result) && result.length === 1 && result[0].integrity_check === 'ok';
console.log(ok ? 'OK' : 'FAIL');
process.exit(ok ? 0 : 1);
'@
    $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "comptario-integrity-$([Guid]::NewGuid().ToString('N')).js"
    [System.IO.File]::WriteAllText($tempScript, $script, (New-Object System.Text.UTF8Encoding($false)))
    try {
        & $NodeExe $tempScript $BetterSqlite3Entry $DbFile 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally {
        Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
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

function Stop-NativeBackend {
    if (Test-Path -LiteralPath $PidPath) {
        $pidText = (Get-Content -LiteralPath $PidPath -Raw).Trim()
        if ($pidText -match '^\d+$') {
            $proc = Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue
            if ($proc) {
                # The saved pid is the wrapper process that launches node.exe as a
                # child; /T kills that whole tree so the SQLite file handle is freed.
                & taskkill.exe /PID $proc.Id /T /F | Out-Null
            }
        }
        Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
    }

    for ($attempt = 1; $attempt -le 15; $attempt++) {
        $stillHolding = Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.ExecutablePath -eq $NodeExe }
        if (-not $stillHolding) { return }
        Start-Sleep -Seconds 1
    }
}

function Start-NativeBackend {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Calisma zamani ayar dosyasi bulunamadi: $ConfigPath"
    }
    foreach ($line in [System.IO.File]::ReadAllLines($ConfigPath)) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -le 0) { continue }
        $name = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1)
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }

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

    for ($attempt = 1; $attempt -le 60; $attempt++) {
        Start-Sleep -Seconds 1
        $health = Get-NativeHealth
        if ($health) { return $true }
    }
    return $false
}

# --- Resolve and validate the archive before touching any live data ---
if (-not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
    throw "Yedek dosyasi bulunamadi: $BackupPath"
}
$BackupPath = (Resolve-Path -LiteralPath $BackupPath).Path
if ([System.IO.Path]::GetExtension($BackupPath) -ne '.zip') {
    throw 'Yedek dosyasi bir .zip arsivi olmalidir.'
}
if (-not (Test-Path -LiteralPath $NodeExe -PathType Leaf)) {
    throw "Ozel Node.js calisma dosyasi bulunamadi: $NodeExe"
}

New-Item -ItemType Directory -Path $BackupsDir -Force | Out-Null
$timestamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$extractDir = Join-Path $BackupsDir ".restore-extract-$timestamp"
$holdingDir = Join-Path $BackupsDir ".previous-$timestamp"

Write-Step 'Yedek arsivi dogrulaniyor...'
if (Test-Path -LiteralPath $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force }
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
try {
    Expand-Archive -LiteralPath $BackupPath -DestinationPath $extractDir -Force
} catch {
    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    throw "Yedek arsivi acilamadi veya bozuk: $($_.Exception.Message)"
}

$manifestPath = Join-Path $extractDir 'manifest.json'
$extractedDb = Join-Path $extractDir 'comptario.db'
$extractedAssets = Join-Path $extractDir 'assets'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    throw 'Yedek arsivinde manifest.json bulunamadi. Arsiv gecersiz.'
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if (-not $manifest.dbChecksumSha256 -or -not (Test-Path -LiteralPath $extractedDb -PathType Leaf)) {
    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    throw 'Yedek arsivi gerekli alanlari icermiyor (veritabani veya checksum eksik). Arsiv gecersiz.'
}

$actualChecksum = Get-FileSha256 -Path $extractedDb
if ($actualChecksum -ne $manifest.dbChecksumSha256) {
    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    throw "Veritabani sifre toplami (checksum) uyusmuyor. Arsiv bozuk veya degistirilmis. Beklenen: $($manifest.dbChecksumSha256), Bulunan: $actualChecksum"
}
Write-Ok 'Checksum dogrulandi.'

Write-Step 'Veritabani butunlugu kontrol ediliyor...'
if (-not (Test-SqliteIntegrity -DbFile $extractedDb)) {
    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    throw 'Veritabani butunluk kontrolunden gecemedi. Arsiv geri yuklenmeyecek.'
}
Write-Ok 'Veritabani butunluk kontrolu basarili.'

if (-not (Test-Path -LiteralPath $extractedAssets)) {
    New-Item -ItemType Directory -Path $extractedAssets -Force | Out-Null
}

# --- Confirmation ---
if (-not $Force) {
    Write-Host ''
    Write-Note 'Bu islem mevcut musteri verisinin yerine yedekteki veriyi koyacak.'
    Write-Note "Yedek tarihi: $($manifest.createdAtUtc)"
    $answer = Read-Host 'Onaylamak icin RESTORE yazin'
    if ($answer -ne 'RESTORE') {
        Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Note 'Geri yukleme iptal edildi.'
        return
    }
}

try {
    Write-Step 'Calisan uygulama durduruluyor...'
    Stop-NativeBackend
    Write-Ok 'Uygulama durduruldu.'

    Write-Step 'Geri yuklemeden once otomatik guvenlik yedegi olusturuluyor...'
    $safetyBackupPath = $null
    if (Test-Path -LiteralPath $DbPath -PathType Leaf) {
        $safetyBackupPath = & $BackupScript -Label 'pre-restore-safety'
        Write-Ok "Guvenlik yedegi olusturuldu: $safetyBackupPath"
    } else {
        Write-Note 'Mevcut veritabani bulunamadi; guvenlik yedegi atlandi.'
    }

    Write-Step 'Mevcut veri gecici olarak tasiniyor...'
    New-Item -ItemType Directory -Path $holdingDir -Force | Out-Null
    Get-ChildItem -LiteralPath $DataDir -Filter 'comptario.db*' -File -ErrorAction SilentlyContinue |
        ForEach-Object { Move-Item -LiteralPath $_.FullName -Destination $holdingDir -Force }
    if (Test-Path -LiteralPath $AssetsDir) {
        Move-Item -LiteralPath $AssetsDir -Destination (Join-Path $holdingDir 'assets') -Force
    }

    Write-Step 'Yedekteki veri devreye aliniyor...'
    Move-Item -LiteralPath $extractedDb -Destination $DbPath -Force
    Move-Item -LiteralPath $extractedAssets -Destination $AssetsDir -Force

    Write-Step 'Uygulama yeniden baslatiliyor...'
    $started = Start-NativeBackend

    if ($started) {
        Write-Ok 'Uygulama saglik kontrolunu gecti.'
        Remove-Item -LiteralPath $holdingDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ''
        Write-Ok 'Geri yukleme tamamlandi.'
        if ($safetyBackupPath) {
            Write-Ok "Onceki veri bu yedekte saklaniyor: $safetyBackupPath"
        }
    } else {
        Write-Err 'Geri yuklenen uygulama saglik kontrolunden gecemedi. Onceki duruma donuluyor...'
        Stop-NativeBackend
        Remove-Item -LiteralPath $DbPath -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $DataDir -Filter 'comptario.db*' -File -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $AssetsDir) {
            Remove-Item -LiteralPath $AssetsDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Get-ChildItem -LiteralPath $holdingDir -Filter 'comptario.db*' -File -ErrorAction SilentlyContinue |
            ForEach-Object { Move-Item -LiteralPath $_.FullName -Destination $DataDir -Force }
        if (Test-Path -LiteralPath (Join-Path $holdingDir 'assets')) {
            Move-Item -LiteralPath (Join-Path $holdingDir 'assets') -Destination $AssetsDir -Force
        }
        Remove-Item -LiteralPath $holdingDir -Recurse -Force -ErrorAction SilentlyContinue
        $restoredOriginal = Start-NativeBackend
        if ($restoredOriginal) {
            Write-Note 'Onceki uygulama durumu geri yuklendi ve calisiyor.'
        } else {
            Write-Err 'Onceki uygulama durumu geri yuklenirken hata olustu. Loglara bakin.'
        }
        throw 'Geri yukleme basarisiz oldu; degisiklikler geri alindi.'
    }
} finally {
    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}
