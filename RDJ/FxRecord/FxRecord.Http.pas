// FactoryX
//
// Copyright (c) FactoryX, Netherlands/Australia/Germany. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: FxRecord.Http.pas
// Kind: Pascal Unit
// Release date: 10-08-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Http client.
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
unit FxRecord.Http;

interface

uses

  {WinApi}
  WinApi.Windows,
  {System}
  System.SysUtils,
  System.Classes;

  function FxResolveHttpUrl(const ABase: string;
                            const AReference: string): string;

type
  TFxHttpClient = class
  private
    FSession: Pointer;

  public
    constructor Create();
    destructor Destroy(); override;

    function Get(const AUrl: string; AMaxBytes: Integer; out AFinalUrl: string): TBytes;
  end;

  function GetTickCount64(): UInt64; stdcall;

  function UrlCombineW(Base,
                       Relative,
                       Combined: PWideChar;
                       var Count: DWORD;
                       Flags: DWORD): HRESULT; stdcall;

  function WinHttpOpen(Agent: PWideChar;
                       Access: DWORD;
                       Proxy: PWideChar;
                       Bypass: PWideChar;
                       Flags: DWORD): Pointer; stdcall;

  function WinHttpConnect(Session: Pointer;
                          Host: PWideChar;
                          Port: Word;
                          Reserved: DWORD): Pointer; stdcall;

  function WinHttpOpenRequest(Connection: Pointer;
                              Verb: PWideChar;
                              Path: PWideChar;
                              Version: PWideChar;
                              Referrer: PWideChar;
                              Accept: Pointer;
                              Flags: DWORD): Pointer; stdcall;

  function WinHttpSendRequest(Request: Pointer;
                              Headers: PWideChar;
                              HeaderLength: DWORD;
                              Data: Pointer;
                              DataLength,
                              Total: DWORD;
                              Context: NativeUInt): BOOL; stdcall;

  function WinHttpReceiveResponse(Request: Pointer;
                                  Reserved: Pointer): BOOL; stdcall;

  function WinHttpQueryHeaders(Request: Pointer;
                               Info: DWORD;
                               Name: PWideChar;
                               Buffer: Pointer;
                               var Size: DWORD;
                               var Index: DWORD): BOOL; stdcall;

  function WinHttpQueryOption(Request: Pointer;
                              Option: DWORD;
                              Buffer: Pointer;
                              var Size: DWORD): BOOL; stdcall;

  function WinHttpReadData(Request: Pointer;
                           Buffer: Pointer;
                           Size: DWORD;
                           var Read: DWORD): BOOL; stdcall;

  function WinHttpSetTimeouts(Handle: Pointer;
                              Resolve: Integer;
                              Connect: Integer;
                              Send: Integer;
                              Receive: Integer): BOOL; stdcall;

  function WinHttpCloseHandle(Handle: Pointer): BOOL; stdcall;


implementation

const
  Kernel32Lib = 'kernel32.dll';
  ShlwApiLib = 'shlwapi.dll';
  WinHttpLib = 'winhttp.dll';


function FxResolveHttpUrl(const ABase: string;
                          const AReference: string): string;
var
  Buffer: array[0..8191] of WideChar;
  Count: DWORD;
  I: Integer;

