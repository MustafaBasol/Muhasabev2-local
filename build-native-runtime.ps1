[CmdletBinding()]
param(
    [string]$NodeVersion = '22.18.0',
    [string]$NodeZipPath
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputRoot = Join-Path $Root 'dist-native'
$RuntimeRoot = Join-Path $OutputRoot 'ComptarioLocalNative'
$BackendRuntime = Join-Path $RuntimeRoot 'app\backend'
$NodeRuntime = Join-Path $RuntimeRoot 'runtime\node'
$CacheRoot = Join-Path $Root '.native-cache'
$CachedNodeZip = Join-Path $CacheRoot "node-v$NodeVersion-win-x64.zip"

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok { param([string]$Message) Write-Host "    $Message" -ForegroundColor Green }
function Write-Note { param([string]$Message) Write-Host "    $Message" -ForegroundColor Yellow }

function Assert-WorkspacePath {
    param([string]$Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not $pathFull.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Workspace disindaki yol reddedildi: $pathFull"
    }
}

function Invoke-Npm {
    param(
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )
    Push-Location $WorkingDirectory
    try {
        & npm.cmd @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "npm islemi basarisiz oldu (kod $LASTEXITCODE): npm $($Arguments -join ' ')"
        }
    } finally {
        Pop-Location
    }
}

function Install-PrivateNode {
    New-Item -ItemType Directory -Path $NodeRuntime -Force | Out-Null
    New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null

    $zipToUse = $null
    if ($NodeZipPath) {
        $zipToUse = (Resolve-Path -LiteralPath $NodeZipPath).Path
    } elseif (Test-Path -LiteralPath $CachedNodeZip -PathType Leaf) {
        $zipToUse = $CachedNodeZip
    }

    if ($zipToUse) {
        Write-Step "Node.js v$NodeVersion Windows x64 arsivi aciliyor..."
        $extractRoot = Join-Path $OutputRoot '.node-extract'
        Assert-WorkspacePath $extractRoot
        if (Test-Path -LiteralPath $extractRoot) {
            Remove-Item -LiteralPath $extractRoot -Recurse -Force
        }
        Expand-Archive -LiteralPath $zipToUse -DestinationPath $extractRoot -Force
        $expanded = Get-ChildItem -LiteralPath $extractRoot -Directory |
            Where-Object { $_.Name -eq "node-v$NodeVersion-win-x64" } |
            Select-Object -First 1
        if (-not $expanded) {
            throw "Node arsivinde beklenen klasor bulunamadi: node-v$NodeVersion-win-x64"
        }
        Get-ChildItem -LiteralPath $expanded.FullName -Force |
            Copy-Item -Destination $NodeRuntime -Recurse -Force
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    } else {
        $installedNode = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
        $installedVersion = if ($installedNode) {
            (& $installedNode --version).Trim().TrimStart('v')
        } else {
            ''
        }
        if ($installedNode -and $installedVersion -eq $NodeVersion) {
            Write-Step "Kurulu Node.js v$NodeVersion paketleme kaynagi olarak kullaniliyor..."
            Copy-Item -LiteralPath $installedNode -Destination (Join-Path $NodeRuntime 'node.exe') -Force
            Write-Note 'Resmi ZIP bulunamadi; ayni sabit surumdeki yerel node.exe kopyalandi.'
        } else {
            $url = "https://nodejs.org/dist/v$NodeVersion/node-v$NodeVersion-win-x64.zip"
            Write-Step "Node.js v$NodeVersion Windows x64 indiriliyor..."
            Invoke-WebRequest -Uri $url -OutFile $CachedNodeZip
            Install-PrivateNode
            return
        }
    }

    $privateNode = Join-Path $NodeRuntime 'node.exe'
    if (-not (Test-Path -LiteralPath $privateNode -PathType Leaf)) {
        throw "Ozel Node.js runtime olusturulamadi: $privateNode"
    }
    $actualVersion = (& $privateNode --version).Trim()
    if ($actualVersion -ne "v$NodeVersion") {
        throw "Node surumu uyusmuyor. Beklenen v$NodeVersion, bulunan $actualVersion"
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $NodeRuntime 'NODE_VERSION.txt'),
        "$actualVersion Windows x64`r`n"
    )
    Write-Ok "Ozel Node.js runtime hazir: $actualVersion"
}

