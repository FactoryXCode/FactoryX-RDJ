// FactoryX
//
// Copyright (c) FactoryX, Netherlands/Australia/Germany. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: FxRecord.Converter.pas
// Kind: Pascal Unit
// Release date: 10-08-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Encodes selected audio profiles and writes AVI or MP4 recordings.
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
unit FxRecord.Converter;

interface

uses

  {WinApi}
  WinApi.Windows,
  {System}
  System.Classes,
  System.SysUtils,
  {Application}
  FxRecord.Diagnostics;

type

  TFxAviIndex = packed record
    ChunkId: DWORD;
    Flags: DWORD;
    Offset: DWORD;
    Size: DWORD;
  end;

  TFxConversionThread = class(TThread)
  private
    FInputFileName: string;
    FPartialFileName: string;
    FFinalFileName: string;
    FErrorText: string;
    FSucceeded: Boolean;
    FOutputProfile: string;
    FSampleRate: Integer;
    FBitRateKbps: Integer;
    FStartedTick: UInt64;
    FPhase: Longint;

  protected
    procedure Execute(); override;

  public

    constructor Create(const AInputFileName: string;
                       const APartialFileName: string;
                       const AFinalFileName: string;
                       const AOutputProfile: string = 'AVI-H264-MP3';
                       const ASampleRate: Integer = 44100;
                       const ABitRateKbps: Integer = 192);

    function DiagnosticText(): string;

    property ErrorText: string read FErrorText;
    property FinalFileName: string read FFinalFileName;
    property InputFileName: string read FInputFileName;
    property Succeeded: Boolean read FSucceeded;
    property StartedTick: UInt64 read FStartedTick;
  end;


implementation

uses

  {WinApi}
  WinApi.ComBaseApi,
  WinApi.WinApiTypes,
  {System}
  System.SyncObjs,
  {ActiveX}
  WinApi.ActiveX.PropIdl,
  WinApi.ActiveX.ObjBase,
  {WinMM}
  WinApi.WinMM.MMeApi,
  {MediaFoundationApi}
  WinApi.MediaFoundationApi.MfApi,
  WinApi.MediaFoundationApi.MfIdl,
  WinApi.MediaFoundationApi.MfObjects,
  WinApi.MediaFoundationApi.MfReadWrite;

var
  ConversionLock: TCriticalSection;


procedure CheckHR(const AResult: HRESULT;
                  const AOperation: string);
begin

  if Failed(AResult) then
    raise Exception.CreateFmt('%s failed (HRESULT 0x%.8x).',
                              [AOperation, Cardinal(AResult)]);
end;


function FourCC(const AText: AnsiString): DWORD;
begin

  if (Length(AText) <> 4) then
    raise Exception.Create('Invalid AVI chunk identifier.');

  Move(AText[1],
       Result,
       SizeOf(Result));
end;


// The Windows AVI sink does not accept the H.264 format on all systems.
// Mux the Windows-encoded packets here; no external codecs or tools are used.
procedure MuxNativePacketsToAvi(const AVideoFile: string;
                                const AEncodedFile: string;
                                const AOutputFile: string);
