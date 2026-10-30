program ListenerScanChecks;

{$APPTYPE CONSOLE}

uses

  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.DateUtils,
  Vcl.Forms,
  Vcl.ExtCtrls,
  RDJ.ListenerScan;

type

  TSlowListenerScan = class(TRdjListenerScan)
  protected
    function ReadListenerCount(): Integer; override;
  end;

  TUiTicks = class
  public
    Count: Integer;
    procedure Tick(Sender: TObject);
  end;


function TSlowListenerScan.ReadListenerCount(): Integer;
begin

  Sleep(450);
  Result := 2;
end;


procedure TUiTicks.Tick(Sender: TObject);
begin

  Inc(Count);
end;


procedure Require(const ACondition: Boolean;
                    const AMessage: string);
begin

  if not ACondition then
    raise Exception.Create(AMessage);
end;


procedure WaitForScan(AScan: TRdjListenerScan);
var
  Started: Cardinal;

begin

  Started := GetTickCount();

  while not AScan.Completed do
    begin
      Application.ProcessMessages();
      Require(Cardinal(GetTickCount() - Started) < 5000,
                 'Listener worker did not finish.');
      Sleep(1);
    end;
end;

var
  Scan: TRdjListenerScan;
  Timer: TTimer;
  Ticks: TUiTicks;
  Path: string;
  Root: string;
  Lines: string;
  TimeStamp: string;
  Fs: TFormatSettings;
  Locked: TFileStream;
  Started: Cardinal;

begin

  try
    Application.Initialize();
    Root := TPath.Combine('D:\PROJECTS\MfPack\Build\UiRefresh-20261018',
                           Format('check-%d', [GetCurrentProcessId()]));
    ForceDirectories(Root);
    Path := TPath.Combine(Root,
                           'access.log');
    Fs := TFormatSettings.Create();
    Fs.DecimalSeparator := '.';
    TimeStamp := FloatToStr((TTimeZone.Local.ToUniversalTime(Now()) - EncodeDate(1970, 1, 1)) * SecsPerDay,
                              Fs);
    Lines := '{"ts":' + TimeStamp + ',"request":{"uri":"/stream/live.json","client_ip":"192.0.2.10"}}' + sLineBreak +
             '{"ts":' + TimeStamp + ',"request":{"uri":"/stream/fragment.m4s","client_ip":"192.0.2.10"}}' + sLineBreak +
             '{"ts":' + TimeStamp + ',"request":{"uri":"/stream/live.json","client_ip":"192.0.2.11"}}' + sLineBreak +
             '{"ts":' + TimeStamp + ',"request":{"uri":"/artwork/cover.jpg","client_ip":"192.0.2.12"}}' + sLineBreak +
             '{"ts":1,"request":{"uri":"/stream/live.json","client_ip":"192.0.2.13"}}';
    TFile.WriteAllText(Path,
                         Lines,
                         TEncoding.UTF8);
    Require(ReadRdjListenerCount(Path) = 2,
               'Listener parser did not preserve filtering and de-duplication.');

    Scan := TRdjListenerScan.Create(Path);
    try
      Scan.Start();
      WaitForScan(Scan);
      Require((Scan.ListenerCount = 2) and (Scan.ErrorText = ''),
                 'Background scan returned different results.');
    finally
      Scan.Free();
    end;

    Ticks := TUiTicks.Create();
    Timer := TTimer.Create(nil);
    try
      Timer.Interval := 16;
      Timer.OnTimer := Ticks.Tick;
      Scan := TSlowListenerScan.Create(Path);
      try
        Started := GetTickCount();
        Scan.Start();
        Require(Cardinal(GetTickCount() - Started) < 100,
                   'Starting a scan blocked the caller.');
        WaitForScan(Scan);
        Require((Ticks.Count >= 10) and (Scan.ListenerCount = 2),
                   'VCL timer updates stopped during a slow scan.');
        Writeln('PASS: VCL processed ', Ticks.Count, ' refresh ticks during a 450 ms scan.');
      finally
        Scan.Free();
      end;
    finally
      Timer.Free();
      Ticks.Free();
    end;

    Locked := TFileStream.Create(Path,
                                   fmOpenReadWrite or fmShareExclusive);
    try
      Scan := TRdjListenerScan.Create(Path);
      try
        Scan.Start();
        WaitForScan(Scan);
        Require((Scan.ListenerCount = -1) and (Scan.ErrorText <> ''),
                   'Read failure escaped the worker or replaced the cached count.');
      finally
        Scan.Free();
      end;
    finally
      Locked.Free();
    end;

    Scan := TRdjListenerScan.Create(Path);
    Scan.Free();
    Writeln('PASS: listener parsing, background results, read-failure isolation and unstarted-worker cleanup.');
  except
    on E: Exception do
      begin
        Writeln('FAIL: ', E.ClassName, ': ', E.Message);
        Halt(1);
      end;
  end;
end.
