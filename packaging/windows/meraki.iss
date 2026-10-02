#ifndef AppVersion
  #error AppVersion deve ser informado pelo script de empacotamento.
#endif
#ifndef SourceDir
  #error SourceDir deve apontar para a compilação Release.
#endif
#ifndef OutputDir
  #error OutputDir deve apontar para a pasta dos instaladores.
#endif

[Setup]
AppId={{6447C16C-E50F-4D9F-88DD-56DA8202192A}
AppName=Meraki Player
AppVersion={#AppVersion}
AppPublisher=Guilherme Lindner
AppPublisherURL=https://github.com/lindnergui/MERAKI-PLAYER
AppSupportURL=https://github.com/lindnergui/MERAKI-PLAYER/issues
AppUpdatesURL=https://github.com/lindnergui/MERAKI-PLAYER/releases/latest
DefaultDirName={localappdata}\Programs\Meraki Player
DefaultGroupName=Meraki Player
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir={#OutputDir}
OutputBaseFilename=meraki-windows-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\meraki.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Meraki Player"; Filename: "{app}\meraki.exe"
Name: "{autodesktop}\Meraki Player"; Filename: "{app}\meraki.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\meraki.exe"; Description: "Abrir Meraki Player"; Flags: nowait postinstall skipifsilent
