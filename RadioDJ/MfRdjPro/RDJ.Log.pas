// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: RDJ.Log.pas
// Kind: Pascal Unit
// Release date: 24-01-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Diagnostics logging unit.
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
//          Keep the diagnostic hooks in place, but do not produce log output during
//          normal operation. Set RDJ_LOGGING_ENABLED to True temporarily when diagnostics are needed.
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
// Source: FactoryX.Code.
// =============================================================================
//
// LICENSE
//
// The contents of this file are subject to the Mozilla Public License
// Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// https://www.mozilla.org/en-US/MPL/2.0/
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
unit RDJ.Log;

interface

uses

  {System}
  System.SysUtils;

  function RDJLogFileName(): string;

  procedure RDJLog(const ACategory: string;
                   const AMessage: string);

  procedure RDJLogFmt(const ACategory: string;
                      const AFormat: string;
                      const AArgs: array of const);

implementation

uses

  {WinApi}
  WinApi.Windows,
  {System}
  System.Classes,
  System.IOUtils;

var
  GLogLock: TRTLCriticalSection;
  GLogLockInitialized: Boolean = False;

const
  // Keep the diagnostic hooks in place, but do not produce log output during
  // normal operation. Set this to True temporarily when diagnostics are needed.
  RDJ_LOGGING_ENABLED = False;
  RDJ_LOG_MAX_BYTES = 25 * 1024 * 1024;


function RDJExistingFileSize(const AFileName: string): Int64;
var
  SearchRec: TSearchRec;

begin

  Result := -1;
  if (FindFirst(AFileName,
                faAnyFile,
                SearchRec) = 0) then
    try
      Result := SearchRec.Size;
    finally
      System.SysUtils.FindClose(SearchRec);
    end;
end;


function RDJLogFileName(): string;
var
  BaseDir: string;

begin

  BaseDir := Trim(GetEnvironmentVariable('LOCALAPPDATA'));
  if (BaseDir = '') then
    BaseDir := ExtractFilePath(ParamStr(0));

  Result := TPath.Combine(BaseDir,
                          'RDJ Pro\Logs\RDJPro.log');
end;


procedure RDJLog(const ACategory: string;
                 const AMessage: string);
var
  FileName: string;
  LogDir: string;
  PreviousFileName: string;
  Line: string;
  Utf8: UTF8String;
  Stream: TFileStream;

begin

  if not RDJ_LOGGING_ENABLED then
    Exit;

  Line := Format('%s | PID=%d TID=%d | %-14s | %s%s',
                 [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
                  GetCurrentProcessId(),
                  GetCurrentThreadId(),
                  Copy(Trim(ACategory), 1, 14),
                  AMessage,
                  sLineBreak]);

  OutputDebugString(PChar(TrimRight(Line)));

  if not GLogLockInitialized then
    Exit;

  EnterCriticalSection(GLogLock);

  try
    try
      FileName := RDJLogFileName();
      LogDir := ExtractFilePath(FileName);
      if not DirectoryExists(LogDir) then
        ForceDirectories(LogDir);

      if FileExists(FileName) and
         (RDJExistingFileSize(FileName) >= RDJ_LOG_MAX_BYTES) then
        begin
          PreviousFileName := TPath.Combine(LogDir,
                                            'RDJPro.previous.log');
          if FileExists(PreviousFileName) then
            DeleteFileW(PWideChar(PreviousFileName));
          MoveFileW(PWideChar(FileName),
                    PWideChar(PreviousFileName));
        end;

      if FileExists(FileName) then
        Stream := TFileStream.Create(FileName,
                                     fmOpenReadWrite or fmShareDenyNone)
      else
        Stream := TFileStream.Create(FileName,
                                     fmCreate or fmShareDenyNone);

      try
        Stream.Seek(0,
                    soFromEnd);
        Utf8 := UTF8String(Line);
        if Length(Utf8) > 0 then
          Stream.WriteBuffer(Utf8[1],
                             Length(Utf8));
      finally
        Stream.Free;
      end;
    except
      // Logging must never prevent RDJ Pro from starting or shutting down.
    end;
  finally
    LeaveCriticalSection(GLogLock);
  end;
end;


procedure RDJLogFmt(const ACategory: string;
                    const AFormat: string;
                    const AArgs: array of const);
begin

  if not RDJ_LOGGING_ENABLED then
    Exit;

  RDJLog(ACategory,
         Format(AFormat,
                AArgs));
end;


initialization
  InitializeCriticalSection(GLogLock);
  GLogLockInitialized := True;

finalization
  GLogLockInitialized := False;
  DeleteCriticalSection(GLogLock);

end.
