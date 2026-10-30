program BroadcastHeartbeatChecks;

{$APPTYPE CONSOLE}

uses

  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Forms,
  Vcl.ExtCtrls,
  RDJ.BroadcastHeartbeat;

type

  TSlowHeartbeat = class(TRdjBroadcastHeartbeat)
  protected
    procedure UpdateHeartbeat(); override;
  end;

  TTimerObserver = class
  public
    Count: Integer;
    procedure Tick(Sender: TObject);
  end;


procedure TSlowHeartbeat.UpdateHeartbeat();
begin

  Sleep(300);
  inherited;
end;


procedure TTimerObserver.Tick(Sender: TObject);
begin

  Inc(Count);
end;


procedure Require(const ACondition: Boolean;
                    const AMessage: string);
begin

  if not ACondition then
    raise Exception.Create(AMessage);
end;


procedure AwaitHeartbeat(const AWorker: TRdjBroadcastHeartbeat);
var
  Started: DWORD;

begin

  Started := GetTickCount();
  AWorker.Start();

  while not AWorker.Completed do
    begin
      Require((GetTickCount() - Started < 5000), 'Heartbeat did not finish.');
      Application.ProcessMessages();
      Sleep(1);
    end;
end;

var
  BaseDir: string;
  LockDir: string;
  OwnerFile: string;
  StatusFile: string;
  Json: string;
  Worker: TRdjBroadcastHeartbeat;
  Observer: TTimerObserver;
  Timer: TTimer;

begin

  BaseDir := TPath.Combine(TPath.GetTempPath(),
                            'RdjHeartbeatChecks-' + IntToStr(GetCurrentProcessId()));
  try
    ForceDirectories(BaseDir);
    LockDir := TPath.Combine(BaseDir, 'broadcast.lock');
    ForceDirectories(LockDir);
    OwnerFile := TPath.Combine(LockDir, 'owner.json');
    StatusFile := TPath.Combine(BaseDir, 'status.json');
    Json := '{"ownerId":"test-owner","state":"on_air"}';
    TFile.WriteAllText(OwnerFile, Json, TEncoding.UTF8);

    Observer := TTimerObserver.Create();
    Timer := TTimer.Create(nil);
    Worker := TSlowHeartbeat.Create(BaseDir, LockDir, StatusFile, 'test-owner', Json, False);
    try
      Timer.Interval := 16;
      Timer.OnTimer := Observer.Tick;
      AwaitHeartbeat(Worker);
      Require((Worker.ErrorText = '') and (not Worker.Conflict), 'Valid owner was rejected: ' + Worker.ErrorText);
      Require((Observer.Count >= 5), 'Slow heartbeat blocked the UI timer.');
      Require((TEncoding.UTF8.GetString(TFile.ReadAllBytes(StatusFile)) = Json),
                 'Public status was not written intact.');
    finally
      Worker.Free();
      Timer.Free();
      Observer.Free();
    end;

    TFile.WriteAllText(OwnerFile, '{"ownerId":"another-dj"}', TEncoding.UTF8);
    Worker := TRdjBroadcastHeartbeat.Create(BaseDir, LockDir, StatusFile, 'test-owner', Json, False);
    try
      AwaitHeartbeat(Worker);
      Require(Worker.Conflict, 'Changed ownership was not detected.');
      Require((Pos('another-dj', TFile.ReadAllText(OwnerFile)) > 0), 'Another DJ was overwritten.');
    finally
      Worker.Free();
    end;

    DeleteFile(OwnerFile);
    RemoveDir(LockDir);
    Worker := TRdjBroadcastHeartbeat.Create(BaseDir, LockDir, StatusFile, 'test-owner', Json, False);
    try
      AwaitHeartbeat(Worker);
      Require((Worker.ErrorText <> '') and (not DirectoryExists(LockDir)), 'Missing lock was silently recreated.');
    finally
      Worker.Free();
    end;

    Worker := TRdjBroadcastHeartbeat.Create(BaseDir, LockDir, StatusFile, 'test-owner', Json, True);
    try
      AwaitHeartbeat(Worker);
      Require((Worker.ErrorText = '') and Worker.ReacquiredLock, 'Reconnect did not reacquire the lock.');
    finally
      Worker.Free();
    end;

    Writeln('PASS: UI timer remains responsive; owner conflict, missing lock and reconnect handled.');
    DeleteFile(OwnerFile);
    RemoveDir(LockDir);
    DeleteFile(StatusFile);
    RemoveDir(BaseDir);
  except
    on E: Exception do
      begin
        Writeln('FAIL: ', E.Message);
        Halt(1);
      end;
  end;
end.
