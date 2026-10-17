unit FxRecord.Http;

interface

uses Winapi.Windows, System.SysUtils, System.Classes;

function FxResolveHttpUrl(const ABase, AReference: string): string;

type
  TFxHttpClient = class
  private
    FSession: Pointer;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const AUrl: string; AMaxBytes: Integer; out AFinalUrl: string): TBytes;
  end;

implementation

function GetTickCount64: UInt64; stdcall; external 'kernel32.dll';
function UrlCombineW(Base, Relative, Combined: PWideChar; var Count: DWORD; Flags: DWORD): HRESULT; stdcall; external 'shlwapi.dll';
function WinHttpOpen(Agent: PWideChar; Access: DWORD; Proxy, Bypass: PWideChar; Flags: DWORD): Pointer; stdcall; external 'winhttp.dll';
function WinHttpConnect(Session: Pointer; Host: PWideChar; Port: Word; Reserved: DWORD): Pointer; stdcall; external 'winhttp.dll';
function WinHttpOpenRequest(Connection: Pointer; Verb, Path, Version, Referrer: PWideChar; Accept: Pointer; Flags: DWORD): Pointer; stdcall; external 'winhttp.dll';
function WinHttpSendRequest(Request: Pointer; Headers: PWideChar; HeaderLength: DWORD; Data: Pointer; DataLength, Total: DWORD; Context: NativeUInt): BOOL; stdcall; external 'winhttp.dll';
function WinHttpReceiveResponse(Request, Reserved: Pointer): BOOL; stdcall; external 'winhttp.dll';
function WinHttpQueryHeaders(Request: Pointer; Info: DWORD; Name: PWideChar; Buffer: Pointer; var Size, Index: DWORD): BOOL; stdcall; external 'winhttp.dll';
function WinHttpQueryOption(Request: Pointer; Option: DWORD; Buffer: Pointer; var Size: DWORD): BOOL; stdcall; external 'winhttp.dll';
function WinHttpReadData(Request, Buffer: Pointer; Size: DWORD; var Read: DWORD): BOOL; stdcall; external 'winhttp.dll';
function WinHttpSetTimeouts(Handle: Pointer; Resolve, Connect, Send, Receive: Integer): BOOL; stdcall; external 'winhttp.dll';
function WinHttpCloseHandle(Handle: Pointer): BOOL; stdcall; external 'winhttp.dll';