var
  Reader: IMFSourceReader;
  VideoReader: IMFSourceReader;
  VideoType: IMFMediaType;
  AudioType: IMFMediaType;
  StreamType: IMFMediaType;
  MajorType: TGUID;
  VideoIndex: DWORD;
  AudioIndex: DWORD;
  NativeVideoIndex: DWORD;
  Sample: IMFSample;
  PendingVideo: IMFSample;
  PendingAudio: IMFSample;
  Buffer: IMFMediaBuffer;
  Wave: PWAVEFORMATEX;
  WaveSize: DWORD;
  Width: DWORD;
  Height: DWORD;
  RateN: DWORD;
  RateD: DWORD;
  StreamIndex: DWORD;
  Data: PByte;
  DataLength: DWORD;
  CleanPoint: DWORD;
  VideoTimestamp: Int64;
  AudioTimestamp: Int64;
  VideoOrigin: Int64;
  AudioOrigin: Int64;
  VideoFlags: DWORD;
  AudioFlags: DWORD;
  Output: TFileStream;
  Index: TMemoryStream;
  Entry: TFxAviIndex;
  RiffStart: Int64;
  HeaderStart: Int64;
  StreamStart: Int64;
  ChunkStart: Int64;
  MoviStart: Int64;
  TotalFramesPosition,
  VideoLengthPosition,
  AudioLengthPosition: Int64;
  VideoFrames: DWORD;
  AudioBytes: DWORD;
  MainHeader: array[0..13] of DWORD;
  StreamHeader: array[0..13] of DWORD;
  BitmapHeader: array[0..9] of DWORD;
  VideoEnded: Boolean;
  AudioEnded: Boolean;
  PaddingByte: Byte;

  // Helpers
  procedure WriteDWord(const AValue: DWORD);
  begin

    Output.WriteBuffer(AValue,
                       SizeOf(AValue));
  end;

  function BeginChunk(const AId: AnsiString): Int64;
  begin

    WriteDWord(FourCC(AId));
    Result := Output.Position;
    WriteDWord(0);
  end;

  procedure PatchDWord(const APosition: Int64;
                       const AValue: DWORD);
  var
    Saved: Int64;

  begin

    Saved := Output.Position;
    Output.Position := APosition;
    WriteDWord(AValue);
    Output.Position := Saved;
  end;

  procedure EndChunk(const AStart: Int64);
  begin

    PatchDWord(AStart,
               DWORD(Output.Position - AStart - 4));

    if Odd(Output.Position) then
      Output.WriteBuffer(PaddingByte,
                         1);
  end;

