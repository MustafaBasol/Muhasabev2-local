[CmdletBinding()]
param(
    [string]$Label
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $Root 'data'
$DbPath = Join-Path $DataDir 'comptario.db'
$AssetsDir = Join-Path $DataDir 'assets'
$BackupsDir = Join-Path $Root 'backups'
$BetterSqlite3Entry = Join-Path $Root 'app\backend\node_modules\better-sqlite3'
$NodeExe = Join-Path $Root 'runtime\node\node.exe'

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok { param([string]$Message) Write-Host "    $Message" -ForegroundColor Green }

function Get-FileSha256 {
    param([string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# Uses better-sqlite3's backup() (SQLite online backup API) so a live WAL
# database is copied safely instead of via a raw file copy.
function Invoke-OnlineSqliteBackup {
    param([string]$SourceDb, [string]$DestinationDb)
    $script = @'
const Database = require(process.argv[2]);
const src = new Database(process.argv[3], { readonly: true, fileMustExist: true });
src.backup(process.argv[4])
    .then(() => { src.close(); process.exit(0); })
    .catch((err) => {
        console.error(err && err.message ? err.message : String(err));
        try { src.close(); } catch (_) {}
        process.exit(1);
    });
'@
    $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "comptario-backup-$([Guid]::NewGuid().ToString('N')).js"
    [System.IO.File]::WriteAllText($tempScript, $script, (New-Object System.Text.UTF8Encoding($false)))
    try {
        & $NodeExe $tempScript $BetterSqlite3Entry $SourceDb $DestinationDb
        if ($LASTEXITCODE -ne 0) {
            throw "Online SQLite yedeklemesi basarisiz oldu (kod $LASTEXITCODE)."
        }
    } finally {
        Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path -LiteralPath $DbPath -PathType Leaf)) {
    throw "Veritabani dosyasi bulunamadi: $DbPath. Once uygulamayi bir kez calistirin."
}
if (-not (Test-Path -LiteralPath $NodeExe -PathType Leaf)) {
    throw "Ozel Node.js calisma dosyasi bulunamadi: $NodeExe"
}

New-Item -ItemType Directory -Path $BackupsDir -Force | Out-Null

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$backupName = if ($Label) { "comptario-backup-$timestamp-$Label" } else { "comptario-backup-$timestamp" }
$stagingDir = Join-Path $BackupsDir ".staging-$timestamp"
$zipPath = Join-Path $BackupsDir "$backupName.zip"

if (Test-Path -LiteralPath $stagingDir) {
    Remove-Item -LiteralPath $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
$stagingDbPath = Join-Path $stagingDir 'comptario.db'
$stagingAssetsDir = Join-Path $stagingDir 'assets'

try {
    Write-Step 'SQLite online yedeklemesi yapiliyor (WAL guvenli)...'
    Invoke-OnlineSqliteBackup -SourceDb $DbPath -DestinationDb $stagingDbPath
    Write-Ok 'Veritabani guvenli sekilde kopyalandi.'

    Write-Step 'Varlik dosyalari kopyalaniyor...'
    if (Test-Path -LiteralPath $AssetsDir) {
        Copy-Item -LiteralPath $AssetsDir -Destination $stagingAssetsDir -Recurse -Force
    } else {
        New-Item -ItemType Directory -Path $stagingAssetsDir -Force | Out-Null
    }

    $dbChecksum = Get-FileSha256 -Path $stagingDbPath
    $assetFiles = Get-ChildItem -LiteralPath $stagingAssetsDir -Recurse -File -ErrorAction SilentlyContinue
    $assetCount = if ($assetFiles) { $assetFiles.Count } else { 0 }

    $manifest = [ordered]@{
        app = 'Comptario Local Native'
        backupFormatVersion = 1
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        dbFileName = 'comptario.db'
        dbChecksumSha256 = $dbChecksum
        assetFileCount = $assetCount
    }
    $manifestPath = Join-Path $stagingDir 'manifest.json'
    $manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    Write-Step 'Yedek arsivi olusturuluyor...'
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $stagingDir '*') -DestinationPath $zipPath -CompressionLevel Optimal

    Write-Host ''
    Write-Ok "Yedek olusturuldu: $zipPath"
    Write-Ok "Veritabani SHA256: $dbChecksum"
} finally {
    if (Test-Path -LiteralPath $stagingDir) {
        Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output $zipPath
