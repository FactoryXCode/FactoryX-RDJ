// FactoryX
//
// Copyright (c) FactoryX, Netherlands/Australia/Germany. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: FxRecord.Diagnostics
// Kind: Pascal Unit
// Release date: 10-08-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Recorder diagnostic unit.
//
// Company: FactoryX
// Intiator(s): Tony (maXcomX), Carmen (carmenh).
// Contributor(s): Tony Kalf (maXcomX), Carmen (carmenh).
//
//------------------------------------------------------------------------------
// CHANGE LOG
// Date       Person              Reason
// ---------- ------------------- ----------------------------------------------
// 24/08/2026 All                 Moby release  SDK 10.0.28000.2705  (Windows 11)
//------------------------------------------------------------------------------
//
// Remarks: Requires Windows 10 or higher.
//
// Related objects: -
// Related projects: MfPackX400
// Known Issues: -
//
// Compiler version: 23 up to 35
// SDK version: 10.0.28000.2705
//
// Todo: -
//
// =============================================================================
// Source: -
//==============================================================================
//
// LICENSE
//
// The contents of this file are subject to the Mozilla Public License
// Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// https://mozilla.org/MPL/2.0/
//
// Software distributed under the License is distributed on an "AS IS"
// basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
// License for the specific language governing rights and limitations
// under the License.
//
// Non commercial users may distribute this sourcecode provided that this
// header is included in full at the top of the file.
// Commercial users are not allowed to distribute this sourcecode as part of
// their product.
//
//==============================================================================
unit FxRecord.Diagnostics;

interface

uses

  {Winapi}
  Winapi.Windows,
  {System}
  System.Classes,
  System.SysUtils,
  System.SyncObjs;


type

  TFxMemoryCounters = record
    cb,
    PageFaultCount: DWORD;
    PeakWorkingSetSize: NativeUInt;
    WorkingSetSize: NativeUInt;
    QuotaPeakPagedPoolUsage: NativeUInt;
    QuotaPagedPoolUsage: NativeUInt;
    QuotaPeakNonPagedPoolUsage: NativeUInt;
    QuotaNonPagedPoolUsage: NativeUInt;
    PagefileUsage: NativeUInt;
    PeakPagefileUsage: NativeUInt;
    PrivateUsage: NativeUInt;
  end;

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
    procedure Execute(); override;

  public

    constructor Create(const ALogFileName: string);
    destructor Destroy(); override;

    procedure SetActivity(const AActivity: string);
    procedure Stop();
  end;


  function GetTickCount64(): UInt64; stdcall;

  function GetProcessMemoryInfo(Process: THandle;
                                var Counters: TFxMemoryCounters;
                                Size: DWORD): BOOL; stdcall;

  function GetProcessHandleCount(Process: THandle;
                                 var Count: DWORD): BOOL; stdcall;


implementation

uses

  {WinApi}
  WinApi.TlHelp32,
  {System}
  System.IOUtils,
  {Application}
  FxRecord.Log;


const
  Kernel32Lib = 'kernel32.dll';
  PsApiLib = 'psapi.dll';


function FileTimeValue(const AValue: TFileTime): UInt64;
begin

  Result := (UInt64(AValue.dwHighDateTime) shl 32) or AValue.dwLowDateTime;
end;


function ProcessThreadCount(): Integer;
var
  Snapshot: THandle;
  Entry: TThreadEntry32;

begin

  Result := -1;
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD,
                                       0);

  if (Snapshot = INVALID_HANDLE_VALUE) then
    Exit;

  try
    Result := 0;
    Entry.dwSize := SizeOf(Entry);

    if Thread32First(Snapshot,
                     Entry) then
      repeat
        if (Entry.th32OwnerProcessID = GetCurrentProcessId) then
          Inc(Result);
      until not Thread32Next(Snapshot,
                             Entry);

  finally
    CloseHandle(Snapshot);
  end;
end;


constructor TFxRecordDiagnostics.Create(const ALogFileName: string);
begin

  inherited Create(True);

  FreeOnTerminate := False;
  FStop := TEvent.Create(nil,
                         True,
                         False,
                         '');

  FLock := TCriticalSection.Create();

  FLogConfig := ChangeFileExt(ALogFileName,
                              '.diagnostics.ini');
  FActivity := 'starting';
  FActivityTick := GetTickCount64();
end;


destructor TFxRecordDiagnostics.Destroy();
begin

  Stop();
  WaitFor();

  FStop.Free;
  FLock.Free;

  inherited;
end;


procedure TFxRecordDiagnostics.Stop();
begin

  Terminate;
  FStop.SetEvent();
end;


procedure TFxRecordDiagnostics.SetActivity(const AActivity: string);
begin

  FLock.Acquire;

  try
    FActivity := AActivity;
    FActivityTick := GetTickCount64();
  finally
    FLock.Release;
  end;
end;


procedure TFxRecordDiagnostics.WriteSample(const AText: string);
var
  Name: string;
  Stream: TFileStream;

begin

  try
    Name := ChangeFileExt(FLogConfig,
                          '.log');

    if FileExists(Name) then
      begin
        Stream := TFileStream.Create(Name,
                                     fmOpenRead or fmShareDenyNone);
      try
        if (Stream.Size < 10 * 1024 * 1024) then
          Name := '';

      finally
        Stream.Free;
      end;

      if (Name <> '') then
        if not MoveFileEx(PChar(Name),
                          PChar(Name + '.previous'),
                          MOVEFILE_REPLACE_EXISTING) then
          Exit;
      end;

    AppendFxRecordLog(FLogConfig,
                      'DIAG',
                      AText);
  except
    // Diagnostics must never interfere with compliance recording.
  end;
