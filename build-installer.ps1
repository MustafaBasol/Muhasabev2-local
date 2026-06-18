[CmdletBinding()]
param(
    # Yalnizca payload klasorunu hazirla, derleme yapma (denetim icin).
    [switch]$StageOnly,
    # Payload denetiminde yasak dosya bulunsa bile devam et (onerilmez).
    [switch]$Force
)

# ============================================================================
#  build-installer.ps1 - Comptario Local kurulum dosyasini olusturur.
# ----------------------------------------------------------------------------
#  1) installer\payload klasorunu KESIN BIR IZIN LISTESI (allowlist) ile
#     hazirlar. Repo'nun tamami kopyalanmaz; yalnizca Docker yerel paketinin
#     calismasi/yeniden derlenmesi icin gereken dosya ve klasorler kopyalanir.
#  2) Payload icerigini denetler (.env.local, node_modules, .git, .claude,
#     .devcontainer, .docker-local-runtime, *.dump, tmp-*, vb. YOK).
#  3) Inno Setup derleyicisini (ISCC.exe) bulur.
#  4) installer\ComptarioLocal.iss dosyasini derler.
#  5) Ciktiyi yazar: dist-installer\ComptarioLocalSetup.exe
#
#  Bu betik musteri makinesinde DEGIL, paketi hazirlayan makinede calistirilir.
#  Node.js, npm, Docker veya Git GEREKTIRMEZ (yalnizca Windows + Inno Setup).
# ============================================================================

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallerDir = Join-Path $Root 'installer'
$PayloadDir = Join-Path $InstallerDir 'payload'
$IssFile = Join-Path $InstallerDir 'ComptarioLocal.iss'
$OutputDir = Join-Path $Root 'dist-installer'
$OutputExe = Join-Path $OutputDir 'ComptarioLocalSetup.exe'

function Write-Step { param([string]$m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host "    $m" -ForegroundColor Green }
function Write-Note { param([string]$m) Write-Host "    $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "    $m" -ForegroundColor Red }

if (-not (Test-Path -LiteralPath $IssFile)) {
    throw "Inno Setup betigi bulunamadi: $IssFile"
}

# ----------------------------------------------------------------------------
# 1) Payload'u ALLOWLIST ile temiz hazirla (repo'nun tamami DEGIL)
# ----------------------------------------------------------------------------
Write-Step 'Payload klasoru hazirlaniyor (allowlist, temiz)...'
if (Test-Path -LiteralPath $PayloadDir) {
    Remove-Item -LiteralPath $PayloadDir -Recurse -Force
}
New-Item -ItemType Directory -Path $PayloadDir -Force | Out-Null

# Kok dizinde, var ise tek tek kopyalanacak dosyalar (Docker yerel paketi ve
# musteri betikleri/dokumanlari icin gerekenler ile sinirli).
$rootFiles = @(
    'docker-compose.local.yml'
    'Dockerfile.local'
    '.dockerignore'
    '.env.local.example'
    'package.json'
    'package-lock.json'
    'index.html'
    'vite.config.ts'
    'vite.config.production.ts'
    'tsconfig.json'
    'tsconfig.app.json'
    'tsconfig.node.json'
    'tailwind.config.js'
    'postcss.config.js'
    'comptario-local.ps1'
    'comptario-local.bat'
    'comptario-local-support.ps1'
    'comptario-local-support.bat'
    'launch-local-app.ps1'
    'launch-local-app.bat'
    'open-local-app.ps1'
    'open-local-app.bat'
    'start-local.ps1'
    'stop-local.ps1'
    'backup-local.ps1'
    'restore-local.ps1'
    'update-local-app.ps1'
    'update-local-app.bat'
    'create-customer-shortcuts.ps1'
    'create-desktop-shortcuts.ps1'
    'install-local-shortcuts.ps1'
    'CUSTOMER_INSTALL_GUIDE.md'
    'CUSTOMER_DAILY_USAGE.md'
    'LOCAL_CUSTOMER_SETUP.md'
    'LOCAL_TECHNICAL_NOTES.md'
    'INSTALLER_BUILD.md'
)

foreach ($rel in $rootFiles) {
    $src = Join-Path $Root $rel
    if (Test-Path -LiteralPath $src -PathType Leaf) {
        $dst = Join-Path $PayloadDir $rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
}

# Comptario uygulama simgesi: assets klasorunun TAMAMI degil, yalnizca ikon.
$iconSrc = Join-Path $Root 'assets\comptario.ico'
if (Test-Path -LiteralPath $iconSrc -PathType Leaf) {
    New-Item -ItemType Directory -Path (Join-Path $PayloadDir 'assets') -Force | Out-Null
    Copy-Item -LiteralPath $iconSrc -Destination (Join-Path $PayloadDir 'assets\comptario.ico') -Force
}

# Bir klasoru robocopy ile, dahili dev/secret/uretilmis alt klasorleri haric
# tutarak kopyalayan yardimci fonksiyon.
function Copy-AllowedDir {
    param(
        [string]$RelSource,
        [string]$RelDest = $RelSource,
        [string[]]$ExtraExcludeDirs = @()
    )
    $src = Join-Path $Root $RelSource
    if (-not (Test-Path -LiteralPath $src -PathType Container)) { return }
    $dst = Join-Path $PayloadDir $RelDest
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    $excludeDirs = @('.git', '.codegraph', '.claude', '.devcontainer', '.docker-local-runtime',
                      '.vscode', '.idea', 'node_modules', 'node_modules.partial',
                      '.npm-cache-local', 'dist') + $ExtraExcludeDirs
    $excludeFiles = @('.env', '.env.local', '*.dump', '*.log', '*.zip', '*.sql',
                       'tmp-*', '*.tsbuildinfo', 'profile.csv', 'user_data.json')
    $roboArgs = @($src, $dst, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1')
    $roboArgs += '/XD'; $roboArgs += $excludeDirs
    $roboArgs += '/XF'; $roboArgs += $excludeFiles
    & robocopy.exe @roboArgs | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy '$RelSource' kopyalama sirasinda hata verdi (kod $LASTEXITCODE)."
    }
    $global:LASTEXITCODE = 0
}

# Frontend kaynaklari (Docker build context icin gerekli).
Copy-AllowedDir -RelSource 'src'
Copy-AllowedDir -RelSource 'public'

# Backend: SADECE Docker build/runtime icin gereken alt kume.
# (backend/node_modules, backend/dist, backend/.env*, backend/backups,
#  backend/test, backend/*.db ve gelistirme betikleri kopyalanmaz.)
$backendDst = Join-Path $PayloadDir 'backend'
New-Item -ItemType Directory -Path $backendDst -Force | Out-Null

$backendRootFiles = @('package.json', 'package-lock.json', 'nest-cli.json', '.env.local.example')
foreach ($rel in $backendRootFiles) {
    $src = Join-Path $Root "backend\$rel"
    if (Test-Path -LiteralPath $src -PathType Leaf) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $backendDst $rel) -Force
    }
}
Get-ChildItem -LiteralPath (Join-Path $Root 'backend') -Filter 'tsconfig*.json' -File -ErrorAction SilentlyContinue |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $backendDst $_.Name) -Force }

