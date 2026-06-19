# Comptario Native Windows Runtime

## Purpose

Phase 2 produces a portable Windows x64 runtime folder for Comptario Local.
It runs the React frontend, NestJS backend, and SQLite database without Docker,
WSL, PostgreSQL, Redis, Git, globally installed Node.js, or npm commands on the
customer computer.

This is not the final customer installer. It is the runtime payload that a
later installer will deploy.

## Build

From the repository root:

```powershell
.\build-native-runtime.ps1
```

Output:

```text
dist-native\ComptarioLocalNative
```

The build pins Windows x64 Node.js `v22.18.0`, matching the ABI used to install
the native SQLite, Argon2, and bcrypt modules.

Node selection order:

1. `-NodeZipPath <official-node-zip>`
2. cached `.native-cache\node-v22.18.0-win-x64.zip`
3. locally installed Node.js, only when its exact version is `v22.18.0`
4. download from the official Node.js distribution URL

The packaging computer requires Node.js/npm and the repository dependencies.
The customer computer does not.

## Runtime contents

```text
ComptarioLocalNative\
  runtime\node\node.exe
  app\backend\dist\
  app\backend\node_modules\
  app\backend\public\dist\
  app\backend\config\
  config\
  data\
  data\assets\
  logs\
  backups\
  comptario-native.bat
  comptario-native.ps1
  backup-native.bat
  backup-native.ps1
  restore-native.bat
  restore-native.ps1
```

Only production backend dependencies are installed. Frontend files are
prebuilt; no Vite development server runs on the customer computer.

## Run

Double-click:

```text
comptario-native.bat
```

The launcher:

- creates stable data, asset, log, backup, and configuration directories;
- creates `config\native-runtime.env` only when missing;
- generates strong JWT, refresh, and CSRF secrets on first launch;
- uses the private `runtime\node\node.exe`;
- prevents duplicate backend processes;
- waits for the native health endpoint;
- opens `http://127.0.0.1:3000`.

Existing runtime configuration is preserved during subsequent launches and
folder-based updates.

## Mutable customer data

Mutable data is kept outside replaceable application files:

- SQLite: `data\comptario.db`
- uploaded assets: `data\assets`
- blog assets: `data\assets\blog`
- logs: `logs`
- future backups: `backups`
- generated secrets/configuration: `config\native-runtime.env`

Do not replace or delete these directories during an update.

## Health endpoint

`GET http://127.0.0.1:3000/api/health` returns JSON containing:

- `status`
- `appEdition`
- `databaseType`
- `databaseReachable`
- `version`

Legacy `appStatus` and `dbStatus` fields remain for Docker and existing health
checks.

## External services

Native-local mode does not require Redis, Stripe, an email provider, or public
webhooks. Login-attempt tracking uses the existing in-process fallback. Email
uses local log mode, and Stripe is disabled.

## Backup and restore

`backup-native.bat` / `backup-native.ps1` and `restore-native.bat` /
`restore-native.ps1` implement SQLite-safe backup and restore for the
native runtime.

### Backup

```powershell
.\backup-native.ps1 [-Label <text>]
```

The script never copies the live database file directly. It opens
`data\comptario.db` read-only and calls better-sqlite3's `backup()` method,
which uses SQLite's online backup API. This is safe even while the backend
is running and the database is in WAL mode, because the API steps through
the source database's pages under SQLite's own locking instead of doing a
raw filesystem copy that could capture a torn/inconsistent file.

Output: a single archive in `backups\`, e.g.
`backups\comptario-backup-20260101-120000.zip`, containing:

- `manifest.json` — `backupFormatVersion`, `createdAtUtc`, `dbFileName`,
  `dbChecksumSha256`, `assetFileCount`
- `comptario.db` — the online-backup copy of the database
- `assets\` — a copy of `data\assets`

`config\native-runtime.env` (secrets/configuration) is intentionally **not**
included in the backup archive.

### Restore

```powershell
.\restore-native.ps1 -BackupPath <path-to-zip> [-Force]
```

Without `-Force`, the script prompts for a typed `RESTORE` confirmation
before changing anything. Restore order:

1. Extract the archive to a temporary folder and validate it: `manifest.json`
   must be present, the extracted database's SHA-256 must match
   `dbChecksumSha256`, and a `PRAGMA integrity_check` run against the
   extracted (not live) database must report `ok`. Any failure here aborts
   immediately — live data is never touched if the archive is invalid.
2. Prompt for confirmation (unless `-Force`).
3. Stop the running backend, killing the whole process tree (the saved pid
   is a launcher wrapper, not the `node.exe` child, so a plain
   `Stop-Process` is not sufficient to release the database file handle).
4. Create an automatic pre-restore safety backup of the current live data
   using the same online-backup mechanism, saved as
   `backups\comptario-backup-<timestamp>-pre-restore-safety.zip`.
5. Move the current `data\comptario.db*` files and `data\assets` into a
   temporary holding folder, then move the validated, extracted backup
   contents into `data\`.
6. Start the backend and wait for the native health endpoint.
7. If the health check passes, the holding folder is deleted and restore is
   complete. If it fails, the script automatically rolls back: it restores
   the holding folder's contents to `data\` and restarts the backend with
   the original data, then exits with an error.

`config\native-runtime.env` is never created, moved, or deleted by restore,
so generated JWT/refresh/CSRF secrets survive a restore.

## Current limitations

- Intended for one Windows computer and one backend process.
- No Windows service yet.
- No automatic application update mechanism yet.
- No PostgreSQL-to-SQLite migration utility yet.
- The folder is not code-signed or wrapped in an installer.

## Later work

Phase 4 covers the signed Windows installer, one desktop icon, upgrades,
uninstall behavior, and clean-machine acceptance testing.

The existing Docker/PostgreSQL package remains available as a support-managed
technical fallback.