end;


procedure TFxRecordDiagnostics.Execute();
var
  Created: TFileTime;
  Exited: TFileTime;
  Kernel: TFileTime;
  UserTime: TFileTime;
  Idle: TFileTime;
  SysKernel: TFileTime;
  SysUser: TFileTime;
  PrevProcess: UInt64;
  PrevIdle: UInt64;
  PrevSystem: UInt64;
  PrevTick: UInt64;
  Tick: UInt64;
  ProcessTime: UInt64;
  SystemTime: UInt64;
  IdleTime: UInt64;
  LastLog: UInt64;
  ActivityTick: UInt64;
  MonitorAge: UInt64;

  Info: TSystemInfo;
  Memory: TFxMemoryCounters;
  Handles: DWORD;
  Activity: string;

  CPU,
  SystemCPU: Double;
  LastPrivate: NativeUInt;
  High: Boolean;
  WasHigh: Boolean;
  MemoryOK: Boolean;
  Stalled: Boolean;
  WasStalled: Boolean;

begin

  GetSystemInfo(Info);

  PrevProcess := 0;
  PrevIdle := 0;
  PrevSystem := 0;
  PrevTick := 0;
  LastLog := 0;
  LastPrivate := 0;
  WasHigh := False;
  WasStalled := False;

  WriteSample(Format('Diagnostics started: PID=%d logicalCPUs=%d exe=%s buildTimestamp=%s sampling=5s baseline=60s spike=15s CPU=normalized-to-machine',
                     [GetCurrentProcessId, Info.dwNumberOfProcessors, ParamStr(0), DateTimeToStr(TFile.GetLastWriteTime(ParamStr(0)))]));

  while not Terminated do
  begin
    try
      Tick := GetTickCount64();

      if GetProcessTimes(GetCurrentProcess,
                         Created,
                         Exited,
                         Kernel,
                         UserTime) and
         Winapi.Windows.GetSystemTimes(Idle,
                                       SysKernel,
                                       SysUser) then
      begin
        ProcessTime := FileTimeValue(Kernel) + FileTimeValue(UserTime);
        SystemTime := FileTimeValue(SysKernel) + FileTimeValue(SysUser);
        IdleTime := FileTimeValue(Idle);

        if (PrevTick <> 0) and (Tick > PrevTick) and (SystemTime > PrevSystem) then
          begin
            CPU := 100.0 * (ProcessTime - PrevProcess) / ((Tick - PrevTick) * 10000.0 * Info.dwNumberOfProcessors);
            SystemCPU := 100.0 * (1.0 - (IdleTime - PrevIdle) / (SystemTime - PrevSystem));

            FillChar(Memory,
                     SizeOf(Memory),
                     0);

          Memory.cb := SizeOf(Memory);
          MemoryOK := GetProcessMemoryInfo(GetCurrentProcess,
                                           Memory,
                                           SizeOf(Memory));
          High := (CPU >= 70.0);
          FLock.Acquire;

          try
            Activity := FActivity;
            ActivityTick := FActivityTick;
          finally
            FLock.Release;
          end;

          // The activity can be updated after the CPU sample timestamp.
          if (Tick >= ActivityTick) then
            MonitorAge := Tick - ActivityTick
          else
            MonitorAge := 0;

          Stalled := (MonitorAge >= 5000);

          if (LastLog = 0) or
             (Tick - LastLog >= 60000) or
             (High <> WasHigh) or
             (High and (Tick - LastLog >= 15000)) or
             (Stalled <> WasStalled) or
             (Stalled and (Tick - LastLog >= 15000)) or
             (MemoryOK and (Memory.PrivateUsage > LastPrivate) and
              (Memory.PrivateUsage - LastPrivate >= 64 * 1024 * 1024)) then
          begin
            Handles := 0;

            GetProcessHandleCount(GetCurrentProcess,
                                  Handles);

            WriteSample(Format('cpu=%.1f%% systemCPU=%.1f%% privateMB=%.1f workingSetMB=%.1f peakWorkingSetMB=%.1f memoryValid=%s threads=%d handles=%d monitorAgeMs=%d activity=%s',
                               [CPU, SystemCPU, Memory.PrivateUsage / 1048576.0,
                                Memory.WorkingSetSize / 1048576.0, Memory.PeakWorkingSetSize / 1048576.0,
                                BoolToStr(MemoryOK, True), ProcessThreadCount, Handles, Int64(MonitorAge), Activity]));
            LastLog := Tick;

            if MemoryOK then
              LastPrivate := Memory.PrivateUsage;
          end;

          WasHigh := High;
          WasStalled := Stalled;

        end;

        PrevProcess := ProcessTime;
        PrevIdle := IdleTime;
        PrevSystem := SystemTime;
        PrevTick := Tick;

      end;
    except
      on E: Exception do WriteSample('Sampling failed: ' + E.ClassName + ': ' + E.Message);
    end;

    if (FStop.WaitFor(5000) = wrSignaled) then
      Break;
  end;

  WriteSample('Diagnostics stopped.');
end;


// External

{$WARN SYMBOL_PLATFORM OFF}

function GetTickCount64;        external Kernel32Lib name 'GetTickCount64' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function GetProcessHandleCount; external Kernel32Lib name 'GetProcessHandleCount' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function GetProcessMemoryInfo;  external PsApiLib name 'GetProcessMemoryInfo' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};

{$WARN SYMBOL_PLATFORM ON}

end.

