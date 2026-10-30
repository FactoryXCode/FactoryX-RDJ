program LoggingSettingsSmoke;
{$APPTYPE CONSOLE}
uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils,
  RDJ.Log in '..\RDJ.Log.pas',
  RDJ.Setup in '..\RDJ.Setup.pas';
type
  TLogWorker = class(TThread)
    procedure Execute; override;
  end;
procedure TLogWorker.Execute;
var I: Integer;
begin
  for I := 1 to 200 do
  begin
    RDJLogFmt('Worker', 'Entry %d', [I]);
    Sleep(1);
  end;
end;
var Settings, Reloaded: TRDJSetup; Root, Ini, BeforeText: string; Worker: TLogWorker;
begin
  Root := TPath.Combine(ExtractFilePath(ParamStr(0)), 'LoggingSmoke-' + IntToStr(GetCurrentProcessId));
  ForceDirectories(Root);
  SetEnvironmentVariable('LOCALAPPDATA', PChar(Root));
  Ini := TPath.Combine(Root, 'Settings.ini');
  LoadSetupFromIni(Ini, Settings);
  if Settings.LoggingEnabled or RDJLoggingEnabled then raise Exception.Create('Default must be off');
  RDJLog('Test', 'Must not create a file while disabled');
  if FileExists(RDJLogFileName) then raise Exception.Create('Disabled logging created a file');
  Settings.LoggingEnabled := True;
  SaveSetupToIni(Ini, Settings);
  LoadSetupFromIni(Ini, Reloaded);
  if not Reloaded.LoggingEnabled then raise Exception.Create('Enabled setting was not persisted');
  SetRDJLoggingEnabled(Reloaded.LoggingEnabled);
  Worker := TLogWorker.Create(True);
  try
    Worker.Start;
    Sleep(50);
    SetRDJLoggingEnabled(False);
    BeforeText := TFile.ReadAllText(RDJLogFileName);
    Worker.WaitFor;
    if BeforeText <> TFile.ReadAllText(RDJLogFileName) then raise Exception.Create('Worker wrote after disable returned');
  finally
    Worker.Free;
  end;
  if (Pos('Diagnostic logging enabled.', BeforeText) = 0) or
     (Pos('Diagnostic logging disabled.', BeforeText) = 0) or
     (Pos('Worker', BeforeText) = 0) then raise Exception.Create('Expected logging entries missing');
  Settings.LoggingEnabled := False;
  SaveSetupToIni(Ini, Settings);
  LoadSetupFromIni(Ini, Reloaded);
  if Reloaded.LoggingEnabled then raise Exception.Create('Disabled setting was not persisted');
  Writeln('PASS: default-off, settings round trip, runtime toggle and worker disable synchronization.');
end.
