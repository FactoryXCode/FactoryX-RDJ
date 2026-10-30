// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: HEOS Remote.
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: RDJ.HeosAudioServer.pas
// Kind: Pascal Unit
// Release date: 24-01-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Audio server.
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
unit RDJ.HeosAudioServer;

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

  THEOSAudioServer = class(TThread)
  private
    FListener: TSocket;
    FPath: string;
    FAddress: string;
    FPort: Word;
    FLock: TCriticalSection;
    FData: TQueue<TBytes>;
    FQueuedBytes: Integer;
    FRequests: Integer;
    FLastError: string;

    procedure Serve(Client: TSocket);
    function Pop(out Data: TBytes): Boolean;
    procedure SetError(const Text: string);

    function ReadClientHeader(Client: TSocket;
                              out Header: string): Boolean;

    function SendClient(Client: TSocket;
                        Data: Pointer;
                        Count: Integer): Boolean;

  protected
    procedure Execute(); override;

  public

    constructor Create(const LocalAddress: string;
                       Port: Word);

    destructor Destroy(); override;

    procedure Push(const Data: TBytes);
    function Url(): string;
    function Requests(): Integer;
    function LastError(): string;
  end;



implementation

uses

  {System}
  System.Diagnostics,
  {Application}
  Heos.Sockets;

constructor THEOSAudioServer.Create(const LocalAddress: string;
                                    Port: Word);
var
  Addr: TSockAddrIn;
  G: TGUID;
  Token: AnsiString;
  Host: AnsiString;
  Reuse: Integer;
  AddrSize: Integer;

begin

  inherited Create(True);

  FreeOnTerminate := False;
  FListener := INVALID_SOCKET;
  FLock := TCriticalSection.Create;
  FData := TQueue<TBytes>.Create;
  FAddress := LocalAddress;
  FPort := Port;
  CreateGUID(G);
  Token := AnsiString(StringReplace(StringReplace(GUIDToString(G),
                                                  '{',
                                                  '',
                                                  []),
                                    '}',
                                    '',
                                    []));

  FPath := '/' + string(Token) + '/master.aac';

  FListener := socket(AF_INET,
                      SOCK_STREAM,
                      IPPROTO_TCP);

  if (FListener = INVALID_SOCKET) then
    SocketCheck(SOCKET_ERROR,
                'Create audio server');

  Reuse := 1;
  SocketCheck(setsockopt(FListener,
                         SOL_SOCKET,
                         SO_REUSEADDR,
                         PAnsiChar(@Reuse),
                         SizeOf(Reuse)),
                         'Set audio server socket reuse');

  FillChar(Addr,
           SizeOf(Addr),
           0);

  Host := AnsiString(LocalAddress);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Port);
  Addr.sin_addr.S_addr := inet_addr(PAnsiChar(Host));

  SocketCheck(bind(FListener,
                   Addr,
                   SizeOf(Addr)),
                   'Bind audio server');

  // Port zero lets Windows allocate an available listening port.
  AddrSize := SizeOf(Addr);
  SocketCheck(getsockname(FListener, Addr, AddrSize),
                'Read audio server port');
  FPort := ntohs(Addr.sin_port);

  SocketCheck(listen(FListener,
                     4),
              'Listen for receiver');
end;


destructor THEOSAudioServer.Destroy();
begin

  Terminate();

  // Nonblocking client I/O checks Terminated at least every 100 ms.
  if Suspended then
    Start();

  WaitFor();

  if (FListener <> INVALID_SOCKET) then
    closesocket(FListener);

  FData.Free;
  FLock.Free;

  inherited;
end;


function THEOSAudioServer.Url(): string;
begin

  Result := Format('http://%s:%d%s',
                   [FAddress, FPort, FPath]);
end;


function THEOSAudioServer.Requests: Integer;
begin

  Result := InterlockedCompareExchange(FRequests,
                                       0,
                                       0);
end;


procedure THEOSAudioServer.SetError(const Text: string);
begin

  FLock.Acquire;
  try
    FLastError := Text;
  finally
    FLock.Release;
  end;
