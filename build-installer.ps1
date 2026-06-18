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
#  1) installer\payload klasorunu temiz bir sekilde hazirlar (dev/secret/veri
#     dosyalarini haric tutar).
#  2) Payload icerigini denetler (.env.local, node_modules, .git, .dump YOK).
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
# 1) Payload'u temiz hazirla
# ----------------------------------------------------------------------------
Write-Step 'Payload klasoru hazirlaniyor (temiz)...'
if (Test-Path -LiteralPath $PayloadDir) {
    Remove-Item -LiteralPath $PayloadDir -Recurse -Force
}
New-Item -ItemType Directory -Path $PayloadDir -Force | Out-Null

# robocopy ile kopyala. Haric tutulan klasorler ve dosyalar asagida.
# /XD: dizinleri haric tut, /XF: dosyalari haric tut.
$excludeDirs = @(
    (Join-Path $Root '.git')
    (Join-Path $Root 'installer')      # kendi cikti/payload klasorumuz (rekursiyonu onler)
    (Join-Path $Root 'dist-installer')
    (Join-Path $Root 'local-backups')
    '.codegraph'                        # ada gore (src\.codegraph, backend\src\.codegraph dahil)
    'node_modules'                      # ada gore (root + backend)
    'node_modules.partial'
    '.npm-cache-local'
    'dist'                              # ada gore (root dist + backend\dist)
)
$excludeFiles = @(
    '.env'                              # gercek kok secret (varsa) - paketlenmez
    '.env.local'                        # musteri secret - asla paketlenmez
    '*.dump'                            # yedekler
    '*.log'
    '*.zip'
    '*.sql'
)

$roboArgs = @($Root, $PayloadDir, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1')
$roboArgs += '/XD'; $roboArgs += $excludeDirs
$roboArgs += '/XF'; $roboArgs += $excludeFiles

& robocopy.exe @roboArgs | Out-Null
# robocopy: 0-7 basari, >=8 hata.
if ($LASTEXITCODE -ge 8) {
    throw "robocopy payload kopyalama sirasinda hata verdi (kod $LASTEXITCODE)."
}
$global:LASTEXITCODE = 0
Write-Ok 'Payload kopyalandi.'

# ----------------------------------------------------------------------------
# 2) Payload denetimi - yasak icerik olmamali
# ----------------------------------------------------------------------------
Write-Step 'Payload denetleniyor (yasak dosyalar)...'
$problems = @()

function Test-Forbidden {
    param([string]$Label, [scriptblock]$Finder)
    $hits = & $Finder
    if ($hits) {
        foreach ($h in $hits) { $script:problems += "$Label -> $($h.FullName)" }
    } else {
        Write-Ok "Yok: $Label"
    }
}

Test-Forbidden '.env.local'         { Get-ChildItem -LiteralPath $PayloadDir -Recurse -File -Force -Filter '.env.local' -ErrorAction SilentlyContinue }
Test-Forbidden 'node_modules'       { Get-ChildItem -LiteralPath $PayloadDir -Recurse -Directory -Force -Filter 'node_modules' -ErrorAction SilentlyContinue }
Test-Forbidden '.git'               { Get-ChildItem -LiteralPath $PayloadDir -Recurse -Directory -Force -Filter '.git' -ErrorAction SilentlyContinue }
Test-Forbidden '.codegraph'         { Get-ChildItem -LiteralPath $PayloadDir -Recurse -Directory -Force -Filter '.codegraph' -ErrorAction SilentlyContinue }
Test-Forbidden 'yedek (*.dump)'     { Get-ChildItem -LiteralPath $PayloadDir -Recurse -File -Force -Filter '*.dump' -ErrorAction SilentlyContinue }
Test-Forbidden 'local-backups'      { Get-ChildItem -LiteralPath $PayloadDir -Recurse -Directory -Force -Filter 'local-backups' -ErrorAction SilentlyContinue }

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
    'C:\Program Files\Inno Setup 6\ISCC.exe'
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
