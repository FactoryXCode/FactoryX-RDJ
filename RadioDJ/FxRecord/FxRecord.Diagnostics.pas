unit FxRecord.Diagnostics;

interface

uses Winapi.Windows, System.Classes, System.SysUtils, System.SyncObjs;

function FxDiagnosticTick: UInt64; stdcall; external 'kernel32.dll' name 'GetTickCount64';

type
  // Independent sampling continues even when the recording monitor is blocked.
  TFxRecordDiagnostics = class(TThread)
  private
    FStop: TEvent;
    FLock: TCriticalSection;
    FLogConfig: string;
    FActivity: string;
    FActivityTick: UInt64;
    procedure WriteSample(const AText: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const ALogFileName: string);
    destructor Destroy; override;
    procedure SetActivity(const AActivity: string);
    procedure Stop;
  end;

implementation

uses Winapi.TlHelp32, System.IOUtils, FxRecord.Log;

type
  TFxMemoryCounters = record
    cb, PageFaultCount: DWORD;
    PeakWorkingSetSize, WorkingSetSize, QuotaPeakPagedPoolUsage,
    QuotaPagedPoolUsage, QuotaPeakNonPagedPoolUsage, QuotaNonPagedPoolUsage,
    PagefileUsage, PeakPagefileUsage, PrivateUsage: NativeUInt;
  end;

function FxGetProcessMemoryInfo(Process: THandle; var Counters: TFxMemoryCounters;
  Size: DWORD): BOOL; stdcall; external 'psapi.dll' name 'GetProcessMemoryInfo';

function FxGetProcessHandleCount(Process: THandle; var Count: DWORD): BOOL;
  stdcall; external 'kernel32.dll' name 'GetProcessHandleCount';

function FileTimeValue(const AValue: TFileTime): UInt64;
begin
  Result := (UInt64(AValue.dwHighDateTime) shl 32) or AValue.dwLowDateTime;
end;

function ProcessThreadCount: Integer;
var Snapshot: THandle; Entry: TThreadEntry32;
begin
  Result := -1;
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if Snapshot = INVALID_HANDLE_VALUE then Exit;
  try
    Result := 0;
    Entry.dwSize := SizeOf(Entry);
    if Thread32First(Snapshot, Entry) then
      repeat
        if Entry.th32OwnerProcessID = GetCurrentProcessId then Inc(Result);
      until not Thread32Next(Snapshot, Entry);
  finally
    CloseHandle(Snapshot);
  end;
end;