end;


function THEOSAudioServer.LastError(): string;
begin

  FLock.Acquire;
  try
    Result := FLastError;
  finally
    FLock.Release;
  end;
end;


function THEOSAudioServer.ReadClientHeader(Client: TSocket;
                                           out Header: string): Boolean;
var
  Buffer: array[0..4095] of AnsiChar;
  Data: AnsiString;
  Chunk: AnsiString;
  Fds: TFDSet;
  Timeout: TTimeVal;
  Timer: TStopwatch;
  Code: Integer;
  Error: Integer;

begin

  Result := False;
  Header := '';
  Data := '';
  Timer := TStopwatch.StartNew();

  while not Terminated do
    begin
      if (Timer.ElapsedMilliseconds >= 3000) then
        begin
          SetError('HTTP request header timed out');
          Exit;
        end;

      Fds.fd_count := 1;
      Fds.fd_array[0] := Client;
      Timeout.tv_sec := 0;
      Timeout.tv_usec := 100000;

      Code := select(0,
                     @Fds,
                     nil,
                     nil,
                     @Timeout);

      if (Code = 0) then
        Continue;

      if (Code = SOCKET_ERROR) then
        begin
          SetError(Format('HTTP read wait failed (Windows socket error %d)',
                           [WSAGetLastError]));
          Exit;
        end;

      Code := recv(Client,
                   Buffer,
                   SizeOf(Buffer),
                   0);

      if (Code = 0) then
        Exit;

      if (Code = SOCKET_ERROR) then
        begin
          Error := WSAGetLastError;

          if (Error = WSAEWOULDBLOCK) then
            Continue;

          SetError(Format('HTTP client read failed (Windows socket error %d)',
                          [Error]));
          Exit;
        end;

      SetString(Chunk,
                PAnsiChar(@Buffer[0]),
                Code);

      Data := Data + Chunk;

      if (Length(Data) > 16384) then
        begin
          SetError('HTTP request header too long');
          Exit;
        end;

      if (Pos(AnsiString(#13#10#13#10),
                         Data) > 0) then
        begin
          Header := string(Data);
          Result := True;
          Exit;
        end;
    end;
end;


function THEOSAudioServer.SendClient(Client: TSocket;
                                     Data: Pointer;
                                     Count: Integer): Boolean;
var
  P: PByte;
  Fds: TFDSet;
  Timeout: TTimeVal;
  Timer: TStopwatch;
  Sent: Integer;
  Code: Integer;
  Error: Integer;

begin

  Result := False;
  P := Data;
  Timer := TStopwatch.StartNew();

  while (Count > 0) and not Terminated do
    begin

      // File players can stop reading while their playback buffer is full.
      // Bound inactivity, rather than imposing a short blocking-send timeout.
      if (Timer.ElapsedMilliseconds >= 120000) then
        begin
          SetError('HTTP receiver stopped reading for 120 seconds; connection closed');
          Exit;
        end;

      Fds.fd_count := 1;
      Fds.fd_array[0] := Client;
      Timeout.tv_sec := 0;
      Timeout.tv_usec := 100000;

      Code := select(0,
                     nil,
                     @Fds,
                     nil,
                     @Timeout);

      if (Code = 0) then
        Continue;

      if (Code = SOCKET_ERROR) then
        begin
          SetError(Format('HTTP send wait failed (Windows socket error %d)',
                           [WSAGetLastError]));
          Exit;
        end;

      Sent := WinApi.WinSock.send(Client,
                                  P^,
                                  Count,
                                  0);

      if (Sent = SOCKET_ERROR) then
        begin
          Error := WSAGetLastError;
          if (Error = WSAEWOULDBLOCK) then
            Continue;

          SetError(Format('HTTP receiver connection ended (Windows socket error %d)',
                          [Error]));
          Exit;
        end;

      if (Sent = 0) then
        begin
          SetError('HTTP receiver closed the connection');
          Exit;
        end;

      Inc(P,
          Sent);

      Dec(Count,
          Sent);

      Timer := TStopwatch.StartNew();
    end;
  Result := (Count = 0) and not Terminated;
end;


procedure THEOSAudioServer.Push(const Data: TBytes);
var
  Old: TBytes;

begin

  if (Length(Data) = 0) then
    Exit;

  FLock.Acquire;

  try
    FData.Enqueue(Copy(Data));
    Inc(FQueuedBytes,
        Length(Data));

    // Bound memory when the receiver disconnects. Drop whole ADTS batches.
    while FQueuedBytes > 256 * 1024 do
      begin
        Old := FData.Dequeue;
        Dec(FQueuedBytes,
            Length(Old));
      end;

  finally
    FLock.Release;
  end;
end;


function THEOSAudioServer.Pop(out Data: TBytes): Boolean;
begin

  FLock.Acquire;

  try
    Result := FData.Count > 0;

    if Result then
      begin
        Data := FData.Dequeue;
        Dec(FQueuedBytes,
            Length(Data));
      end;

  finally
    FLock.Release;
  end;
end;


procedure THEOSAudioServer.Execute();
var
  Client: TSocket;
  Mode: u_long;

begin

  while not Terminated do
    begin
      try
        if not SocketReady(FListener,
                           False,
                           100) then
          Continue;

        Client := accept(FListener,
                         nil,
                         nil);

        if (Client = INVALID_SOCKET) then
          Continue;

        try
          Mode := 1;

          if (ioctlsocket(Client,
                          FIONBIO, Mode) = SOCKET_ERROR) then
            begin
              SetError(Format('Cannot set HTTP client nonblocking mode (Windows socket error %d)',
                              [WSAGetLastError]));
              Continue;
            end;

          SetError('');
          Serve(Client);

        finally
          closesocket(Client);
        end;

    except

      // A failed receiver request must not kill the listener. The next request
      // can reconnect; UI reports the request count and HEOS result separately.
      on E: Exception do
        SetError('Denon audio HTTP: ' + E.Message);
      end;
    end;
end;


procedure THEOSAudioServer.Serve(Client: TSocket);
var
  Header: string;
  First: string;
  Method: string;
  Path: string;
  Lines: TArray<string>;
  P: Integer;
  IsHead: Boolean;
  Data: TBytes;

  // Helper
  function Respond(const Status,
                    Extra: string): Boolean;
  var
    Response: AnsiString;

  begin

    Response := AnsiString('HTTP/1.1 ' + Status + #13#10 + 'Connection: close' + #13#10 + Extra + #13#10);
    Result := SendClient(Client,
                         PAnsiChar(Response),
                         Length(Response));
  end;

begin

  if not ReadClientHeader(Client,
                          Header) then
    Exit;

  Lines := Header.Split([#10]);
  First := Trim(Lines[0]);

  P := Pos(' ',
           First);

  Method := Copy(First,
                 1,
                 P - 1);

  Delete(First,
         1,
         P);

  P := Pos(' ',
           First);
  Path := Copy(First,
               1,
               P - 1);

  IsHead := Method = 'HEAD';

  if (Method <> 'GET') and not IsHead then
    begin
      Respond('405 Method Not Allowed',
              'Content-Length: 0' + #13#10);
      Exit;
    end;

  if (Path <> FPath) then
    begin
      Respond('404 Not Found',
              'Content-Length: 0' + #13#10);
      Exit;
    end;

  InterlockedIncrement(FRequests);

  if not Respond('200 OK',
                   'Content-Type: audio/aac' + #13#10 + 'Cache-Control: no-store' + #13#10 + 'Accept-Ranges: none' + #13#10) then
    Exit;

  if IsHead then
    Exit;

  FLock.Acquire;

  try
    FData.Clear;
    FQueuedBytes := 0;

  finally
    FLock.Release;
  end;

  // A continuous close-delimited stream avoids chunked-transfer assumptions.
  while not Terminated do
    begin
      if Pop(Data) then
        begin
          if not SendClient(Client,
                            @Data[0],
                            Length(Data)) then
            Exit;
        end
      else
        Sleep(10);
    end;

end;

end.
