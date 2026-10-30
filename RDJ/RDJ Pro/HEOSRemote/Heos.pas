// FactoryX
//
// Copyright: (c) FactoryX. All rights reserved.
//
// Project: HEOS Remote.
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module:  Heos.pas
// Kind: Pascal / Delphi unit
// Release date: 13-08-2025
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Heos main.
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
unit Heos;

interface

uses

  {System}
  System.Classes,
  System.SysUtils,
  System.JSON,
  {Application}
  HEOSSockets;

type

  THEOSAction = (haPlayUrl,
                 haStop);

  THEOSRequest = class(TThread)
  private
    FHost: string;
    FUrl: string;
    FError: string;
    FSummary: string;
    FAction: THeosAction;
    FPort: Word;

    function Exchange(Client: THEOSConnection;
                      const Command,
                      Expected: string): TJSONObject;

  protected
    procedure Execute(); override;

  public

    constructor Create(const Host: string;
                       Action: THEOSAction;
                       const Url: string = '';
                       Port: Word = 1255);

    property ErrorText: string read FError;
    property Summary: string read FSummary;
  end;


implementation

uses

  System.Diagnostics;

function JsonText(Obj: TJSONObject;
                  const Name: string): string;
var
  Value: TJSONValue;

begin

  Result := '';

  if (Obj = nil) then
    Exit;

  Value := Obj.GetValue(Name);
  if (Value <> nil) then
    Result := Value.Value;
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


function THeosRequest.Exchange(Client: THEOSConnection;
                               const Command: string;
                               const Expected: string): TJSONObject;
var
  Line: string;
  Value: TJSONValue;
  Header: TJSONObject;
  Timer: TStopwatch;

begin

  Client.Send(UTF8Encode('heos://' + Command + #13#10));
  Timer := TStopwatch.StartNew();

  while (not Terminated) and (Timer.ElapsedMilliseconds < 6000) do
  begin
    Line := Trim(Client.ReadLine(#10, 500));

    if (Line = '') then
      Continue;

    Value := TJSONObject.ParseJSONValue(Line);
    try
      if not (Value is TJSONObject) then
        Continue;

      Header := TJSONObject(TJSONObject(Value).GetValue('heos'));

      if (JsonText(Header,
                   'command') <> Expected) then
        Continue;

      if (JsonText(Header,
                   'result') <> 'success') then
        raise Exception.Create('HEOS rejected request: ' + JsonText(Header, 'message'));

      Result := TJSONObject(Value);
      Value := nil;
      Exit;

    finally
      Value.Free;
    end;
  end;

  raise Exception.Create('HEOS response timed out');
end;


procedure THeosRequest.Execute();
var
  Client: THEOSConnection;
  Reply: TJSONObject;
  Players: TJSONArray;
  Player: TJSONObject;
  I: Integer;
  Pid: string;
  Command: string;

begin

  Client := nil;

  try
    try
      Client := THEOSConnection.Create(FHost,
                                        FPort);

      Reply := Exchange(Client,
                        'player/get_players',
                        'player/get_players');

      try
        Players := TJSONArray(Reply.GetValue('payload'));

        if (Players = nil) then
          raise Exception.Create('No HEOS players returned');

        Pid := '';

        for I := 0 to Players.Count - 1 do
          begin
            Player := TJSONObject(Players.Items[I]);

            if (JsonText(Player,
                         'ip') = FHost) then
              Pid := JsonText(Player, 'pid');
          end;

        if (Pid = '') and (Players.Count = 1) then
          Pid := JsonText(TJSONObject(Players.Items[0]),
                                      'pid');

        if (Pid = '') then
          raise Exception.Create('Could not identify this receiver in HEOS');

      finally
        Reply.Free;
      end;

      if Terminated then
        Exit;

      if (FAction = haPlayUrl) then
        begin
          Command := 'browse/play_stream?pid=' + Pid + '&url=' + FUrl;
          Reply := Exchange(Client, Command, 'browse/play_stream');
          Reply.Free;
          FSummary := 'HEOS accepted the stream URL. Playback may take a few seconds.';
        end
      else
        begin
          Reply := Exchange(Client,
                            'player/set_play_state?pid=' + Pid + '&state=stop',
                            'player/set_play_state');
          Reply.Free;
          FSummary := 'HEOS accepted the end of the Masterdeck stream.';
        end;

    except on E: Exception do
      FError := E.Message;
    end;

  finally
    Client.Free;
  end;
end;

end.
