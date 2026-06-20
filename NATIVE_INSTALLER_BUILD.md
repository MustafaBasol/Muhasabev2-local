# Native Installer Build — `ComptarioLocalNativeSetup.exe`

This document covers building and validating the Docker-free native Windows
installer. It does not replace the Docker installer
([`INSTALLER_BUILD.md`](./INSTALLER_BUILD.md)) — both packages remain
available; this is an additional, separate package.

## Prerequisites (packaging machine only)

- Windows with Node.js/npm and the repository's dependencies (to build the
  frontend/backend and install production backend dependencies).
- [Inno Setup 6](https://jrsoftware.org/isdl.php), at one of:
  - `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`
  - `C:\Program Files\Inno Setup 6\ISCC.exe`
  - `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`
  - or `ISCC.exe` on `PATH`

The customer machine needs **none** of this — no Docker, WSL, PostgreSQL,
Redis, global Node.js, npm, or Git.

## Build

From the repository root:

```powershell
.\build-native-installer.ps1
```

This:

1. Runs `build-native-runtime.ps1` to produce a clean
   `dist-native\ComptarioLocalNative` runtime (unless `-SkipRuntimeBuild` is
   passed and that folder already exists).
2. Audits the runtime payload and fails the build if it finds: `.git`,
   `.env`/`.env.local`, a generated `config\native-runtime.env`, a generated
   `data\comptario.db`, non-empty `logs\`/`backups\`/`data\`, Docker
   files/volumes, `dist-installer`, an embedded `installer`/`installer-native`
   copy, `node_modules` anywhere other than
   `app\backend\node_modules` (production runtime dependencies are expected
   there and are not flagged), or test artifacts in our own code (test
   folders/spec files *inside* npm dependencies are not flagged).
3. Locates `ISCC.exe`.
4. Compiles `installer-native\ComptarioLocalNative.iss`.
5. Writes `dist-native-installer\ComptarioLocalNativeSetup.exe` and prints its
   SHA-256 hash and size.

Parameters:

- `-SkipRuntimeBuild` — reuse an already-built `dist-native\ComptarioLocalNative`
  instead of rebuilding it. The payload is still audited.
- `-Force` — compile even if the payload audit finds problems (not
  recommended; only for debugging).

## Output

```text
dist-native-installer\ComptarioLocalNativeSetup.exe
```

Not committed — see `.gitignore` (`/dist-native/`, `/dist-native-installer/`).

## What gets installed

```text
C:\ComptarioLocal\
  app\backend\...          (replaceable, replaced on every install/upgrade)
  runtime\node\...         (replaceable, replaced on every install/upgrade)
  assets\comptario.ico     (replaceable, replaced on every install/upgrade)
  comptario-native.bat / .ps1
  run-native-backend.ps1
  backup-native.bat / .ps1
  restore-native.bat / .ps1
  stop-native.bat / .ps1
  comptario-native-support.bat / .ps1
  native-runtime.env.example
  NATIVE_WINDOWS_RUNTIME.md
  data\               (persistent — never touched by the installer)
  data\assets\        (persistent)
  logs\               (persistent)
  backups\            (persistent)
  config\             (persistent — config\native-runtime.env holds secrets)
```

`[Files]` in `ComptarioLocalNative.iss` only ever sources `app\`, `runtime\`,
`assets\`, and root scripts/docs from the payload. `data\`, `logs\`,
`backups\`, and `config\` are created via `[Dirs]` with
`uninsneveruninstall` and are **never** part of `[Files]` — so they cannot be
overwritten on upgrade or removed on uninstall, by construction.

On upgrade, the installer's `[Code]` step deletes the previous `app\`,
`runtime\`, and `assets\` folders before copying the new ones in, so stale
files (e.g. old hashed frontend bundle chunks) do not accumulate across
versions. This never touches `data\`, `logs\`, `backups\`, or `config\`.

## Validation checklist

### Build validation

- [ ] `.\build-native-runtime.ps1` succeeds.
- [ ] `.\build-native-installer.ps1` succeeds.
- [ ] `dist-native-installer\ComptarioLocalNativeSetup.exe` exists.
- [ ] Installer size and SHA-256 are printed.

### Install validation (clean machine/folder)

- [ ] Install completes without Docker Desktop, WSL, PostgreSQL, Redis,
      global Node.js, npm, or Git present.
- [ ] Desktop has exactly **one** new shortcut: **Comptario Local**, using
      the Comptario icon.
- [ ] Start Menu has **Comptario Local** and **Comptario Local\Support Tools**
      (Yedek Al, Geri Yükle, Durdur, Destek Menüsü).
- [ ] Double-clicking the desktop shortcut opens `http://127.0.0.1:3000`.
- [ ] `GET /api/health` returns HTTP 200 with `appEdition: native-local`.
- [ ] First-user registration works.
- [ ] Customer create/read works.
- [ ] Backup (Support Tools → Yedek Al) produces an archive in `backups\`.
- [ ] Restore (Support Tools → Geri Yükle) restores data correctly.
- [ ] Stop/restart preserves data.

### Upgrade validation

- [ ] Install once, create data (customers, a backup).
- [ ] Re-run the same (or a newer) installer build over the existing install.
- [ ] Data, `config\native-runtime.env` secrets, and existing backups in
      `backups\` all survive.
- [ ] The app still starts and serves the preserved data afterward.

### Uninstall validation

- [ ] Uninstall removes `app\`, `runtime\`, `assets\`, root scripts, and all
      shortcuts.
- [ ] `data\`, `logs\`, `backups\`, and `config\` are **not** deleted.
