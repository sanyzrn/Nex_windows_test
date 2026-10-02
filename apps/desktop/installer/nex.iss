; Build with tools/build_installer.ps1. All runtime files come from its payload.
[Setup]
AppId={{48B6A24D-07D7-4DE8-8D6C-801190DF6A42}
AppName=Nex Windows (Test)
AppVersion=0.10.0
AppPublisher=Nex
DefaultDirName={localappdata}\Programs\Nex
DefaultGroupName=Nex
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
DisableProgramGroupPage=yes
WizardStyle=modern
ShowLanguageDialog=yes
LicenseFile=..\LICENSE
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\nex_desktop.exe
OutputDir=..\build\installer\output
OutputBaseFilename=Nex-Windows-Setup-0.10.0-x64
Compression=lzma2
SolidCompression=yes
AppMutex=Local\NexDesktopSingleton
CloseApplications=no
RestartApplications=no
VersionInfoVersion=0.10.0.6
VersionInfoDescription=Nex Windows test installer

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
Name: "{group}\Nex"; Filename: "{app}\nex_desktop.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\Nex"; Filename: "{app}\nex_desktop.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\nex_desktop.exe"; WorkingDir: "{app}"; Description: "{cm:LaunchNex}"; Flags: nowait postinstall skipifsilent

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