begin

  Count := Length(Buffer);

  if UrlCombineW(PWideChar(ABase),
                 PWideChar(AReference),
                 @Buffer[0],
                 Count,
                 0) < 0 then
    raise Exception.Create('Cannot resolve the HTTP media URL.');

  Result := PWideChar(@Buffer[0]);

  if not SameText(Copy(Result,
                       1,
                       7), 'http://') and
     not SameText(Copy(Result,
                       1,
                       8), 'https://') then
    raise Exception.Create('Media URLs must use HTTP or HTTPS.');

  for I := 1 to Length(Result) do
    if (Ord(Result[I]) <= 32) or (Result[I] = '\') then
      raise Exception.Create('Invalid HTTP media URL.');

  I := Pos('#', Result);
  if (I > 0) then
    Delete(Result,
           I,
           MaxInt);
end;


constructor TFxHttpClient.Create();
begin

  inherited;

  FSession := WinHttpOpen('FactoryX FxRecord/4.2 (HLS recorder)', 0, nil, nil, 0);

  if (FSession = nil) then
    RaiseLastOSError;

  if not WinHttpSetTimeouts(FSession,
                            5000,
                            5000,
                            5000,
                            5000) then
    RaiseLastOSError();
end;


destructor TFxHttpClient.Destroy();
begin

  if (FSession <> nil) then
    WinHttpCloseHandle(FSession);

  inherited;
end;


function TFxHttpClient.Get(const AUrl: string;
                           AMaxBytes: Integer;
                           out AFinalUrl: string): TBytes;
var
  Url: string;
  Authority: string;
  Host: string;
  Path: string;
  PortText: string;
  Detail: string;
  Raw: UTF8String;
  P: Integer;
  Q: Integer;
  Port: Integer;

  Connection: Pointer;
  Request: Pointer;

  Secure: Boolean;
  Flags: DWORD;
  Status: DWORD;
  Size: DWORD;
  Index: DWORD;
  Count: DWORD;
  UrlBuffer: array[0..8191] of WideChar;
  Buffer: array[0..32767] of Byte;
  Stream: TMemoryStream;
  Started: UInt64;

begin

  Result := nil;
  Url := FxResolveHttpUrl(AUrl,
                          AUrl);
  AFinalUrl := Url;
  Secure := SameText(Copy(Url,
                          1,
                          8), 'https://');

  P := Pos('://',
           Url) + 3;
  Q := P;

  while (Q <= Length(Url)) and not CharInSet(Url[Q],
                                             ['/',
                                             '?']) do
    Inc(Q);

  Authority := Copy(Url,
                    P,
                    Q - P);

  if (Authority = '') or (Pos('@', Authority) > 0) then
    raise Exception.Create('The HTTP URL requires a host without embedded credentials.');

  Path := Copy(Url,
               Q,
               MaxInt);

  if (Path = '') or (Path[1] = '?') then
    Path := '/' + Path;

  Host := Authority;
  PortText := '';

  if Copy(Host,
          1,
          1) = '[' then
    begin
      P := Pos(']',
               Host);

      if (P < 3) then
        raise Exception.Create('Invalid IPv6 HTTP host.');

      if (Length(Host) > P) then
        begin
          if (Host[P + 1] <> ':') then
            raise Exception.Create('Invalid HTTP port.');

          PortText := Copy(Host,
                           P + 2,
                           MaxInt);
        end;

      Host := Copy(Host,
                   2,
                   P - 2);
    end
  else
    begin
      P := Pos(':',
               Host);

      if (P > 0) then
        begin
          PortText := Copy(Host,
                           P + 1,
                           MaxInt);
          Host := Copy(Host,
                       1,
                       P - 1) end;
    end;

  if Secure then
    Port := 443
  else
    Port := 80;

  if (PortText <> '') then
    if not TryStrToInt(PortText, Port) or (Port < 1) or (Port > 65535) then
      raise Exception.Create('Invalid HTTP port.');

  Connection := WinHttpConnect(FSession,
                               PWideChar(Host),
                               Port,
                               0);

  if (Connection = nil) then
    RaiseLastOSError();

  try
    Flags := 0;

    if Secure then
      Flags := $00800000;

    Request := WinHttpOpenRequest(Connection,
                                  'GET',
                                  PWideChar(Path),
                                  nil,
                                  nil,
                                  nil,
                                  Flags);

    if (Request = nil) then
      RaiseLastOSError();

    try
      if not WinHttpSendRequest(Request,
                                'Cache-Control: no-cache'#13#10'Accept: */*'#13#10'Accept-Encoding: identity'#13#10,
                                DWORD(-1),
                                nil,
                                0,
                                0,
                                0) then
        RaiseLastOSError;

      if not WinHttpReceiveResponse(Request,
                                    nil) then
        RaiseLastOSError();

      Size := SizeOf(UrlBuffer);

      if WinHttpQueryOption(Request,
                            34,
                            @UrlBuffer[0],
                            Size) then
        AFinalUrl := PWideChar(@UrlBuffer[0]);

      Status := 0;
      Size := SizeOf(Status);
      Index := 0;

      if not WinHttpQueryHeaders(Request,
                                 19 or $20000000,
                                 nil,
                                 @Status,
                                 Size,
                                 Index) then
        RaiseLastOSError();

      if (Status <> 200) then
        begin
          Detail := '';

          if WinHttpReadData(Request,
                             @Buffer[0],
                             512,
                             Count) and (Count > 0) then
            begin
              SetString(Raw,
                        PAnsiChar(@Buffer[0]),
                        Count);
              Detail := UTF8ToString(Raw)
            end;

          Detail := StringReplace(StringReplace(Detail,
                                                #13,
                                                ' ',
                                                [rfReplaceAll]),
                                                #10,
                                                ' ',
                                                [rfReplaceAll]);

          raise Exception.CreateFmt('Stream HTTP %d. %s',
                                    [Status, Trim(Detail)]);
        end;

      Stream := TMemoryStream.Create();

      try
        Started := GetTickCount64();

        repeat
          if not WinHttpReadData(Request,
                                 @Buffer[0],
                                 SizeOf(Buffer),
                                 Count) then
            RaiseLastOSError();

          if (Stream.Size + Count > AMaxBytes) or (GetTickCount64 - Started > 20000) then
            raise Exception.Create('HTTP response exceeds the size or time limit.');

          if (Count > 0) then
            Stream.WriteBuffer(Buffer[0],
                               Count);
        until Count = 0; //repeat

        SetLength(Result,
                  Stream.Size);

        if (Length(Result) > 0) then
          Move(Stream.Memory^,
               Result[0],
               Length(Result));

      finally
        Stream.Free();
      end;

    finally
      WinHttpCloseHandle(Request);
    end;

  finally
    WinHttpCloseHandle(Connection);
  end;
end;


// External

{$WARN SYMBOL_PLATFORM OFF}

function GetTickCount64;         external Kernel32Lib name 'GetTickCount64' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function UrlCombineW;            external ShlwApiLib name 'UrlCombineW' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function WinHttpOpen;            external WinHttpLib name 'WinHttpOpen' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function WinHttpConnect;         external WinHttpLib name 'WinHttpConnect' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};

function WinHttpOpenRequest;     external WinHttpLib name 'WinHttpOpenRequest' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function WinHttpSendRequest;     external WinHttpLib name 'WinHttpSendRequest' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function WinHttpReceiveResponse; external WinHttpLib name 'WinHttpReceiveResponse' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};

function WinHttpQueryHeaders;    external WinHttpLib name 'WinHttpQueryHeaders' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function WinHttpQueryOption;     external WinHttpLib name 'WinHttpQueryOption' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function WinHttpReadData;        external WinHttpLib name 'WinHttpReadData' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function WinHttpSetTimeouts;     external WinHttpLib name 'WinHttpSetTimeouts' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};
function WinHttpCloseHandle;     external WinHttpLib name 'WinHttpCloseHandle' {$IF COMPILERVERSION > 20.0} delayed {$ENDIF};

{$WARN SYMBOL_PLATFORM ON}

end.
