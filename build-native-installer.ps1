[CmdletBinding()]
param(
    # dist-native\ComptarioLocalNative zaten temiz ve guncel ise yeniden
    # derlemeyi atla (build-native-runtime.ps1 calistirilmaz).
    [switch]$SkipRuntimeBuild,
    # Payload denetiminde sorun bulunsa bile devam et (onerilmez).
    [switch]$Force
)

# ============================================================================
#  build-native-installer.ps1 - ComptarioLocalNativeSetup.exe olusturur.
# ----------------------------------------------------------------------------
#  1) Varsayilan olarak build-native-runtime.ps1'i calistirip temiz bir
#     dist-native\ComptarioLocalNative runtime payload'u uretir
#     (-SkipRuntimeBuild ile atlanabilir, ancak payload zaten mevcut olmalidir).
#  2) Payload'u denetler: .git, .env, uretilmis sirlar/veritabani/log/yedek,
#     Docker volume'lari, dist-installer, installer/payload, beklenmeyen
#     node_modules ve test artefaktlari OLMAMALI.
#  3) Inno Setup derleyicisini (ISCC.exe) bulur.
#  4) installer-native\ComptarioLocalNative.iss dosyasini derler.
#  5) Ciktiyi yazar: dist-native-installer\ComptarioLocalNativeSetup.exe
#     ve SHA-256 / boyut bilgisini yazdirir.
#
#  Bu betik musteri makinesinde DEGIL, paketi hazirlayan makinede calistirilir.
# ============================================================================

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RuntimeBuildScript = Join-Path $Root 'build-native-runtime.ps1'
$RuntimeRoot = Join-Path $Root 'dist-native\ComptarioLocalNative'
$InstallerDir = Join-Path $Root 'installer-native'
$IssFile = Join-Path $InstallerDir 'ComptarioLocalNative.iss'
$OutputDir = Join-Path $Root 'dist-native-installer'
$OutputExe = Join-Path $OutputDir 'ComptarioLocalNativeSetup.exe'

function Write-Step { param([string]$m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host "    $m" -ForegroundColor Green }
function Write-Note { param([string]$m) Write-Host "    $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "    $m" -ForegroundColor Red }

if (-not (Test-Path -LiteralPath $IssFile)) {
    throw "Inno Setup betigi bulunamadi: $IssFile"
}

# ----------------------------------------------------------------------------
# 1) Temiz native runtime payload'u uret veya dogrula
# ----------------------------------------------------------------------------
if ($SkipRuntimeBuild) {
    Write-Step 'Mevcut native runtime payload dogrulaniyor (-SkipRuntimeBuild)...'
    if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
        throw "dist-native\ComptarioLocalNative bulunamadi. -SkipRuntimeBuild kullanmadan calistirin."
    }
    Write-Ok "Bulundu: $RuntimeRoot"
} else {
    Write-Step 'Temiz native runtime olusturuluyor (build-native-runtime.ps1)...'
    & $RuntimeBuildScript
    if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
        throw "build-native-runtime.ps1 tamamlandi ancak cikti bulunamadi: $RuntimeRoot"
    }
}

# ----------------------------------------------------------------------------
# 2) Payload denetimi - yasak icerik olmamali
# ----------------------------------------------------------------------------
Write-Step 'Native runtime payload denetleniyor (yasak dosyalar/klasorler)...'
$problems = @()

function Test-ForbiddenDir {
    param([string]$Label, [string]$Name, [string[]]$AllowUnderRelative = @())
    $hits = Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -Directory -Force -Filter $Name -ErrorAction SilentlyContinue
    foreach ($h in $hits) {
        $rel = $h.FullName.Substring($RuntimeRoot.Length + 1)
        $allowed = $false
        foreach ($prefix in $AllowUnderRelative) {
            if ($rel -like "$prefix*") { $allowed = $true; break }
        }
        if (-not $allowed) { $script:problems += "$Label -> $($h.FullName)" }
    }
    if (-not $hits) { Write-Ok "Yok: $Label" }
}

function Test-ForbiddenFile {
    param([string]$Label, [string]$Filter, [string[]]$AllowUnderRelative = @())
    $hits = Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -File -Force -Filter $Filter -ErrorAction SilentlyContinue
    foreach ($h in $hits) {
        $rel = $h.FullName.Substring($RuntimeRoot.Length + 1)
        $allowed = $false
        foreach ($prefix in $AllowUnderRelative) {
            if ($rel -like "$prefix*") { $allowed = $true; break }
        }
        if (-not $allowed) { $script:problems += "$Label -> $($h.FullName)" }
    }
    if (-not $hits) { Write-Ok "Yok: $Label" }
}

