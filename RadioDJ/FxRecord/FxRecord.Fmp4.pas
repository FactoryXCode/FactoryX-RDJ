// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Module: FxRecord.Fmp4.pas
// Kind: Pascal Unit
// Language: ENU
//
// Description: Rebases received fMP4 track decode times for standalone archive files.
//
// LICENSE
//
// The contents of this file are subject to the Mozilla Public License
// Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// https://www.mozilla.org/en-US/MPL/2.0/
//
//==============================================================================
unit FxRecord.Fmp4;

interface

uses

  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

function FxValidFmp4Initialization(const AData: TBytes): Boolean;
function FxValidFmp4Fragment(const AData: TBytes): Boolean;
function FxCompatibleFmp4Initialization(const ALeft, ARight: TBytes): Boolean;

type

  TFxFmp4Rebaser = class(TObject)
  private
    FTrackOrigins: TDictionary<Cardinal, UInt64>;
    FTrackOffsets, FTrackEnds: TDictionary<Cardinal, UInt64>;
    FTrackDurations: TDictionary<Cardinal, Cardinal>;
    FContinuationValid: Boolean;
    function TrafDuration(const AData: TBytes; AStart, AEnd: Integer): UInt64;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Reset();
    procedure SetInitialization(const AData: TBytes);
    function BeginContinuityEpoch(): Boolean;
    function Rebase(const AFragment: TBytes;
                    out ARebasedFragment: TBytes): Boolean;
  end;

implementation

const

  BOX_MOOF = $6D6F6F66;
  BOX_TRAF = $74726166;
  BOX_TFHD = $74666864;
  BOX_TFDT = $74666474;


function ReadU32(const AData: TBytes;
                 const AOffset: Integer): Cardinal;
begin

  if (AOffset < 0) or (AOffset + 4 > Length(AData)) then
    Exit(0);
  Result := (Cardinal(AData[AOffset]) shl 24) or
            (Cardinal(AData[AOffset + 1]) shl 16) or
            (Cardinal(AData[AOffset + 2]) shl 8) or
             Cardinal(AData[AOffset + 3]);
end;


function ReadU64(const AData: TBytes;
                 const AOffset: Integer): UInt64;
begin

  Result := (UInt64(ReadU32(AData, AOffset)) shl 32) or
             UInt64(ReadU32(AData, AOffset + 4));
end;


procedure WriteU32(var AData: TBytes;
                   const AOffset: Integer;
                   const AValue: Cardinal);
begin

  if (AOffset < 0) or (AOffset + 4 > Length(AData)) then
    Exit;
  AData[AOffset] := Byte(AValue shr 24);
  AData[AOffset + 1] := Byte(AValue shr 16);
  AData[AOffset + 2] := Byte(AValue shr 8);
  AData[AOffset + 3] := Byte(AValue);
end;


procedure WriteU64(var AData: TBytes;
                   const AOffset: Integer;
                   const AValue: UInt64);
begin

  WriteU32(AData, AOffset, Cardinal(AValue shr 32));
  WriteU32(AData, AOffset + 4, Cardinal(AValue));
end;


function ValidBox(const AData: TBytes;
                  const AOffset,
                        AEnd: Integer;
                  out ASize,
                      AType: Cardinal): Boolean;
begin

  Result := False;
  if (AOffset < 0) or (AOffset + 8 > AEnd) or
     (AEnd > Length(AData)) then
    Exit;
  ASize := ReadU32(AData, AOffset);
  AType := ReadU32(AData, AOffset + 4);
  Result := (ASize >= 8) and
            (AOffset + Integer(ASize) <= AEnd);
end;


function FxValidFmp4Initialization(const AData: TBytes): Boolean;
var Offset: Integer; Size, Kind: Cardinal; Ftyp, Moov: Boolean;
begin
  Offset := 0; Ftyp := False; Moov := False;
  while Offset < Length(AData) do
    begin
      if not ValidBox(AData, Offset, Length(AData), Size, Kind) then Exit(False);
      if Kind = $66747970 then Ftyp := True;
      if Kind = $6D6F6F76 then Moov := True;
      Inc(Offset, Integer(Size));
    end;
  Result := Ftyp and Moov;
