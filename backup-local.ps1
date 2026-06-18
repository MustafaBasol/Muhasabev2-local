[CmdletBinding()]
param()

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

$dbUser = Read-EnvValue -Path '.env.local' -Name 'POSTGRES_USER' -Default 'moneyflow'
$dbName = Read-EnvValue -Path '.env.local' -Name 'POSTGRES_DB' -Default 'moneyflow_local'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$fileName = "muhasabe-$timestamp.dump"
$containerPath = "/tmp/$fileName"
$backupDirectory = Join-Path $Root 'local-backups'
$backupPath = Join-Path $backupDirectory $fileName

New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

& docker compose --env-file .env.local -f docker-compose.local.yml up -d postgres
if ($LASTEXITCODE -ne 0) {
    throw 'PostgreSQL could not be started.'
}

& docker compose --env-file .env.local -f docker-compose.local.yml exec -T postgres pg_dump -U $dbUser -d $dbName -Fc -f $containerPath
if ($LASTEXITCODE -ne 0) {
    throw 'PostgreSQL backup failed.'
}

& docker compose --env-file .env.local -f docker-compose.local.yml cp "postgres:$containerPath" $backupPath
if ($LASTEXITCODE -ne 0) {
    throw 'The backup could not be copied to the local-backups folder.'
}

& docker compose --env-file .env.local -f docker-compose.local.yml exec -T postgres rm -f $containerPath

$size = (Get-Item -LiteralPath $backupPath).Length
Write-Host "Backup created: $backupPath"
Write-Host "Backup size: $size bytes"
