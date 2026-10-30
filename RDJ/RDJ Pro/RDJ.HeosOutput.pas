// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: HEOS Remote.
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: RDJ.HeosOutput.pas
// Kind: Pascal Unit
// Release date: 24-01-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Bounded Masterdeck PCM queue and background HEOS AAC output.
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
//          Please, read documentation carefully!
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
// Source: FactoryX.Code / MfPack
// =============================================================================
//
// LICENSE
//
// The contents of this file are subject to the Mozilla Public License
// Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// https://www.mozilla.org/en-US/MPL/2.0/
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

unit RDJ.HeosOutput;

interface

uses

  {WinApi}
  WinApi.Windows,
  {System}
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  {Application}
  RDJ.HeosAudioServer;

type

  TRdjHeosOutput = class;

  TRdjHeosEncoderThread = class(TThread)
  private

    FOwner: TRdjHeosOutput;

  protected

    procedure Execute(); override;

  public

    constructor Create(AOwner: TRdjHeosOutput);
  end;

  TRdjHeosOutput = class
  private

    FLock: TCriticalSection;
    FWake: TEvent;
    FBuffer: TArray<Single>;
    FRead: Integer;
    FWrite: Integer;
    FCount: Integer;
    FObservedRate: Integer;
    FSampleRate: Integer;
    FActive: Integer;
    FReady: Integer;
    FFormatChanged: Integer;
    FDropped: Integer;
    FGainL: Integer;
    FGainR: Integer;
    FError: string;
    FServer: THeosAudioServer;
    FWorker: TRdjHeosEncoderThread;

    function Pop(ABuffer: PSingle; AMaximum: Integer): Integer;
    procedure SetError(const AText: string);

  public

    constructor Create();
    destructor Destroy(); override;

    procedure Start(const AReceiver: string; APort: Word = 0;
                      const ALocalAddress: string = '');
    procedure Stop();
    procedure SetMasterGains(ALeft: Single; ARight: Single);
    procedure PushFloat32(AData: PSingle; AFrames: Integer; ASampleRate: Integer);
    function Active(): Boolean;
    function Ready(): Boolean;
    function Url(): string;
    function ErrorText(): string;
    function DroppedBlocks(): Integer;
    function Requests(): Integer;
  end;

implementation

uses

  {WinApi}
  WinApi.ComBaseApi,
  WinApi.ActiveX.ObjBase,
  WinApi.MediaFoundationApi.MfApi,
  {System}
  System.Math,
  {Application}
  Heos.Sockets,
  RDJ.HeosAacEncoder;

const

  HEOS_RING_FRAMES = 96000;
  HEOS_ENCODER_FRAMES = 1024;

procedure CheckResult(AResult: HRESULT; const AOperation: string);
begin

  if Failed(AResult) then
    raise EInvalidOperation.CreateFmt('%s failed ($%.8x).', [AOperation, Cardinal(AResult)]);
end;


constructor TRdjHeosOutput.Create();
begin

  inherited;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
  SetLength(FBuffer, HEOS_RING_FRAMES * 2);
  FGainL := 1000000;
  FGainR := 1000000;
end;


destructor TRdjHeosOutput.Destroy();
begin

  Stop();
  FWake.Free;
  FLock.Free;
  inherited;
end;


procedure TRdjHeosOutput.Start(const AReceiver: string; APort: Word;
                                const ALocalAddress: string);
var
  Rate: Integer;
  Address: string;

begin

  Stop();
  Rate := InterlockedCompareExchange(FObservedRate, 0, 0);
  if (Rate <> 44100) and (Rate <> 48000) then
    raise EInvalidOperation.Create('Start the RDJ Masterdeck audio engine at 44100 or 48000 Hz first.');

  FLock.Acquire;
  try
    FRead := 0;
    FWrite := 0;
    FCount := 0;
    FError := '';
    FSampleRate := Rate;
  finally
    FLock.Release;
  end;
  InterlockedExchange(FReady, 0);
  InterlockedExchange(FFormatChanged, 0);
  InterlockedExchange(FDropped, 0);

  try
    Address := ALocalAddress;
    if (Address = '') then
      Address := LocalAddressFor(AReceiver);
    if not IPv4Valid(Address) then
      raise EArgumentException.Create('Enter a valid local PC IPv4 address.');
    FServer := THeosAudioServer.Create(Address, APort);
    FServer.Start;
    FWorker := TRdjHeosEncoderThread.Create(Self);
    InterlockedExchange(FActive, 1);
    FWorker.Start;
  except
    Stop();
    raise;
  end;
end;


procedure TRdjHeosOutput.Stop();
begin

  InterlockedExchange(FActive, 0);
  // Pair with an already-entered audio callback before clearing the queue.
  FLock.Acquire;
  try
    FCount := 0;
  finally
    FLock.Release;
  end;
  if Assigned(FWorker) then
    begin
      FWorker.Terminate;
      FWake.SetEvent;
      if FWorker.Suspended then
        FWorker.Start;
      FWorker.WaitFor;
      FreeAndNil(FWorker);
    end;
  FreeAndNil(FServer);
  InterlockedExchange(FReady, 0);
end;


procedure TRdjHeosOutput.SetMasterGains(ALeft: Single; ARight: Single);
begin

  InterlockedExchange(FGainL, Round(EnsureRange(ALeft, 0.0, 1.0) * 1000000));
  InterlockedExchange(FGainR, Round(EnsureRange(ARight, 0.0, 1.0) * 1000000));
end;


procedure TRdjHeosOutput.PushFloat32(AData: PSingle; AFrames: Integer; ASampleRate: Integer);
var
  I: Integer;
  GainL: Single;
  GainR: Single;