constructor TFxRecordDiagnostics.Create(const ALogFileName: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FStop := TEvent.Create(nil, True, False, '');
  FLock := TCriticalSection.Create;
  FLogConfig := ChangeFileExt(ALogFileName, '.diagnostics.ini');
  FActivity := 'starting';
  FActivityTick := FxDiagnosticTick;
end;

destructor TFxRecordDiagnostics.Destroy;
begin
  Stop;
  WaitFor;
  FStop.Free;
  FLock.Free;
  inherited;
end;

procedure TFxRecordDiagnostics.Stop;
begin
  Terminate;
  FStop.SetEvent;
end;

procedure TFxRecordDiagnostics.SetActivity(const AActivity: string);
begin
  FLock.Acquire;
  try
    FActivity := AActivity;
    FActivityTick := FxDiagnosticTick;
  finally
    FLock.Release;
  end;
end;

procedure TFxRecordDiagnostics.WriteSample(const AText: string);
var Name: string; Stream: TFileStream;
begin
  try
    Name := ChangeFileExt(FLogConfig, '.log');
    if FileExists(Name) then
    begin
      Stream := TFileStream.Create(Name, fmOpenRead or fmShareDenyNone);
      try
        if Stream.Size < 10 * 1024 * 1024 then Name := '';
      finally
        Stream.Free;
      end;
      if Name <> '' then
        if not MoveFileEx(PChar(Name), PChar(Name + '.previous'), MOVEFILE_REPLACE_EXISTING) then Exit;
    end;
    AppendFxRecordLog(FLogConfig, 'DIAG', AText);
  except
    // Diagnostics must never interfere with compliance recording.
  end;
end;

procedure TFxRecordDiagnostics.Execute;
var
  Created, Exited, Kernel, UserTime, Idle, SysKernel, SysUser: TFileTime;
  PrevProcess, PrevIdle, PrevSystem, PrevTick, Tick, ProcessTime,
  SystemTime, IdleTime, LastLog, ActivityTick, MonitorAge: UInt64;
  Info: TSystemInfo;
  Memory: TFxMemoryCounters;
  Handles: DWORD;
  Activity: string;
  CPU, SystemCPU: Double;
  LastPrivate: NativeUInt;
  High, WasHigh, MemoryOK, Stalled, WasStalled: Boolean;
begin
  GetSystemInfo(Info);
  PrevProcess := 0; PrevIdle := 0; PrevSystem := 0; PrevTick := 0;
  LastLog := 0; LastPrivate := 0; WasHigh := False; WasStalled := False;
  WriteSample(Format('Diagnostics started: PID=%d logicalCPUs=%d exe=%s buildTimestamp=%s sampling=5s baseline=60s spike=15s CPU=normalized-to-machine',
    [GetCurrentProcessId, Info.dwNumberOfProcessors, ParamStr(0),
     DateTimeToStr(TFile.GetLastWriteTime(ParamStr(0)))]));
  while not Terminated do
  begin
    try
      Tick := FxDiagnosticTick;
      if GetProcessTimes(GetCurrentProcess, Created, Exited, Kernel, UserTime) and
         Winapi.Windows.GetSystemTimes(Idle, SysKernel, SysUser) then
      begin
        ProcessTime := FileTimeValue(Kernel) + FileTimeValue(UserTime);
        SystemTime := FileTimeValue(SysKernel) + FileTimeValue(SysUser);
        IdleTime := FileTimeValue(Idle);
        if (PrevTick <> 0) and (Tick > PrevTick) and (SystemTime > PrevSystem) then
        begin
          CPU := 100.0 * (ProcessTime - PrevProcess) /
            ((Tick - PrevTick) * 10000.0 * Info.dwNumberOfProcessors);
          SystemCPU := 100.0 * (1.0 - (IdleTime - PrevIdle) / (SystemTime - PrevSystem));
          FillChar(Memory, SizeOf(Memory), 0);
          Memory.cb := SizeOf(Memory);
          MemoryOK := FxGetProcessMemoryInfo(GetCurrentProcess, Memory, SizeOf(Memory));
          High := CPU >= 70.0;
          FLock.Acquire;
          try
            Activity := FActivity; ActivityTick := FActivityTick;
          finally
            FLock.Release;
          end;
          // The activity can be updated after the CPU sample timestamp.
          if Tick >= ActivityTick then MonitorAge := Tick - ActivityTick
          else MonitorAge := 0;
          Stalled := MonitorAge >= 5000;
          if (LastLog = 0) or (Tick - LastLog >= 60000) or
             (High <> WasHigh) or (High and (Tick - LastLog >= 15000)) or
             (Stalled <> WasStalled) or (Stalled and (Tick - LastLog >= 15000)) or
             (MemoryOK and (Memory.PrivateUsage > LastPrivate) and
              (Memory.PrivateUsage - LastPrivate >= 64 * 1024 * 1024)) then
          begin
            Handles := 0;
            FxGetProcessHandleCount(GetCurrentProcess, Handles);
            WriteSample(Format('cpu=%.1f%% systemCPU=%.1f%% privateMB=%.1f workingSetMB=%.1f peakWorkingSetMB=%.1f memoryValid=%s threads=%d handles=%d monitorAgeMs=%d activity=%s',
              [CPU, SystemCPU, Memory.PrivateUsage / 1048576.0,
               Memory.WorkingSetSize / 1048576.0, Memory.PeakWorkingSetSize / 1048576.0,
               BoolToStr(MemoryOK, True), ProcessThreadCount, Handles, Int64(MonitorAge), Activity]));
            LastLog := Tick;
            if MemoryOK then LastPrivate := Memory.PrivateUsage;
          end;
          WasHigh := High;
          WasStalled := Stalled;
        end;
        PrevProcess := ProcessTime; PrevIdle := IdleTime;
        PrevSystem := SystemTime; PrevTick := Tick;
      end;
    except
      on E: Exception do WriteSample('Sampling failed: ' + E.ClassName + ': ' + E.Message);
    end;
    if FStop.WaitFor(5000) = wrSignaled then Break;
  end;
  WriteSample('Diagnostics stopped.');
end;

end.
