// FactoryX. Licensed under the Mozilla Public License 2.0.
unit RDJ.BroadcastHeartbeat;

interface

uses

  WinApi.Windows,
  System.Classes;

type

  TRdjBroadcastHeartbeat = class(TThread)
  private
    FBaseDir: string;
    FLockDir: string;
    FStatusFile: string;
    FOwnerId: string;
    FJson: string;
    FWasConnectionLost: Boolean;
    FReacquiredLock: Boolean;
    FConflict: Boolean;
    FErrorText: string;
    FWriteError: string;
    function GetCompleted(): Boolean;
    function WriteJson(const AFileName: string): Boolean;
  protected
    procedure Execute(); override;
    procedure UpdateHeartbeat(); virtual;
  public
    constructor Create(const ABaseDir: string;
                         const ALockDir: string;
                         const AStatusFile: string;
                         const AOwnerId: string;
                         const AJson: string;
                         const AWasConnectionLost: Boolean);
    destructor Destroy(); override;
    property Completed: Boolean read GetCompleted;
    property OwnerId: string read FOwnerId;
    property Conflict: Boolean read FConflict;
    property ReacquiredLock: Boolean read FReacquiredLock;
    property ErrorText: string read FErrorText;
  end;

function CancelBroadcastHeartbeatIo(AThread: THandle): BOOL; stdcall;

implementation

uses

  System.SysUtils,
  System.IOUtils,
  System.JSON;


constructor TRdjBroadcastHeartbeat.Create(const ABaseDir: string;
                                           const ALockDir: string;
                                           const AStatusFile: string;
                                           const AOwnerId: string;
                                           const AJson: string;
                                           const AWasConnectionLost: Boolean);
begin

  inherited Create(True);
  FreeOnTerminate := False;
  FBaseDir := ABaseDir;
  FLockDir := ALockDir;
  FStatusFile := AStatusFile;
  FOwnerId := AOwnerId;
  FJson := AJson;
  FWasConnectionLost := AWasConnectionLost;
end;


destructor TRdjBroadcastHeartbeat.Destroy();
begin

  Terminate();

  if not Suspended then
    begin
      CancelBroadcastHeartbeatIo(Handle);
      WaitFor();
    end;

  inherited;
end;


function TRdjBroadcastHeartbeat.GetCompleted(): Boolean;
begin

  Result := (WaitForSingleObject(Handle, 0) = WAIT_OBJECT_0);
end;


function TRdjBroadcastHeartbeat.WriteJson(const AFileName: string): Boolean;
var
  TempFile: string;
  Stream: TFileStream;
  Bytes: TBytes;
  ErrorCode: DWORD;
  I: Integer;

begin

  Result := False;
  FWriteError := '';

  if Terminated then
    Exit;

  TempFile := AFileName + Format('.tmp_%x_%x',
                                  [GetCurrentProcessId(), GetCurrentThreadId()]);
  try
    try
      Bytes := TEncoding.UTF8.GetBytes(FJson);
      Stream := TFileStream.Create(TempFile,
                                     fmCreate or fmShareDenyWrite);
      try
        if (Length(Bytes) > 0) then
          Stream.WriteBuffer(Bytes[0], Length(Bytes));
      finally
        Stream.Free();
      end;

      for I := 0 to 20 do
        begin
          if Terminated then
            Exit;

          if MoveFileEx(PChar(TempFile),
                          PChar(AFileName),
                          MOVEFILE_REPLACE_EXISTING) then
            Exit(True);

          ErrorCode := GetLastError();
          FWriteError := 'Cannot update ' + AFileName + ': ' + SysErrorMessage(ErrorCode);
          Sleep(5);
        end;
    finally
      if FileExists(TempFile) then
        DeleteFile(TempFile);
    end;
  except
    on E: Exception do
      FWriteError := E.ClassName + ': ' + E.Message;
  end;
end;


procedure TRdjBroadcastHeartbeat.UpdateHeartbeat();
var
  OwnerFile: string;
  OwnerJson: TJSONValue;
  OwnerValue: TJSONValue;
  CurrentOwner: string;
  OwnerText: string;

begin

  if not DirectoryExists(FBaseDir) then
    begin
      FErrorText := 'Broadcast server path is unavailable: ' + FBaseDir;
      Exit;
    end;

  if Terminated then
    Exit;

  if not DirectoryExists(FLockDir) then
    begin
      if not FWasConnectionLost then
        begin
          FErrorText := 'The broadcast lock disappeared from the server.';
          Exit;
        end;

      if not CreateDir(FLockDir) then
        begin
          FErrorText := 'The broadcast server is reachable, but the broadcast lock cannot be reacquired.';
          Exit;
        end;

      FReacquiredLock := True;
    end
  else
    begin
      OwnerFile := TPath.Combine(FLockDir, 'owner.json');

      if not FileExists(OwnerFile) then
        begin
          FErrorText := 'The broadcast lock owner file is temporarily unavailable.';
          Exit;
        end;

      CurrentOwner := '';
      OwnerText := TEncoding.UTF8.GetString(TFile.ReadAllBytes(OwnerFile));

      if (Length(OwnerText) > 0) and (OwnerText[1] = #$FEFF) then
        Delete(OwnerText, 1, 1);

      OwnerJson := TJSONObject.ParseJSONValue(OwnerText);
      try
        if (OwnerJson is TJSONObject) then
          begin
            OwnerValue := TJSONObject(OwnerJson).GetValue('ownerId');

            if (OwnerValue is TJSONString) then
              CurrentOwner := OwnerValue.Value;
          end;
      finally
        OwnerJson.Free();
      end;

      if (CurrentOwner = '') then
        begin
          FErrorText := 'The broadcast lock owner cannot be read from the server.';
          Exit;
        end;

      if not SameText(CurrentOwner, FOwnerId) then
        begin
          FConflict := True;
          Exit;
        end;
    end;

  if Terminated then
    Exit;

  if not WriteJson(TPath.Combine(FLockDir, 'owner.json')) then
    begin
      FErrorText := FWriteError;

      if (FErrorText = '') then
        FErrorText := 'Cannot update the broadcast lock.';
      Exit;
    end;

  // As before, a failed public status write does not invalidate ownership.
  if (FStatusFile <> '') and (not Terminated) then
    WriteJson(FStatusFile);
end;


procedure TRdjBroadcastHeartbeat.Execute();
begin

  try
    if not Terminated then
      UpdateHeartbeat();
  except
    on E: Exception do
      FErrorText := E.ClassName + ': ' + E.Message;
  end;
end;

function CancelBroadcastHeartbeatIo; external 'kernel32.dll' name 'CancelSynchronousIo';

end.