Copy-AllowedDir -RelSource 'backend\src' -RelDest 'backend\src'
# backend/public/assets is build-generated (copied from the frontend build at
# Docker build time) - excluded here so the payload stays minimal and never
# ships stale generated assets.
Copy-AllowedDir -RelSource 'backend\public' -RelDest 'backend\public' -ExtraExcludeDirs @('assets')

Write-Ok 'Payload kopyalandi (allowlist).'

# ----------------------------------------------------------------------------
# 2) Payload denetimi - yasak icerik olmamali
# ----------------------------------------------------------------------------
Write-Step 'Payload denetleniyor (yasak dosyalar/klasorler)...'
$problems = @()

function Test-ForbiddenDir {
    param([string]$Label, [string]$Name)
    $hits = Get-ChildItem -LiteralPath $PayloadDir -Recurse -Directory -Force -Filter $Name -ErrorAction SilentlyContinue
    if ($hits) {
        foreach ($h in $hits) { $script:problems += "$Label -> $($h.FullName)" }
    } else {
        Write-Ok "Yok: $Label"
    }
}

function Test-ForbiddenFile {
    param([string]$Label, [string]$Filter)
    $hits = Get-ChildItem -LiteralPath $PayloadDir -Recurse -File -Force -Filter $Filter -ErrorAction SilentlyContinue
    if ($hits) {
        foreach ($h in $hits) { $script:problems += "$Label -> $($h.FullName)" }
    } else {
        Write-Ok "Yok: $Label"
    }
}

Test-ForbiddenDir  '.docker-local-runtime' '.docker-local-runtime'
Test-ForbiddenDir  '.git'                  '.git'
Test-ForbiddenDir  '.claude'                '.claude'
Test-ForbiddenDir  '.devcontainer'          '.devcontainer'
Test-ForbiddenDir  '.codegraph'             '.codegraph'
Test-ForbiddenDir  'node_modules'           'node_modules'
Test-ForbiddenDir  'dist-installer'         'dist-installer'
Test-ForbiddenFile '.env.local'             '.env.local'
Test-ForbiddenFile '.env'                   '.env'
Test-ForbiddenFile 'yedek (*.dump)'         '*.dump'
Test-ForbiddenFile 'tmp-*'                  'tmp-*'
Test-ForbiddenFile '*.tsbuildinfo'          '*.tsbuildinfo'
Test-ForbiddenFile 'profile.csv'            'profile.csv'
Test-ForbiddenFile 'user_data.json'         'user_data.json'

# installer\payload kendi icine ic ice paketlenmis olmamali.
$nestedPayload = Join-Path $PayloadDir 'installer\payload'
if (Test-Path -LiteralPath $nestedPayload) {
    $problems += "installer\payload payload icinde ic ice -> $nestedPayload"
} else {
    Write-Ok 'Yok: installer\payload (ic ice)'
}