begin
  StreamIndex := 0;
  PaddingByte := 0;

  CheckHR(MFCreateSourceReaderFromURL(PWideChar(AEncodedFile),
                                      nil,
                                      Reader),
                                      'Open encoded packets');

  // The work MP4 contains only MP3 audio. Copy video from the original source,
  // avoiding a second MP4 sink that can discard reordered H.264 frames.
  AudioIndex := 0;
  VideoIndex := 1;

  CheckHR(MFCreateSourceReaderFromURL(PWideChar(AVideoFile),
                                      nil,
                                      VideoReader),
          'Open original H.264 packets');

  CheckHR(VideoReader.GetNativeMediaType(0,
                                         0,
                                         @StreamType),
          'Read first original stream');

  CheckHR(StreamType.GetGUID(MF_MT_MAJOR_TYPE,
                             MajorType),
    'Read original stream type');

  if IsEqualGUID(MajorType,
                 MFMediaType_Video) then
    NativeVideoIndex := 0
  else
    NativeVideoIndex := 1;

  CheckHR(VideoReader.SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS,
                                         False),
          'Deselect original streams');

  CheckHR(VideoReader.SetStreamSelection(NativeVideoIndex,
                                         True),
          'Select original video');

  CheckHR(VideoReader.GetNativeMediaType(NativeVideoIndex,
                                         0,
                                         @VideoType),
          'Read original H.264 format');

  CheckHR(VideoReader.SetCurrentMediaType(NativeVideoIndex,
                                          0,
                                          VideoType),
          'Select original H.264 packets');

  CheckHR(Reader.GetNativeMediaType(AudioIndex,
                                    0,
                                    @AudioType),
          'Read encoded MP3 format');

  CheckHR(Reader.SetCurrentMediaType(AudioIndex,
                                     0,
                                     AudioType),
          'Select MP3 packets');

  CheckHR(MFGetAttributeSize(VideoType,
                             MF_MT_FRAME_SIZE,
                             Width,
                             Height),
          'Read AVI dimensions');

  CheckHR(MFGetAttributeRatio(VideoType,
                              MF_MT_FRAME_RATE,
                              RateN,
                              RateD),
          'Read encoded frame rate');

  if (RateN = 0) or (RateD = 0) then
    raise Exception.Create('Invalid source video frame rate.');

  Wave := nil;
  CheckHR(MFCreateWaveFormatExFromMFMediaType(AudioType,
                                              Wave,
                                              WaveSize),
          'Create AVI MP3 format');
  try
    Output := TFileStream.Create(AOutputFile,
                                 fmCreate);

    try
      Index := TMemoryStream.Create();

      try
        RiffStart := BeginChunk('RIFF');
        WriteDWord(FourCC('AVI '));
        HeaderStart := BeginChunk('LIST');
        WriteDWord(FourCC('hdrl'));
        ChunkStart := BeginChunk('avih');
        FillChar(MainHeader,
                 SizeOf(MainHeader), 0);
        MainHeader[0] := DWORD((UInt64(1000000) * RateD) div RateN);
        MainHeader[1] := 150000 + Wave.nAvgBytesPerSec;
        MainHeader[3] := $10; // AVIF_HASINDEX
        MainHeader[6] := 2;
        MainHeader[8] := Width;
        MainHeader[9] := Height;

        TotalFramesPosition := Output.Position + 4 * 4;
        Output.WriteBuffer(MainHeader,
                           SizeOf(MainHeader));
        EndChunk(ChunkStart);

        StreamStart := BeginChunk('LIST');
        WriteDWord(FourCC('strl'));
        ChunkStart := BeginChunk('strh');
        FillChar(StreamHeader,
                 SizeOf(StreamHeader),
                        0);

        StreamHeader[0] := FourCC('vids');
        StreamHeader[1] := FourCC('H264');
        StreamHeader[5] := RateD;
        StreamHeader[6] := RateN;
        StreamHeader[10] := DWORD(-1);
        StreamHeader[13] := (Height shl 16) or Width;

        VideoLengthPosition := Output.Position + 8 * 4;
        Output.WriteBuffer(StreamHeader,
                           SizeOf(StreamHeader));
        EndChunk(ChunkStart);
        ChunkStart := BeginChunk('strf');

        FillChar(BitmapHeader,
                 SizeOf(BitmapHeader),
                 0);

        BitmapHeader[0] := 40;
        BitmapHeader[1] := Width;
        BitmapHeader[2] := Height;
        BitmapHeader[3] := (24 shl 16) or 1;
        BitmapHeader[4] := FourCC('H264');
        BitmapHeader[5] := Width * Height * 3;

        Output.WriteBuffer(BitmapHeader,
                           SizeOf(BitmapHeader));

        EndChunk(ChunkStart);
        EndChunk(StreamStart);

        StreamStart := BeginChunk('LIST');
        WriteDWord(FourCC('strl'));
        ChunkStart := BeginChunk('strh');

        FillChar(StreamHeader,
                 SizeOf(StreamHeader),
                 0);

        StreamHeader[0] := FourCC('auds');
        StreamHeader[5] := 1;
        StreamHeader[6] := Wave.nAvgBytesPerSec;
        StreamHeader[10] := DWORD(-1);
        StreamHeader[11] := 1; // Audio stream length is expressed in bytes.

        AudioLengthPosition := Output.Position + 8 * 4;

        Output.WriteBuffer(StreamHeader,
                           SizeOf(StreamHeader));

        EndChunk(ChunkStart);
        ChunkStart := BeginChunk('strf');
        Output.WriteBuffer(Wave^,
                           WaveSize);

        EndChunk(ChunkStart);
        EndChunk(StreamStart);
        EndChunk(HeaderStart);

        MoviStart := BeginChunk('LIST');
        WriteDWord(FourCC('movi'));
        VideoFrames := 0;
        AudioBytes := 0;
        VideoEnded := False;
        AudioEnded := False;
        PendingVideo := nil; PendingAudio := nil;
        VideoOrigin := -1; AudioOrigin := -1;

        repeat
          Sample := nil;

          if (PendingVideo = nil) and not VideoEnded then
            begin
              CheckHR(VideoReader.ReadSample(NativeVideoIndex,
                                             0,
                                             nil,
                                             @VideoFlags,
                                             @VideoTimestamp,
                                             @PendingVideo),
                      'Read original AVI video packet');

              VideoEnded := ((VideoFlags and DWORD(MF_SOURCE_READERF_ENDOFSTREAM)) <> 0);

              if ((VideoFlags and DWORD(MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED)) <> 0) then
                raise Exception.Create('Original video type changed during AVI muxing.');

              if (PendingVideo <> nil) and (VideoOrigin < 0) then
                VideoOrigin := VideoTimestamp;
            end;

          if (PendingAudio = nil) and not AudioEnded then
            begin
              CheckHR(Reader.ReadSample(AudioIndex,
                                        0,
                                        nil,
                                        @AudioFlags,
                                        @AudioTimestamp,
                                        @PendingAudio),
                      'Read AVI MP3 packet');

              AudioEnded := ((AudioFlags and DWORD(MF_SOURCE_READERF_ENDOFSTREAM)) <> 0);

             if (PendingAudio <> nil) and (AudioOrigin < 0) then
               AudioOrigin := AudioTimestamp;
            end;

          if (PendingVideo <> nil) and ((PendingAudio = nil) or (VideoTimestamp - VideoOrigin <= AudioTimestamp - AudioOrigin)) then
            begin
              Sample := PendingVideo;
              PendingVideo := nil;
              StreamIndex := VideoIndex;
            end
          else
            if (PendingAudio <> nil) then
              begin
                Sample := PendingAudio;
                PendingAudio := nil;
                StreamIndex := AudioIndex;
              end;

          if (Sample <> nil) then
            begin
              CheckHR(Sample.ConvertToContiguousBuffer(@Buffer),
                      'Get AVI packet');

              CheckHR(Buffer.Lock(Data,
                                  nil,
                                  @DataLength),
                      'Lock AVI packet');

              try
                // Classic AVI has 32-bit offsets. Fail safely before exceeding
                // 2 GiB, retaining both the original source and encoded work file.
                if Output.Position + DataLength + Index.Size + 32 >= $7FFF0000 then
                  raise Exception.Create('AVI segment exceeds 2 GiB; reduce FragmentDuration.');

                Entry.Offset := DWORD(Output.Position - MoviStart - 4);
                Entry.Size := DataLength;
                Entry.Flags := $10;

                if (StreamIndex = VideoIndex) then
                  begin
                    Entry.ChunkId := FourCC('00dc');
                    CleanPoint := 0;
                    Sample.GetUINT32(MFSampleExtension_CleanPoint,
                                     CleanPoint);

                    if (CleanPoint = 0) then
                      Entry.Flags := 0;

                    Inc(VideoFrames);
                  end
                else
                  begin
                    Entry.ChunkId := FourCC('01wb');
                    Inc(AudioBytes,
                        DataLength);
                  end;

                WriteDWord(Entry.ChunkId);
                WriteDWord(DataLength);
                Output.WriteBuffer(Data^,
                                   DataLength);

                if Odd(DataLength) then
                  Output.WriteBuffer(PaddingByte,
                                     1);
                Index.WriteBuffer(Entry,
                                  SizeOf(Entry));
              finally
                Buffer.Unlock();
              end;

            Buffer := nil;
          end;
        until VideoEnded and AudioEnded and (PendingVideo = nil) and (PendingAudio = nil);

        if (VideoFrames = 0) or (AudioBytes = 0) then
          raise Exception.Create('The AVI recording requires both video and audio packets.');

        EndChunk(MoviStart);
        ChunkStart := BeginChunk('idx1');
        Index.Position := 0;
        Output.CopyFrom(Index,
                        Index.Size);

        EndChunk(ChunkStart);

        PatchDWord(TotalFramesPosition,
                   VideoFrames);

        PatchDWord(VideoLengthPosition,
                   VideoFrames);

        PatchDWord(AudioLengthPosition,
                   AudioBytes);
        EndChunk(RiffStart);

      finally
        Index.Free;
      end;

    finally
      Output.Free;
    end;

  finally
    CoTaskMemFree(Wave);
  end;
