unit FxRecord.PublicSource;

interface

uses System.SysUtils, System.Generics.Collections, FxRecord.Http;

type
  // Standard HLS adapter. JSON here is an internal recorder message generated
  // from M3U8; no server-side JSON API or local folders are required.
  TFxPublicSource = class
  private
    FClient: TFxHttpClient;
    FManifestUrl, FSignature, FLastError, FMediaSession: string;
    FLastChangedUtc: TDateTime;
    FMediaUrls: TDictionary<string, string>;
    FInit: TBytes;
    FLastHlsSequence: Int64;
    FLastHlsFirst: Int64;
    FLastInitUrl, FLastDiscontinuity: string;
    FEpoch: Integer;
  public
    constructor Create(const AUrl: string);
    destructor Destroy; override;
    function ReadManifest(out AText: string; out ALastChangedUtc: TDateTime): Boolean;
    function ReadMedia(const AFileName: string; out ABytes: TBytes): Boolean;
    property ManifestUrl: string read FManifestUrl;
    property LastError: string read FLastError;
  end;

implementation

uses System.JSON, System.DateUtils, FxRecord.Config, FxRecord.Hls, FxRecord.Fmp4;

constructor TFxPublicSource.Create(const AUrl: string);
begin
  inherited Create;
  FManifestUrl := NormalizeFxRecordStreamUrl(AUrl);
  FMediaUrls := TDictionary<string, string>.Create;
  FClient := TFxHttpClient.Create;
  FLastHlsSequence := -1;
end;

destructor TFxPublicSource.Destroy;
begin
  FClient.Free;
  FMediaUrls.Free;
  inherited;
end;

function TFxPublicSource.ReadManifest(out AText: string; out ALastChangedUtc: TDateTime): Boolean;
var
  Url, FinalUrl, InitUrl, Session, Signature, Text: string;
  Playlist: TFxHlsPlaylist;
  Depth, I: Integer;
  Json: TJSONObject;
begin
  Result := False; AText := ''; ALastChangedUtc := 0;
  try
    Url := FManifestUrl;
    for Depth := 0 to 3 do
      begin
        Text := TEncoding.UTF8.GetString(FClient.Get(Url, 1024 * 1024, FinalUrl));
        Playlist := ParseFxHls(Text);
        if Playlist.Variant = '' then Break;
        if Depth = 3 then raise Exception.Create('HLS master playlist nesting exceeds the limit.');
        Url := FxResolveHttpUrl(FinalUrl, Playlist.Variant);
      end;
    InitUrl := FxResolveHttpUrl(FinalUrl, Playlist.InitUri);
    if (FLastHlsSequence >= 0) and (Playlist.Last < FLastHlsSequence) then
      begin
        if (InitUrl = FLastInitUrl) and (Playlist.Identity = FLastDiscontinuity) and
           (Playlist.Last >= FLastHlsFirst) then
          raise Exception.Create('Received an older overlapping HLS playlist; retrying for current media.');
        Inc(FEpoch);
      end;
    FLastHlsSequence := Playlist.Last;
    FLastHlsFirst := Playlist.First;
    FLastInitUrl := InitUrl;
    FLastDiscontinuity := Playlist.Identity;
    Session := InitUrl + '|d=' + Playlist.Identity + '|e=' + IntToStr(FEpoch);
    Signature := Session + '/' + IntToStr(Playlist.Last);
    if Signature <> FSignature then
      begin FSignature := Signature; FLastChangedUtc := TTimeZone.Local.ToUniversalTime(Now) end;
    if Session <> FMediaSession then begin FInit := nil; FMediaSession := Session end;
    FMediaUrls.Clear;
    FMediaUrls.Add('init.mp4', InitUrl);
    for I := 0 to Length(Playlist.Media) - 1 do
      FMediaUrls.Add(Format('patched_frag_%.6d.m4s', [Playlist.First + I]),
        FxResolveHttpUrl(FinalUrl, Playlist.Media[I]));
    Json := TJSONObject.Create;
    try
      Json.AddPair('version', TJSONNumber.Create(1));
      Json.AddPair('live', TJSONTrue.Create);
      Json.AddPair('first', TJSONNumber.Create(Playlist.First));
      Json.AddPair('last', TJSONNumber.Create(Playlist.Last));
      Json.AddPair('publishSeq', TJSONNumber.Create(Playlist.Last));
      Json.AddPair('sessionId', Session);
      Json.AddPair('init', 'init.mp4');
      Json.AddPair('prefix', 'patched_frag_');
      Json.AddPair('ext', '.m4s');
      Json.AddPair('digits', TJSONNumber.Create(6));
      Json.AddPair('fragmentTargetMs', TJSONNumber.Create(Playlist.TargetMs));
      AText := Json.ToJSON;
    finally Json.Free end;
    ALastChangedUtc := FLastChangedUtc;
    FLastError := '';
    Result := True;
  except on E: Exception do FLastError := E.Message end;
end;

function TFxPublicSource.ReadMedia(const AFileName: string; out ABytes: TBytes): Boolean;
var Url, FinalUrl: string;
begin
  Result := False; ABytes := nil;
  try
    if not FMediaUrls.TryGetValue(AFileName, Url) then
      raise Exception.Create('Requested media is outside the current HLS playlist.');
    if (AFileName = 'init.mp4') and (Length(FInit) > 0) then
      begin ABytes := FInit; FLastError := ''; Exit(True) end;
    ABytes := FClient.Get(Url, 64 * 1024 * 1024, FinalUrl);
    if Length(ABytes) = 0 then raise Exception.Create('HTTP media file is empty.');
    if AFileName = 'init.mp4' then
      begin
        if not FxValidFmp4Initialization(ABytes) then
          raise Exception.Create('The HTTP initialization segment is incomplete; waiting for a complete fMP4 header.');
        FInit := Copy(ABytes);
      end
    else if not FxValidFmp4Fragment(ABytes) then
      raise Exception.Create('The HTTP media segment is incomplete; retrying before adding it to the recording.');
    FLastError := '';
    Result := True;
  except on E: Exception do FLastError := E.Message end;
end;

end.
