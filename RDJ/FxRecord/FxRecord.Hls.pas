// FactoryX
//
// Copyright (c) FactoryX, Netherlands/Australia/Germany. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: FxRecord.Hls.pas
// Kind: Pascal Unit
// Release date: 10-08-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Reads and interprets the stream’s .m3u8 playlist and
//              tells the rest of FxRecord which media fragments are currently available.
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
unit FxRecord.Hls;

interface

uses

  {System}
  System.SysUtils;

type
  TFxHlsPlaylist = record
    Variant: string;
    InitUri: string;
    Identity: string;
    First: Int64;
    Last: Int64;
    TargetMs: Integer;
    Media: TArray<string>;
    Ended: Boolean;
  end;

  function ParseFxHls(const AText: string): TFxHlsPlaylist;


implementation

uses

  {Sysyem}
  System.Classes;

function Attribute(ALine: string;
                   AName: string): string;
var
  P: Integer;
  Start: Integer;

begin

  Result := '';
  P := Pos(AName + '=',
           ALine);

  if (P = 0) then
    Exit;

  Start := P + Length(AName) + 1;
  P := Start;

  if (P <= Length(ALine)) and (ALine[P] = '"') then
    begin
      Inc(Start); P := Start;
      while (P <= Length(ALine)) and (ALine[P] <> '"') do Inc(P);
    end
  else
    while (P <= Length(ALine)) and (ALine[P] <> ',') do Inc(P);

  Result := Copy(ALine,
                 Start,
                 P - Start);
end;


function ParseFxHls(const AText: string): TFxHlsPlaylist;
var
  Lines: TStringList;
  Line: string;
  Map: string;
  Value: string;
  I: Integer;
  N: Integer;
  Seq: Int64;
  Discontinuity: Int64;
  VariantPending,
  HasDuration: Boolean;
  Duration: Double;
  Settings: TFormatSettings;

begin

  Result := Default(TFxHlsPlaylist);
  Result.TargetMs := 4000;

  if (Pos('#EXTM3U',
          Trim(AText)) <> 1) then
    raise Exception.Create('The stream URL did not return an HLS playlist. Enter the media .m3u8 URL.');

  Lines := TStringList.Create();

  try
    Lines.Text := AText;
    Seq := 0;
    Discontinuity := 0;
    Map := '';
    VariantPending := False;
    HasDuration := False;
    Settings := TFormatSettings.Create();
    Settings.DecimalSeparator := '.';

    for I := 0 to Lines.Count - 1 do
      begin
        Line := Trim(Lines[I]);

        if (Line = '') then
          Continue;

        if Pos('#EXT-X-STREAM-INF:',
               Line) = 1 then
          begin
            if (Attribute(Line,
                'AUDIO') <> '') then
              raise Exception.Create('Choose an HLS rendition with audio and video in the same stream.');
            VariantPending := True;
          end
        else
          if (Line[1] <> '#') and VariantPending then
            begin
              Result.Variant := Line;
              Exit
            end
          else
            if (Pos('#EXT-X-MEDIA-SEQUENCE:',
                    Line) = 1) then
              begin
                if not TryStrToInt64(Copy(Line,
                                          23,
                                          MaxInt),
                                     Seq) or (Seq < 0) then
                  raise Exception.Create('Invalid HLS media sequence.');
              end
            else
              if Pos('#EXT-X-DISCONTINUITY-SEQUENCE:',
                     Line) = 1 then
                 begin
                   if not TryStrToInt64(Copy(Line,
                                             31,
                                             MaxInt),
                                        Discontinuity) or (Discontinuity < 0) then
                     raise Exception.Create('Invalid HLS discontinuity sequence.');
                end
              else
                if (Line = '#EXT-X-DISCONTINUITY') then
                  begin
                    Inc(Discontinuity);
                    Result.Media := nil;
                  end
                else
                  if (Pos('#EXT-X-KEY:',
                          Line) = 1) then
                    begin
                      if (Attribute(Line,
                                    'METHOD') <> 'NONE') then
                        raise Exception.Create('Encrypted HLS streams are not supported.');
                    end
                  else
                    if Pos('#EXT-X-BYTERANGE:',
                           Line) = 1 then
                      raise Exception.Create('HLS byte-range segments are not supported.')
                  else
                    if Pos('#EXT-X-MAP:',
                           Line) = 1 then
                      begin
                        if (Attribute(Line,
                                     'BYTERANGE') <> '') then
                          raise Exception.Create('HLS byte-range initialization is not supported.');

                        Value := Attribute(Line,
                                           'URI');
                        if (Value = '') then
                          raise Exception.Create('HLS initialization URI is missing.');

                        if (Map <> '') and (Map <> Value) then
                          Result.Media := nil;

                        Map := Value;
                      end
                    else
                      if Pos('#EXTINF:',
                             Line) = 1 then
                        begin
                          Value := Copy(Line,
                                        9,
                                        MaxInt);
                          N := Pos(',',
                                   Value);
                          if (N > 0) then
                            SetLength(Value,
                                      N - 1);
                          if not TryStrToFloat(Value,
                                               Duration,
                                               Settings) or (Duration <= 0) or (Duration > 600) then
                            raise Exception.Create('Invalid HLS segment duration.');
                          Result.TargetMs := Round(Duration * 1000);
                          HasDuration := True;
                        end
                      else
                        if (Line = '#EXT-X-ENDLIST') then
                          Result.Ended := True
                        else
                          if (Line[1] <> '#') then
                            begin
                              if not HasDuration then
                                raise Exception.Create('HLS segment is missing EXTINF.');

                              if (Map = '') then
                                raise Exception.Create('Use an fMP4 HLS stream with EXT-X-MAP; MPEG-TS input is not supported.');

                              N := Length(Result.Media);

                              if (N >= 4096)then
                                raise Exception.Create('HLS playlist exceeds the segment limit.');

                              if (N = 0) then
                                Result.First := Seq;

                              SetLength(Result.Media,
                                        N + 1);
                              Result.Media[N] := Line;
                              Result.Last := Seq;

                              if Seq = High(Int64) then
                                raise Exception.Create('HLS sequence overflow.');

                              Inc(Seq);
                              HasDuration := False;
                            end;
      end; //for I :=

    if (Length(Result.Media) = 0) then
      raise Exception.Create('HLS playlist has no complete media segments.');

    Result.InitUri := Map;
    Result.Identity := IntToStr(Discontinuity);

  finally
    Lines.Free;
  end;
end;

end.