end;


procedure EncodeMp3Audio(const AInputFile, AOutputFile: string;
                         const ASampleRate, ABitRateKbps: Integer);
var
  Reader: IMFSourceReader;
  Writer: IMFSinkWriter;
  VideoType, PcmType, Mp3Type, FirstType: IMFMediaType;
  Attributes: IMFAttributes;
  MajorType: TGUID;
  AudioTypes: IMFCollection;
  AudioObject: IUnknown;
  Count, Channels, Rate, BytesPerSecond, I: DWORD;
  AudioFound: Boolean;
  AudioSamples: DWORD;
  Sample: IMFSample;
  VideoIn, AudioIn, AudioOut, StreamIndex, Flags: DWORD;
  TimeStamp: Int64;
  AudioStart: Int64;
  AudioEnded: Boolean;

begin

  CheckHR(MFCreateSourceReaderFromURL(PWideChar(AInputFile),
                                      nil,
                                      Reader),
                                      'Open MP3 source recording');

  CheckHR(Reader.GetNativeMediaType(0,
                                    0,
                                    @FirstType),
          'Read first source stream');

  CheckHR(FirstType.GetGUID(MF_MT_MAJOR_TYPE,
                            MajorType),
          'Read source stream type');

  if IsEqualGUID(MajorType,
                 MFMediaType_Video) then
    begin
      VideoIn := 0;
      AudioIn := 1;
    end
  else
    begin
      VideoIn := 1;
      AudioIn := 0;
    end;

  CheckHR(Reader.SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS,
                                    False),
          'Deselect source streams');

  CheckHR(Reader.SetStreamSelection(AudioIn,
                                    True),
          'Select source audio');

  CheckHR(Reader.GetNativeMediaType(VideoIn,
                                    0,
                                    @VideoType),
          'Read H.264 source format');

  CheckHR(VideoType.GetGUID(MF_MT_SUBTYPE,
                            MajorType),
          'Read source video subtype');

  if not IsEqualGUID(MajorType,
                     MFVideoFormat_H264) then
    raise Exception.Create('AVI-H264-MP3 requires H.264 source video.');

  CheckHR(Reader.SetCurrentMediaType(VideoIn, 0, VideoType), 'Preserve H.264 source packets');

  CheckHR(MFCreateMediaType(PcmType),
          'Create PCM input type');

  CheckHR(PcmType.SetGUID(MF_MT_MAJOR_TYPE,
                          MFMediaType_Audio),
          'Set PCM major type');

  CheckHR(PcmType.SetGUID(MF_MT_SUBTYPE,
                          MFAudioFormat_PCM),
          'Set PCM subtype');

  CheckHR(PcmType.SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE,
                            16),
          'Set 16-bit PCM');

  CheckHR(Reader.SetCurrentMediaType(AudioIn,
                                     0,
                                     PcmType),
          'Decode native PCM audio');

  CheckHR(Reader.GetCurrentMediaType(AudioIn,
                                     @PcmType),
          'Read negotiated PCM type');

  CheckHR(MFTranscodeGetAudioOutputAvailableTypes(MFAudioFormat_MP3,
                                                  DWORD(MFT_ENUM_FLAG_SYNCMFT),
                                                  nil,
                                                  AudioTypes),
          'Enumerate MP3 formats');

  CheckHR(AudioTypes.GetElementCount(Count),
          'Count MP3 formats');

  AudioFound := False;
  I := 0;

  while (I < Count) do
    begin
      CheckHR(AudioTypes.GetElement(I,
                                    AudioObject),
              'Read MP3 format');

      Mp3Type := AudioObject as IMFMediaType;

      CheckHR(Mp3Type.GetUINT32(MF_MT_AUDIO_NUM_CHANNELS,
                                Channels),
              'Read MP3 channels');

      CheckHR(Mp3Type.GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                                Rate),
              'Read MP3 rate');

      CheckHR(Mp3Type.GetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                                BytesPerSecond),
              'Read MP3 bitrate');

      if (Channels = 2) and (Rate = DWORD(ASampleRate)) and (BytesPerSecond = DWORD(ABitRateKbps * 1000 div 8)) then
        begin
          AudioFound := True;
          Break;
        end;

      Inc(I);
    end;

  if not AudioFound then
    raise Exception.CreateFmt('Windows did not enumerate stereo MP3 at %d Hz and %d kbps.',
                              [ASampleRate, ABitRateKbps]);

  CheckHR(MFCreateAttributes(Attributes,
                             2),
          'Create MP4 writer attributes');

  CheckHR(Attributes.SetGUID(MF_TRANSCODE_CONTAINERTYPE,
                             MFTranscodeContainerType_MPEG4),
          'Set MP4 output');

  CheckHR(Attributes.SetUINT32(MF_SINK_WRITER_DISABLE_THROTTLING,
                               0),
          'Enable writer throttling');

  CheckHR(MFCreateSinkWriterFromURL(PWideChar(AOutputFile),
                                    nil,
                                    Attributes,
                                    Writer),
          'Create MP4 writer');

  CheckHR(Writer.AddStream(Mp3Type,
                           AudioOut),
          'Add selected MP3 stream');

  CheckHR(Writer.SetInputMediaType(AudioOut,
                                   PcmType,
                                   nil),
          'Set MP3 PCM input');

  CheckHR(Writer.BeginWriting(),
          'Begin MP3 recording');

  AudioSamples := 0;
  AudioStart := -1;

  repeat
    Sample := nil;

    CheckHR(Reader.ReadSample(AudioIn,
                              0,
                              @StreamIndex,
                              @Flags,
                              @TimeStamp,
                              @Sample),
            'Read audio conversion sample');

    AudioEnded := ((Flags and DWORD(MF_SOURCE_READERF_ENDOFSTREAM)) <> 0);

    if ((Flags and DWORD(MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED)) <> 0) then
      raise Exception.Create('Source audio type changed during MP3 conversion.');

    if (Sample <> nil) then
      begin
        if (AudioStart < 0) then
          AudioStart := TimeStamp;

        CheckHR(Sample.SetSampleTime(TimeStamp - AudioStart),
                'Rebase MP3 timestamp');

        CheckHR(Writer.WriteSample(AudioOut,
                                   Sample),
                'Encode MP3 sample');

      // Yield in the audio sample loop; H.264 will be copied directly into AVI.
      Inc(AudioSamples);

      if ((AudioSamples mod 4) = 0) then
        Sleep(1);
    end;

  until AudioEnded;

  CheckHR(Writer.Finalize(),
          'Finalize MP3 MP4 recording');

  Writer := nil;
  Reader := nil;
