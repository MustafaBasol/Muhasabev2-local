[CmdletBinding()]
param(
    [string]$BackupFile,
    [switch]$ConfirmRestore
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Read-EnvValue {
    param([string]$Path, [string]$Name, [string]$Default)
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match "^$([regex]::Escape($Name))=(.*)$") {
            return $Matches[1].Trim()
        }
    }
    return $Default
}

if (-not (Test-Path -LiteralPath '.env.local')) {
    throw '.env.local is missing. Run .\start-local.ps1 first.'
}

if ([string]::IsNullOrWhiteSpace($BackupFile)) {
    $latest = Get-ChildItem -LiteralPath (Join-Path $Root 'local-backups') -Filter '*.dump' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $latest) {
        throw 'No .dump backup was found in local-backups.'
    }
    $BackupFile = $latest.FullName
}

$resolvedBackup = (Resolve-Path -LiteralPath $BackupFile).Path
if (-not $ConfirmRestore) {
    Write-Host ''
    Write-Host "Geri yuklenecek yedek: $resolvedBackup" -ForegroundColor Yellow
    Write-Host 'Bu islem mevcut veritabanini yedekten geri yukleyecek.' -ForegroundColor Yellow
    $confirmation = Read-Host "Devam etmek icin GERIYUKLE yazip Enter'a basin"
    if ($confirmation -cne 'GERIYUKLE') {
        Write-Host 'Geri yukleme iptal edildi. Hicbir veri degistirilmedi.'
        exit 0
    }
}

$dbUser = Read-EnvValue -Path '.env.local' -Name 'POSTGRES_USER' -Default 'moneyflow'
$dbName = Read-EnvValue -Path '.env.local' -Name 'POSTGRES_DB' -Default 'moneyflow_local'
$containerPath = "/tmp/restore-$([Guid]::NewGuid().ToString('N')).dump"
$appStopped = $false

try {
    & docker compose --env-file .env.local -f docker-compose.local.yml stop app
    if ($LASTEXITCODE -ne 0) {
        throw 'The app container could not be stopped.'
    }
    $appStopped = $true

    & docker compose --env-file .env.local -f docker-compose.local.yml up -d postgres
    if ($LASTEXITCODE -ne 0) {
        throw 'PostgreSQL could not be started.'
    }

    & docker compose --env-file .env.local -f docker-compose.local.yml cp $resolvedBackup "postgres:$containerPath"
    if ($LASTEXITCODE -ne 0) {
        throw 'The backup could not be copied into PostgreSQL.'
    }

    & docker compose --env-file .env.local -f docker-compose.local.yml exec -T postgres dropdb --if-exists --force -U $dbUser $dbName
    if ($LASTEXITCODE -ne 0) {
        throw 'The current database could not be removed.'
    }

    & docker compose --env-file .env.local -f docker-compose.local.yml exec -T postgres createdb -U $dbUser -O $dbUser $dbName
    if ($LASTEXITCODE -ne 0) {
        throw 'A clean database could not be created.'
    }

    & docker compose --env-file .env.local -f docker-compose.local.yml exec -T postgres pg_restore -U $dbUser -d $dbName --no-owner --no-privileges $containerPath
    if ($LASTEXITCODE -ne 0) {
        throw 'PostgreSQL restore failed.'
    }

    & docker compose --env-file .env.local -f docker-compose.local.yml exec -T postgres rm -f $containerPath
    & docker compose --env-file .env.local -f docker-compose.local.yml up -d app
    if ($LASTEXITCODE -ne 0) {
        throw 'The app container could not be restarted.'
    }
    $appStopped = $false
} finally {
    if ($appStopped) {
        Write-Warning 'Restore did not finish; attempting to restart the app container.'
        & docker compose --env-file .env.local -f docker-compose.local.yml up -d app
    }
}

Write-Host "Restore completed from: $resolvedBackup"
Write-Host 'The app is restarting at http://localhost:3000'
