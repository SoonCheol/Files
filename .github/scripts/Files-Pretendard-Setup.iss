; Personal, self-signed FilesDev package installer. Windows will require elevation.
#ifndef BuildOutput
  #error BuildOutput define is required
#endif
[Setup]
AppId={{C5A87CC5-B804-47DF-A096-5D2DD2A24E95}
AppName=Files Pretendard (Personal)
AppVersion=4.3.3
AppPublisher=Personal Files build
DefaultDirName={autopf}\FilesPretendardPersonal
CreateAppDir=no
DisableDirPage=yes
DisableProgramGroupPage=yes
Uninstallable=no
PrivilegesRequired=admin
OutputDir=.
OutputBaseFilename=Files-Pretendard-Setup-x64
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
SetupLogging=yes

[Files]
Source: "{#BuildOutput}\*"; DestDir: "{tmp}\FilesDevPayload"; Flags: recursesubdirs createallsubdirs deleteafterinstall
Source: "Install-FilesDev-Package.ps1"; DestDir: "{tmp}\FilesDevPayload"; Flags: deleteafterinstall

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  Command: String;
begin
  if CurStep = ssPostInstall then
  begin
    Command := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\FilesDevPayload\Install-FilesDev-Package.ps1') +
      '" -PackageRoot "' + ExpandConstant('{tmp}\FilesDevPayload') + '"';
    if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), Command,
      '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
      RaiseException('Could not start the FilesDev installer.');
    if ResultCode <> 0 then
      RaiseException('FilesDev package installation failed (exit ' + IntToStr(ResultCode) + '). See setup log for details.');
  end;
end;
