# Installer Plan (Inno Setup) — Comptario Local

This document describes how the local/on-premise package can later be turned
into a single-click Windows installer using [Inno Setup](https://jrsoftware.org/isinfo.php).
It is a plan only; no installer is built yet. The current delivery method
(extract ZIP + run `install-local-shortcuts.ps1`) keeps working until then.

## Goals

- Customer runs **one** `ComptarioLocalSetup.exe`.
- Files are copied to a stable location: **`C:\ComptarioLocal`**.
- Exactly **one** desktop shortcut is created: **“Comptario Local”**.
- Support tools (Yedek Al, Geri Yükle, Güncelle, Durdur, Aç, Destek Menüsü) are
  placed under the Start Menu folder **“Comptario Local\Support Tools”**, not on
  the desktop.
- All customer-facing shortcuts use the **Comptario application icon**
  (`{app}\assets\comptario.ico`). The installer must **never** create
  Docker-icon shortcuts, and must **never** create six desktop shortcuts.
- Docker-based architecture is unchanged. The installer does **not** replace
  Docker; it only lays down files and shortcuts.
- No Git, Node.js, npm, VS Code, or PowerShell knowledge required from the
  customer.
- Data safety: the installer must never delete Docker volumes, the
  `local-backups` folder, or existing `.env` files on upgrade.

## What the Installer Ships

The installer payload is the contents of this repository needed to build and
run locally, including:

- `docker-compose.local.yml`, `Dockerfile.local`
- Application source needed by the Docker build (frontend + `backend/`)
- `.env.local.example`, `backend/.env.local.example`
- The Comptario icon: `assets/comptario.ico`
- Scripts: `comptario-local.ps1/.bat` (main launcher),
  `comptario-local-support.ps1/.bat` (support menu),
  `create-customer-shortcuts.ps1`, `install-local-shortcuts.ps1`,
  `launch-local-app.ps1/.bat`, `open-local-app.ps1/.bat`,
  `update-local-app.ps1/.bat`, `start-local.ps1`, `stop-local.ps1`,
  `backup-local.ps1`, `restore-local.ps1`, `create-desktop-shortcuts.ps1`
  (compatibility shim that forwards to `create-customer-shortcuts.ps1`)
- Docs: `LOCAL_CUSTOMER_SETUP.md`, `CUSTOMER_DAILY_USAGE.md`

It should **exclude** developer-only files (`.git`, `node_modules`, build
output, local secrets `.env.local`, `local-backups/`).

## Docker Desktop Dependency

Docker Desktop is a separate, large product. The installer should **not** bundle
or silently install it. Instead:

- During install, check whether `C:\Program Files\Docker\Docker\Docker Desktop.exe`
  exists.
- If missing, show a message with the download link
  (<https://www.docker.com/products/docker-desktop>) and let the customer
  continue (the `Başlat` shortcut already explains this if Docker is absent).
- Optionally offer to enable Docker auto-start (see below).

## Inno Setup Script Sketch

```ini
[Setup]
AppName=Comptario Local
AppVersion=1.0.0
DefaultDirName=C:\ComptarioLocal
DisableProgramGroupPage=yes
PrivilegesRequired=admin            ; needed to write under C:\
OutputBaseFilename=ComptarioLocalSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Installer/uninstaller icon uses the Comptario brand mark.
SetupIconFile=payload\assets\comptario.ico

[Files]
; Copy the prepared payload. Exclusions keep secrets/data/dev files out.
; The payload includes assets\comptario.ico, used for every customer shortcut.
Source: "payload\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Tasks]
Name: "desktopicon"; Description: "Masaüstüne 'Comptario Local' kısayolu ekle"; Flags: checkedonce
Name: "dockerautostart"; Description: "Docker Desktop'ı Windows ile başlat"; Flags: unchecked

[Run]
; Create the single "Comptario Local" desktop icon AND the Start Menu folder
; (Comptario Local\Support Tools) by reusing the PowerShell script. The script
; applies assets\comptario.ico to every shortcut and never uses the Docker icon.
; Do NOT pass -IncludeSupportShortcuts here: support tools stay in the Start Menu.
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\create-customer-shortcuts.ps1"""; \
  WorkingDir: "{app}"; Flags: runhidden; Tasks: desktopicon

; Optionally enable Docker auto-start (Startup-folder shortcut).
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install-local-shortcuts.ps1"" -StartDockerWithWindows -NoPrompt"; \
  WorkingDir: "{app}"; Flags: runhidden; Tasks: dockerautostart

[UninstallDelete]
; IMPORTANT: do NOT delete user data on uninstall.
; Leave local-backups and .env.local in place. Docker volumes are managed by
; Docker and are never touched by this installer.
```

> Note: `create-customer-shortcuts.ps1` builds shortcuts on the **current user's**
> desktop and Start Menu using `[Environment]::GetFolderPath('Desktop')` /
> `('Programs')`. When run elevated by the installer this resolves to the
> elevated user; if that differs from the end user, pass `-DesktopPath` /
> `-StartMenuPath` explicitly or run the shortcut step non-elevated. Validate
> this during installer testing.

## Upgrade & Data-Safety Rules

- On reinstall/upgrade, overwrite only program and script files. Never overwrite
  an existing `.env.local` or `backend\.env.local`.
- Never remove `local-backups/`.
- Never run `docker compose down -v` or any volume-deleting command.
- After an upgrade replaces the files, rebuild and restart by reusing the
  existing update script — the installer should not embed its own rebuild logic:

  ```ini
  [Run]
  ; Rebuild + restart on upgrade (data-safe; runs only when an install exists).
  ; -NoPause keeps it non-interactive so the installer is never blocked by Read-Host.
  Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\update-local-app.ps1"" -NoPause"; \
    WorkingDir: "{app}"; Description: "Yeni sürümü uygula"; \
    Flags: postinstall skipifsilent runhidden
  ```

  Pass **`-NoPause`** when the installer runs the script: this suppresses the
  closing `Read-Host` and the error prompt so the script exits on its own instead
  of blocking the installer. The desktop **“Comptario Local Güncelle”** shortcut
  (via `update-local-app.bat`) deliberately omits `-NoPause` so its window stays
  open for the support person.

  `update-local-app.ps1` only rebuilds the `app` image (`build --no-cache app`)
  and runs `up -d`; it never deletes volumes, overwrites `.env` files, or touches
  `local-backups`, so it is safe to invoke from the installer.
- Uninstall removes program files and desktop shortcuts only. Customer data
  (Docker volumes + backups) is intentionally preserved; document how to fully
  purge data manually for customers who request it.

## Build Steps (Future)

1. Stage a clean `payload\` folder (export from Git, strip dev/secret files).
2. Install Inno Setup, create `ComptarioLocal.iss` from the sketch above.
3. Compile to `ComptarioLocalSetup.exe`.
4. Test on a clean Windows VM: install → first `Başlat` → verify the app opens
   at <http://localhost:3000>, then test backup/restore/stop shortcuts.
5. Sign the installer (code-signing certificate) to reduce SmartScreen warnings.
