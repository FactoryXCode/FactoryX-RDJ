// FactoryX
//
// Copyright (c) FactoryX, Netherlands/Australia/Germany. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: FxRecord.Config.pas
// Kind: Pascal Unit
// Release date: 10-08-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Loads and saves recorder settings in the INI file.
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
unit FxRecord.Config;

interface

uses

  {System}
  System.SysUtils,
  System.Classes,
  System.Math,
  System.IniFiles,
  System.IOUtils;

type

  TFxRecordSettings = record
    Enabled: Boolean;
    SourceMode: string;
    StreamUrl: string;
    StreamPath: string;
    ArchivePath: string;
    PollIntervalMs: Integer;
    RequireLiveStream: Boolean;
    LiveStaleSeconds: Integer;
    WarningFreeGB: Integer;
    CriticalFreeGB: Integer;
    FragmentDuration: Integer;
    RetentionDays: Integer;
    OutputProfile: string;
    Mp3SampleRate: Integer;
    Mp3BitRateKbps: Integer;
    AacSampleRate: Integer;
    AacBitRateKbps: Integer;
  end;

  procedure SetDefaultFxRecordSettings(out ASettings: TFxRecordSettings;
                                       const ABasePath: string);

  procedure LoadFxRecordSettings(const AFileName: string;
                                 out ASettings: TFxRecordSettings);

  procedure SaveFxRecordSettings(const AFileName: string;
                                 const ASettings: TFxRecordSettings);

  function NormalizeFxRecordStreamUrl(const AValue: string): string;
  procedure ValidateFxRecordSource(const ASettings: TFxRecordSettings);

implementation

function NormalizeFxRecordStreamUrl(const AValue: string): string;
var
  Value, Authority, Host, PortText, Path, Name, Query: string;
  P, Q, Port: Integer;
  C: Char;
