# Installer Plan (Inno Setup) — Comptario Local

> **Status: implemented.** The installer described here now exists. See:
> - `installer/ComptarioLocal.iss` — the Inno Setup script
> - `build-installer.ps1` — stages the payload and compiles the installer
> - `INSTALLER_BUILD.md` — how to build/test (for the packager)
> - `CUSTOMER_INSTALL_GUIDE.md` — Turkish customer install guide
>
> This document remains the design/rationale reference. The older delivery
> method (extract ZIP + run `install-local-shortcuts.ps1`) also keeps working.

This document describes how the local/on-premise package is turned into a
single-click Windows installer using [Inno Setup](https://jrsoftware.org/isinfo.php).

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

## Inno Setup Script — key design decisions

The full, authoritative script is `installer/ComptarioLocal.iss`. The notable
choices it makes:

- **`DefaultDirName=C:\ComptarioLocal`**, `PrivilegesRequired=admin` (writing
  under `C:\` needs elevation), stable `AppId` so re-running the installer
  upgrades in place. `SetupIconFile`/`UninstallDisplayIcon` use
  `assets\comptario.ico`.
- **`[Files]`** copies `payload\*` with `ignoreversion`. Because the staged
  payload contains no `.env.local`, no `local-backups`, and no `*.dump`, an
  upgrade physically cannot overwrite customer env files or delete backups.
- **Shortcuts are created natively in `[Icons]`** (not via
  `create-customer-shortcuts.ps1`). This is deliberate: under an elevated
  install, the PowerShell script's `GetFolderPath('Desktop')` would resolve to
  the *elevated* account, not the logged-in user. Inno's `{autodesktop}` /
  `{group}` resolve correctly under elevation. Every icon sets
  `IconFilename={app}\assets\comptario.ico` — never the Docker icon. The
  `create-customer-shortcuts.ps1` script remains the path used by the
  ZIP + `install-local-shortcuts.ps1` install method.
  - Desktop: one icon, `Comptario Local` (task `desktopicon`, checked by default).
  - `{group}\Comptario Local` plus `{group}\Support Tools\…` (Uygulamayı Aç,
    Yedek Al, Geri Yükle, Güncelle, Durdur, Destek Menüsü). The PowerShell-backed
    entries keep their window open with a trailing `Read-Host`.
- **`[Run]` — permissions:** an `icacls` step grants the built-in **Users** group
  (`*S-1-5-32-545`) `(OI)(CI)M` (Modify) on `{app}`, so the customer can run
  backup/update scripts (which write `.env.local`, `local-backups`) without being
  an admin.
- **`[Run]` — optional steps:** an *unchecked* `dockerautostart` task wires Docker
  Desktop into the Startup folder via `install-local-shortcuts.ps1`; an *unchecked*
  post-install checkbox can run `update-local-app.ps1 -NoPause` (rebuild) — left
  unchecked because daily use never needs a rebuild; a *checked* post-install
  checkbox launches `comptario-local.bat`.
- **`[Code]` — Docker prerequisite:** `InitializeSetup` checks for
  `C:\Program Files\Docker\Docker\Docker Desktop.exe`; if missing it shows the
  Turkish "Docker Desktop gereklidir" warning and still allows the install to
  continue. Docker Desktop is never bundled.
- **Uninstall data safety:** there is intentionally **no `[UninstallDelete]`**
  removing data. Uninstall removes only the installed program files and
  shortcuts; runtime-created `.env.local`, `local-backups`, and Docker volumes
  are left untouched. Fully purging data is a separate manual support action.

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

## Build Steps

These are implemented by `build-installer.ps1`; see `INSTALLER_BUILD.md` for the
full procedure.

1. `build-installer.ps1` stages a clean `installer\payload\` (via `robocopy`,
   stripping dev/secret/data files) and audits it.
2. It locates Inno Setup (`ISCC.exe`) and compiles `installer\ComptarioLocal.iss`.
3. Output: `dist-installer\ComptarioLocalSetup.exe`.
4. Test on a clean Windows VM: install → first launch → verify the app opens at
   <http://localhost:3000>, then test backup/restore/stop shortcuts and an
   upgrade-over-the-top (env files + `local-backups` must survive).
5. Sign the installer (code-signing certificate) to reduce SmartScreen warnings.