Test-ForbiddenDir  '.git'              '.git'
Test-ForbiddenDir  '.codegraph'        '.codegraph'
Test-ForbiddenDir  '.claude'           '.claude'
Test-ForbiddenDir  '.devcontainer'     '.devcontainer'
Test-ForbiddenDir  '.vscode'           '.vscode'
Test-ForbiddenDir  'dist-installer'    'dist-installer'
Test-ForbiddenDir  'dist-native-installer' 'dist-native-installer'
Test-ForbiddenFile '.env'              '.env'
Test-ForbiddenFile '.env.local'        '.env.local'
# Uretilmis calisma zamani sirlari/yapilandirmasi: paket icinde olmamali,
# yalnizca musteri makinesinde ilk calistirmada olusturulur.
Test-ForbiddenFile 'native-runtime.env (uretilmis)' 'native-runtime.env'
# Uretilmis SQLite veritabani: paket icinde olmamali.
Test-ForbiddenFile 'comptario.db (uretilmis)' 'comptario.db'
Test-ForbiddenFile 'comptario.db-wal'  'comptario.db-wal'
Test-ForbiddenFile 'comptario.db-shm'  'comptario.db-shm'
# Docker'a ait hicbir sey native pakette olmamali (yalnizca kendi
# kodumuzda; bazi npm bagimliliklari (orn. bcrypt) kendi Dockerfile'larini
# yayinlama dokumantasyonu olarak node_modules icinde barindirir - bu
# zararsizdir ve denetlenmez).
function Test-ForbiddenInOwnCode {
    param([string]$Label, [string]$Filter, [switch]$Directory)
    $hits = if ($Directory) {
        Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -Directory -Force -Filter $Filter -ErrorAction SilentlyContinue
    } else {
        Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -File -Force -Filter $Filter -ErrorAction SilentlyContinue
    }
    $relevant = $hits | Where-Object { $_.FullName -notmatch '\\node_modules\\' }
    if ($relevant) {
        foreach ($h in $relevant) { $script:problems += "$Label -> $($h.FullName)" }
    } else {
        Write-Ok "Yok: $Label"
    }
}
Test-ForbiddenInOwnCode 'test'           'test'      -Directory
Test-ForbiddenInOwnCode '__tests__'      '__tests__' -Directory
Test-ForbiddenInOwnCode '*.spec.js'      '*.spec.js'
Test-ForbiddenInOwnCode '*.spec.ts'      '*.spec.ts'
Test-ForbiddenInOwnCode '*.test.js'      '*.test.js'
Test-ForbiddenInOwnCode 'tmp-*'          'tmp-*'
Test-ForbiddenInOwnCode 'docker-compose' 'docker-compose*.yml'
Test-ForbiddenInOwnCode 'Dockerfile'     'Dockerfile*'
# Bu paket kendi installer/installer-native kopyasini ic ice barindirmamali.
Test-ForbiddenDir 'installer/payload (ic ice)' 'payload'
Test-ForbiddenDir 'installer-native (ic ice)'  'installer-native'
Test-ForbiddenDir '.docker-local-runtime'      '.docker-local-runtime'

# node_modules: SADECE app\backend\node_modules altinda bulunabilir
# (production runtime bagimliliklari). Baska herhangi bir yerde olmamali.
$nodeModulesHits = Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -Directory -Force -Filter 'node_modules' -ErrorAction SilentlyContinue
$expectedNodeModules = Join-Path $RuntimeRoot 'app\backend\node_modules'
$topLevelOutsideExpected = $nodeModulesHits | Where-Object {
    $_.FullName -ne $expectedNodeModules -and $_.FullName -notlike "$expectedNodeModules\*"
}
foreach ($hit in $topLevelOutsideExpected) {
    $problems += "Beklenmeyen node_modules -> $($hit.FullName)"
}
if (-not (Test-Path -LiteralPath $expectedNodeModules)) {
    $problems += "Beklenen production node_modules eksik -> $expectedNodeModules"
} elseif ($topLevelOutsideExpected.Count -eq 0) {
    Write-Ok 'node_modules sadece app\backend\node_modules altinda (production runtime bagimliliklari)'
}

# data\, logs\, backups\ klasorleri sadece bos alt klasor yapisini icermeli
# (musteri verisi uretmeden once). Icerisinde dosya varsa bu, paketleme
# makinesinde uygulamanin yanlislikla calistirildigi anlamina gelir.
foreach ($dirName in @('data', 'logs', 'backups')) {
    $dirPath = Join-Path $RuntimeRoot $dirName
    if (Test-Path -LiteralPath $dirPath) {
        $files = Get-ChildItem -LiteralPath $dirPath -Recurse -File -Force -ErrorAction SilentlyContinue
        if ($files.Count -gt 0) {
            foreach ($f in $files) { $problems += "$dirName icinde uretilmis dosya -> $($f.FullName)" }
        } else {
            Write-Ok "Bos: $dirName"
        }
    }
}

$required = @(
    'runtime\node\node.exe',
    'app\backend\dist\src\main.js',
    'app\backend\public\dist\index.html',
    'app\backend\node_modules\sqlite3',
    'app\backend\node_modules\better-sqlite3',
    'assets\comptario.ico',
    'comptario-native.bat', 'comptario-native.ps1',
    'run-native-backend.ps1',
    'backup-native.bat', 'backup-native.ps1',
    'restore-native.bat', 'restore-native.ps1',
    'stop-native.bat', 'stop-native.ps1',
    'comptario-native-support.bat', 'comptario-native-support.ps1'
)
foreach ($rel in $required) {
    $p = Join-Path $RuntimeRoot $rel
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
Write-Step 'Native kurulum dosyasi derleniyor...'
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

# ----------------------------------------------------------------------------
# 5) Sonuc bilgisi
# ----------------------------------------------------------------------------
$hash = (Get-FileHash -LiteralPath $OutputExe -Algorithm SHA256).Hash.ToLowerInvariant()
$sizeMb = [Math]::Round((Get-Item -LiteralPath $OutputExe).Length / 1MB, 1)

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Ok 'Native kurulum dosyasi olusturuldu.'
Write-Host "    $OutputExe" -ForegroundColor White
Write-Ok "Boyut: $sizeMb MB"
Write-Ok "SHA-256: $hash"
Write-Host '============================================================' -ForegroundColor Green