end;

function FxValidFmp4Fragment(const AData: TBytes): Boolean;
var Offset: Integer; Size, Kind: Cardinal; Moof, Mdat: Boolean;
begin
  Offset := 0; Moof := False; Mdat := False;
  while Offset < Length(AData) do
    begin
      if not ValidBox(AData, Offset, Length(AData), Size, Kind) then Exit(False);
      if Kind = BOX_MOOF then Moof := True;
      if Kind = $6D646174 then Mdat := True;
      Inc(Offset, Integer(Size));
    end;
  Result := Moof and Mdat;
end;

function FindChild(const Data: TBytes; Start, Limit: Integer; Kind: Cardinal;
  out Offset, Count: Integer): Boolean;
var Size, BoxType: Cardinal;
begin
  Result := False;
  while ValidBox(Data, Start, Limit, Size, BoxType) do
    begin
      if BoxType = Kind then begin Offset := Start; Count := Size; Exit(True) end;
      Inc(Start, Integer(Size));
    end;
end;

function InitSignature(const Data: TBytes): TBytes;
var Moov, MoovSize, Trak, TrakSize, Cursor, P, N, Mdia, MdiaSize: Integer;
  Minf, MinfSize, Stbl, StblSize, Stsd, StsdSize: Integer;
  TrackId, Timescale: Cardinal;
  Stream: TBytesStream;
begin
  Result := nil;
  if not FindChild(Data, 0, Length(Data), $6D6F6F76, Moov, MoovSize) then Exit;
  Stream := TBytesStream.Create;
  try
    Cursor := Moov + 8;
    while FindChild(Data, Cursor, Moov + MoovSize, $7472616B, Trak, TrakSize) do
      begin
        Cursor := Trak + TrakSize;
        if not FindChild(Data, Trak + 8, Cursor, $746B6864, P, N) then Exit;
        if (N < 32) then Exit;
        if Data[P + 8] = 1 then TrackId := ReadU32(Data, P + 28)
        else TrackId := ReadU32(Data, P + 20);
        if not FindChild(Data, Trak + 8, Cursor, $6D646961, Mdia, MdiaSize) then Exit;
        if not FindChild(Data, Mdia + 8, Mdia + MdiaSize, $6D646864, P, N) or (N < 32) then Exit;
        if Data[P + 8] = 1 then Timescale := ReadU32(Data, P + 28)
        else Timescale := ReadU32(Data, P + 20);
        if not FindChild(Data, Mdia + 8, Mdia + MdiaSize, $6D696E66, Minf, MinfSize) then Exit;
        if not FindChild(Data, Minf + 8, Minf + MinfSize, $7374626C, Stbl, StblSize) then Exit;
        if not FindChild(Data, Stbl + 8, Stbl + StblSize, $73747364, Stsd, StsdSize) then Exit;
        Stream.WriteBuffer(TrackId, SizeOf(TrackId));
        Stream.WriteBuffer(Timescale, SizeOf(Timescale));
        Stream.WriteBuffer(Data[Stsd], StsdSize);
      end;
    SetLength(Result, Stream.Size);
    if Length(Result) > 0 then Move(Stream.Memory^, Result[0], Length(Result));
  finally Stream.Free end;
end;

function FxCompatibleFmp4Initialization(const ALeft, ARight: TBytes): Boolean;
var Left, Right: TBytes;
begin
  Left := InitSignature(ALeft); Right := InitSignature(ARight);
  Result := (Length(Left) > 0) and (Length(Left) = Length(Right));
  if Result then Result := CompareMem(@Left[0], @Right[0], Length(Left));
end;

constructor TFxFmp4Rebaser.Create();
begin

  inherited Create();
  FTrackOrigins := TDictionary<Cardinal, UInt64>.Create();
  FTrackOffsets := TDictionary<Cardinal, UInt64>.Create;
  FTrackEnds := TDictionary<Cardinal, UInt64>.Create;
  FTrackDurations := TDictionary<Cardinal, Cardinal>.Create;
  FContinuationValid := True;