function FxResolveHttpUrl(const ABase, AReference: string): string;
var Buffer: array[0..8191] of WideChar; Count: DWORD; I: Integer;
begin
  Count := Length(Buffer);
  if UrlCombineW(PWideChar(ABase), PWideChar(AReference), @Buffer[0], Count, 0) < 0 then
    raise Exception.Create('Cannot resolve the HTTP media URL.');
  Result := PWideChar(@Buffer[0]);
  if not SameText(Copy(Result, 1, 7), 'http://') and
     not SameText(Copy(Result, 1, 8), 'https://') then
    raise Exception.Create('Media URLs must use HTTP or HTTPS.');
  for I := 1 to Length(Result) do
    if (Ord(Result[I]) <= 32) or (Result[I] = '\') then
      raise Exception.Create('Invalid HTTP media URL.');
  I := Pos('#', Result);
  if I > 0 then Delete(Result, I, MaxInt);
end;

constructor TFxHttpClient.Create;
begin
  inherited;
  FSession := WinHttpOpen('FactoryX FxRecord/4.2 (HLS recorder)', 0, nil, nil, 0);
  if FSession = nil then RaiseLastOSError;
  if not WinHttpSetTimeouts(FSession, 5000, 5000, 5000, 5000) then RaiseLastOSError;
end;

destructor TFxHttpClient.Destroy;
begin
  if FSession <> nil then WinHttpCloseHandle(FSession);
  inherited;
end;

function TFxHttpClient.Get(const AUrl: string; AMaxBytes: Integer; out AFinalUrl: string): TBytes;
var
  Url, Authority, Host, Path, PortText, Detail: string;
  Raw: UTF8String;
  P, Q, Port: Integer;
  Connection, Request: Pointer;
  Secure: Boolean;
  Flags, Status, Size, Index, Count: DWORD;
  UrlBuffer: array[0..8191] of WideChar;
  Buffer: array[0..32767] of Byte;
  Stream: TMemoryStream;
  Started: UInt64;
begin
  Result := nil;
  Url := FxResolveHttpUrl(AUrl, AUrl);
  AFinalUrl := Url;
  Secure := SameText(Copy(Url, 1, 8), 'https://');
  P := Pos('://', Url) + 3; Q := P;
  while (Q <= Length(Url)) and not CharInSet(Url[Q], ['/', '?']) do Inc(Q);
  Authority := Copy(Url, P, Q - P);
  if (Authority = '') or (Pos('@', Authority) > 0) then
    raise Exception.Create('The HTTP URL requires a host without embedded credentials.');
  Path := Copy(Url, Q, MaxInt);
  if (Path = '') or (Path[1] = '?') then Path := '/' + Path;
  Host := Authority; PortText := '';
  if Copy(Host, 1, 1) = '[' then
    begin
      P := Pos(']', Host);
      if P < 3 then raise Exception.Create('Invalid IPv6 HTTP host.');
      if Length(Host) > P then
        begin
          if Host[P + 1] <> ':' then raise Exception.Create('Invalid HTTP port.');
          PortText := Copy(Host, P + 2, MaxInt);
        end;
      Host := Copy(Host, 2, P - 2);
    end
  else
    begin
      P := Pos(':', Host);
      if P > 0 then begin PortText := Copy(Host, P + 1, MaxInt); Host := Copy(Host, 1, P - 1) end;
    end;
  if Secure then Port := 443 else Port := 80;
  if PortText <> '' then
    if not TryStrToInt(PortText, Port) or (Port < 1) or (Port > 65535) then
      raise Exception.Create('Invalid HTTP port.');
  Connection := WinHttpConnect(FSession, PWideChar(Host), Port, 0);
  if Connection = nil then RaiseLastOSError;
  try
    Flags := 0;
    if Secure then Flags := $00800000;
    Request := WinHttpOpenRequest(Connection, 'GET', PWideChar(Path), nil, nil, nil, Flags);
    if Request = nil then RaiseLastOSError;
    try
      if not WinHttpSendRequest(Request, 'Cache-Control: no-cache'#13#10'Accept: */*'#13#10'Accept-Encoding: identity'#13#10,
        DWORD(-1), nil, 0, 0, 0) then RaiseLastOSError;
      if not WinHttpReceiveResponse(Request, nil) then RaiseLastOSError;
      Size := SizeOf(UrlBuffer);
      if WinHttpQueryOption(Request, 34, @UrlBuffer[0], Size) then AFinalUrl := PWideChar(@UrlBuffer[0]);
      Status := 0; Size := SizeOf(Status); Index := 0;
      if not WinHttpQueryHeaders(Request, 19 or $20000000, nil, @Status, Size, Index) then RaiseLastOSError;
      if Status <> 200 then
        begin
          Detail := '';
          if WinHttpReadData(Request, @Buffer[0], 512, Count) and (Count > 0) then
            begin SetString(Raw, PAnsiChar(@Buffer[0]), Count); Detail := UTF8ToString(Raw) end;
          Detail := StringReplace(StringReplace(Detail, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
          raise Exception.CreateFmt('Stream HTTP %d. %s', [Status, Trim(Detail)]);
        end;
      Stream := TMemoryStream.Create;
      try
        Started := GetTickCount64;
        repeat
          if not WinHttpReadData(Request, @Buffer[0], SizeOf(Buffer), Count) then RaiseLastOSError;
          if (Stream.Size + Count > AMaxBytes) or (GetTickCount64 - Started > 20000) then
            raise Exception.Create('HTTP response exceeds the size or time limit.');
          if Count > 0 then Stream.WriteBuffer(Buffer[0], Count);
        until Count = 0;
        SetLength(Result, Stream.Size);
        if Length(Result) > 0 then Move(Stream.Memory^, Result[0], Length(Result));
      finally Stream.Free end;
    finally WinHttpCloseHandle(Request) end;
  finally WinHttpCloseHandle(Connection) end;
end;

end.
