# Local Customer Setup (Windows)

This package runs Comptario locally with Docker. The application, database,
Redis, and optional pgAdmin ports are bound to `127.0.0.1`, so they are not
available to other computers on the local network by default.

> **For non-technical customers:** Daily use does **not** require a terminal,
> PowerShell, Git, Node.js, or Docker commands. After the one-time setup below,
> everything is done by double-clicking desktop shortcuts. See
> [CUSTOMER_DAILY_USAGE.md](./CUSTOMER_DAILY_USAGE.md) for the simple daily guide.

## One-Time Installation

> **Easiest path: the installer.** If you were given
> `ComptarioLocalSetup.exe`, just install Docker Desktop and run that — it copies
> the files to `C:\ComptarioLocal` and creates the single **“Comptario Local”**
> desktop icon plus the Start Menu **Support Tools** folder for you. See
> [CUSTOMER_INSTALL_GUIDE.md](./CUSTOMER_INSTALL_GUIDE.md). The manual steps below
> are the alternative ZIP-based method and are still fully supported.

Performed once, ideally by whoever delivers the package to the customer:

1. **Install Docker Desktop for Windows.** This is required only once. Download
   it from <https://www.docker.com/products/docker-desktop>.
2. (Recommended) Set Docker Desktop to start automatically with Windows so the
   customer never has to start it manually. See
   [Auto-Start Docker With Windows](#auto-start-docker-with-windows).
3. Place this project folder on the customer's machine (extract the supplied ZIP
   or clone with Git).
4. Create the shortcuts by running, once, in PowerShell from the project folder:

   ```powershell
   .\install-local-shortcuts.ps1
   ```

   This creates the shortcuts and offers to enable Docker auto-start.
   (You can also run `.\create-customer-shortcuts.ps1` to only create
   shortcuts. The older name `.\create-desktop-shortcuts.ps1` still works and
   now produces the same single-icon layout.)

After this, the customer uses only the **“Comptario Local”** desktop icon.
Node.js is not required; Docker builds and runs the frontend and backend.

All customer-facing shortcuts use the **Comptario application icon**
(`assets\comptario.ico`) — never the Docker icon.

## Daily Usage (Customer — One Icon)

The customer never needs to open a terminal. The desktop has a **single**
shortcut:

| Shortcut | What it does |
| --- | --- |
| **Comptario Local** | Starts Docker if needed, starts the app, waits until healthy, and opens the browser. |

Daily flow:

1. Double-click **“Comptario Local”**.
2. Wait for the browser to open (the first start can take a few minutes).
3. Use the app.

This one shortcut automatically checks whether Docker Desktop is running, starts
it if needed, launches the containers (`docker compose up -d` — it does **not**
rebuild during normal daily use), waits for the app to be healthy, and opens the
browser. It is safe to run multiple times and never deletes data or overwrites
`.env` files.

### Support / Advanced Tools (Start Menu)

Backup, restore, update, and stop are **support/advanced** tools. They are not
on the desktop; they live in the Start Menu so the customer desktop stays clean:

**Start → Comptario Local → Support Tools**

| Tool | What it does |
| --- | --- |
| **Uygulamayı Aç** | Opens the already-running app in the browser. |
| **Yedek Al** | Creates a database backup in `local-backups`. |
| **Geri Yükle** | Restores a backup. |
| **Güncelle** | Installs a newly delivered version (data is preserved). |
| **Durdur** | Stops the app (data is preserved). |
| **Destek Menüsü** | A single window menu (`comptario-local-support.ps1`) offering all of the above. |

To also place these support tools on the desktop (e.g. on a support machine),
run `.\create-customer-shortcuts.ps1 -IncludeSupportShortcuts`.

## Updating to a New Version (Support)

Daily users only ever click the **“Comptario Local”** desktop icon. When a new
version of the package is delivered (files copied or installed over the existing
folder), support should run the update step **once** after replacing the files:

- Use **Start → Comptario Local → Support Tools → “Güncelle”**, or run from the
  project folder:

  ```powershell
  .\update-local-app.ps1
  ```

This rebuilds the application image (`build --no-cache app`) and restarts the
containers with `up -d`, then waits for the app to become healthy and opens the
browser. It is safe to run multiple times.

The update is data-safe by design:

- It never deletes Docker volumes (database, Redis, uploaded assets).
- It never overwrites existing `.env.local` / `backend\.env.local` files.
- It never touches the `local-backups` folder.

