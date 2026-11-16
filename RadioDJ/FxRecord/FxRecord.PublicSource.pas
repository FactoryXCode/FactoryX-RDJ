// FactoryX
//
// Copyright (c) FactoryX, Netherlands/Australia/Germany. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: FxRecord.PublicSource.pas
// Kind: Pascal Unit
// Release date: 10-08-2026
// Language: ENU
//
// Revision Version: 4.1.0
// Description: Standard HLS adapter. JSON here is an internal recorder message generated
//              from M3U8; no server-side JSON API or local folders are required.
//
// Company: FactoryX
// Intiator(s): Tony (maXcomX), Carmen (carmenh).
// Contributor(s): Tony Kalf (maXcomX), Carmen (carmenh).
//
//------------------------------------------------------------------------------
// CHANGE LOG
// Date       Person              Reason
// ---------- ------------------- ----------------------------------------------
// 15/11/2026 All                 Eels release  SDK 10.0.28000.2705 (Windows 11)
//------------------------------------------------------------------------------
//
// Remarks: Requires Windows 10 or higher.
//
// Related objects: -
// Related projects: MfPackX410
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
unit FxRecord.PublicSource;

interface

uses

  {System}
  System.SysUtils,
  System.Generics.Collections,
  {FxRecord}
  FxRecord.Http;

type

  TFxPublicSource = class
  private
    FClient: TFxHttpClient;
    FManifestUrl: string;
    FSignature: string;
    FLastError: string;
    FMediaSession: string;
    FLastChangedUtc: TDateTime;
    FMediaUrls: TDictionary<string, string>;
    FInit: TBytes;
    FLastHlsSequence: Int64;
    FLastHlsFirst: Int64;
    FLastInitUrl: string;
    FLastDiscontinuity: string;
    FEpoch: Integer;

  public
    constructor Create(const AUrl: string);
    destructor Destroy(); override;

    function ReadManifest(out AText: string;
                          out ALastChangedUtc: TDateTime): Boolean;

    function ReadMedia(const AFileName: string;
                       out ABytes: TBytes): Boolean;

    property ManifestUrl: string read FManifestUrl;
    property LastError: string read FLastError;
  end;


implementation

uses

  {System}
  System.JSON,
  System.DateUtils,
  {FxRecord}
  FxRecord.Config,
  FxRecord.Hls,
  FxRecord.Fmp4;


constructor TFxPublicSource.Create(const AUrl: string);
begin

  inherited Create;

  FManifestUrl := NormalizeFxRecordStreamUrl(AUrl);
  FMediaUrls := TDictionary<string, string>.Create;
  FClient := TFxHttpClient.Create();
  FLastHlsSequence := -1;
end;


destructor TFxPublicSource.Destroy();
begin

  FClient.Free;
  FMediaUrls.Free;

  inherited;
end;


function TFxPublicSource.ReadManifest(out AText: string;
                                      out ALastChangedUtc: TDateTime): Boolean;
var
  Url: string;
  FinalUrl: string;
  InitUrl: string;
  Session: string;
  Signature: string;
  Text: string;
  Playlist: TFxHlsPlaylist;
  Depth: Integer;
  I: Integer;
  Json: TJSONObject;

begin

  Result := False;
  AText := '';
  ALastChangedUtc := 0;

  try
    Url := FManifestUrl;

    for Depth := 0 to 3 do
      begin
        Text := TEncoding.UTF8.GetString(FClient.Get(Url,
                                         1024 * 1024,
                                         FinalUrl));
        Playlist := ParseFxHls(Text);

        if (Playlist.Variant = '') then
          Break;

        if Depth = 3 then
          raise Exception.Create('HLS master playlist nesting exceeds the limit.');

        Url := FxResolveHttpUrl(FinalUrl,
                                Playlist.Variant);
      end;

    InitUrl := FxResolveHttpUrl(FinalUrl,
                                Playlist.InitUri);

    if (FLastHlsSequence >= 0) and (Playlist.Last < FLastHlsSequence) then
      begin
        if (InitUrl = FLastInitUrl) and (Playlist.Identity = FLastDiscontinuity) and (Playlist.Last >= FLastHlsFirst) then
          raise Exception.Create('Received an older overlapping HLS playlist; retrying for current media.');
        Inc(FEpoch);
      end;

    FLastHlsSequence := Playlist.Last;
    FLastHlsFirst := Playlist.First;
    FLastInitUrl := InitUrl;
    FLastDiscontinuity := Playlist.Identity;
    Session := InitUrl + '|d=' + Playlist.Identity + '|e=' + IntToStr(FEpoch);
    Signature := Session + '/' + IntToStr(Playlist.Last);

    if (Signature <> FSignature) then
      begin
        FSignature := Signature;
        FLastChangedUtc := TTimeZone.Local.ToUniversalTime(Now)
      end;

    if (Session <> FMediaSession) then
      begin
        FInit := nil;
        FMediaSession := Session
      end;

    FMediaUrls.Clear();
    FMediaUrls.Add('init.mp4',
                   InitUrl);

    for I := 0 to Length(Playlist.Media) - 1 do
      FMediaUrls.Add(Format('patched_frag_%.6d.m4s',
                            [Playlist.First + I]),
                     FxResolveHttpUrl(FinalUrl,
                                      Playlist.Media[I]));

    Json := TJSONObject.Create();

    try
      Json.AddPair('version',
                   TJSONNumber.Create(1));

      Json.AddPair('live',
                   TJSONTrue.Create());

      Json.AddPair('first',
                   TJSONNumber.Create(Playlist.First));

      Json.AddPair('last',
                   TJSONNumber.Create(Playlist.Last));

      Json.AddPair('publishSeq',
                   TJSONNumber.Create(Playlist.Last));

      Json.AddPair('sessionId',
                   Session);

      Json.AddPair('init',
                   'init.mp4');

      Json.AddPair('prefix',
                   'patched_frag_');

      Json.AddPair('ext',
                   '.m4s');

      Json.AddPair('digits',
                   TJSONNumber.Create(6));

      Json.AddPair('fragmentTargetMs',
                   TJSONNumber.Create(Playlist.TargetMs));
      AText := Json.ToJSON;

    finally
      Json.Free
    end;

    ALastChangedUtc := FLastChangedUtc;
    FLastError := '';
    Result := True;

  except on E: Exception do
    FLastError := E.Message end;
end;


function TFxPublicSource.ReadMedia(const AFileName: string;
                                   out ABytes: TBytes): Boolean;
var
  Url: string;
  FinalUrl: string;

begin

  Result := False;
  ABytes := nil;

  try
    if not FMediaUrls.TryGetValue(AFileName,
                                  Url) then
      raise Exception.Create('Requested media is outside the current HLS playlist.');

    if (AFileName = 'init.mp4') and (Length(FInit) > 0) then
      begin
        ABytes := FInit;
        FLastError := '';
        Exit(True)
      end;

    ABytes := FClient.Get(Url,
                          64 * 1024 * 1024,
                          FinalUrl);

    if (Length(ABytes) = 0) then
      raise Exception.Create('HTTP media file is empty.');

    if (AFileName = 'init.mp4') then
      begin
        if not FxValidFmp4Initialization(ABytes) then
          raise Exception.Create('The HTTP initialization segment is incomplete; waiting for a complete fMP4 header.');
        FInit := Copy(ABytes);
      end
    else
      if not FxValidFmp4Fragment(ABytes) then
        raise Exception.Create('The HTTP media segment is incomplete; retrying before adding it to the recording.');

    FLastError := '';
    Result := True;

  except on E: Exception do
    FLastError := E.Message end;
end;

end.
