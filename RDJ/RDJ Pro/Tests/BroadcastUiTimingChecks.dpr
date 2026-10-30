program BroadcastUiTimingChecks;

{$APPTYPE CONSOLE}

uses

  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  RDJ.BroadcastUiTiming;


procedure Require(const ACondition: Boolean;
                    const AMessage: string);
begin

  if not ACondition then
    raise Exception.Create(AMessage);
end;

var
  Trace: TRdjBroadcastUiTiming;
  Path: string;
  Lines: TStringList;
  I: Integer;

begin

  try
    Path := TPath.Combine('D:\PROJECTS\MfPack\Build\BroadcastUiTiming-20261018',
                           Format('timing-check-%d.log', [GetCurrentProcessId()]));
    Trace := TRdjBroadcastUiTiming.Create(Path);
    try
      Trace.TimerEntered(True);
      Sleep(65);
      Trace.TimerEntered(True);
      Trace.Finished('test.slow-fragment-write',
                       BroadcastUiTick() - 50);
      Require(not FileExists(Path),
                 'Timing capture performed disk I/O during playback.');
      Trace.Flush();
      Require(Trace.LastError = '',
                 'Trace could not be saved.');
      Lines := TStringList.Create();
      try
        Lines.LoadFromFile(Path,
                             TEncoding.UTF8);
        Require((Pos('broadcast.timer-gap', Lines.Text) > 0) and
                (Pos('test.slow-fragment-write', Lines.Text) > 0),
                   'Trace lost a timer gap or slow publication stage.');
      finally
        Lines.Free();
      end;
    finally
      Trace.Free();
    end;

    Path := Path + '.bounded';
    Trace := TRdjBroadcastUiTiming.Create(Path);
    try
      for I := 1 to 2000 do
        Trace.Finished('test.stage-' + IntToStr(I),
                         BroadcastUiTick() - 25);
      Require(not FileExists(Path),
                 'The bounded trace performed runtime disk writes.');
      Trace.Flush();
      Lines := TStringList.Create();
      try
        Lines.LoadFromFile(Path,
                             TEncoding.UTF8);
        Require((Lines.Count <= 512) and (Pos('stage-2000 ', Lines.Text) > 0),
                   'Trace storage was unbounded or dropped its newest evidence.');
      finally
        Lines.Free();
      end;
    finally
      Trace.Free();
    end;

    Writeln('PASS: gaps and slow stages captured, memory bounded, files written only on flush.');
  except
    on E: Exception do
      begin
        Writeln('FAIL: ', E.ClassName, ': ', E.Message);
        Halt(1);
      end;
  end;
end.
