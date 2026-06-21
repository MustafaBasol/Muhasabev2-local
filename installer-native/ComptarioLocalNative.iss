; ============================================================================
;  Comptario Local Native - Inno Setup installer script
; ----------------------------------------------------------------------------
;  Builds ComptarioLocalNativeSetup.exe.
;
;  This installer packages the Docker-free native Windows runtime built by
;  build-native-runtime.ps1 (bundled Node.js + SQLite). It does NOT:
;    - require Docker Desktop, WSL, PostgreSQL, Redis, global Node.js, npm,
;      or Git on the customer machine,
;    - overwrite the customer's data\, logs\, backups\ or config\ folders,
;    - delete customer data, backups, or generated secrets on upgrade or
;      uninstall.
;
;  Compile with build-native-installer.ps1, which first (re)builds a clean
;  dist-native\ComptarioLocalNative runtime payload and audits it.
;  Do NOT compile this file directly unless that payload already exists.
; ============================================================================

#define AppName "Comptario Local"
#define AppVersion "1.0.0"
#define AppPublisher "Comptario"
#define RuntimeDir "..\dist-native\ComptarioLocalNative"

[Setup]
; A stable, native-specific AppId keeps upgrades in-place (same install,
; data preserved) and never collides with the Docker package's AppId.
AppId={{E3F9D24E-3D8C-4484-AEBA-FF5858CD65A4}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName=C:\ComptarioLocal
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Writing under C:\ requires administrator rights during install.
; A post-install icacls step grants normal users Modify rights so the
; customer can run backup/restore scripts (which write to data\, logs\,
; backups\, config\).
PrivilegesRequired=admin
OutputDir=..\dist-native-installer
OutputBaseFilename=ComptarioLocalNativeSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
; Installer/uninstaller icon uses the Comptario brand mark.
SetupIconFile={#RuntimeDir}\assets\comptario.ico
UninstallDisplayIcon={app}\assets\comptario.ico
UninstallDisplayName={#AppName}

[Languages]
Name: "tr"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstüne 'Comptario Local' kısayolu ekle"; Flags: checkedonce

[Files]
; Only replaceable application/runtime files are packaged here. data\,
; logs\, backups\ and config\ are intentionally NEVER sourced from the
; payload - see the [Dirs] section below, which creates them only if
; missing and never deletes their contents on upgrade or uninstall. This
; guarantees the installer can never overwrite the customer's database,
; uploaded assets, backups, or generated secrets.
Source: "{#RuntimeDir}\app\*"; DestDir: "{app}\app"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RuntimeDir}\runtime\*"; DestDir: "{app}\runtime"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RuntimeDir}\assets\*"; DestDir: "{app}\assets"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#RuntimeDir}\*.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\*.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\*.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\native-runtime.env.example"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RuntimeDir}\runtime-manifest.json"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
; Persistent customer directories. Created only if missing; never removed
; or emptied by upgrade or uninstall (uninsneveruninstall).
Name: "{app}\data"; Flags: uninsneveruninstall
Name: "{app}\data\assets"; Flags: uninsneveruninstall
Name: "{app}\data\assets\blog"; Flags: uninsneveruninstall
Name: "{app}\logs"; Flags: uninsneveruninstall
Name: "{app}\backups"; Flags: uninsneveruninstall
Name: "{app}\config"; Flags: uninsneveruninstall

[Icons]
; --- Desktop: exactly ONE shortcut, using the Comptario icon (never Docker) ---
Name: "{autodesktop}\Comptario Local"; Filename: "{app}\comptario-native.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Comptario Local uygulamasını başlatır ve tarayıcıda açar."; Tasks: desktopicon

; --- Start Menu: "Comptario Local" group ---
Name: "{group}\Comptario Local"; Filename: "{app}\comptario-native.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Comptario Local uygulamasını başlatır ve tarayıcıda açar."

; --- Start Menu: "Comptario Local\Support Tools" (admin/support, not daily) ---
Name: "{group}\Support Tools\Yedek Al"; Filename: "{app}\backup-native.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Veritabanının ve dosyaların yedeğini backups klasörüne alır."

Name: "{group}\Support Tools\Geri Yükle"; Filename: "{app}\restore-native.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Seçilen yedekten veritabanını geri yükler."

Name: "{group}\Support Tools\Başlat"; Filename: "{app}\comptario-native.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Comptario Local uygulamasını başlatır."

Name: "{group}\Support Tools\Durdur"; Filename: "{app}\stop-native.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Comptario Local uygulamasını durdurur. Veriler korunur."

Name: "{group}\Support Tools\Destek Menüsü"; Filename: "{app}\comptario-native-support.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Başlatma, yedekleme, geri yükleme ve durdurma işlemlerini tek pencerede sunar."

[Run]
; 1) Grant normal (non-admin) users Modify rights on the install folder so
;    the customer can run the launcher and support scripts, which write to
;    data\, logs\, backups\ and config\. *S-1-5-32-545 is the
;    locale-independent SID of the built-in Users group.
Filename: "{sys}\icacls.exe"; \
  Parameters: """{app}"" /grant *S-1-5-32-545:(OI)(CI)M /T /C /Q"; \
  Flags: runhidden waituntilterminated; StatusMsg: "Klasör izinleri ayarlanıyor..."

; 2) Optional: launch Comptario Local right after install (checked by default).
Filename: "{app}\comptario-native.bat"; \
  WorkingDir: "{app}"; \
  Description: "Comptario Local'i şimdi başlat"; \
  Flags: postinstall skipifsilent nowait

; ----------------------------------------------------------------------------
; NOTE on upgrade / uninstall / data safety:
;   [Files] only ever sources app\, runtime\, assets\ and the root launcher
;   scripts/docs from the payload, so an upgrade install can only replace
;   application/runtime files - it never touches data\, logs\, backups\ or
;   config\native-runtime.env (generated secrets, SQLite database, uploaded
;   assets). [Dirs] uses uninsneveruninstall so those folders are created if
;   missing but never removed, and there is intentionally no
;   [UninstallDelete] entry for them. Uninstall removes only the files this
;   installer laid down (app\, runtime\, assets\, root scripts) and the
;   shortcuts; customer data, backups, logs and config are left in place.
;   Fully purging data is a separate, manual, explicit support action.
; ----------------------------------------------------------------------------

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  // Before copying fresh files, remove the previous version's replaceable
  // app\, runtime\ and assets\ trees so stale files (e.g. old hashed
  // frontend bundle chunks) do not accumulate across upgrades. This never
  // touches data\, logs\, backups\ or config\, which live in separate
  // top-level folders untouched by this step.
  if CurStep = ssInstall then
  begin
    if DirExists(ExpandConstant('{app}\app')) then
      DelTree(ExpandConstant('{app}\app'), True, True, True);
    if DirExists(ExpandConstant('{app}\runtime')) then
      DelTree(ExpandConstant('{app}\runtime'), True, True, True);
    if DirExists(ExpandConstant('{app}\assets')) then
      DelTree(ExpandConstant('{app}\assets'), True, True, True);
  end;

  // Belt-and-suspenders: the customer relies on these Start Menu shortcuts
  // as the ONLY way to reach Backup/Restore/Stop (there is no other UI for
  // them). [Icons] entries above are skipped entirely if Setup is launched
  // with /NOICONS (a switch some silent-deploy/RMM wrappers add by default
  // for "no desktop clutter" policies) - that flag suppresses every [Icons]
  // entry, not just task-gated ones. Recreate the critical shortcuts here
  // unconditionally so they always exist regardless of how Setup was
  // invoked. CreateShellLink overwrites any shortcut [Icons] already made,
  // so this is a no-op duplicate in the normal case.
  if CurStep = ssPostInstall then
  begin
    ForceDirectories(ExpandConstant('{group}'));
    ForceDirectories(ExpandConstant('{group}\Support Tools'));

    CreateShellLink(
      ExpandConstant('{group}\Comptario Local.lnk'),
      'Comptario Local uygulamasını başlatır ve tarayıcıda açar.',
      ExpandConstant('{app}\comptario-native.bat'), '',
      ExpandConstant('{app}'), ExpandConstant('{app}\assets\comptario.ico'),
      0, SW_SHOWNORMAL);

    CreateShellLink(
      ExpandConstant('{group}\Support Tools\Başlat.lnk'),
      'Comptario Local uygulamasını başlatır.',
      ExpandConstant('{app}\comptario-native.bat'), '',
      ExpandConstant('{app}'), ExpandConstant('{app}\assets\comptario.ico'),
      0, SW_SHOWNORMAL);

    CreateShellLink(
      ExpandConstant('{group}\Support Tools\Yedek Al.lnk'),
      'Veritabanının ve dosyaların yedeğini backups klasörüne alır.',
      ExpandConstant('{app}\backup-native.bat'), '',
      ExpandConstant('{app}'), ExpandConstant('{app}\assets\comptario.ico'),
      0, SW_SHOWNORMAL);

    CreateShellLink(
      ExpandConstant('{group}\Support Tools\Geri Yükle.lnk'),
      'Seçilen yedekten veritabanını geri yükler.',
      ExpandConstant('{app}\restore-native.bat'), '',
      ExpandConstant('{app}'), ExpandConstant('{app}\assets\comptario.ico'),
      0, SW_SHOWNORMAL);

    CreateShellLink(
      ExpandConstant('{group}\Support Tools\Durdur.lnk'),
      'Comptario Local uygulamasını durdurur. Veriler korunur.',
      ExpandConstant('{app}\stop-native.bat'), '',
      ExpandConstant('{app}'), ExpandConstant('{app}\assets\comptario.ico'),
      0, SW_SHOWNORMAL);

    CreateShellLink(
      ExpandConstant('{group}\Support Tools\Destek Menüsü.lnk'),
      'Başlatma, yedekleme, geri yükleme ve durdurma işlemlerini tek pencerede sunar.',
      ExpandConstant('{app}\comptario-native-support.bat'), '',
      ExpandConstant('{app}'), ExpandConstant('{app}\assets\comptario.ico'),
      0, SW_SHOWNORMAL);
  end;
end;