end;


procedure EncodeAacToMp4(const AInputFile: string;
                         const AOutputFile: string;
                         const ASampleRate: Integer;
                         const ABitRateKbps: Integer);
var
  Reader: IMFSourceReader;
  Writer: IMFSinkWriter;
  VideoType: IMFMediaType;
  PcmType: IMFMediaType;
  AacType: IMFMediaType;
  FirstType: IMFMediaType;
  Attributes: IMFAttributes;
  MajorType: TGUID;
  Sample: IMFSample;
  VideoIn: DWORD;
  AudioIn: DWORD;
  VideoOut: DWORD;
  AudioOut: DWORD;
  StreamIndex: DWORD;
  Flags: DWORD;
  TimeStamp: Int64;
  VideoStart: Int64;
  AudioStart: Int64;
  VideoEnded: Boolean;
  AudioEnded: Boolean;

begin

  CheckHR(MFCreateSourceReaderFromURL(PWideChar(AInputFile),
                                      nil,
                                      Reader),
          'Open AAC source recording');

  CheckHR(Reader.GetNativeMediaType(0,
                                    0,
                                    @FirstType),
          'Read first source stream');

  CheckHR(FirstType.GetGUID(MF_MT_MAJOR_TYPE,
                            MajorType),
          'Read source stream type');

  if IsEqualGUID(MajorType,
                 MFMediaType_Video) then
    begin
      VideoIn := 0;
      AudioIn := 1;
    end
  else
    begin
      VideoIn := 1;
      AudioIn := 0;
    end;

  CheckHR(Reader.SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS,
                                    False),
          'Deselect source streams');

  CheckHR(Reader.SetStreamSelection(VideoIn,
                                    True),
          'Select source video');

  CheckHR(Reader.SetStreamSelection(AudioIn,
                                    True),
          'Select source audio');

  CheckHR(Reader.GetNativeMediaType(VideoIn,
                                    0,
                                    @VideoType),
          'Read H.264 source format');

  CheckHR(VideoType.GetGUID(MF_MT_SUBTYPE,
                            MajorType),
          'Read source video subtype');

  if not IsEqualGUID(MajorType,
                    MFVideoFormat_H264) then
    raise Exception.Create('MP4-H264-AAC requires H.264 source video.');

  CheckHR(Reader.SetCurrentMediaType(VideoIn,
                                     0,
                                     VideoType),
          'Preserve H.264 source packets');

  CheckHR(MFCreateMediaType(PcmType),
          'Create PCM input type');

  CheckHR(PcmType.SetGUID(MF_MT_MAJOR_TYPE,
                          MFMediaType_Audio),
          'Set PCM major type');


  CheckHR(PcmType.SetGUID(MF_MT_SUBTYPE,
                          MFAudioFormat_PCM),
          'Set PCM subtype');

  CheckHR(PcmType.SetUINT32(MF_MT_AUDIO_NUM_CHANNELS,
                            2),
          'Set stereo PCM');

  CheckHR(PcmType.SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                            ASampleRate),
          'Set PCM sample rate');

  CheckHR(PcmType.SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE,
                            16),
          'Set 16-bit PCM');

  CheckHR(PcmType.SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT,
                            4),
          'Set PCM block alignment');

  CheckHR(PcmType.SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                            ASampleRate * 4),
          'Set PCM byte rate');

  CheckHR(Reader.SetCurrentMediaType(AudioIn,
                                     0,
                                     PcmType),
          'Decode and resample source audio');

  CheckHR(Reader.GetCurrentMediaType(AudioIn,
                                     @PcmType),
          'Read negotiated PCM type');


  CheckHR(MFCreateMediaType(AacType),
          'Create AAC output type');

  CheckHR(AacType.SetGUID(MF_MT_MAJOR_TYPE,
                          MFMediaType_Audio),
          'Set AAC major type');

  CheckHR(AacType.SetGUID(MF_MT_SUBTYPE,
                          MFAudioFormat_AAC),
          'Set AAC subtype');

  CheckHR(AacType.SetUINT32(MF_MT_AUDIO_NUM_CHANNELS,
                            2),
          'Set stereo AAC');

  CheckHR(AacType.SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND,
                            ASampleRate),
          'Set AAC sample rate');

  CheckHR(AacType.SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE,
                            16),
          'Set AAC sample format');

  CheckHR(AacType.SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                            ABitRateKbps * 1000 div 8),
          'Set AAC bitrate');

  CheckHR(AacType.SetUINT32(MF_MT_AAC_PAYLOAD_TYPE,
                            0),
          'Set raw AAC payload');


  CheckHR(MFCreateAttributes(Attributes,
                             2),
          'Create MP4 writer attributes');

  CheckHR(Attributes.SetGUID(MF_TRANSCODE_CONTAINERTYPE,
                             MFTranscodeContainerType_MPEG4),
          'Set MP4 output');

  CheckHR(Attributes.SetUINT32(MF_SINK_WRITER_DISABLE_THROTTLING,
                               1),
          'Disable writer throttling');

  CheckHR(MFCreateSinkWriterFromURL(PWideChar(AOutputFile),
                                    nil,
                                    Attributes,
                                    Writer),
          'Create MP4 writer');

  CheckHR(Writer.AddStream(VideoType,
                           VideoOut),
          'Add H.264 copy stream');

  CheckHR(Writer.SetInputMediaType(VideoOut,
                                   VideoType,
                                   nil),
          'Set H.264 copy input');

  CheckHR(Writer.AddStream(AacType,
                           AudioOut),
          'Add selected AAC stream');

  CheckHR(Writer.SetInputMediaType(AudioOut,
                                   PcmType,
                                   nil),
          'Set AAC PCM input');

  CheckHR(Writer.BeginWriting(),
          'Begin AAC recording');

  VideoStart := -1;
  AudioStart := -1;
  VideoEnded := False;
  AudioEnded := False;

  repeat
    Sample := nil;

    CheckHR(Reader.ReadSample(MF_SOURCE_READER_ANY_STREAM,
                              0,
                              @StreamIndex,
                              @Flags,
                              @TimeStamp,
                              @Sample),
            'Read AAC conversion sample');

    if ((Flags and DWORD(MF_SOURCE_READERF_ENDOFSTREAM)) <> 0) then
      begin
        if (StreamIndex = VideoIn) then
          VideoEnded := True
        else
          if (StreamIndex = AudioIn) then
            AudioEnded := True;

        CheckHR(Reader.SetStreamSelection(StreamIndex,
                                          False),
                'Finish source stream');
      end;

    if (Sample <> nil) then
      begin
        if (StreamIndex = VideoIn) then
          begin
            if (VideoStart < 0) then
              VideoStart := TimeStamp;

            CheckHR(Sample.SetSampleTime(TimeStamp - VideoStart),
                    'Rebase H.264 timestamp');

            CheckHR(Writer.WriteSample(VideoOut,
                                   Sample),
                    'Copy H.264 sample');
         end
      else
        begin
          if (AudioStart < 0) then
            AudioStart := TimeStamp;

          CheckHR(Sample.SetSampleTime(TimeStamp - AudioStart),
                  'Rebase AAC timestamp');

          CheckHR(Writer.WriteSample(AudioOut,
                                     Sample),
                  'Encode AAC sample');
        end;
      end;

  until VideoEnded and AudioEnded;

  CheckHR(Writer.Finalize(),
          'Finalize AAC MP4 recording');

  Writer := nil;
  Reader := nil;