begin
  Value := Trim(AValue);
  if not SameText(Copy(Value, 1, 7), 'http://') and
     not SameText(Copy(Value, 1, 8), 'https://') then
    raise Exception.Create('Enter an http:// or https:// HLS playlist URL.');
  for C in Value do
    if (Ord(C) <= 32) or CharInSet(C, ['\', '#']) then
      raise Exception.Create('The stream URL must not contain spaces, backslashes or a fragment.');
  P := Pos('://', Value) + 3;
  Q := P;
  while (Q <= Length(Value)) and not CharInSet(Value[Q], ['/', '?']) do Inc(Q);
  Authority := Copy(Value, P, Q - P);
  if Pos('@', Authority) > 0 then raise Exception.Create('Embedded HTTP credentials are not supported.');
  Host := Authority;
  PortText := '';
  if Copy(Host, 1, 1) = '[' then
    begin
      P := Pos(']', Host);
      if P < 3 then raise Exception.Create('Invalid IPv6 broadcast host.');
      if Length(Host) > P then
        begin
          if Host[P + 1] <> ':' then raise Exception.Create('Invalid broadcast port.');
          PortText := Copy(Host, P + 2, MaxInt);
          if PortText = '' then raise Exception.Create('Invalid broadcast port.');
        end;
      Host := Copy(Host, 1, P);
    end
  else
    begin
      P := Pos(':', Host);
      if P > 0 then
        begin
          PortText := Copy(Host, P + 1, MaxInt);
          Host := Copy(Host, 1, P - 1);
          if PortText = '' then raise Exception.Create('Invalid broadcast port.');
        end;
    end;
  if Host = '' then raise Exception.Create('The broadcast URL needs a host name.');
  if (PortText <> '') and (not TryStrToInt(PortText, Port) or (Port < 1) or (Port > 65535)) then
    raise Exception.Create('The broadcast port must be between 1 and 65535.');
  Path := Copy(Value, Q, MaxInt);
  Query := '';
  P := Pos('?', Path);
  if P > 0 then
    begin
      Query := Copy(Path, P, MaxInt);
      SetLength(Path, P - 1);
    end;
  Name := Copy(Path, LastDelimiter('/', Path) + 1, MaxInt);
  if (Path = '') or (Path = '/') then Path := '/stream/live.m3u8'
  else if SameText(Name, 'live.json') then
    Path := Copy(Path, 1, Length(Path) - Length(Name)) + 'live.m3u8'
  else if not SameText(ExtractFileExt(Name), '.m3u8') and
          not ((Query <> '') and (Name <> '') and (Pos('.', Name) = 0)) then
    begin
      if Pos('.', Name) > 0 then
        raise Exception.Create('Use the stream .m3u8 playlist URL.');
      if Copy(Path, Length(Path), 1) <> '/' then Path := Path + '/';
      Path := Path + 'live.m3u8';
    end;
  Result := Copy(Value, 1, Pos('://', Value) + 2) + Authority + Path + Query;
end;

procedure ValidateFxRecordSource(const ASettings: TFxRecordSettings);
begin
  if SameText(ASettings.SourceMode, 'PublicUrl') then
    NormalizeFxRecordStreamUrl(ASettings.StreamUrl)
  else if not SameText(ASettings.SourceMode, 'LocalFolder') then
    raise Exception.Create('Select LocalFolder or PublicUrl recording input.')
  else if Trim(ASettings.StreamPath) = '' then
    raise Exception.Create('The local stream folder is required.');
end;


function ResolvePath(const ABasePath, AValue: string): string;
begin

  if TPath.IsPathRooted(AValue) then
    Result := TPath.GetFullPath(AValue)
  else
    Result := TPath.GetFullPath(TPath.Combine(ABasePath,
                                              AValue));
end;


procedure SetDefaultFxRecordSettings(out ASettings: TFxRecordSettings;
                                     const ABasePath: string);
begin

  ASettings.Enabled := False;
  ASettings.SourceMode := 'LocalFolder';
  ASettings.StreamUrl := '';
  ASettings.StreamPath := TPath.Combine(ABasePath,
                                        'www\Stream');

  ASettings.ArchivePath := TPath.Combine(ABasePath,
                                         'ComplianceRecordings');

  ASettings.PollIntervalMs := 500;
  ASettings.RequireLiveStream := False;
  ASettings.LiveStaleSeconds := 15;
  ASettings.WarningFreeGB := 20;
  ASettings.CriticalFreeGB := 5;
  ASettings.FragmentDuration := 60;
  ASettings.RetentionDays := 14;
  ASettings.OutputProfile := 'SourceCopy';
  ASettings.Mp3SampleRate := 44100;
  ASettings.Mp3BitRateKbps := 192;
  ASettings.AacSampleRate := 44100;
  ASettings.AacBitRateKbps := 160;
end;


procedure LoadFxRecordSettings(const AFileName: string;
                               out ASettings: TFxRecordSettings);
var
  Ini: TMemIniFile;
  BasePath: string;

begin

  BasePath := ExtractFileDir(ExpandFileName(AFileName));
  SetDefaultFxRecordSettings(ASettings,
                             BasePath);

  if not FileExists(AFileName) then
    Exit;

  Ini := TMemIniFile.Create(AFileName,
                            TEncoding.UTF8);

  try
    ASettings.SourceMode := Ini.ReadString('Recorder', 'SourceMode', ASettings.SourceMode);
    ASettings.StreamUrl := Ini.ReadString('Recorder', 'StreamUrl', ASettings.StreamUrl);
    if SameText(ASettings.SourceMode, 'PublicUrl') then
      ASettings.StreamUrl := NormalizeFxRecordStreamUrl(ASettings.StreamUrl);
    ASettings.Enabled := Ini.ReadBool('Recorder',
                                      'Enabled',
                                      ASettings.Enabled);

    ASettings.StreamPath := ResolvePath(BasePath,
                                        Ini.ReadString('Recorder',
                                                       'StreamPath',
                                                       ASettings.StreamPath));

    ASettings.ArchivePath := ResolvePath(BasePath,
                                         Ini.ReadString('Recorder',
                                                        'ArchivePath',
                                                        ASettings.ArchivePath));

    ASettings.PollIntervalMs := EnsureRange(Ini.ReadInteger('Recorder',
                                                            'PollIntervalMs',
                                                            ASettings.PollIntervalMs),
                                                            100,
                                                            60000);

    ASettings.RequireLiveStream := Ini.ReadBool('Recorder',
                                                'RequireLiveStream',
                                                ASettings.RequireLiveStream);

    ASettings.LiveStaleSeconds := EnsureRange(Ini.ReadInteger('Recorder',
                                                              'LiveStaleSeconds',
                                                              ASettings.LiveStaleSeconds),
                                                              5,
                                                              3600);

    ASettings.WarningFreeGB := EnsureRange(Ini.ReadInteger('Recorder',
                                                           'WarningFreeGB',
                                                           ASettings.WarningFreeGB),
                                                           1,
                                                           100000);

    ASettings.CriticalFreeGB := EnsureRange(Ini.ReadInteger('Recorder',
                                                            'CriticalFreeGB',
                                                            ASettings.CriticalFreeGB),
                                                            1,
                                                            ASettings.WarningFreeGB);

    ASettings.FragmentDuration := EnsureRange(Ini.ReadInteger('Archive',
                                                              'FragmentDuration',
                                                              ASettings.FragmentDuration),
                                                              1,
                                                              1440);

    ASettings.RetentionDays := EnsureRange(Ini.ReadInteger('Archive',
                                                           'RetentionDays',
                                                           ASettings.RetentionDays),
                                                           1,
                                                           3650);

    ASettings.Mp3SampleRate := Ini.ReadInteger('Audio',
                                               'Mp3SampleRate',
                                               ASettings.Mp3SampleRate);

    ASettings.Mp3BitRateKbps := Ini.ReadInteger('Audio',
                                                'Mp3BitRateKbps',
                                                ASettings.Mp3BitRateKbps);

    ASettings.AacSampleRate := Ini.ReadInteger('Audio',
                                               'AacSampleRate',
                                               ASettings.AacSampleRate);

    ASettings.AacBitRateKbps := Ini.ReadInteger('Audio',
                                                'AacBitRateKbps',
                                                ASettings.AacBitRateKbps);

    ASettings.OutputProfile := Ini.ReadString('Archive',
                                              'OutputProfile',
                                              ASettings.OutputProfile);
  finally
    Ini.Free();
  end;
end;


procedure SaveFxRecordSettings(const AFileName: string;
                               const ASettings: TFxRecordSettings);
var
  Ini: TMemIniFile;

begin

  ForceDirectories(ExtractFileDir(ExpandFileName(AFileName)));
  Ini := TMemIniFile.Create(AFileName,
                            TEncoding.UTF8);

  try
    ValidateFxRecordSource(ASettings);
    Ini.WriteString('Recorder', 'SourceMode', ASettings.SourceMode);
    Ini.WriteString('Recorder', 'StreamUrl', ASettings.StreamUrl);
    Ini.WriteBool('Recorder',
                  'Enabled',
                  ASettings.Enabled);

    Ini.WriteString('Recorder',
                    'StreamPath',
                    ASettings.StreamPath);

    Ini.WriteString('Recorder',
                    'ArchivePath',
                    ASettings.ArchivePath);

    Ini.WriteInteger('Recorder',
                     'PollIntervalMs',
                     ASettings.PollIntervalMs);

    Ini.WriteBool('Recorder',
                  'RequireLiveStream',
                  ASettings.RequireLiveStream);

    Ini.WriteInteger('Recorder',
                     'LiveStaleSeconds',
                     ASettings.LiveStaleSeconds);

    Ini.WriteInteger('Recorder',
                     'WarningFreeGB',
                     ASettings.WarningFreeGB);

    Ini.WriteInteger('Recorder',
                     'CriticalFreeGB',
                     ASettings.CriticalFreeGB);

    Ini.WriteInteger('Archive',
                     'FragmentDuration',
                     ASettings.FragmentDuration);

    Ini.WriteInteger('Archive',
                     'RetentionDays',
                     ASettings.RetentionDays);

    Ini.WriteString('Archive',
                    'OutputProfile',
                    ASettings.OutputProfile);

    Ini.WriteInteger('Audio',
                     'Mp3SampleRate',
                     ASettings.Mp3SampleRate);

    Ini.WriteInteger('Audio',
                     'Mp3BitRateKbps',
                     ASettings.Mp3BitRateKbps);

    Ini.WriteInteger('Audio',
                     'AacSampleRate',
                     ASettings.AacSampleRate);

    Ini.WriteInteger('Audio',
                     'AacBitRateKbps',
                     ASettings.AacBitRateKbps);

    Ini.UpdateFile();

  finally
    Ini.Free();
  end;
end;

end.
