"""Build a native harness from the actual mirror class, without RDJ UI/devices.

Usage: python mirror_regression.py source.pas output.dpr
The extracted class and file helpers are unchanged; this avoids maintaining a
second implementation of the publishing queue in the regression tests.
"""
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8-sig")
types = source[source.index("  TRdjProMseMirrorJobKind ="):source.index("  TfrmMediaServer = class")]
helpers = source[source.index("function RDJEnsureDirectoryExists("):source.index("function RDJReadUtf8TextFile(")]
start = source.find("destructor TRdjProMseMirrorJob.Destroy;")
if start < 0:
    start = source.index("constructor TRdjProMseMirrorThread.Create(")
methods = source[start:source.index("procedure TfrmMediaServer.btnMinimizeClick(")]
header = '''program MirrorChecks;
{$APPTYPE CONSOLE}
uses Winapi.Windows, Winapi.ShlObj, System.SysUtils, System.Classes,
  System.SyncObjs, System.Math, System.IOUtils, RDJ.RdjPro.MirrorPlaylist;
const
  RDJ_MSE_KEEP_PATCHED_FRAGMENTS_DEFAULT = 24;
  RDJ_MSE_KEEP_PATCHED_FRAGMENTS_MIN = 12;
  RDJ_MSE_KEEP_PATCHED_FRAGMENTS_MAX = 48;
  RDJ_MSE_MIRROR_ACCOUNTANT_ENABLED = True;
  RDJ_MSE_MIRROR_CLEANUP_SAFETY_FRAGMENTS = 2;
  RDJ_MSE_MIRROR_ORPHAN_SCAN_INTERVAL_MS = 60000;
type
'''
tests = r'''
type
  TIdleMirror = class(TRdjProMseMirrorThread)
    procedure Execute; override;
  end;
procedure TIdleMirror.Execute;
begin end;
procedure Require(Value: Boolean; const Message: string);
begin if not Value then raise Exception.Create(Message) end;

var Worker: TRdjProMseMirrorThread; Idle: TIdleMirror;
  Root, LocalFile, RemoteFile, Playlist, Safe, Json: string;
  Data: TBytes; I: Integer; Job: TRdjProMseMirrorJob;
  HandlesBefore, HandlesAfter: DWORD;
begin
  try
    Root := TPath.Combine(ExtractFilePath(ParamStr(0)),
      'MirrorChecks-' + IntToStr(GetCurrentProcessId));
    ForceDirectories(Root);
    LocalFile := TPath.Combine(Root, 'source.m4s');
    RemoteFile := TPath.Combine(Root, 'outpatched_frag_000001.m4s');
    Data := TEncoding.UTF8.GetBytes('retained local media data');
    TFile.WriteAllBytes(LocalFile, Data);
    Worker := TRdjProMseMirrorThread.Create;
    try
      // Hold the real worker while the producer expires its local filename.
      Worker.FLock.Acquire;
      try
        Worker.EnqueueCopy(LocalFile, RemoteFile);
        Require(Winapi.Windows.DeleteFile(PChar(LocalFile)), 'Local rolling cleanup could not delete');
      finally Worker.FLock.Release end;
      for I := 1 to 100 do
      begin
        if FileExists(RemoteFile) then Break;
        Sleep(20);
      end;
      Worker.StopAndWait;
      Require(FileExists(RemoteFile), 'Queued media was lost when its local filename expired');
      Require(TFile.ReadAllText(RemoteFile) = 'retained local media data', 'Copied payload differs');
      Require(Worker.FatalException = nil, 'Worker exception');
    finally Worker.Free end;
    Writeln('PASS: actual worker copies media after local rolling deletion.');

    Idle := TIdleMirror.Create;
    try
      Idle.WaitFor;
      for I := 1 to 1000 do
        Idle.EnqueueWrite(TPath.Combine(Root, 'live.m3u8'), TEncoding.UTF8.GetBytes(IntToStr(I)));
      Require(Idle.QueueCount = 1, 'Superseded HLS updates accumulated');
      Idle.EnqueueWrite(TPath.Combine(Root, 'patched_frag_000001.m4s'), Data);
      Job := Idle.PopJob;
      try Require(Pos('patched_frag_', ExtractFileName(Job.FileName)) = 1, 'Playlist took priority over media')
      finally Job.Free end;
      Job := Idle.PopJob;
      try Require(TEncoding.UTF8.GetString(Job.Bytes) = '1000', 'Latest playlist was lost')
      finally Job.Free end;
      Idle.AdvanceMirroredPatchedSeq(1);
      Idle.AdvanceMirroredPatchedSeq(3);
      Require(Idle.FLastMirroredPatchedSeq = 3, 'Manifest froze at a short copy gap');
      Json := '{"first":1,"last":8,"keepBehind":48}';
      Require(Idle.BuildSafeLiveJson(Json, 3, Safe), 'Safe JSON unavailable');
      Require(Idle.ExtractJsonInteger(Safe, 'first', 0) = 3, 'Safe JSON advertises a missing fragment');
    finally Idle.Free end;
    Writeln('PASS: playlist coalescing, media priority, short-gap recovery and safe JSON.');

    Playlist := '#EXTM3U' + sLineBreak + '#EXT-X-VERSION:7' + sLineBreak +
      '#EXT-X-MEDIA-SEQUENCE:1' + sLineBreak + '#EXT-X-MAP:URI="init.mp4"' + sLineBreak;
    for I := 1 to 5 do
      Playlist := Playlist + '#EXT-X-PROGRAM-DATE-TIME:2026-10-15T20:00:00Z' + sLineBreak +
        '#EXTINF:1.000,' + sLineBreak + Format('patched_frag_%.6d.m4s?session=test', [I]) + sLineBreak;
    Safe := RdjSafeMirrorPlaylist(Playlist, 3, 4);
    Require(Pos('#EXT-X-MEDIA-SEQUENCE:3', Safe) > 0, 'HLS first sequence wrong');
    Require((Pos('000003.m4s', Safe) > 0) and (Pos('000004.m4s', Safe) > 0), 'HLS lost available media');
    Require((Pos('000001.m4s', Safe) = 0) and (Pos('000005.m4s', Safe) = 0), 'HLS advertises unavailable media');
    Require(RdjSafeMirrorPlaylist(Playlist, 9, 10) = '', 'Disjoint HLS window accepted');
    Writeln('PASS: safe HLS ranges and session query strings.');
    TFile.WriteAllBytes(LocalFile, Data);
    Idle := TIdleMirror.Create(4);
    try
      Idle.WaitFor;
      Require(GetProcessHandleCount(GetCurrentProcess, HandlesBefore), 'Cannot count source handles');
      for I := 1 to 20 do
        Idle.EnqueueCopy(LocalFile, TPath.Combine(Root, Format('patched_frag_%.6d.m4s', [I])));
      Require(Idle.QueueCount = 4, 'Media queue exceeded its cap');
      Require(GetProcessHandleCount(GetCurrentProcess, HandlesAfter), 'Cannot count retained handles');
      Require(HandlesAfter = HandlesBefore + 4, 'Dropped jobs leaked source handles');
      while Idle.QueueCount > 0 do
      begin
        Job := Idle.PopJob;
        Job.Free;
      end;
      Require(GetProcessHandleCount(GetCurrentProcess, HandlesAfter), 'Cannot count released handles');
      Require(HandlesAfter = HandlesBefore, 'Completed jobs leaked source handles');
    finally Idle.Free end;
    Writeln('PASS: bounded retained-file queue and source handle release.');
    Writeln('OUTPUT=' + Root);
  except on E: Exception do begin Writeln('FAIL: ' + E.Message); Halt(1) end end;
end.
'''
Path(sys.argv[2]).write_text(header + types + helpers + methods + tests, encoding="utf-8")