Write-Step 'Native runtime cikti klasoru temizleniyor...'
Assert-WorkspacePath $OutputRoot
if (Test-Path -LiteralPath $OutputRoot) {
    Remove-Item -LiteralPath $OutputRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $BackendRuntime -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $BackendRuntime 'public\dist') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $BackendRuntime 'config') -Force | Out-Null
@('assets', 'data', 'data\assets', 'data\assets\blog', 'logs', 'backups', 'config') |
    ForEach-Object {
        New-Item -ItemType Directory -Path (Join-Path $RuntimeRoot $_) -Force | Out-Null
    }

Write-Step 'Frontend production build olusturuluyor...'
$previousFrontendEnv = @{
    VITE_API_URL = $env:VITE_API_URL
    VITE_EMAIL_VERIFICATION_REQUIRED = $env:VITE_EMAIL_VERIFICATION_REQUIRED
    VITE_TURNSTILE_SITE_KEY = $env:VITE_TURNSTILE_SITE_KEY
    VITE_CAPTCHA_DEV_BYPASS = $env:VITE_CAPTCHA_DEV_BYPASS
    VITE_LOCAL_MODE = $env:VITE_LOCAL_MODE
}
try {
    $env:VITE_API_URL = '/api'
    $env:VITE_EMAIL_VERIFICATION_REQUIRED = 'false'
    $env:VITE_TURNSTILE_SITE_KEY = ''
    $env:VITE_CAPTCHA_DEV_BYPASS = 'true'
    $env:VITE_LOCAL_MODE = 'true'
    Invoke-Npm -Arguments @('run', 'build') -WorkingDirectory $Root
} finally {
    foreach ($key in $previousFrontendEnv.Keys) {
        [Environment]::SetEnvironmentVariable($key, $previousFrontendEnv[$key], 'Process')
    }
}

Write-Step 'Backend production build olusturuluyor...'
Invoke-Npm -Arguments @('run', 'build') -WorkingDirectory (Join-Path $Root 'backend')

Write-Step 'Backend runtime dosyalari kopyalaniyor...'
Copy-Item -LiteralPath (Join-Path $Root 'backend\package.json') -Destination $BackendRuntime -Force
Copy-Item -LiteralPath (Join-Path $Root 'backend\package-lock.json') -Destination $BackendRuntime -Force
Copy-Item -LiteralPath (Join-Path $Root 'backend\dist') -Destination (Join-Path $BackendRuntime 'dist') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $Root 'backend\config\plan-limits.json') -Destination (Join-Path $BackendRuntime 'config\plan-limits.json') -Force
Copy-Item -LiteralPath (Join-Path $Root 'backend\config\retention.json') -Destination (Join-Path $BackendRuntime 'config\retention.json') -Force
Get-ChildItem -LiteralPath (Join-Path $Root 'dist') -Force |
    Copy-Item -Destination (Join-Path $BackendRuntime 'public\dist') -Recurse -Force

Get-ChildItem -LiteralPath (Join-Path $BackendRuntime 'dist') -Recurse -File |
    Where-Object { $_.Extension -in @('.map', '.d.ts') -or $_.Name -like '*.tsbuildinfo' } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }

Write-Step 'Yalnizca production backend bagimliliklari kuruluyor...'
$previousNpmCache = $env:npm_config_cache
try {
    $env:npm_config_cache = Join-Path $Root 'backend\.npm-cache-local'
    New-Item -ItemType Directory -Path $env:npm_config_cache -Force | Out-Null
    Invoke-Npm `
        -Arguments @('ci', '--omit=dev', '--no-audit', '--no-fund') `
        -WorkingDirectory $BackendRuntime
} finally {
    [Environment]::SetEnvironmentVariable('npm_config_cache', $previousNpmCache, 'Process')
}

