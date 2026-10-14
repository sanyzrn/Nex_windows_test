; Build with tools/build_installer.ps1. All runtime files come from its payload.
[Setup]
AppId={{48B6A24D-07D7-4DE8-8D6C-801190DF6A42}
AppName=Nex
AppVersion=0.12.1+9
AppPublisher=Nex
DefaultDirName={localappdata}\Programs\Nex
DefaultGroupName=Nex
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
DisableProgramGroupPage=yes
DisableWelcomePage=no
WizardStyle=modern dark includetitlebar hidebevels
WizardBackColor=#11161B
WizardImageFile=artwork\wizard-brand.png
WizardSmallImageFile=artwork\wizard-logo.png
WizardImageStretch=yes
ShowLanguageDialog=yes
LicenseFile=..\LICENSE
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\nex_desktop.exe
OutputDir=..\build\installer\output
OutputBaseFilename=Nex-Windows-Setup-0.12.1-x64
Compression=lzma2
SolidCompression=yes
AppMutex=Local\NexDesktopSingleton
CloseApplications=no
RestartApplications=no
VersionInfoVersion=0.12.1.9
VersionInfoDescription=Nex Windows installer

[Languages]
Name: "farsi"; MessagesFile: "Farsi.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.DesktopShortcut=Create a desktop shortcut
farsi.DesktopShortcut=ایجاد میان‌بر روی دسکتاپ
english.LaunchNex=Launch Nex
farsi.LaunchNex=اجرای نکس

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopShortcut}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\installer\payload\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Nex"; Filename: "{app}\nex_desktop.exe"; WorkingDir: "{app}"; AppUserModelID: "Nex.Desktop.App"
Name: "{userdesktop}\Nex"; Filename: "{app}\nex_desktop.exe"; WorkingDir: "{app}"; Tasks: desktopicon; AppUserModelID: "Nex.Desktop.App"

[Run]
Filename: "{app}\nex_desktop.exe"; WorkingDir: "{app}"; Description: "{cm:LaunchNex}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKCU; Subkey: "Software\Classes\nex-win"; ValueType: string; ValueData: "URL:Nex note"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\nex-win"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\nex-win\shell\open\command"; ValueType: string; ValueData: """{app}\nex_desktop.exe"" --open-note ""%1"""

[UninstallDelete]
Type: files; Name: "{app}\install-language.txt"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  Locale: String;
begin
  if CurStep = ssPostInstall then
  begin
    if ActiveLanguage = 'english' then Locale := 'en' else Locale := 'fa';
    SaveStringToFile(ExpandConstant('{app}\install-language.txt'),
      Locale + '|' + GetDateTimeString('yyyymmddhhnnss', '-', ':'), False);
  end;
end;

// Remove our own optional startup value, never another installation's entry.
// User databases, media and preferences outside {app} are never removed.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  StartupValue, Executable: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    Executable := ExpandConstant('{app}\nex_desktop.exe');
    if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run',
      'NexDesktop', StartupValue) then
    begin
      if (CompareText(StartupValue, '"' + Executable + '"') = 0) or
        (CompareText(StartupValue, '"' + Executable + '" --background') = 0) or
        (CompareText(StartupValue, Executable) = 0) then
        RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'NexDesktop');
    end;
  end;
end;
