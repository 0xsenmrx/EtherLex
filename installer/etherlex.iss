; Build with installer\build.ps1, which runs flutter build windows --release
; first. ISCC alone packs whatever release build is lying around, however old.
; Output: installer\Output\EtherLex-Setup-<version>.exe
#ifndef AppVersion
  #define AppVersion "0.2.2"
#endif

[Setup]
AppId={{6D0C3B7E-4C1A-4E0B-9A56-0E7E41EC0001}
AppName=EtherLex
AppVersion={#AppVersion}
AppPublisher=EtherLex
DefaultDirName={autopf}\EtherLex
DefaultGroupName=EtherLex
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=EtherLex-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
; Same AppId as earlier versions: running a newer setup upgrades in place and keeps settings.
CloseApplications=yes
UninstallDisplayIcon={app}\etherlex.exe
SetupIconFile=..\windows\runner\resources\app_icon.ico
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\EtherLex"; Filename: "{app}\etherlex.exe"
Name: "{autodesktop}\EtherLex"; Filename: "{app}\etherlex.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\etherlex.exe"; Description: "Start EtherLex"; Flags: nowait postinstall skipifsilent
; An in-app update runs the setup silently: open the new version when it is done.
Filename: "{app}\etherlex.exe"; Flags: nowait; Check: WizardSilent
