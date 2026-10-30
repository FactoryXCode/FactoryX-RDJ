// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: HEOS Remote.
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: HEOSTransport.pas
// Kind: Pascal Unit
// Release date: 24-01-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: .
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
// Remarks: Requires Windows 10 22H2 or higher.
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
// Source: FactoryX.Code
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
unit HEOSTransport;

interface

uses

  {WinApi}
  WinApi.Windows,
  {System}
  System.Classes,
  System.SysUtils;

type

  TDenonRequest = class(TThread)
  private
    FHost: string;
    FPort: Integer;
    FCommands: TStringList;
    FLines: TStringList;
    FError: string;
    FStopOnVolumeReply: Boolean;
    FStopOnChannelReply: Boolean;
    FStopOnZoneReply: Boolean;
    FStopOnToneReply: Boolean;

  protected
    procedure Execute(); override;

  public

    constructor Create(const Host: string;
                       const Commands: array of string;
                       Port: Integer = 23;
                       StopOnVolumeReply: Boolean = False;
                       StopOnChannelReply: Boolean = False;
                       StopOnZoneReply: Boolean = False;
                       StopOnToneReply: Boolean = False);

    destructor Destroy(); override;

    property Lines: TStringList read FLines;
    property ErrorText: string read FError;
  end;


implementation

uses

  {System}
  System.Diagnostics,
  {Application}
  HEOSSockets;

constructor TDenonRequest.Create(const Host: string;
                                 const Commands: array of string;
                                 Port: Integer;
                                 StopOnVolumeReply: Boolean;
                                 StopOnChannelReply: Boolean;
                                 StopOnZoneReply: Boolean;
                                 StopOnToneReply: Boolean);
var
  I: Integer;

begin

  inherited Create(True);

  FreeOnTerminate := False;
  FHost := Host;
  FPort := Port;
  FStopOnVolumeReply := StopOnVolumeReply;
  FStopOnChannelReply := StopOnChannelReply;
  FStopOnZoneReply := StopOnZoneReply;
  FStopOnToneReply := StopOnToneReply;
  FCommands := TStringList.Create;
  FLines := TStringList.Create;

  for I := Low(Commands) to High(Commands) do
    FCommands.Add(Commands[I]);
end;


destructor TDenonRequest.Destroy();
begin

  FCommands.Free;
  FLines.Free;

  inherited;
end;


procedure TDenonRequest.Execute;
var
  Client: THEOSConnection;
  Command: string;
  Line: string;
  Timer: TStopwatch;
  Value: Integer;
  ExpectedVolume: Integer;
  ReplyVolume: Integer;
  MaximumVolume: Integer;
  VolumeMaximumReceived: Boolean;
  VolumeReceived: Boolean;
  LeftReceived: Boolean;
  RightReceived: Boolean;
  ChannelReceived: Boolean;
  MainZoneReceived: Boolean;
  Zone2Received: Boolean;
  ToneReceived: Boolean;
  BassReceived: Boolean;
  TrebleReceived: Boolean;
  ModeReceived: Boolean;
  DynamicEqReceived: Boolean;
  ExpectedTone: string;
  ExpectedBass: string;
  ExpectedTreble: string;

