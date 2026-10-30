// FactoryX. Licensed under the Mozilla Public License 2.0.
// Read listener statistics without blocking the VCL message loop.
unit RDJ.ListenerScan;

interface

uses

  WinApi.Windows,
  System.Classes;

type

  TRdjListenerScan = class(TThread)
  private
    FFileName: string;
    FListenerCount: Integer;
    FElapsedMs: Cardinal;
    FErrorText: string;
    function GetCompleted(): Boolean;
  protected
    procedure Execute(); override;
    function ReadListenerCount(): Integer; virtual;
  public
    constructor Create(const AFileName: string);
    destructor Destroy(); override;

    property Completed: Boolean read GetCompleted;
    property FileName: string read FFileName;
    property ListenerCount: Integer read FListenerCount;
    property ElapsedMs: Cardinal read FElapsedMs;
    property ErrorText: string read FErrorText;
  end;

function ReadRdjListenerCount(const AFileName: string): Integer;

function CancelListenerScanIo(AThread: THandle): BOOL; stdcall;

implementation

uses

  System.SysUtils,
  System.DateUtils,
  System.JSON;

const

  RDJ_CADDY_ACTIVE_LISTENER_SECONDS = 180;
  RDJ_CADDY_LOG_TAIL_BYTES = 262144;

constructor TRdjListenerScan.Create(const AFileName: string);
begin

  inherited Create(True);
  FreeOnTerminate := False;
  FFileName := AFileName;
  FListenerCount := -1;
end;


destructor TRdjListenerScan.Destroy();
begin

  Terminate();

  if not Suspended then
    begin
      CancelListenerScanIo(Handle);
      WaitFor();
    end;

  inherited;
end;


function TRdjListenerScan.GetCompleted(): Boolean;
begin

  Result := (WaitForSingleObject(Handle, 0) = WAIT_OBJECT_0);
end;


function TRdjListenerScan.ReadListenerCount(): Integer;
begin

  Result := ReadRdjListenerCount(FFileName);
end;


procedure TRdjListenerScan.Execute();
var
  Started: Cardinal;

begin

  Started := GetTickCount();

  try
    if not Terminated then
      FListenerCount := ReadListenerCount();
  except
    on E: Exception do
      FErrorText := E.ClassName + ': ' + E.Message;
  end;

  FElapsedMs := Cardinal(GetTickCount() - Started);
end;

function ReadRdjListenerCount(const AFileName: string): Integer;
var
  LogFileName: string;
  Stream: TFileStream;
  Bytes: TBytes;
  ReadSize: Integer;
  Text: string;
  Lines: TStringList;
  Clients: TStringList;
  I: Integer;
  Line: string;
  JsonValue: TJSONValue;
  Json: TJSONObject;
  RequestJson: TJSONObject;
  Value: TJSONValue;
  Uri: string;
  ClientIp: string;
  TsText: string;
  LogTs: Double;
  NowUtc: TDateTime;
  NowUnix: Double;

  function JsonText(const AJson: TJSONObject;
                    const AName: string): string;
  var
    V: TJSONValue;

  begin

    Result := '';
    if not Assigned(AJson) then
      Exit;

    V := AJson.GetValue(AName);
    if Assigned(V) then
      Result := V.Value;
  end;

  function RelevantUri(const AUri: string): Boolean;
  var
    S: string;

  begin

    S := LowerCase(Trim(AUri));
    Result := (Copy(S,
                    1,
                    8) = '/stream/') or
              (Copy(S,
                    1,
                    7) = '/video/') or
              (Copy(S,
                    1,
                    5) = '/live') or
              (Copy(S,
                    1,
                    11) = '/video.mjpg');
  end;

  function CleanClientIp(const AValue: string): string;
  var
    P: Integer;
    S: string;

  begin

    S := Trim(AValue);
    if (S = '') then
      Exit('');

    if (Length(S) > 0) and (S[1] = '[') then
      begin
        P := Pos(']',
                 S);
        if (P > 0) then
          Exit(Copy(S,
                    2,
                    P - 2));
      end;

    P := Pos(':',
             S);
    if (P > 0) then
      S := Copy(S,
                1,
                P - 1);

    Result := S;
  end;

begin

  Result := -1;

  LogFileName := AFileName;
  if (LogFileName = '') or not FileExists(LogFileName) then
    Exit;

  Stream := TFileStream.Create(LogFileName,
                               fmOpenRead or fmShareDenyNone);
  try
    ReadSize := Stream.Size;
    if (ReadSize > RDJ_CADDY_LOG_TAIL_BYTES) then
      ReadSize := RDJ_CADDY_LOG_TAIL_BYTES;

    if (ReadSize <= 0) then
      Exit;

    Stream.Position := Stream.Size - ReadSize;
    SetLength(Bytes,
              ReadSize);
    Stream.ReadBuffer(Bytes[0],
                      ReadSize);
  finally
    Stream.Free;
  end;

  Text := TEncoding.UTF8.GetString(Bytes);

  Lines := TStringList.Create;
  Clients := TStringList.Create;

  try
    Lines.Text := Text;
    Clients.Sorted := True;
    Clients.Duplicates := dupIgnore;

    NowUtc := TTimeZone.Local.ToUniversalTime(Now);
    NowUnix := (NowUtc - EncodeDate(1970,
                                    1,
                                    1)) * SecsPerDay;

    for I := 0 to Lines.Count - 1 do
      begin
        Line := Trim(Lines[I]);
        if (Line = '') or (Line[1] <> '{') then
          Continue;

        JsonValue := TJSONObject.ParseJSONValue(Line);
        try
          if not (JsonValue is TJSONObject) then
            Continue;

          Json := TJSONObject(JsonValue);
          RequestJson := nil;

          Value := Json.GetValue('request');
          if (Value is TJSONObject) then
            RequestJson := TJSONObject(Value);

          Uri := JsonText(RequestJson,
                          'uri');
          if (Uri = '') then
            Uri := JsonText(Json,
                            'uri');

          if not RelevantUri(Uri) then
            Continue;

          TsText := JsonText(Json,
                             'ts');
          LogTs := StrToFloatDef(StringReplace(TsText,
                                               '.',
                                               FormatSettings.DecimalSeparator,
                                               []),
                                 0);

          if (LogTs > 0) and
             ((NowUnix - LogTs) > RDJ_CADDY_ACTIVE_LISTENER_SECONDS) then
            Continue;

          ClientIp := CleanClientIp(JsonText(RequestJson,
                                            'client_ip'));
          if (ClientIp = '') then
            ClientIp := CleanClientIp(JsonText(RequestJson,
                                              'remote_ip'));
          if (ClientIp = '') then
            ClientIp := CleanClientIp(JsonText(Json,
                                              'remote_ip'));

          if (ClientIp <> '') then
            Clients.Add(ClientIp);
        finally
          JsonValue.Free;
        end;
      end;

    Result := Clients.Count;
  finally
    Clients.Free;
    Lines.Free;
  end;
end;

function CancelListenerScanIo; external 'kernel32.dll' name 'CancelSynchronousIo';

end.
