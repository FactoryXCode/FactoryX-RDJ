#ifndef PayloadRoot
  #define PayloadRoot "Payload"
#endif
[Setup]
AppId={{AD70B3AA-60AB-454E-908A-626B03442B87}
AppName=FactoryX Radio DJ
AppVersion=4.0.1
AppPublisher=FactoryX
DefaultDirName={sd}\FactoryXRadioDJ
DefaultGroupName=FactoryX Radio DJ
PrivilegesRequired=admin
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=Output
OutputBaseFilename=FactoryX-RadioDJ-4.0.1-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
LicenseFile={#PayloadRoot}\License.txt
InfoAfterFile=InstallGuide.txt
UninstallDisplayIcon={app}\RDJPro\MfRdjJ.exe
CloseApplications=yes

[Types]
Name: "combined"; Description: "RDJ Pro workstation and broadcast server"
Name: "workstation"; Description: "RDJ Pro workstation (existing broadcast server)"
Name: "server"; Description: "Broadcast server only"
Name: "custom"; Description: "Choose components"; Flags: iscustom

[Components]
Name: "pro"; Description: "RDJ Pro mixer (audio and video)"; Types: combined workstation
Name: "rdj"; Description: "RDJ mixer (audio only)"
Name: "server"; Description: "FxServe broadcast server and administrator"; Types: combined server
Name: "recorder"; Description: "FxRecord compliance recorder"
Name: "admin"; Description: "FxRecord remote administrator"; Types: combined workstation server
Name: "icecast"; Description: "Icecast installer (needed for RDJ audio broadcasting)"
Name: "caddy"; Description: "Alternative Caddy deployment archives"
Name: "docs"; Description: "User manuals and deployment scripts"; Types: combined workstation server custom; Flags: fixed

[Dirs]
Name: "{app}\RDJ"; Components: rdj; Permissions: users-modify
Name: "{app}\RDJPro"; Components: pro; Permissions: users-modify
Name: "{app}\FxRecordAdmin"; Components: admin; Permissions: users-modify
Name: "{app}\FxServe"; Components: server
Name: "{app}\FxServe\www"; Components: server
Name: "{app}\FxRecord"; Components: recorder

[Tasks]
Name: "services"; Description: "Register and start selected FxServe/FxRecord Windows services"; Components: server recorder; Flags: unchecked
Name: "firewall"; Description: "Allow broadcast traffic through Windows Firewall (LAN/WAN)"; Components: server; Flags: unchecked

[Files]
Source: "{#PayloadRoot}\RDJ\MfRdjJ.exe"; DestDir: "{app}\RDJ"; Components: rdj; Flags: ignoreversion
Source: "{#PayloadRoot}\RDJPro\MfRdjJ.exe"; DestDir: "{app}\RDJPro"; Components: pro; Flags: ignoreversion
Source: "{#PayloadRoot}\FxServe\*.exe"; DestDir: "{app}\FxServe"; Components: server; Flags: ignoreversion
Source: "{#PayloadRoot}\FxServe\FxServe.ini"; DestDir: "{app}\FxServe"; Components: server; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#PayloadRoot}\FxRecord\FxRecord.exe"; DestDir: "{app}\FxRecord"; Components: recorder; Flags: ignoreversion
Source: "{#PayloadRoot}\FxRecord\FxRecord.ini"; DestDir: "{app}\FxRecord"; Components: recorder; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#PayloadRoot}\FxRecord\*.cmd"; DestDir: "{app}\FxRecord"; Components: recorder
Source: "{#PayloadRoot}\FxRecordAdmin\FxRecordAdmin.exe"; DestDir: "{app}\FxRecordAdmin"; Components: admin; Flags: ignoreversion
Source: "{#PayloadRoot}\Redist\icecast_win64_2.5.0.exe"; DestDir: "{app}\Redist"; Components: icecast
Source: "{#PayloadRoot}\Caddy\*.zip"; DestDir: "{app}\Caddy"; Components: caddy
Source: "{#PayloadRoot}\Docs\*"; DestDir: "{app}\Docs"; Flags: recursesubdirs createallsubdirs
Source: "Configure-Server.ps1"; DestDir: "{app}\Scripts"
Source: "InstallGuide.txt"; DestDir: "{app}"
Source: "{#PayloadRoot}\License.txt"; DestDir: "{app}"
Source: "{#PayloadRoot}\BuildManifest.json"; DestDir: "{app}\Docs"

[Icons]
Name: "{group}\RDJ"; Filename: "{app}\RDJ\MfRdjJ.exe"; WorkingDir: "{app}\RDJ"; Components: rdj
Name: "{group}\RDJ Pro"; Filename: "{app}\RDJPro\MfRdjJ.exe"; WorkingDir: "{app}\RDJPro"; Components: pro
Name: "{group}\FxServe Admin"; Filename: "{app}\FxServe\FxServeAdmin.exe"; WorkingDir: "{app}\FxServe"; Components: server
Name: "{group}\FxRecord Admin"; Filename: "{app}\FxRecordAdmin\FxRecordAdmin.exe"; WorkingDir: "{app}\FxRecordAdmin"; Components: admin
Name: "{group}\Installation guide"; Filename: "{app}\InstallGuide.txt"
Name: "{group}\Uninstall"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\Redist\icecast_win64_2.5.0.exe"; Description: "Install Icecast for RDJ audio broadcasting"; Components: icecast; Flags: postinstall skipifsilent unchecked
Filename: "{app}\InstallGuide.txt"; Description: "Read deployment instructions"; Flags: postinstall shellexec skipifsilent

[Code]
var
  NetworkPage: TInputOptionWizardPage;
  HostPage: TInputQueryWizardPage;
  NewFxServeConfig, NewFxRecordConfig: Boolean;

procedure InitializeWizard;
begin
  NetworkPage := CreateInputOptionPage(wpSelectComponents, 'Network deployment',
    'Where will the broadcast be available?',
    'Setup runs on this machine. Install the workstation and server components on their respective machines for a split deployment.', True, False);
  NetworkPage.Add('Local computer only');
  NetworkPage.Add('LAN (private network)');
  NetworkPage.Add('WAN (public HTTPS)');
  NetworkPage.SelectedValueIndex := 0;
  HostPage := CreateInputQueryPage(NetworkPage.ID, 'Public hostname',
    'WAN requires a DNS hostname pointing to this server',
    'Enter the public DNS hostname only, without https:// or a path. Forward TCP 80 and 443 to the server. FxServe handles certificates.');
  HostPage.Add('Hostname:', False);
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := ((PageID = NetworkPage.ID) and not WizardIsComponentSelected('server')) or
    ((PageID = HostPage.ID) and ((NetworkPage.SelectedValueIndex <> 2) or not WizardIsComponentSelected('server')));
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var H: String; I: Integer;
begin
  Result := True;
  if CurPageID = HostPage.ID then begin
    H := Trim(HostPage.Values[0]);
    Result := (Pos('.', H) > 1) and (Length(H) <= 253);
    for I := 1 to Length(H) do
      if Pos(H[I], 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.') = 0 then Result := False;
    if not Result then MsgBox('Enter a DNS hostname such as radio.example.com.', mbError, MB_OK);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var Mode, Params: String; ExitCode: Integer;
begin
  if CurStep = ssPostInstall then begin
    Mode := 'Local';
    if NetworkPage.SelectedValueIndex = 1 then Mode := 'LAN';
    if NetworkPage.SelectedValueIndex = 2 then Mode := 'WAN';
    Params := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\Scripts\Configure-Server.ps1') + '" -InstallRoot "' + ExpandConstant('{app}') + '" -NetworkMode ' + Mode;
    if Mode = 'WAN' then Params := Params + ' -PublicHostname "' + Trim(HostPage.Values[0]) + '"';
    if WizardIsComponentSelected('server') then Params := Params + ' -ConfigureFxServe';
    if WizardIsComponentSelected('recorder') then Params := Params + ' -ConfigureFxRecord';
    if NewFxServeConfig then Params := Params + ' -InitializeFxServe';
    if NewFxRecordConfig then Params := Params + ' -InitializeFxRecord';
    if WizardIsTaskSelected('services') then Params := Params + ' -InstallServices';
    if WizardIsTaskSelected('firewall') then Params := Params + ' -OpenFirewall';
    if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), Params, '', SW_HIDE, ewWaitUntilTerminated, ExitCode) or (ExitCode <> 0) then
      MsgBox('Server configuration failed. Read Scripts\Configure-Server.log and the installation guide before starting services.', mbError, MB_OK);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Name, ImagePath: String; I: Integer;
begin
  Result := '';
  NewFxServeConfig := not FileExists(ExpandConstant('{app}\FxServe\FxServe.ini'));
  NewFxRecordConfig := not FileExists(ExpandConstant('{app}\FxRecord\FxRecord.ini'));
  for I := 0 to 1 do begin
    if I = 0 then Name := 'FxServe' else Name := 'FxRecord';
    if (((I = 0) and WizardIsComponentSelected('server')) or ((I = 1) and WizardIsComponentSelected('recorder'))) and
      RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Services\' + Name, 'ImagePath', ImagePath) then begin
      Result := Name + ' is already registered. Stop and unregister the existing service before installing server updates. Its configuration and recordings will be preserved.';
      Exit;
    end;
  end;
end;

function InitializeUninstall(): Boolean;
var Name, ImagePath: String; I: Integer;
begin
  Result := True;
  for I := 0 to 1 do begin
    if I = 0 then Name := 'FxServe' else Name := 'FxRecord';
    if RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Services\' + Name, 'ImagePath', ImagePath) then
      if Pos(Lowercase(ExpandConstant('{app}') + '\' + Name + '\'), Lowercase(ImagePath)) > 0 then begin
        MsgBox('Stop and unregister ' + Name + ' before uninstalling. See InstallGuide.txt. Configuration and archives will be preserved.', mbError, MB_OK);
        Result := False;
        Exit;
      end;
  end;
end;