# local-backups payload icinde olmamali (musteri verisi).
Test-ForbiddenDir 'local-backups' 'local-backups'

# Docker'in yeniden insa icin ihtiyac duydugu cekirdek dosyalar mevcut mu?
$required = @(
    'docker-compose.local.yml', 'Dockerfile.local', '.dockerignore',
    '.env.local.example', 'backend\.env.local.example',
    'assets\comptario.ico',
    'comptario-local.bat', 'comptario-local.ps1',
    'package.json', 'package-lock.json',
    'backend\package.json', 'backend\package-lock.json',
    'index.html', 'src', 'public', 'backend\src'
)
foreach ($rel in $required) {
    $p = Join-Path $PayloadDir $rel
    if (-not (Test-Path -LiteralPath $p)) {
        $problems += "EKSIK gerekli dosya/klasor -> $rel"
    }
}

if ($problems.Count -gt 0) {
    Write-Host ''
    Write-Err 'Payload denetimi sorunlar buldu:'
    $problems | ForEach-Object { Write-Err "  - $_" }
    if (-not $Force) {
        throw 'Payload denetimi basarisiz. Duzeltin veya -Force ile zorlayin (onerilmez).'
    }
    Write-Note '-Force verildi: sorunlara ragmen devam ediliyor.'
} else {
    Write-Ok 'Payload denetimi temiz.'
}

# ----------------------------------------------------------------------------
# 2b) Payload ozeti
# ----------------------------------------------------------------------------
Write-Step 'Payload ozeti hazirlaniyor...'
$allFiles = Get-ChildItem -LiteralPath $PayloadDir -Recurse -File -Force
$totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum
$totalSizeMb = [Math]::Round($totalSize / 1MB, 1)
$topLevel = Get-ChildItem -LiteralPath $PayloadDir -Force | Select-Object -ExpandProperty Name | Sort-Object

Write-Ok "Toplam boyut: $totalSizeMb MB"
Write-Ok "Toplam dosya sayisi: $($allFiles.Count)"
Write-Ok "Ust seviye ogeler: $($topLevel -join ', ')"

# Kaynakta (repo) bulunan ama bilerek payload'a kopyalanmayan tehlikeli yollar.
$dangerousNames = @('.git', '.codegraph', '.claude', '.devcontainer', '.docker-local-runtime',
                     'node_modules', 'dist-installer', 'local-backups')
$foundButExcluded = @()
foreach ($name in $dangerousNames) {
    $hit = Get-ChildItem -LiteralPath $Root -Force -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { $foundButExcluded += $name }
}
if ($foundButExcluded.Count -gt 0) {
    Write-Note "Kaynakta mevcut ama payload'a kopyalanmayan: $($foundButExcluded -join ', ')"
}

if ($StageOnly) {
    Write-Host ''
    Write-Ok "Payload hazir: $PayloadDir"
    Write-Note '-StageOnly verildi: derleme atlandi.'
    return
}

# ----------------------------------------------------------------------------
# 3) Inno Setup derleyicisini bul
# ----------------------------------------------------------------------------
Write-Step 'Inno Setup derleyicisi (ISCC.exe) araniyor...'
$isccCandidates = @(
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 6\ISCC.exe',
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
)
$iscc = $isccCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $iscc) {
    $cmd = Get-Command 'iscc.exe' -ErrorAction SilentlyContinue
    if ($cmd) { $iscc = $cmd.Source }
}

if (-not $iscc) {
    Write-Host ''
    Write-Err 'Inno Setup 6 bulunamadi.'
    Write-Host ''
    Write-Host 'Kurulum:' -ForegroundColor White
    Write-Host '  1) https://jrsoftware.org/isdl.php adresinden Inno Setup 6 indirin.' -ForegroundColor Gray
    Write-Host '  2) Varsayilan konuma kurun:' -ForegroundColor Gray
    Write-Host '       C:\Program Files (x86)\Inno Setup 6\' -ForegroundColor Gray
    Write-Host '  3) Veya: winget install JRSoftware.InnoSetup' -ForegroundColor Gray
    Write-Host '  4) Kurduktan sonra bu betigi tekrar calistirin.' -ForegroundColor Gray
    Write-Host ''
    throw 'ISCC.exe bulunamadi. Inno Setup kurun ve tekrar deneyin.'
}
Write-Ok "Bulundu: $iscc"

# ----------------------------------------------------------------------------
# 4) Derle
# ----------------------------------------------------------------------------
Write-Step 'Kurulum dosyasi derleniyor...'
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

& $iscc $IssFile
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup derlemesi basarisiz oldu (kod $LASTEXITCODE)."
}

if (-not (Test-Path -LiteralPath $OutputExe)) {
    throw "Derleme bitti ancak cikti bulunamadi: $OutputExe"
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Ok 'Kurulum dosyasi olusturuldu.'
Write-Host "    $OutputExe" -ForegroundColor White
Write-Host '============================================================' -ForegroundColor Green
