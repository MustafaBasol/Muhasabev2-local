[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function New-RandomSecret {
    param([int]$Bytes = 48)
    $buffer = New-Object byte[] $Bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($buffer)
    } finally {
        $rng.Dispose()
    }
    return [Convert]::ToBase64String($buffer)
}

function Ensure-EnvFile {
    param(
        [string]$ExamplePath,
        [string]$TargetPath
    )
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        Copy-Item -LiteralPath $ExamplePath -Destination $TargetPath
        Write-Host "Created $TargetPath from its example."
    } else {
        Write-Host "Preserving existing $TargetPath."
    }
}

function Replace-PlaceholderSecret {
    param(
        [string]$Path,
        [string]$Name,
        [string[]]$Placeholders
    )
    $lines = [System.IO.File]::ReadAllLines($Path)
    $changed = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match "^$([regex]::Escape($Name))=(.*)$") {
            $current = $Matches[1].Trim()
            if ($Placeholders -contains $current) {
                $lines[$i] = "$Name=$(New-RandomSecret)"
                $changed = $true
            }
        }
    }
    if ($changed) {
        [System.IO.File]::WriteAllLines($Path, $lines, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Generated a unique value for $Name."
    }
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop is not running. Start Docker Desktop, wait until it is ready, then run this script again."
}

Ensure-EnvFile -ExamplePath '.env.local.example' -TargetPath '.env.local'
Ensure-EnvFile -ExamplePath 'backend\.env.local.example' -TargetPath 'backend\.env.local'

Replace-PlaceholderSecret -Path 'backend\.env.local' -Name 'JWT_SECRET' -Placeholders @(
    'REPLACE_WITH_GENERATED_LOCAL_JWT_SECRET',
    'your_super_secret_jwt_key_min_256_bits_long_very_secure_key_here',
    'default-secret'
)
Replace-PlaceholderSecret -Path 'backend\.env.local' -Name 'JWT_REFRESH_SECRET' -Placeholders @(
    'REPLACE_WITH_GENERATED_LOCAL_REFRESH_SECRET',
    'your_refresh_token_secret_key_different_from_access_token'
)
Replace-PlaceholderSecret -Path 'backend\.env.local' -Name 'CSRF_SECRET' -Placeholders @(
    'REPLACE_WITH_GENERATED_LOCAL_CSRF_SECRET'
)

New-Item -ItemType Directory -Path 'local-backups' -Force | Out-Null

Write-Host 'Starting the local application...'
& docker compose --env-file .env.local -f docker-compose.local.yml up -d --build
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose failed with exit code $LASTEXITCODE."
}

$healthUrl = 'http://localhost:3000/api/health'
$healthy = $false
$maxAttempts = 90
$pollIntervalSec = 5
$maxWaitMin = [math]::Round($maxAttempts * $pollIntervalSec / 60, 0)
Write-Host "Waiting for the app to become healthy (up to $maxWaitMin minutes)..."
Start-Sleep -Seconds 10
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5
        if ($health.appStatus -eq 'ok' -and $health.dbStatus -eq 'ok') {
            $healthy = $true
            break
        }
    } catch {
        # Container not ready yet — keep waiting
    }
    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds $pollIntervalSec
    }
}

if (-not $healthy) {
    & docker compose --env-file .env.local -f docker-compose.local.yml ps
    throw "The app did not become healthy within $maxWaitMin minutes. Review logs with: docker compose --env-file .env.local -f docker-compose.local.yml logs app"
}

Write-Host ''
Write-Host 'Local application is ready.'
Write-Host 'App:      http://localhost:3000'
Write-Host 'Health:   http://localhost:3000/api/health'
Write-Host 'Database: 127.0.0.1:5433'
Write-Host 'Login:    No default account. Register the first customer user in the app.'
Write-Host 'pgAdmin:  Optional; start with docker compose --env-file .env.local -f docker-compose.local.yml --profile support up -d pgadmin'
