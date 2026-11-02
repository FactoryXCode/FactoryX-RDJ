// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: RDJ Pro.
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: RDJ.BackgroundAudio.pas
// Kind: Pascal Unit
// Release date: 01-11-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Automatic public AAC output lifecycle and recovery.
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

unit RDJ.BackgroundAudio;

interface

uses

  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  RDJ.HeosOutput;

type

  TRdjBackgroundAudioLogEvent = procedure(const Text: string) of object;

  TRdjBackgroundAudio = class
  private

    FOutput: TRdjHeosOutput;
    FEnabled: Boolean;
    FAddress: string;
    FPort: Word;
    FConfigError: string;
    FSampleRate: Integer;
    FLastAttemptTick: DWORD;
    FHasAttempted: Boolean;
    FReadyReported: Boolean;
    FOnLog: TRdjBackgroundAudioLogEvent;
    procedure Log(const Text: string);

  protected

    function CurrentTick(): DWORD; virtual;

  public

    constructor Create(const SettingsFile: string);
    destructor Destroy(); override;
    procedure Update(ABroadcasting: Boolean);
    procedure Stop();
    procedure SetMasterGains(ALeft: Single; ARight: Single);
    procedure PushFloat32(Data: PSingle; Frames: Integer; SampleRate: Integer);
    property OnLog: TRdjBackgroundAudioLogEvent read FOnLog write FOnLog;
  end;

implementation

uses

  System.IniFiles;

constructor TRdjBackgroundAudio.Create(const SettingsFile: string);
var
  Settings: TIniFile;
  Port: Integer;

begin

  inherited Create();
  FOutput := TRdjHeosOutput.Create();
  FEnabled := True;
  FAddress := '0.0.0.0';
  FPort := 8098;
  Settings := nil;

  try
    try
      Settings := TIniFile.Create(SettingsFile);
      FEnabled := Settings.ReadBool('AudioRadio', 'Enabled', True);
      FAddress := Trim(Settings.ReadString('AudioRadio', 'Bind', FAddress));
      Port := Settings.ReadInteger('AudioRadio', 'Port', FPort);

      if (Port < 1) or (Port > 65535) then
        raise EArgumentException.Create('AudioRadio Port must be between 1 and 65535.');

      FPort := Port;
    except
      on E: Exception do
        FConfigError := E.Message;
    end;
  finally
    Settings.Free();
  end;
end;


destructor TRdjBackgroundAudio.Destroy();
begin

  FOnLog := nil;
  FOutput.Free();
  inherited;
end;


function TRdjBackgroundAudio.CurrentTick(): DWORD;
begin

  Result := GetTickCount();
end;


procedure TRdjBackgroundAudio.Log(const Text: string);
begin

  if Assigned(FOnLog) then
    FOnLog(Text);
end;


procedure TRdjBackgroundAudio.Update(ABroadcasting: Boolean);
var
  Tick: DWORD;
  Elapsed: DWORD;
  Rate: Integer;
  Error: string;

begin

  if not ABroadcasting or not FEnabled then
    begin
      Stop();
      Exit;
    end;

  Tick := CurrentTick();

  if FOutput.Active() then
    begin
      Error := FOutput.ErrorText();

      if (Error = '') then
        begin
          if FOutput.Ready() and not FReadyReported then
            begin
              FReadyReported := True;
              Log('Background AAC ready: ' + FOutput.Url());
            end;

          Exit;
        end;

      FOutput.Stop();
      FReadyReported := False;
      FLastAttemptTick := Tick;
      FHasAttempted := True;
      Log('Background AAC error: ' + Error + ' Retrying in 30 seconds.');
      Exit;
    end;

  // The audio callback only forwards PCM and updates this atomic rate.
  // Starting the listener and encoder always happens on the owner thread.
  Rate := InterlockedCompareExchange(FSampleRate, 0, 0);

  if (Rate <> 44100) and (Rate <> 48000) then
    Exit;

  if Tick >= FLastAttemptTick then
    Elapsed := Tick - FLastAttemptTick
  else
    Elapsed := (High(DWORD) - FLastAttemptTick) + Tick + 1;

  if FHasAttempted and (Elapsed < 30000) then
    Exit;

  FHasAttempted := True;
  FLastAttemptTick := Tick;

  try
    if (FConfigError <> '') then
      raise EInvalidOperation.Create(FConfigError);

    FOutput.StartBroadcast(FAddress, FPort);
    FReadyReported := False;
    Log('Background AAC started on port ' + IntToStr(FPort) + ' (/radio/live.aac).');
  except
    on E: Exception do
      Log('Background AAC start failed: ' + E.Message + ' Retrying in 30 seconds.');
  end;
end;


procedure TRdjBackgroundAudio.Stop();
var
  WasActive: Boolean;

begin

  WasActive := FOutput.Active();

  if WasActive then
    FOutput.Stop();

  FHasAttempted := False;
  FReadyReported := False;

  if WasActive then
    Log('Background AAC stopped.');
end;


procedure TRdjBackgroundAudio.SetMasterGains(ALeft: Single; ARight: Single);
begin

  FOutput.SetMasterGains(ALeft, ARight);
end;


procedure TRdjBackgroundAudio.PushFloat32(Data: PSingle; Frames: Integer;
                                           SampleRate: Integer);
begin

  InterlockedExchange(FSampleRate, SampleRate);
  FOutput.PushFloat32(Data, Frames, SampleRate);
end;

end.