If `.env.local` is missing, the update script refuses to run and asks support to
complete the first-time setup via the **“Comptario Local”** icon instead. Taking
a backup with **Support Tools → “Yedek Al”** before a major update is recommended.

## Advanced / Support: Manual Prerequisites

For support scenarios the same steps can be run manually:

1. Install Docker Desktop for Windows.
2. Start Docker Desktop and wait until it reports that the engine is running.
3. Download this project with Git or extract the supplied ZIP file.

Node.js is not required for normal customer use. Docker builds and runs the
frontend and backend.

## Start

Open PowerShell in the project folder and run:

```powershell
.\start-local.ps1
```

The first run creates `.env.local` and `backend\.env.local` only when they do
not already exist. Existing customer settings are preserved. Recognized
placeholder JWT and CSRF secrets are replaced with unique generated values.

Open:

- Application: <http://localhost:3000>
- Health check: <http://localhost:3000/api/health>

There is no default customer account. Register the first user through the
application. Local email verification, external email delivery, captcha, and
Stripe billing are disabled by default.

## Stop

```powershell
.\stop-local.ps1
```

This stops the containers but does not delete Docker volumes or customer data.

## Backup

```powershell
.\backup-local.ps1
```

Backups are timestamped PostgreSQL custom-format files in `local-backups`.
Copy this folder to separate storage as part of the customer's backup policy.

## Restore

Restore the newest backup:

```powershell
.\restore-local.ps1
```

Restore a selected backup:

```powershell
.\restore-local.ps1 -BackupFile ".\local-backups\muhasabe-YYYYMMDD-HHMMSS.dump"
```

The script warns that current data will be replaced and requires typing
`GERIYUKLE` (Turkish confirmation prompt: *"Bu işlem mevcut veritabanını yedekten
geri yükleyecek. Devam etmek için GERIYUKLE yazıp Enter'a basın."*). It stops the
app container, keeps PostgreSQL running, restores the database, and restarts the
app.

## Data Storage

PostgreSQL, Redis, uploaded blog assets, and pgAdmin settings use named Docker
volumes. Their physical location is managed by Docker Desktop. `stop-local.ps1`
does not remove them. Do not run `docker compose down -v` unless permanent data
deletion is intended.

## Optional pgAdmin

pgAdmin is not required for normal use. Start it for support work with:

```powershell
docker compose --env-file .env.local -f docker-compose.local.yml --profile support up -d pgadmin
```

Then open <http://localhost:5051>. The PostgreSQL server name inside pgAdmin is
`postgres`, and its port is `5432`.

## Ports Already In Use

The package uses these local-only ports:

- App: `127.0.0.1:3000`
- PostgreSQL: `127.0.0.1:5433`
- Redis: `127.0.0.1:6379`
- Optional pgAdmin: `127.0.0.1:5051`

Stop the conflicting program before starting Comptario. Changing the published
ports in `docker-compose.local.yml` is possible for support scenarios, but the
app URL and related environment values must be updated together.

## Auto-Start Docker With Windows

So the customer never has to start Docker Desktop manually, enable it to launch
at sign-in. Two ways:

1. **In Docker Desktop:** open Docker Desktop, click the gear (Settings) icon,
   go to **General**, and tick **“Start Docker Desktop when you sign in”**.
   Click **Apply & restart**.
2. **Via the helper script:** run `.\install-local-shortcuts.ps1` and answer
   **E** (Evet/Yes) when it asks about auto-start. This places a Docker Desktop
   shortcut in the current user's Startup folder. To undo it later, delete the
   `Docker Desktop.lnk` file from the Startup folder (Win+R → `shell:startup`).

Even without auto-start, the **“Comptario Local”** shortcut will try to start
Docker Desktop automatically, so the customer can still rely on a single click.

## PowerShell Execution Policy

If PowerShell reports that scripts are disabled, use a limited-scope option.
For the current PowerShell window only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Or, if allowed by company policy, enable locally created scripts for the current
Windows user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Do not set an unrestricted machine-wide policy.

## Troubleshooting

- Docker error: start Docker Desktop and wait for the engine to become ready.
- App does not open: run
  `docker compose --env-file .env.local -f docker-compose.local.yml ps`.
- App logs: run
  `docker compose --env-file .env.local -f docker-compose.local.yml logs app`.
- Database health: open <http://localhost:3000/api/health> and confirm both
  `appStatus` and `dbStatus` are `ok`.
- Configuration changes: edit the existing env files, then rerun
  `.\start-local.ps1`. The script preserves customer-specific values.
