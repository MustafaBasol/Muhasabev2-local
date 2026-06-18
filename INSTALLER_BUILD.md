# Building the Comptario Local Installer

This document is for whoever **packages** Comptario Local (not the end customer).
It explains how to produce `ComptarioLocalSetup.exe` and how to test it.

The end-customer guide is [`CUSTOMER_INSTALL_GUIDE.md`](./CUSTOMER_INSTALL_GUIDE.md).

---

## 1. Prerequisites (build machine only)

You need a Windows machine with:

- **Inno Setup 6** — the installer compiler.
- **Windows PowerShell 5.1** (built into Windows) and `robocopy` (built in).

You do **not** need Node.js, npm, Docker, or Git on the build machine. The
installer ships source files and lets the **customer's** Docker build the images.

### Installing Inno Setup

1. Download from <https://jrsoftware.org/isdl.php> and install to the default
   location (`C:\Program Files (x86)\Inno Setup 6\`), **or**
2. `winget install JRSoftware.InnoSetup`

`build-installer.ps1` automatically looks in the default install folders and on
`PATH`. If it cannot find `ISCC.exe`, it prints these instructions and stops.

---

## 2. Build

From the **repository root**:

```powershell
.\build-installer.ps1
```

What it does:

1. **Stages** a clean `installer\payload\` with `robocopy` (excludes listed below).
2. **Audits** the payload: fails if `.env.local`, `node_modules`, `.git`,
   `.codegraph`, `local-backups`, or `*.dump` files slipped in, and fails if a
   required build file is missing.
3. **Finds** the Inno Setup compiler.
4. **Compiles** `installer\ComptarioLocal.iss`.
5. **Outputs** `dist-installer\ComptarioLocalSetup.exe` and prints its path.

Useful switches:

- `.\build-installer.ps1 -StageOnly` — stage + audit the payload, skip compiling
  (handy for inspecting exactly what will ship).
- `.\build-installer.ps1 -Force` — compile even if the audit found problems
  (not recommended).

The generated installer is written to:

```
dist-installer\ComptarioLocalSetup.exe
```

---

## 3. What is and is not included

**Included (everything Docker needs to build & run locally):**

- `docker-compose.local.yml`, `Dockerfile.local`, `.dockerignore`
- `.env.local.example`, `backend\.env.local.example`
- `assets\comptario.ico`
- All launcher/support scripts (`comptario-local*`, `launch-local-app*`,
  `open-local-app*`, `start-local.ps1`, `stop-local.ps1`, `backup-local.ps1`,
  `restore-local.ps1`, `update-local-app*`, `create-customer-shortcuts.ps1`,
  `create-desktop-shortcuts.ps1`, `install-local-shortcuts.ps1`)
- Frontend build inputs: `index.html`, `tsconfig*.json`, `vite.config*.ts`,
  `postcss.config.js`, `tailwind.config.js`, `src\`, `public\`
- Backend build inputs: `backend\` source
- `package.json`, `package-lock.json`, `backend\package.json`,
  `backend\package-lock.json`
- Customer docs

**Excluded (dev artifacts, data, secrets):**

| Excluded | Why |
| --- | --- |
| `.git`, `.codegraph` | Version-control / index metadata |
| `node_modules`, `backend\node_modules`, `node_modules.partial`, `.npm-cache-local` | Rebuilt inside Docker |
| `dist`, `backend\dist` | Build output, rebuilt inside Docker |
| `local-backups` | Customer data / backups |
| `.env`, `.env.local`, `backend\.env.local` | Real secrets — never shipped |
| `*.dump` | Database backups |
| `*.log`, `*.zip`, `*.sql` | Temporary / irrelevant to the build |
| `installer\`, `dist-installer\` | Build tooling & output |

> The example env files (`.env.local.example`, `backend\.env.local.example`,
> `*.env.example`) **are** shipped — `start-local.ps1` uses them to create the
> real `.env.local` files on first run.

---

## 4. Testing on a clean Windows machine or VM

Do this on a machine/VM that has never run Comptario:

1. **Install Docker Desktop** (or deliberately skip it once to confirm the
   installer shows the Turkish "Docker Desktop gereklidir" warning and still
   lets you continue).
2. Run `ComptarioLocalSetup.exe`. Accept `C:\ComptarioLocal`.
3. On the finish page, leave **"Comptario Local'i şimdi başlat"** checked.
4. Verify the **desktop has exactly one icon**: `Comptario Local` (Comptario
   icon, not Docker).
5. Verify **Start Menu → Comptario Local** has `Comptario Local` and a
   **Support Tools** folder with `Uygulamayı Aç`, `Yedek Al`, `Geri Yükle`,
   `Güncelle`, `Durdur`, `Destek Menüsü`.
6. Wait for the first build; confirm the browser opens at
   <http://localhost:3000> and the health check
   <http://localhost:3000/api/health> returns `ok`.
7. Register the first user, log out, log back in.
8. **Durdur**, then double-click **Comptario Local** again → confirm your data
   is still there (persistence).
9. Run **Support Tools → Yedek Al**; confirm a `.dump` appears in
   `C:\ComptarioLocal\local-backups`.
10. Run **Support Tools → Geri Yükle** (type `GERIYUKLE`) and confirm restore.
11. Re-run the installer over the top (simulated upgrade); confirm `.env.local`
    and `local-backups` survive untouched.
12. Uninstall; confirm program files/shortcuts are removed but
    `C:\ComptarioLocal\local-backups`, `.env.local`, and Docker volumes remain.

### Non-interactive update check

```powershell
.\update-local-app.ps1 -NoPause
```

Should rebuild the `app` image and restart without prompting (no `Read-Host`),
preserving data.

---

## 5. Notes

- The installer requires **administrator** rights to write under `C:\`. A
  post-install `icacls` step grants the built-in **Users** group Modify rights on
  `C:\ComptarioLocal`, so the customer can run backup/update scripts afterward
  without being an administrator.
- Consider **code-signing** `ComptarioLocalSetup.exe` to reduce SmartScreen
  warnings on customer machines.