Write-Step 'Production dependency agaci sadelestiriliyor...'
$nodeModules = Join-Path $BackendRuntime 'node_modules'
Get-ChildItem -LiteralPath $nodeModules -Recurse -Directory -Force -Filter '.vscode' -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
Get-ChildItem -LiteralPath $nodeModules -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.key', '.pem', '.pfx') } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
@(
    (Join-Path $nodeModules 'ts-node'),
    (Join-Path $nodeModules 'typescript'),
    (Join-Path $nodeModules '@types'),
    (Join-Path $nodeModules 'node-gyp')
) | ForEach-Object {
    if (Test-Path -LiteralPath $_) {
        Remove-Item -LiteralPath $_ -Recurse -Force
    }
}

Write-Step 'Native Windows baslaticilari ve dokumanlari kopyalaniyor...'
$runtimeFiles = @(
    'comptario-native.ps1',
    'comptario-native.bat',
    'run-native-backend.ps1',
    'backup-native.ps1',
    'backup-native.bat',
    'restore-native.ps1',
    'restore-native.bat',
    'stop-native.ps1',
    'stop-native.bat',
    'comptario-native-support.ps1',
    'comptario-native-support.bat',
    'native-runtime.env.example',
    'NATIVE_WINDOWS_RUNTIME.md',
    'NATIVE_LOCAL_SQLITE_PLAN.md'
)
foreach ($file in $runtimeFiles) {
    $source = Join-Path $Root $file
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Native runtime icin gerekli dosya eksik: $file"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $RuntimeRoot $file) -Force
}
Copy-Item -LiteralPath (Join-Path $Root 'assets\comptario.ico') -Destination (Join-Path $RuntimeRoot 'assets\comptario.ico') -Force

Install-PrivateNode

Write-Step 'Native runtime payload denetleniyor...'
$problems = @()
$forbiddenDirs = @('.git', '.codegraph', '.claude', '.devcontainer', '.vscode')
foreach ($name in $forbiddenDirs) {
    Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -Directory -Force -Filter $name -ErrorAction SilentlyContinue |
        ForEach-Object { $problems += "Yasak klasor: $($_.FullName)" }
}
$forbiddenFiles = @('.env', '.env.local', '*.pem', '*.key', '*.pfx', '*.dump')
foreach ($filter in $forbiddenFiles) {
    Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -File -Force -Filter $filter -ErrorAction SilentlyContinue |
        ForEach-Object { $problems += "Yasak dosya: $($_.FullName)" }
}
$devPackages = @(
    '@nestjs\cli',
    'jest',
    'ts-jest',
    'ts-node',
    'typescript'
)
foreach ($rel in $devPackages) {
    $candidate = Join-Path (Join-Path $BackendRuntime 'node_modules') $rel
    if (Test-Path -LiteralPath $candidate) {
        $problems += "Dev paketi runtime'a girdi: $rel"
    }
}
$requiredFiles = @(
    'runtime\node\node.exe',
    'app\backend\dist\src\main.js',
    'app\backend\public\dist\index.html',
    'app\backend\node_modules\sqlite3',
    'app\backend\node_modules\better-sqlite3',
    'app\backend\node_modules\argon2',
    'app\backend\node_modules\bcrypt',
    'comptario-native.bat',
    'comptario-native.ps1',
    'run-native-backend.ps1',
    'stop-native.bat',
    'stop-native.ps1',
    'comptario-native-support.bat',
    'comptario-native-support.ps1',
    'assets\comptario.ico'
)
foreach ($rel in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot $rel))) {
        $problems += "Gerekli runtime ogesi eksik: $rel"
    }
}
if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    throw 'Native runtime payload denetimi basarisiz.'
}
Write-Ok 'Payload denetimi temiz.'

$files = Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -File -Force
$totalBytes = ($files | Measure-Object Length -Sum).Sum
$totalMb = [Math]::Round($totalBytes / 1MB, 1)

$manifest = [ordered]@{
    app = 'Comptario Local Native'
    phase = 2
    nodeVersion = "v$NodeVersion"
    architecture = 'win-x64'
    builtAtUtc = [DateTime]::UtcNow.ToString('o')
    fileCount = $files.Count
    sizeBytes = $totalBytes
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $RuntimeRoot 'runtime-manifest.json') -Encoding UTF8

Write-Host ''
Write-Ok "Native runtime hazir: $RuntimeRoot"
Write-Ok "Toplam boyut: $totalMb MB"
Write-Ok "Dosya sayisi: $($files.Count)"
