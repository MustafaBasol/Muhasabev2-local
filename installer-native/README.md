# installer-native/ — Comptario Local Native Setup

This folder contains everything needed to build the Docker-free Windows
installer **`ComptarioLocalNativeSetup.exe`** with
[Inno Setup 6](https://jrsoftware.org/isinfo.php).

## Files

| File | Purpose |
| --- | --- |
| `ComptarioLocalNative.iss` | Inno Setup script: install location, files, dirs, shortcuts, data-safety rules. |

Unlike the Docker installer, there is no staged `payload\` folder here.
`[Files]` reads directly from the generated `dist-native\ComptarioLocalNative`
runtime (built by `build-native-runtime.ps1`), which is **not** committed.

## How to build

From the **repository root** (not this folder), run:

```powershell
.\build-native-installer.ps1
```

That script builds a clean native runtime (`build-native-runtime.ps1`), audits
it for forbidden/generated content, finds the Inno Setup compiler, compiles
`ComptarioLocalNative.iss`, and writes the result to
`dist-native-installer\ComptarioLocalNativeSetup.exe`, printing its SHA-256
hash and size.

Use `-SkipRuntimeBuild` to reuse an already-built, already-clean
`dist-native\ComptarioLocalNative` instead of rebuilding it.

Full instructions and validation steps are in
[`../NATIVE_INSTALLER_BUILD.md`](../NATIVE_INSTALLER_BUILD.md).

## Do not compile `ComptarioLocalNative.iss` directly

`[Files]` reads from `..\dist-native\ComptarioLocalNative`, which only exists
and is only guaranteed clean after `build-native-runtime.ps1` /
`build-native-installer.ps1` has run. Compiling the `.iss` by hand without a
fresh, audited runtime may ship a stale or unsafe payload.

## What the installer guarantees

- One desktop shortcut only: **Comptario Local** (Comptario icon, never Docker).
- Start Menu group **Comptario Local** with a **Support Tools** subfolder
  (Yedek Al, Geri Yükle, Durdur, Destek Menüsü).
- Installs to `C:\ComptarioLocal` and grants normal users Modify rights there.
- Never requires Docker Desktop, WSL, PostgreSQL, Redis, global Node.js, npm,
  or Git on the customer machine — it ships its own Node.js runtime and uses
  SQLite.
- `[Files]` only ever sources `app\`, `runtime\`, `assets\` and the root
  launcher scripts/docs. `data\`, `logs\`, `backups\` and
  `config\native-runtime.env` are never part of the installer payload, so
  upgrade and uninstall can never overwrite or delete customer data, backups,
  logs, or generated secrets.