begin

  Client := nil;
  ExpectedVolume := -1;
  ReplyVolume := -1;
  MaximumVolume := 196;
  VolumeMaximumReceived := False;
  VolumeReceived := False;
  LeftReceived := False;
  RightReceived := False;
  ChannelReceived := False;
  MainZoneReceived := False;
  Zone2Received := False;
  ToneReceived := False;
  BassReceived := False;
  TrebleReceived := False;
  ModeReceived := False;
  DynamicEqReceived := False;
  ExpectedTone := '';
  ExpectedBass := '';
  ExpectedTreble := '';

  for Command in FCommands do
    begin
      if (Command = 'PSTONE CTRL ON') or (Command = 'PSTONE CTRL OFF') then
        ExpectedTone := Command;
      if (Copy(Command, 1, 6) = 'PSBAS ') and
         TryStrToInt(Copy(Command, 7, MaxInt), Value) then
        ExpectedBass := Command;
      if (Copy(Command, 1, 6) = 'PSTRE ') and
         TryStrToInt(Copy(Command, 7, MaxInt), Value) then
        ExpectedTreble := Command;
    end;

  try
    try
      Client := THEOSConnection.Create(FHost, FPort);
      for Command in FCommands do
        if (Copy(Command, 1, 2) = 'MV') and
           (Length(Command) in [4, 5]) and
           TryStrToInt(Copy(Command, 3, MaxInt), Value) then
          begin
            if (Length(Command) = 4) then
              ExpectedVolume := Value * 2
            else
              ExpectedVolume := Value div 5;
          end;

      for Command in FCommands do
        begin
          if Terminated then
            Exit;

          // Denon's AVR protocol terminates commands with CR, not CR/LF.
          Client.Send(AnsiString(Command) + #13);
          // Space commands to avoid overrunning the receiver's control interface.
          if (Command = 'PWON') or (Command = 'ZMON') or (Command = 'Z2ON') then
            Sleep(1000)
          else
            Sleep(80);
        end;

        Timer := TStopwatch.StartNew();

      while (not Terminated) and (Timer.ElapsedMilliseconds < 2500) do
        begin
          Line := Client.ReadLine(#13,
                                  250);

          if (Trim(Line) <> '') then
            FLines.Add(Trim(Line));

          if FStopOnToneReply then
            begin
              if (Line = 'PSTONE CTRL ON') or (Line = 'PSTONE CTRL OFF') then
                ToneReceived := (ExpectedTone = '') or (Line = ExpectedTone);

              if (Copy(Line, 1,
                             6) = 'PSBAS ') and
                 TryStrToInt(Copy(Line,
                                  7,
                                  MaxInt),
                             Value) and
                            (Value >= 44) and
                            (Value <= 56) then
                BassReceived := (ExpectedBass = '') or (Line = ExpectedBass);

              if (Copy(Line,
                       1,
                       6) = 'PSTRE ') and
                 TryStrToInt(Copy(Line,
                                  7,
                                  MaxInt),
                             Value) and
                             (Value >= 44) and
                             (Value <= 56) then
                TrebleReceived := (ExpectedTreble = '') or (Line = ExpectedTreble);

              if (Copy(Line,
                       1,
                       2) = 'MS') and (Length(Line) > 2) then
                ModeReceived := True;

              if (Line = 'PSDYNEQ ON') or (Line = 'PSDYNEQ OFF') then
                DynamicEqReceived := True;
            end;

          if FStopOnZoneReply then
            begin
              if (Line = 'ZMON') or (Line = 'ZMOFF') then
                MainZoneReceived := True;

              if (Line = 'Z2ON') or (Line = 'Z2OFF') then
                Zone2Received := True;
            end;

          if FStopOnChannelReply then
            begin
              if (Copy(Line,
                       1,
                       5) = 'CVFL ') and
                 TryStrToInt(Copy(Line,
                                  6,
                                  MaxInt),
                             Value) then
                LeftReceived := True;

              if (Copy(Line,
                       1,
                       5) = 'CVFR ') and
                 TryStrToInt(Copy(Line,
                                  6,
                                  MaxInt),
                             Value) then
                RightReceived := True;

              if (Line = 'CVEND') and LeftReceived and RightReceived then
                begin
                  ChannelReceived := True;
                end;
            end;

          if FStopOnVolumeReply and
             (Copy(Line,
                   1,
                   2) = 'MV') and
             (Length(Line) in [4, 5]) and
             TryStrToInt(Copy(Line,
                              3,
                              MaxInt),
                         Value) then
            begin
              if (Length(Line) = 4) then
                ReplyVolume := Value * 2
              else
                ReplyVolume := Value div 5;

            end;

          if FStopOnVolumeReply and (Copy(Line,
                                          1,
                                          6) = 'MVMAX ') and
             TryStrToInt(Copy(Line,
                              7,
                              MaxInt), Value) then
            begin
              if (Length(Line) = 8) then
                Value := Value * 2
              else
                if (Length(Line) = 9) and (Value mod 5 = 0) then
                  Value := Value div 5
                else
                  Value := -1;

              if (Value >= 0) and (Value <= 196) then
                begin
                  MaximumVolume := Value;
                  VolumeMaximumReceived := True;
                end;
            end;

          if FStopOnVolumeReply then
            begin
              if (ExpectedVolume > MaximumVolume) then
                ExpectedVolume := MaximumVolume;

              // Confirm the target, including a target capped by the receiver.
              VolumeReceived := (ReplyVolume >= 0) and
                                  ((ExpectedVolume < 0) or (ReplyVolume = ExpectedVolume));
            end;

          if (FStopOnVolumeReply or
              FStopOnChannelReply or
              FStopOnZoneReply or
              FStopOnToneReply) and
              (not FStopOnVolumeReply or VolumeReceived) and
              (not FStopOnVolumeReply or VolumeMaximumReceived or (Line = '')) and
              (not FStopOnChannelReply or ChannelReceived) and
              (not FStopOnZoneReply or (MainZoneReceived and Zone2Received)) and
              (not FStopOnToneReply or (ToneReceived and BassReceived and TrebleReceived and
              ModeReceived and DynamicEqReceived)) then
            Break;
        end;

      if (FLines.Count = 0) then
        FError := 'Connected, but no status reply was received. ' + 'A sent command is not confirmation of a change.';

      if FStopOnVolumeReply and not VolumeReceived and (FError = '') then
        FError := 'Receiver did not confirm a volume value';

      if FStopOnChannelReply and not ChannelReceived and (FError = '') then
        FError := 'Receiver did not confirm both front channel levels';

      if FStopOnZoneReply and not (MainZoneReceived and Zone2Received) and (FError = '') then
        FError := 'Receiver did not confirm both zone power states';

      if FStopOnToneReply and not
        (ToneReceived and
        BassReceived and
        TrebleReceived and
        ModeReceived and
        DynamicEqReceived) and
        (FError = '') then
        FError := 'Receiver did not confirm tone settings. Check the sound mode, Dynamic EQ and audio signal.';

    except
      on E: Exception do
        FError := E.ClassName + ': ' + E.Message;
    end;

  finally
    Client.Free();
  end;
end;

end.
