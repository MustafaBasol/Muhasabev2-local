[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

if (-not (Test-Path -LiteralPath '.env.local')) {
    throw '.env.local is missing. Run .\start-local.ps1 first.'
}

& docker compose --env-file .env.local -f docker-compose.local.yml down
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose failed with exit code $LASTEXITCODE."
}

Write-Host 'Local containers stopped. Customer data volumes were preserved.'