end;


destructor TFxFmp4Rebaser.Destroy();
begin

  FTrackOrigins.Free();
  FTrackOffsets.Free;
  FTrackEnds.Free;
  FTrackDurations.Free;
  inherited Destroy();
end;


procedure TFxFmp4Rebaser.Reset();
begin

  FTrackOrigins.Clear();
  FTrackOffsets.Clear;
  FTrackEnds.Clear;
  FTrackDurations.Clear;
  FContinuationValid := True;
end;

procedure TFxFmp4Rebaser.SetInitialization(const AData: TBytes);
var Moov, MoovSize, Mvex, MvexSize, Trex, TrexSize, Cursor: Integer;
begin
  FTrackDurations.Clear;
  if not FindChild(AData, 0, Length(AData), $6D6F6F76, Moov, MoovSize) then Exit;
  if not FindChild(AData, Moov + 8, Moov + MoovSize, $6D766578, Mvex, MvexSize) then Exit;
  Cursor := Mvex + 8;
  while FindChild(AData, Cursor, Mvex + MvexSize, $74726578, Trex, TrexSize) do
    begin
      if TrexSize >= 32 then FTrackDurations.AddOrSetValue(ReadU32(AData, Trex + 12), ReadU32(AData, Trex + 20));
      Cursor := Trex + TrexSize;
    end;
end;

function TFxFmp4Rebaser.BeginContinuityEpoch(): Boolean;
var Pair: TPair<Cardinal, UInt64>;
begin
  Result := FContinuationValid and (FTrackEnds.Count > 0);
  if not Result then Exit;
  FTrackOrigins.Clear;
  FTrackOffsets.Clear;
  for Pair in FTrackEnds do FTrackOffsets.Add(Pair.Key, Pair.Value);
end;

function TFxFmp4Rebaser.TrafDuration(const AData: TBytes; AStart, AEnd: Integer): UInt64;
var Cursor, P, I, Header, Count, EntrySize, TotalSamples: Integer;
  Size, Kind, Flags, DefaultDuration, Duration, TrackId: Cardinal;
begin
  Result := 0; Cursor := AStart + 8; DefaultDuration := 0; TotalSamples := 0;
  while ValidBox(AData, Cursor, AEnd, Size, Kind) do
    begin
      if (Kind = BOX_TFHD) and (Size >= 16) then
        begin
          TrackId := ReadU32(AData, Cursor + 12);
          FTrackDurations.TryGetValue(TrackId, DefaultDuration);
          Flags := ReadU32(AData, Cursor + 8) and $FFFFFF;
          P := Cursor + 16;
          if (Flags and 1) <> 0 then Inc(P, 8);
          if (Flags and 2) <> 0 then Inc(P, 4);
          if ((Flags and 8) <> 0) and (P + 4 <= Cursor + Integer(Size)) then DefaultDuration := ReadU32(AData, P);
        end
      else if (Kind = $7472756E) and (Size >= 16) then
        begin
          Flags := ReadU32(AData, Cursor + 8) and $FFFFFF;
          Count := Integer(ReadU32(AData, Cursor + 12));
          if (Count < 0) or (Count > 1000000) then Exit(0);
          Inc(TotalSamples, Count);
          if TotalSamples > 1000000 then Exit(0);
          Header := 16;
          if (Flags and 1) <> 0 then Inc(Header, 4);
          if (Flags and 4) <> 0 then Inc(Header, 4);
          EntrySize := 0;
          if (Flags and $100) <> 0 then Inc(EntrySize, 4);
          if (Flags and $200) <> 0 then Inc(EntrySize, 4);
          if (Flags and $400) <> 0 then Inc(EntrySize, 4);
          if (Flags and $800) <> 0 then Inc(EntrySize, 4);
          if Int64(Header) + Int64(EntrySize) * Count > Size then Exit(0);
          P := Cursor + Header;
          for I := 1 to Count do
            begin
              Duration := DefaultDuration;
              if (Flags and $100) <> 0 then Duration := ReadU32(AData, P);
              if Duration = 0 then Exit(0);
              Inc(Result, Duration);
              Inc(P, EntrySize);
            end;
        end;
      Inc(Cursor, Integer(Size));
    end;
