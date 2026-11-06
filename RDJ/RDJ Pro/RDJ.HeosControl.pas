// FactoryX
//
// Copyright: (c) FactoryX. All rights reserved.
//
// Project: HEOS Remote.
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: RDJ.HeosControl.pas
// Kind: Pascal / Delphi unit
// Release date: 13-08-2025
// Language: ENU
//
// Revision Version: 4.0.0
// Description: RDJ request lifecycle adapters for the shared HEOS/AVR API.
//
//
// Organisation: FactoryX
// Initiator(s): Tony (maXcomX), Peter (OzShips)
// Contributor(s): Carmen (carmenh), Tony Kalf (maXcomX)
//
//------------------------------------------------------------------------------
// CHANGE LOG
// Date       Person              Reason
// ---------- ------------------- ----------------------------------------------
// 24/08/2026 All                 Moby release  SDK 10.0.28000.2705  (Windows 11)
//------------------------------------------------------------------------------
//
// Remarks: -
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
//==============================================================================
// Source: -
//
// Copyright (c) FactoryX. All rights reserved.
//==============================================================================
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
unit RDJ.HeosControl;

interface

uses
  System.Classes,
  System.SysUtils,
  Heos.Cli,
  Heos.Discovery,
  Avr.Client;

type
  TRdjHeosDevice = record
    Address: string;
    Name: string;
    Model: string;
    AvrAvailable: Boolean;
  end;

  TRdjHeosDiscovery = class(TThread)
  private
    FDevices: TArray<TRdjHeosDevice>;
    FError: string;
  protected
    procedure Execute(); override;
  public
    constructor Create();
    property Devices: TArray<TRdjHeosDevice> read FDevices;
    property ErrorText: string read FError;
  end;

  THeosAction = (haPlayUrl, haStop);

  // RDJ lifecycle adapters; protocol, matching and I/O belong to the shared API.
  THeosRequest = class(TThread)
  private
    FHost: string;
    FUrl: string;
    FPort: Word;
    FAction: THeosAction;
    FError: string;
    FSummary: string;
    function Exchange(Client: THeosClient;
                       const Command: THeosCommand): THeosMessage;
  protected
    procedure Execute(); override;
  public
    constructor Create(const Host: string;
                         Action: THeosAction;
                         const Url: string = '';
                         Port: Word = 1255);
    property ErrorText: string read FError;
    property Summary: string read FSummary;
  end;

  TDenonRequest = class(TThread)
  private
    FHost: string;
    FPort: Word;
    FCommands: TStringList;
    FLines: TStringList;
    FError: string;
    function Exchange(Client: TAvrClient;
                       RequestId: UInt64): Boolean;
  protected
    procedure Execute(); override;
  public
    constructor Create(const Host: string;
                         const Commands: array of string;
                         Port: Word = 23);
    destructor Destroy(); override;
    property Lines: TStringList read FLines;
    property ErrorText: string read FError;
  end;

implementation

uses
  System.JSON,
  System.Diagnostics,
  Heos.Commands,
  Heos.Sockets,
  Avr.Commands;

constructor TRdjHeosDiscovery.Create();
begin

  inherited Create(True);
  FreeOnTerminate := False;
end;


procedure TRdjHeosDiscovery.Execute();
var
  Discovery: THEOSDiscovery;
  Devices: TArray<THEOSDevice>;
  I: Integer;
  ErrorText: string;

begin

  Discovery := THEOSDiscovery.Create();
  try
    Discovery.Start();
    while not Terminated and not Discovery.Finished do
      Sleep(10);
    if Terminated then
      Discovery.Terminate;
    Discovery.WaitFor();
    if Terminated then
      Exit;

    FError := Discovery.ErrorText;
    Devices := Discovery.Devices;
    SetLength(FDevices, Length(Devices));
    for I := 0 to High(Devices) do
      begin
        if Terminated then
          Exit;
        FDevices[I].Address := Devices[I].Address;
        FDevices[I].Name := Devices[I].Name;
        FDevices[I].Model := Devices[I].Model;
        // RDJ's receiver controls also require the separate AVR endpoint.
        FDevices[I].AvrAvailable := ProbeReceiver(Devices[I].Address,
                                                  23,
                                                  800,
                                                  ErrorText);
      end;
  finally
    Discovery.Free();
  end;
