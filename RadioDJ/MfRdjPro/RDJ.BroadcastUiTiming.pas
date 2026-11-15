// FactoryX. Licensed under the Mozilla Public License 2.0.
// Keep broadcast UI timings in memory; write them only after broadcasting stops.
unit RDJ.BroadcastUiTiming;

interface

uses

  System.Classes;

type

  TRdjBroadcastUiTiming = class
  private
    FLines: TStringList;
    FFileName: string;
    FLastTimerTick: UInt64;
    FLastError: string;
    procedure Add(const AStage: string;
                    const AElapsedMs: UInt64);
  public
    constructor Create(const AFileName: string);
    destructor Destroy(); override;
    procedure TimerEntered(const AActive: Boolean);
    procedure Finished(const AStage: string;
                         const AStartedTick: UInt64);
    procedure Flush();
    property FileName: string read FFileName;
    property LastError: string read FLastError;
  end;

function BroadcastUiTimingFileName(): string;
function BroadcastUiTick(): UInt64; stdcall;

implementation

uses

  WinApi.Windows,
  System.SysUtils,
  System.IOUtils;


function BroadcastUiTimingFileName(): string;
var
  AppDir: string;
  SearchDir: string;
  ParentDir: string;

begin

  AppDir := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  SearchDir := AppDir;

  // Development builds belong to the application root, above Win32/Win64.
  // Installed copies keep their log beside the executable.
  while (SearchDir <> '') do
    begin
      if FileExists(TPath.Combine(SearchDir, 'MfRdjJ.dproj')) then
        begin
          AppDir := SearchDir;
          Break;
        end;

      ParentDir := ExtractFileDir(SearchDir);

      if SameText(ParentDir, SearchDir) then
        Break;

      SearchDir := ParentDir;
    end;

  Result := TPath.Combine(AppDir,
                           'BroadcastUiTiming-' + IntToStr(GetCurrentProcessId()) + '.log');
end;


constructor TRdjBroadcastUiTiming.Create(const AFileName: string);
begin

  inherited Create();
  FFileName := AFileName;
  FLines := TStringList.Create();
  FLines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now()) +
               Format(' | trace started PID=%d pointerBits=%d; slowStageMs=20 timerGapMs=50',
                        [GetCurrentProcessId(), SizeOf(Pointer) * 8]));
end;


destructor TRdjBroadcastUiTiming.Destroy();
begin

  Flush();
  FLines.Free();
  inherited;
end;


procedure TRdjBroadcastUiTiming.Add(const AStage: string;
                                     const AElapsedMs: UInt64);
begin

  // All callers are on the form's UI thread. No disk I/O or locks here.
  if (FLines.Count >= 512) then
    FLines.Delete(0);

  FLines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now()) +
               Format(' | thread=%d stage=%s elapsedMs=%d',
                        [GetCurrentThreadId(), AStage, AElapsedMs]));
end;


procedure TRdjBroadcastUiTiming.TimerEntered(const AActive: Boolean);
var
  Tick: UInt64;

begin

  if not AActive then
    begin
      FLastTimerTick := 0;
      Exit;
    end;

  Tick := BroadcastUiTick();

  if (FLastTimerTick <> 0) and (Tick - FLastTimerTick >= 50) then
    Add('broadcast.timer-gap',
          Tick - FLastTimerTick);

  FLastTimerTick := Tick;
end;


procedure TRdjBroadcastUiTiming.Finished(const AStage: string;
                                          const AStartedTick: UInt64);
var
  Elapsed: UInt64;

begin

  Elapsed := BroadcastUiTick() - AStartedTick;

  if (Elapsed >= 20) then
    Add(AStage,
          Elapsed);
end;


procedure TRdjBroadcastUiTiming.Flush();
var
  Stream: TFileStream;
  Bytes: TBytes;

begin

  if (FLines.Count = 0) then
    Exit;

  try
    ForceDirectories(ExtractFilePath(FFileName));

    if FileExists(FFileName) then
      Stream := TFileStream.Create(FFileName,
                                     fmOpenReadWrite or fmShareDenyWrite)
    else
      Stream := TFileStream.Create(FFileName,
                                     fmCreate or fmShareDenyWrite);
    try
      Stream.Position := Stream.Size;
      Bytes := TEncoding.UTF8.GetBytes(FLines.Text);
      Stream.WriteBuffer(Bytes[0],
                            Length(Bytes));
      FLines.Clear();
      FLastError := '';
    finally
      Stream.Free();
    end;
  except
    on E: Exception do
      FLastError := E.ClassName + ': ' + E.Message;
  end;
end;

function BroadcastUiTick; external 'kernel32.dll' name 'GetTickCount64';

end.