end;


function TFxFmp4Rebaser.Rebase(const AFragment: TBytes;
                                       out ARebasedFragment: TBytes): Boolean;
var
  Cursor: Integer;
  Size: Cardinal;
  BoxType: Cardinal;
  MoofEnd: Integer;
  TrafCursor: Integer;
  TrafSize: Cardinal;
  TrafType: Cardinal;
  TrafEnd: Integer;
  ChildCursor: Integer;
  ChildSize: Cardinal;
  ChildType: Cardinal;
  TrackId: Cardinal;
  Version: Byte;
  DecodeTime: UInt64;
  Origin: UInt64;
  OffsetTime, Duration: UInt64;
  PatchedCount: Integer;

begin

  ARebasedFragment := Copy(AFragment, 0, Length(AFragment));
  Cursor := 0;
  PatchedCount := 0;

  while ValidBox(ARebasedFragment,
                 Cursor,
                 Length(ARebasedFragment),
                 Size,
                 BoxType) do
    begin
      if BoxType = BOX_MOOF then
        begin
          MoofEnd := Cursor + Integer(Size);
          TrafCursor := Cursor + 8;
          while ValidBox(ARebasedFragment,
                         TrafCursor,
                         MoofEnd,
                         TrafSize,
                         TrafType) do
            begin
              if TrafType = BOX_TRAF then
                begin
                  TrackId := 0;
                  TrafEnd := TrafCursor + Integer(TrafSize);
                  ChildCursor := TrafCursor + 8;
                  while ValidBox(ARebasedFragment,
                                 ChildCursor,
                                 TrafEnd,
                                 ChildSize,
                                 ChildType) do
                    begin
                      if (ChildType = BOX_TFHD) and (ChildSize >= 16) then
                        TrackId := ReadU32(ARebasedFragment,
                                           ChildCursor + 12)
                      else if (ChildType = BOX_TFDT) and
                              (TrackId <> 0) and
                              (ChildSize >= 16) then
                        begin
                          Version := ARebasedFragment[ChildCursor + 8];
                          if Version = 1 then
                            DecodeTime := ReadU64(ARebasedFragment,
                                                  ChildCursor + 12)
                          else
                            DecodeTime := ReadU32(ARebasedFragment,
                                                  ChildCursor + 12);

                          if not FTrackOrigins.TryGetValue(TrackId, Origin) then
                            begin
                              Origin := DecodeTime;
                              FTrackOrigins.Add(TrackId, Origin);
                            end;

                          if DecodeTime >= Origin then
                            DecodeTime := DecodeTime - Origin
                          else
                            DecodeTime := 0;

                          OffsetTime := 0;
                          FTrackOffsets.TryGetValue(TrackId, OffsetTime);
                          Inc(DecodeTime, OffsetTime);
                          Duration := TrafDuration(ARebasedFragment, TrafCursor, TrafEnd);
                          if Duration = 0 then FContinuationValid := False;
                          FTrackEnds.AddOrSetValue(TrackId, DecodeTime + Duration);

                          if Version = 1 then
                            WriteU64(ARebasedFragment,
                                     ChildCursor + 12,
                                     DecodeTime)
                          else
                            WriteU32(ARebasedFragment,
                                     ChildCursor + 12,
                                     Cardinal(DecodeTime));
                          Inc(PatchedCount);
                        end;

                      Inc(ChildCursor,
                          Integer(ChildSize));
                    end;
                end;

              Inc(TrafCursor,
                  Integer(TrafSize));
            end;
        end;

      Inc(Cursor,
          Integer(Size));
    end;

  Result := PatchedCount > 0;
end;

end.