end;

constructor THeosRequest.Create(const Host: string;
                                  Action: THeosAction;
                                  const Url: string;
                                  Port: Word);
begin

  inherited Create(True);
  FreeOnTerminate := False;
  FHost := Host;
  FAction := Action;
  FUrl := Url;
  FPort := Port;
end;


function THeosRequest.Exchange(Client: THeosClient;
                                 const Command: THeosCommand): THeosMessage;
var
  Id: UInt64;
  Message: THeosMessage;
  Timer: TStopwatch;

begin

  Result := nil;
  Id := Client.Enqueue(Command);
  Timer := TStopwatch.StartNew();
  while not Terminated and (Timer.ElapsedMilliseconds < 10000) do
    begin
      if not Client.TakeMessage(Message) then
        begin
          Sleep(10);
          Continue;
        end;

      if (Message.RequestId = Id) and (Message.Kind in [hmReply, hmError]) then
        begin
          if Message.Success then
            Exit(Message);

          FError := Message.ErrorText;
          Message.Free();
          Exit;
        end;

      Message.Free();
    end;

  if Terminated then
    FError := 'HEOS request cancelled.'
  else
    FError := 'HEOS request timed out.';
end;


procedure THeosRequest.Execute();
var
  Client: THeosClient;
  Reply: THeosMessage;
  Players: TJSONArray;
  Player: TJSONValue;
  Address: TJSONValue;
  Id: TJSONValue;
  PlayerId: Int64;
  Candidate: Int64;
  Command: THeosCommand;

begin

  Client := THeosClient.Create(FHost, FPort);
  try
    Reply := Exchange(Client, THeosCommands.GetPlayers());
    if not Assigned(Reply) then
      Exit;

    PlayerId := 0;
    try
      if not (Reply.Payload is TJSONArray) then
        begin
          FError := 'No HEOS players returned.';
          Exit;
        end;

      Players := TJSONArray(Reply.Payload);
      for Player in Players do
        if Player is TJSONObject then
          begin
            Address := TJSONObject(Player).GetValue('ip');
            Id := TJSONObject(Player).GetValue('pid');
            if Assigned(Id) and TryStrToInt64(Id.Value, Candidate) and
               ((Assigned(Address) and (Address.Value = FHost)) or (Players.Count = 1)) then
              PlayerId := Candidate;
          end;
    finally
      Reply.Free();
    end;

    if PlayerId = 0 then
      begin
        FError := 'Could not identify this receiver in HEOS.';
        Exit;
      end;

    if Terminated then
      Exit;

    if FAction = haPlayUrl then
      Command := THeosCommands.PlayUrl(PlayerId, FUrl)
    else
      Command := THeosCommands.SetPlayState(PlayerId, hpsStop);

    Reply := Exchange(Client, Command);
    if not Assigned(Reply) then
      Exit;
    Reply.Free();

    if FAction = haPlayUrl then
      FSummary := 'HEOS accepted the stream URL. Playback may take a few seconds.'
    else
      FSummary := 'HEOS accepted the end of the Masterdeck stream.';
  finally
    Client.Free();
  end;
end;


constructor TDenonRequest.Create(const Host: string;
                                   const Commands: array of string;
                                   Port: Word);
var
  Command: string;

begin

  inherited Create(True);
  FreeOnTerminate := False;
  FHost := Host;
  FPort := Port;
  FCommands := TStringList.Create();
  FLines := TStringList.Create();
  for Command in Commands do
    FCommands.Add(Command);
end;


destructor TDenonRequest.Destroy();
begin

  FCommands.Free();
  FLines.Free();
  inherited;
end;


