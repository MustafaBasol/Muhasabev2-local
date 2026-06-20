[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogsDir = Join-Path $Root 'logs'
$PidPath = Join-Path $LogsDir 'comptario-native.pid'

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok { param([string]$Message) Write-Host "    $Message" -ForegroundColor Green }
function Write-Note { param([string]$Message) Write-Host "    $Message" -ForegroundColor Yellow }

Write-Step 'Comptario Local durduruluyor...'

if (-not (Test-Path -LiteralPath $PidPath)) {
    Write-Note 'Uygulama zaten calismiyor.'
    return
}

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

Write-Ok 'Comptario Local durduruldu. Veriler korundu.'