begin

  InterlockedExchange(FObservedRate, ASampleRate);
  if not Active() or (AData = nil) or (AFrames <= 0) then
    Exit;
  if not FLock.TryEnter then
    begin
      InterlockedIncrement(FDropped);
      Exit;
    end;
  try
    if not Active() then
      Exit;
    if (ASampleRate <> FSampleRate) then
      begin
        InterlockedExchange(FFormatChanged, 1);
        Exit;
      end;
    if (AFrames > HEOS_RING_FRAMES - FCount) then
      begin
        InterlockedIncrement(FDropped);
        Exit;
      end;
    GainL := InterlockedCompareExchange(FGainL, 0, 0) / 1000000;
    GainR := InterlockedCompareExchange(FGainR, 0, 0) / 1000000;
    for I := 0 to AFrames - 1 do
      begin
        FBuffer[FWrite * 2] := AData^ * GainL;
        Inc(AData);
        FBuffer[FWrite * 2 + 1] := AData^ * GainR;
        Inc(AData);
        Inc(FWrite);
        if (FWrite = HEOS_RING_FRAMES) then
          FWrite := 0;
      end;
    Inc(FCount, AFrames);
  finally
    FLock.Release;
  end;
  FWake.SetEvent;
end;


function TRdjHeosOutput.Pop(ABuffer: PSingle; AMaximum: Integer): Integer;
var
  First: Integer;

begin

  FLock.Acquire;
  try
    Result := Min(FCount, AMaximum);
    if (Result = 0) then
      Exit;
    First := Min(Result, HEOS_RING_FRAMES - FRead);
    Move(FBuffer[FRead * 2], ABuffer^, First * 2 * SizeOf(Single));
    if (First < Result) then
      begin
        Inc(ABuffer, First * 2);
        Move(FBuffer[0], ABuffer^, (Result - First) * 2 * SizeOf(Single));
      end;
    FRead := (FRead + Result) mod HEOS_RING_FRAMES;
    Dec(FCount, Result);
  finally
    FLock.Release;
  end;
end;


procedure TRdjHeosOutput.SetError(const AText: string);
begin

  FLock.Acquire;
  try
    FError := AText;
  finally
    FLock.Release;
  end;
end;


function TRdjHeosOutput.Active(): Boolean;
begin

  Result := InterlockedCompareExchange(FActive, 0, 0) <> 0;
end;


function TRdjHeosOutput.Ready(): Boolean;
begin

  Result := Active() and (InterlockedCompareExchange(FReady, 0, 0) <> 0);
end;


function TRdjHeosOutput.Url(): string;
begin

  Result := '';
  if Assigned(FServer) then
    Result := FServer.Url();
end;


function TRdjHeosOutput.ErrorText(): string;
begin

  if (InterlockedCompareExchange(FFormatChanged, 0, 0) <> 0) then
    Exit('The Masterdeck sample rate changed. Restart HEOS streaming.');
  FLock.Acquire;
  try
    Result := FError;
  finally
    FLock.Release;
  end;
  // A receiver can close a probe/old HTTP connection and reconnect normally.
  if (Result = '') and Assigned(FServer) and FServer.Finished then
    begin
      Result := FServer.LastError();
      if (Result = '') then
        Result := 'The HEOS audio HTTP server stopped.';
    end;
end;


function TRdjHeosOutput.DroppedBlocks(): Integer;
begin

  Result := InterlockedCompareExchange(FDropped, 0, 0);
end;


function TRdjHeosOutput.Requests(): Integer;
begin

  Result := 0;
  if Assigned(FServer) then
    Result := FServer.Requests();
end;


constructor TRdjHeosEncoderThread.Create(AOwner: TRdjHeosOutput);
begin

  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;


procedure TRdjHeosEncoderThread.Execute();
var
  Encoder: THeosAacEncoder;
  Settings: TDenonAudioSettings;
  Samples: array[0..HEOS_ENCODER_FRAMES * 2 - 1] of Single;
  Bytes: TBytes;
  Frames: Integer;
  ComStarted: Boolean;
  MfStarted: Boolean;

begin

  Encoder := nil;
  ComStarted := False;
  MfStarted := False;
  try
    try
      CheckResult(CoInitializeEx(nil, COINIT_MULTITHREADED), 'Initialize HEOS COM');
      ComStarted := True;
      CheckResult(MFStartup(MF_VERSION, MFSTARTUP_FULL), 'Initialize HEOS Media Foundation');
      MfStarted := True;
      Encoder := THeosAacEncoder.Create();
      Settings.SampleRate := FOwner.FSampleRate;
      Settings.Channels := 2;
      Settings.BitrateKbps := 192;
      CheckResult(Encoder.Initialize(Settings), 'Initialize HEOS AAC encoder');
      InterlockedExchange(FOwner.FReady, 1);
      while not Terminated do
        begin
          Frames := FOwner.Pop(@Samples[0], HEOS_ENCODER_FRAMES);
          if (Frames = 0) then
            begin
              FOwner.FWake.WaitFor(100);
              Continue;
            end;
          CheckResult(Encoder.EncodeInterleavedFloat32(@Samples[0], Frames, Bytes), 'Encode HEOS Masterdeck audio');
          if (Length(Bytes) > 0) then
            FOwner.FServer.Push(Bytes);
        end;
    except
      on E: Exception do
        FOwner.SetError(E.Message);
    end;
  finally
    InterlockedExchange(FOwner.FReady, 0);
    Encoder.Free;
    if MfStarted then
      MFShutdown;
    if ComStarted then
      CoUninitialize;
  end;
end;

end.
