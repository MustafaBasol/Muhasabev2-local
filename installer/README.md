# installer/ — Comptario Local Setup

This folder contains everything needed to build the Windows installer
**`ComptarioLocalSetup.exe`** with [Inno Setup 6](https://jrsoftware.org/isinfo.php).

## Files

| File | Purpose |
| --- | --- |
| `ComptarioLocal.iss` | Inno Setup script: install location, files, shortcuts, data-safety rules, Docker check. |
| `payload/` | **Generated** staging folder (created by `build-installer.ps1`). Not committed. |

## How to build

From the **repository root** (not this folder), run:

```powershell
.\build-installer.ps1
```

That script stages a clean `installer\payload\`, audits it, finds the Inno Setup
compiler, compiles `ComptarioLocal.iss`, and writes the result to
`dist-installer\ComptarioLocalSetup.exe`.

Full instructions, prerequisites, and clean-machine testing steps are in
[`../INSTALLER_BUILD.md`](../INSTALLER_BUILD.md).

## Do not compile `ComptarioLocal.iss` directly

`[Files]` reads from `payload\*`, which only exists after `build-installer.ps1`
stages it (excluding `node_modules`, `.git`, `.codegraph`, `dist`,
`local-backups`, `.env.local`, `backend\.env.local`, `*.dump`, `*.log`, `*.zip`).
Compiling the `.iss` by hand without staging will fail or ship the wrong files.

## What the installer guarantees

- One desktop shortcut only: **Comptario Local** (Comptario icon, never Docker).
- Start Menu group **Comptario Local** with a **Support Tools** subfolder.
- Installs to `C:\ComptarioLocal` and grants normal users Modify rights there.
- Never bundles Docker Desktop; warns (in Turkish) if it is missing, then continues.
- Never overwrites `.env.local` / `backend\.env.local`, never deletes
  `local-backups` or Docker volumes (on install, upgrade, or uninstall).
