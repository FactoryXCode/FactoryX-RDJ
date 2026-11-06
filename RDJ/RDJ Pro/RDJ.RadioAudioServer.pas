// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: HEOS Remote.
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: RDJ.RadioAudioServer.pas
// Kind: Pascal Unit
// Release date: 24-01-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Bounded multi-listener AAC radio HTTP server.
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
//         HARMAN International (HEOS_CLI_ProtocolSpecification-Version-1.17)
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
unit RDJ.RadioAudioServer;

interface

uses

  {WinApi}
  WinApi.Windows,
  WinApi.WinSock,
  {System}
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections;

type

  TRdjRadioClient = class
  public

    Socket: TSocket;
    Header: AnsiString;
    Data: TQueue<TBytes>;
    Pending: TBytes;
    Offset: Integer;
    Queued: Integer;
    Streaming: Boolean;
    Closing: Boolean;
    Dead: Boolean;
    Started: UInt64;
    Progress: UInt64;

    constructor Create(ASocket: TSocket);
    destructor Destroy(); override;
  end;

  TRdjRadioAudioServer = class(TThread)
  private

    FListener: TSocket;
    FInitialized: Boolean;
    FAddress: string;
    FPort: Word;
    FLock: TCriticalSection;
    FClients: TObjectList<TRdjRadioClient>;
    FRequests: Integer;
    FLastError: string;

    function CheckSocket(Code: Integer;
                         const Operation: string): Boolean;

    procedure AcceptClient();
    procedure ReadHeader(Client: TRdjRadioClient);
    procedure WriteClient(Client: TRdjRadioClient);

    procedure Respond(Client: TRdjRadioClient;
                      const Status, Extra: string);

  protected

    procedure Execute(); override;

  public

    constructor Create(const Address: string;
                       Port: Word);

    destructor Destroy(); override;

    procedure Push(const Data: TBytes);
    function Url(): string;
    function Requests(): Integer;
    function Listeners(): Integer;
    function LastError(): string;

    property Initialized: Boolean read FInitialized;
  end;

  function GetTickCount64(): UInt64; stdcall;


implementation

uses

  {System}
  System.Math,
  {Application}
  Heos.Sockets;

const

  Kernel32Lib = 'kernel32.dll';

  RadioPath = '/radio/live.aac';
  RadioMaximumClients = 32;
  RadioMaximumQueuedBytes = 128 * 1024;


constructor TRdjRadioClient.Create(ASocket: TSocket);
begin

  inherited Create();

  Socket := ASocket;
  Data := TQueue<TBytes>.Create;
  Started := GetTickCount64();
  Progress := Started;
end;


destructor TRdjRadioClient.Destroy();
begin

  if (Socket <> INVALID_SOCKET) then
    closesocket(Socket);

  Data.Free;

  inherited;
end;


function TRdjRadioAudioServer.CheckSocket(Code: Integer; const Operation: string): Boolean;
begin

  Result := (Code <> SOCKET_ERROR);

  if not Result then
    FLastError := Format('%s failed (Windows socket error %d)',
                         [Operation, WSAGetLastError]);
end;


constructor TRdjRadioAudioServer.Create(const Address: string;
                                        Port: Word);
var
  Addr: TSockAddrIn;
  Host: AnsiString;
  Mode: u_long;
  Size: Integer;
  Exclusive: Integer;

begin

  inherited Create(True);

  FreeOnTerminate := False;
  FListener := INVALID_SOCKET;
  FLock := TCriticalSection.Create;
  FClients := TObjectList<TRdjRadioClient>.Create(True);
  FAddress := Address;
  FPort := Port;

  if not IPv4Valid(Address) then
    begin
      FLastError := 'Enter a valid IPv4 bind address, or 0.0.0.0 for all interfaces.';
      Exit;
    end;


  FListener := socket(AF_INET,
                      SOCK_STREAM,
                      IPPROTO_TCP);

  if (FListener = INVALID_SOCKET) then
    if not CheckSocket(SOCKET_ERROR,
                       'Create radio listener') then
      Exit;

  // Do not silently share a fixed radio port with another process.
  Exclusive := 1;

  if not CheckSocket(setsockopt(FListener,
                                SOL_SOCKET,
                                -5,
                                PAnsiChar(@Exclusive),
                                SizeOf(Exclusive)),
                     'Reserve radio port') then
    Exit;

  FillChar(Addr,
           SizeOf(Addr),
           0);

  Host := AnsiString(Address);
  Addr.sin_family := AF_INET;
  Addr.sin_addr.S_addr := inet_addr(PAnsiChar(Host));
  Addr.sin_port := htons(Port);

  if not CheckSocket(bind(FListener,
                          Addr,
                          SizeOf(Addr)),
                     'Bind radio listener') then
    Exit;

  Size := SizeOf(Addr);

  if not CheckSocket(getsockname(FListener,
                                 Addr,
                                 Size),
                     'Read radio port') then
    Exit;

  FPort := ntohs(Addr.sin_port);

  if not CheckSocket(listen(FListener,
                            RadioMaximumClients),
                     'Listen for radio clients') then
    Exit;

  Mode := 1;

  if not CheckSocket(ioctlsocket(FListener,
                                 FIONBIO,
                                 Mode),
                     'Set radio listener nonblocking') then
    Exit;

  FInitialized := True;
