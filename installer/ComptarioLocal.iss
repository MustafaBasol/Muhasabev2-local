; ============================================================================
;  Comptario Local - Inno Setup installer script
; ----------------------------------------------------------------------------
;  Builds ComptarioLocalSetup.exe.
;
;  This installer ONLY lays down files and creates shortcuts. It does NOT:
;    - change the Docker architecture,
;    - bundle or install Docker Desktop,
;    - delete Docker volumes,
;    - overwrite an existing .env.local / backend\.env.local,
;    - touch the local-backups folder or existing .dump backups.
;
;  Compile with build-installer.ps1 (which first stages installer\payload).
;  Do NOT compile this file directly unless installer\payload already exists.
; ============================================================================

#define AppName "Comptario Local"
#define AppVersion "1.0.0"
#define AppPublisher "Comptario"
#define DockerDesktopExe "C:\Program Files\Docker\Docker\Docker Desktop.exe"

[Setup]
; A stable AppId keeps upgrades in-place (same install, data preserved).
AppId={{B8E9A1C4-2D7F-4E3A-9C6B-1F0A5D8E2C73}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName=C:\ComptarioLocal
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Writing under C:\ requires administrator rights during install.
; A post-install icacls step grants normal users Modify rights so the
; customer can run backup/update scripts (which write .env.local, local-backups).
PrivilegesRequired=admin
OutputDir=..\dist-installer
OutputBaseFilename=ComptarioLocalSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
; Installer/uninstaller icon uses the Comptario brand mark.
SetupIconFile=payload\assets\comptario.ico
UninstallDisplayIcon={app}\assets\comptario.ico
UninstallDisplayName={#AppName}

[Languages]
Name: "tr"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstüne 'Comptario Local' kısayolu ekle"; Flags: checkedonce
Name: "dockerautostart"; Description: "Docker Desktop'ı Windows ile birlikte otomatik başlat"; Flags: unchecked

[Files]
; The staged payload (see build-installer.ps1) already excludes node_modules,
; .git, .codegraph, dist, local-backups, .env.local and backend\.env.local,
; *.dump, *.log and *.zip. Because those files are not in the payload, an
; upgrade install can never overwrite the customer's .env.local files and never
; deletes local-backups.
Source: "payload\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
; --- Desktop: exactly ONE shortcut, using the Comptario icon (never Docker) ---
Name: "{autodesktop}\Comptario Local"; Filename: "{app}\comptario-local.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Comptario Local uygulamasını başlatır ve tarayıcıda açar."; Tasks: desktopicon

; --- Start Menu: "Comptario Local" group ---
Name: "{group}\Comptario Local"; Filename: "{app}\comptario-local.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Comptario Local uygulamasını başlatır ve tarayıcıda açar."

; --- Start Menu: "Comptario Local\Support Tools" (admin/support, not daily) ---
Name: "{group}\Support Tools\Uygulamayı Aç"; Filename: "{app}\open-local-app.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Çalışan Comptario Local uygulamasını tarayıcıda açar."

Name: "{group}\Support Tools\Yedek Al"; Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""& '{app}\backup-local.ps1'; Read-Host 'Kapatmak icin Enter tusuna basin'"""; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Veritabanının yedeğini local-backups klasörüne alır."

Name: "{group}\Support Tools\Geri Yükle"; Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""& '{app}\restore-local.ps1'; Read-Host 'Kapatmak icin Enter tusuna basin'"""; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Seçilen yedekten veritabanını geri yükler."

Name: "{group}\Support Tools\Güncelle"; Filename: "{app}\update-local-app.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Yeni sürümü güvenle kurar. Veritabanı, yedekler ve ayarlar korunur."

Name: "{group}\Support Tools\Durdur"; Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""& '{app}\stop-local.ps1'; Read-Host 'Kapatmak icin Enter tusuna basin'"""; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Comptario Local uygulamasını durdurur. Veriler korunur."

Name: "{group}\Support Tools\Destek Menüsü"; Filename: "{app}\comptario-local-support.bat"; \
  WorkingDir: "{app}"; IconFilename: "{app}\assets\comptario.ico"; \
  Comment: "Tüm destek işlemlerini tek pencerede sunan menü."

[Run]
; 1) Grant normal (non-admin) users Modify rights on the install folder so the
;    customer can run daily/support scripts that write .env.local, local-backups,
;    etc. *S-1-5-32-545 is the locale-independent SID of the built-in Users group.
Filename: "{sys}\icacls.exe"; \
  Parameters: """{app}"" /grant *S-1-5-32-545:(OI)(CI)M /T /C /Q"; \
  Flags: runhidden waituntilterminated; StatusMsg: "Klasör izinleri ayarlanıyor..."

; 2) Optional: make Docker Desktop start with Windows (unchecked task).
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install-local-shortcuts.ps1"" -StartDockerWithWindows -NoPrompt"; \
  WorkingDir: "{app}"; Flags: runhidden waituntilterminated; Tasks: dockerautostart

; 3) OPTIONAL upgrade rebuild - unchecked by default. Daily use never needs this;
;    support normally runs Start Menu > Support Tools > Güncelle after a new
;    version. -NoPause keeps it non-interactive so the installer is not blocked.
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\update-local-app.ps1"" -NoPause"; \
  WorkingDir: "{app}"; \
  Description: "Yeni sürümü şimdi uygula (yeniden derle - birkaç dakika sürebilir)"; \
  Flags: postinstall unchecked skipifsilent runhidden

; 4) Optional: launch Comptario Local right after install (checked by default).
Filename: "{app}\comptario-local.bat"; \
  WorkingDir: "{app}"; \
  Description: "Comptario Local'i şimdi başlat"; \
  Flags: postinstall skipifsilent nowait

; ----------------------------------------------------------------------------
; NOTE on uninstall / data safety:
;   There is intentionally NO [UninstallDelete] section that removes user data.
;   Uninstall only removes the files this installer laid down (program + scripts)
;   and the shortcuts. Runtime-created data - .env.local, backend\.env.local,
;   local-backups and Docker volumes - is NOT installed by this script, so the
;   uninstaller leaves it in place. Docker volumes are managed by Docker and are
;   never touched here. Fully purging data is a separate, manual support action.
; ----------------------------------------------------------------------------

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
  // Docker Desktop is a prerequisite but is NOT bundled. If it is missing we
  // warn (in Turkish) and still allow the install to continue.
  if not FileExists(ExpandConstant('{#DockerDesktopExe}')) then
  begin
    MsgBox('Bu uygulamanın çalışması için Docker Desktop gereklidir.' + #13#10 + #13#10 +
           'Kuruluma devam edebilirsiniz, ancak uygulamayı çalıştırmadan önce ' +
           'Docker Desktop kurulmalıdır.' + #13#10 + #13#10 +
           'Comptario Local başlatıcısı indirme sayfasını açmanıza yardımcı olur.' + #13#10 +
           'Docker kurulumundan sonra Windows''u yeniden başlatmanız gerekebilir.' + #13#10 + #13#10 +
           'İndirme adresi: https://www.docker.com/products/docker-desktop/',
           mbInformation, MB_OK);
  end;
end;