end;


constructor TFxConversionThread.Create(const AInputFileName: string;
                                       const APartialFileName: string;
                                       const AFinalFileName: string;
                                       const AOutputProfile: string;
                                       const ASampleRate: Integer;
                                       const ABitRateKbps: Integer);
begin

  inherited Create(True);

  FreeOnTerminate := False;
  FInputFileName := AInputFileName;
  FPartialFileName := APartialFileName;
  FFinalFileName := AFinalFileName;
  FOutputProfile := AOutputProfile;
  FSampleRate := ASampleRate;
  FBitRateKbps := ABitRateKbps;
  FStartedTick := GetTickCount64();
  FPhase := 0;
end;


function TFxConversionThread.DiagnosticText: string;
var
  Phase: Longint;
  PhaseName: string;

begin

  Phase := InterlockedCompareExchange(FPhase,
                                      0,
                                      0);

  case Phase of
    0: PhaseName := 'queued';
    1: PhaseName := 'initializing';
    2: PhaseName := 'MP3-encode';
    3: PhaseName := 'AVI-mux';
    4: PhaseName := 'AAC-encode';
    5: PhaseName := 'finalizing';
    6: PhaseName := 'MF-shutdown';
    7: PhaseName := 'finished';
  else
    PhaseName := 'unknown';
  end;

  Result := Format('thread=%d phase=%s ageMs=%d file=%s',
                   [ThreadID, PhaseName, Int64(GetTickCount64() - FStartedTick), FFinalFileName]);