end;


destructor TRdjRadioAudioServer.Destroy();
begin

  Terminate;

  if Suspended then
    Start();

  WaitFor();

  if (FListener <> INVALID_SOCKET) then
    closesocket(FListener);

  FClients.Free;
  FLock.Free;

  inherited;
end;


function TRdjRadioAudioServer.Url(): string;
var
  Host: string;

begin

  Host := FAddress;
  if (Host = '0.0.0.0') then
    Host := GetEnvironmentVariable('COMPUTERNAME');

  Result := Format('http://%s:%d%s',
                   [Host, FPort, RadioPath]);
end;


function TRdjRadioAudioServer.Requests(): Integer;
begin

  Result := InterlockedCompareExchange(FRequests,
                                       0,
                                       0);
end;


function TRdjRadioAudioServer.Listeners(): Integer;
var
  Client: TRdjRadioClient;

begin

  Result := 0;
  FLock.Acquire;

  try
    for Client in FClients do
      if Client.Streaming and not Client.Dead then
        Inc(Result);

  finally
    FLock.Release;
  end;
end;


function TRdjRadioAudioServer.LastError(): string;
begin

  FLock.Acquire;

  try
    Result := FLastError;

  finally
    FLock.Release;
  end;
end;


procedure TRdjRadioAudioServer.Push(const Data: TBytes);
var
  Client: TRdjRadioClient;

begin

  if (Length(Data) = 0) then
    Exit;

  FLock.Acquire;

  try
    // Each client starts at a new complete ADTS batch. No listener consumes
    // another listener's data, and no historical radio audio accumulates.
    for Client in FClients do
      if Client.Streaming and not Client.Dead then
        begin
          if (Client.Queued + Length(Data) > RadioMaximumQueuedBytes) then
            begin
              Client.Dead := True;
              Continue;
            end;

          Client.Data.Enqueue(Copy(Data));
          Inc(Client.Queued,
              Length(Data));
        end;

  finally
    FLock.Release;
  end;
end;


procedure TRdjRadioAudioServer.AcceptClient();
var
  Socket: TSocket;
  Mode: u_long;

begin

  Socket := accept(FListener,
                   nil,
                   nil);

  if (Socket = INVALID_SOCKET) then
    begin
      if (WSAGetLastError <> WSAEWOULDBLOCK) then
        FLastError := Format('Radio accept failed (%d).',
                             [WSAGetLastError]);
      Exit;
    end;

  if (FClients.Count >= RadioMaximumClients) then
    begin
      closesocket(Socket);
      Exit;
    end;

  Mode := 1;

  if (ioctlsocket(Socket,
                  FIONBIO,
                  Mode) = SOCKET_ERROR) then
    begin
      closesocket(Socket);
      Exit;
    end;

  FClients.Add(TRdjRadioClient.Create(Socket));
end;


procedure TRdjRadioAudioServer.Respond(Client: TRdjRadioClient;
                                        const Status, Extra: string);