function TDenonRequest.Exchange(Client: TAvrClient;
                                  RequestId: UInt64): Boolean;
var
  Message: TAvrMessage;
  Timer: TStopwatch;

begin

  Result := False;
  Timer := TStopwatch.StartNew();
  while not Terminated and (Timer.ElapsedMilliseconds < 10000) do
    begin
      if not Client.TakeMessage(Message) then
        begin
          Sleep(10);
          Continue;
        end;

      try
        if Message.Value.RawText <> '' then
          FLines.Add(Message.Value.RawText);

        if Message.RequestId = RequestId then
          case Message.Kind of
            amReply: Exit(True);
            amError: begin
                       FError := Message.ErrorText;
                       Exit;
                     end;
          end;
      finally
        Message.Free();
      end;
    end;

  if Terminated then
    FError := 'AVR request cancelled.'
  else
    FError := 'AVR request timed out.';
end;


function ReceiverCommand(const Text: string): TAvrCommand;
var
  Value: TAvrValue;

begin

  // Translate the form's existing commands using the API's builders and parser.
  if Text = 'PW?' then
    Exit(TAvrCommands.GetPower());
  if Text = 'ZM?' then
    Exit(TAvrCommands.GetMainZonePower());
  if Text = 'Z2?' then
    Exit(TAvrCommands.GetZone2Power());
  if Text = 'MV?' then
    Exit(TAvrCommands.GetVolume());
  if Text = 'MU?' then
    Exit(TAvrCommands.GetMute());
  if Text = 'SI?' then
    Exit(TAvrCommands.GetInput());
  if Text = 'MS?' then
    Exit(TAvrCommands.GetSurroundMode());
  if Text = 'PSDYNEQ ?' then
    Exit(TAvrCommands.GetDynamicEq());
  if Text = 'PSTONE CTRL ?' then
    Exit(TAvrCommands.GetToneControl());
  if Text = 'PSBAS ?' then
    Exit(TAvrCommands.GetBass());
  if Text = 'PSTRE ?' then
    Exit(TAvrCommands.GetTreble());
  if Text = 'CV?' then
    Exit(TAvrCommand.Raw(Text, 'CVEND'));

  Value := ParseAvrValue(Text);
  case Value.Kind of
    avPower:
      Exit(TAvrCommands.SetPower(Value.Enabled));
    avMainZonePower:
      Exit(TAvrCommands.SetMainZonePower(Value.Enabled));
    avZone2Power:
      Exit(TAvrCommands.SetZone2Power(Value.Enabled));
    avVolume:
      Exit(TAvrCommands.SetVolume(Value.Number));
    avMute:
      Exit(TAvrCommands.SetMute(Value.Enabled));
    avInput:
      Exit(TAvrCommands.SetInput(Value.Value));
    avFrontLeft:
      Exit(TAvrCommands.SetFrontLeft(Value.Number));
    avFrontRight:
      Exit(TAvrCommands.SetFrontRight(Value.Number));
    avToneControl:
      Exit(TAvrCommands.SetToneControl(Value.Enabled));
    avBass:
      Exit(TAvrCommands.SetBass(Round(Value.Number)));
    avTreble:
      Exit(TAvrCommands.SetTreble(Round(Value.Number)));
    avSurroundMode:
      Exit(TAvrCommands.SetSurroundMode(Value.Value));
    avDynamicEq:
      Exit(TAvrCommands.SetDynamicEq(Value.Enabled));
  end;

  Result := TAvrCommand.Raw(Text, Copy(Text, 1, 2));
end;


procedure TDenonRequest.Execute();
var
  Client: TAvrClient;
  Command: string;

begin

  Client := TAvrClient.Create(FHost, FPort);
  try
    // Each command is confirmed by the API; writes are never replayed here.
    for Command in FCommands do
      begin
        if Terminated then
          Exit;
        if not Exchange(Client, Client.Enqueue(ReceiverCommand(Command))) then
          Exit;
      end;
  finally
    Client.Free();
  end;
end;

end.