end;


procedure TFxConversionThread.Execute();
var
  EncodedFile: string;

begin

  ConversionLock.Enter;
  try

  FSucceeded := False;
  FErrorText := '';

  InterlockedExchange(FPhase,
                      1);

  try
    CheckHR(CoInitializeEx(nil,
                           COINIT_MULTITHREADED),
            'Initialize converter COM');

    try
      CheckHR(MFStartup(),
              'Initialize Media Foundation');

      try

        // An old partial file is evidence of an interrupted conversion.
        if FileExists(FPartialFileName) or FileExists(FFinalFileName) then
          raise Exception.Create('Recording output already exists; it has been preserved.');

        EncodedFile := '';

        if SameText(FOutputProfile,
                    'AVI-H264-MP3') then
          begin
            if not ((FSampleRate = 32000) or
               (FSampleRate = 44100) or
               (FSampleRate = 48000)) or not
               ((FBitRateKbps = 128) or
               (FBitRateKbps = 160) or
               (FBitRateKbps = 192)) then
              raise Exception.Create('Invalid MP3 sample rate or bitrate.');

            EncodedFile := FPartialFileName + '.encoded.mp4';
            if FileExists(EncodedFile) then
              raise Exception.Create('Encoded work file already exists; it has been preserved.');

            InterlockedExchange(FPhase,
                                2);

            EncodeMp3Audio(FInputFileName,
                           EncodedFile,
                           FSampleRate,
                           FBitRateKbps);

            InterlockedExchange(FPhase,
                                3);

            MuxNativePacketsToAvi(FInputFileName,
                                  EncodedFile,
                                  FPartialFileName);
          end
        else
          if SameText(FOutputProfile,
                      'MP4-H264-AAC') then
            begin
              if not ((FSampleRate = 44100) or
                      (FSampleRate = 48000)) or not
                     ((FBitRateKbps = 96) or
                      (FBitRateKbps = 128) or
                     (FBitRateKbps = 160) or
                     (FBitRateKbps = 192)) then
                raise Exception.Create('Invalid AAC sample rate or bitrate (96-192 kbps).');

              InterlockedExchange(FPhase,
                                  4);

              EncodeAacToMp4(FInputFileName,
                             FPartialFileName,
                             FSampleRate,
                             FBitRateKbps);
            end
          else
            raise Exception.Create('Unsupported conversion profile.');

        InterlockedExchange(FPhase,
                             5);


        if not FileExists(FPartialFileName) then
          raise Exception.Create('The native converter did not create an output file.');

        if not MoveFileEx(PChar(FPartialFileName),
                          PChar(FFinalFileName),
                          MOVEFILE_WRITE_THROUGH) then
          raise Exception.Create('Cannot finalize recording. ' + SysErrorMessage(GetLastError()));

        if (EncodedFile <> '') then
          DeleteFile(PChar(EncodedFile));

        DeleteFile(PChar(FInputFileName));

        FSucceeded := True;

      finally
        InterlockedExchange(FPhase,
                            6);
        MFShutdown();
      end;

    finally
      CoUninitialize();
    end;

  except
    on E: Exception do
      FErrorText := E.Message;
  end;

  InterlockedExchange(FPhase,
                      7);
  finally ConversionLock.Leave end;
end;

initialization
  ConversionLock := TCriticalSection.Create;
finalization
  ConversionLock.Free;
end.