begin

  Client.Pending := TEncoding.ASCII.GetBytes('HTTP/1.1 ' +
                                             Status + #13#10 +
                                             'Connection: close' + #13#10 +
                                             Extra + #13#10);

  Client.Queued := Length(Client.Pending);
  Client.Offset := 0;
  Client.Closing := True;
end;


procedure TRdjRadioAudioServer.ReadHeader(Client: TRdjRadioClient);
var
  Buffer: array[0..2047] of AnsiChar;
  Chunk: AnsiString;
  First: string;
  Method: string;
  Path: string;
  Count: Integer;
  P: Integer;

begin

  Count := recv(Client.Socket,
                Buffer,
                SizeOf(Buffer),
                       0);

  if (Count = SOCKET_ERROR) then
    begin
      if (WSAGetLastError <> WSAEWOULDBLOCK) then
        Client.Dead := True;

      Exit;
    end;

  if (Count = 0) then
    begin
      Client.Dead := True;
      Exit;
    end;

  SetString(Chunk,
            PAnsiChar(@Buffer[0]),
            Count);

  Client.Header := Client.Header + Chunk;

  if (Length(Client.Header) > 8192) then
    begin
      Respond(Client, '431 Request Header Fields Too Large', 'Content-Length: 0' + #13#10);
      Exit;
    end;

  if (Pos(AnsiString(#13#10#13#10),
          Client.Header) = 0) then
    Exit;

  First := string(Copy(Client.Header,
                       1,
                       Pos(AnsiString(#13#10),
                           Client.Header) - 1));
  P := Pos(' ',
           First);

  if (P <= 1) then
    begin
      Respond(Client,
              '400 Bad Request',
              'Content-Length: 0' + #13#10);
      Exit;
    end;

  Method := Copy(First,
                 1,
                 P - 1);

  Delete(First,
         1,
         P);

  P := Pos(' ',
           First);

  if (P <= 1) then
    begin
      Respond(Client,
              '400 Bad Request',
              'Content-Length: 0' + #13#10);
      Exit;
    end;

  Path := Copy(First,
               1,
               P - 1);

  if (Method <> 'GET') and (Method <> 'HEAD') then
    begin
      Respond(Client, '405 Method Not Allowed', 'Allow: GET, HEAD' + #13#10 + 'Content-Length: 0' + #13#10);
      Exit;
    end;

  if (Path <> RadioPath) then
    begin
      Respond(Client, '404 Not Found', 'Content-Length: 0' + #13#10);
      Exit;
    end;

  InterlockedIncrement(FRequests);

  Respond(Client,
          '200 OK',
          'Content-Type: audio/aac' + #13#10 +
          'Cache-Control: no-store' + #13#10 +
          'Accept-Ranges: none' + #13#10 +
          'icy-name: FactoryX Radio' + #13#10 +
          'icy-br: 192' + #13#10);

  Client.Streaming := Method = 'GET';
  Client.Closing := not Client.Streaming;
  Client.Header := '';
end;


procedure TRdjRadioAudioServer.WriteClient(Client: TRdjRadioClient);
var
  Count: Integer;

begin

  if (Length(Client.Pending) = 0) then
    begin
      if (Client.Data.Count = 0) then
        begin
          if Client.Closing then
            Client.Dead := True;

          Exit;
        end;

      Client.Pending := Client.Data.Dequeue;
      Client.Offset := 0;
    end;

  Count := WinApi.WinSock.send(Client.Socket,
                               Client.Pending[Client.Offset],
                               Min(16384,
                                   Length(Client.Pending) - Client.Offset),
                               0);

  if (Count = SOCKET_ERROR) then
    begin
      if (WSAGetLastError <> WSAEWOULDBLOCK) then
        Client.Dead := True;

      Exit;
    end;

  if (Count = 0) then
    begin
      Client.Dead := True;
      Exit;
    end;

  Inc(Client.Offset,
    Count);

  Dec(Client.Queued,
      Count);

  Client.Progress := GetTickCount64();

  if (Client.Offset = Length(Client.Pending)) then
    Client.Pending := nil;
end;


procedure TRdjRadioAudioServer.Execute();
var
  I: Integer;
  Client: TRdjRadioClient;
  Stamp: UInt64;
  Probe: Byte;
  Count: Integer;

begin

  if not FInitialized then
    Exit;

  while not Terminated do
    begin
      FLock.Acquire;
      try
        try
          AcceptClient();
          Stamp := GetTickCount64();

          for I := FClients.Count - 1 downto 0 do
            begin
              Client := FClients[I];

              if not Client.Streaming and not Client.Closing then
                begin
                  ReadHeader(Client);
                  if (Stamp - Client.Started > 5000) and not Client.Streaming then
                    Client.Dead := True;
                end;

              if not Client.Dead and (Client.Streaming or Client.Closing) then
                begin

                  // Detect a disconnected listener even while the mixer is idle.
                  Count := recv(Client.Socket,
                                Probe,
                                1,
                                MSG_PEEK);

                  if (Count = 0) or ((Count = SOCKET_ERROR) and (WSAGetLastError <> WSAEWOULDBLOCK)) then
                    Client.Dead := True;

                  if not Client.Dead then
                    WriteClient(Client);

                  if (Client.Queued > 0) and (Stamp - Client.Progress > 10000) then
                    Client.Dead := True;

                end;

              if Client.Dead then
                FClients.Delete(I);
            end;

        except
          on E: Exception do
            begin
              FLastError := E.Message;
              Exit;
            end;
        end;

      finally
        FLock.Release;
      end;

      Sleep(5);
    end;
end;

// External

{$WARN SYMBOL_PLATFORM OFF}

function GetTickCount64; external Kernel32Lib name 'GetTickCount64' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};

{$WARN SYMBOL_PLATFORM ON}

end.
