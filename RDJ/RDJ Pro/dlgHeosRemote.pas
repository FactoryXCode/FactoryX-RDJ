// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: dlgHeosRemote.pas
// Kind: Pascal Unit
// Release date: 24-01-2026
// Language: ENU
//
// Revision Version: 4.0.0
// Description: Main remote GUI.
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
// 30/10/2026 Tony                Added HEOS support.
//------------------------------------------------------------------------------
//
// Remarks: Requires Windows 10 22h2 or higher.
//
// Related objects: RDJ Pro
// Related projects: MfPackX400
// Known Issues: -
//
// Compiler version: 23 up to 35
// SDK version: 10.0.28000.2705
//
// Todo: -
//
// =============================================================================
// Source: FactoryX.Code - RDJ Pro & FactoryX-HEOS-CLI
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
unit dlgHeosRemote;

interface

uses

  {System}
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  {Vcl}
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Vcl.Dialogs,
  Vcl.Imaging.jpeg,
  {Application}
  HEOSTransport,
  Heos,
  RDJ.HeosOutput,
  HEOSDiscovery,
  // Controls
  HEOSButton,
  HEOSTrackBar, MPxpButton;

type

  TReceiverAvailabilityProbe = class(TThread)
  private

    FHost: string;
    FAvailable: Boolean;
    FErrorText: string;

  protected

    procedure Execute(); override;

  public

    constructor Create(const Host: string);
    property Host: string read FHost;
    property Available: Boolean read FAvailable;
    property ErrorText: string read FErrorText;
  end;


  TRdjHeosRemoteForm = class(TForm)
    pnlSettings: TPanel;
    AddressLabel: TLabel;
    FStatus: TLabel;
    edHost: TEdit;
    cbxHEOSDevices: TComboBox;
    VolumeTimer: TTimer;
    StreamTimer: TTimer;
    pnlPlay: TPanel;
    lblStreamInfo: TLabel;
    Panel3: TPanel;
    imgLogo: TImage;
    btnSettings: TDnButton;
    btnPlayer: TDnButton;
    btnStreamRdjAudio: TDnButton;
    lblElapsed: TLabel;
    PcAddressLabel: TLabel;
    PcAddressEdit: TEdit;
    PortLabel: TLabel;
    StreamPortEdit: TEdit;
    btnFindHEOSDevice: TDnButton;
    tbVolume: TDnTrackBar;
    tbBalance: TDnTrackBar;
    lblBalance: TLabel;
    lblVolumePerc: TLabel;
    lblVol: TLabel;
    btnMainZone: TDnButton;
    btnZone2: TDnButton;
    Bevel2: TBevel;
    lblZones: TLabel;
    Bevel3: TBevel;
    btnMute: TDnButton;
    btnTone: TDnButton;
    tbBass: TDnTrackBar;
    tbTreble: TDnTrackBar;
    lblBass: TLabel;
    lblTreble: TLabel;
    lblToneStatus: TLabel;
    FSource: TComboBox;
    memFLog: TMemo;
    Label2: TLabel;
    Label3: TLabel;
    Bevel5: TBevel;
    btnSelectInput: TDnButton;
    btnWebInterface: TDnButton;
    btnReadStatus: TDnButton;
    Label1: TLabel;
    Bevel7: TBevel;
    Label4: TLabel;
    Label5: TLabel;
    btnMinimize: TMPxpButton;
    btnExit: TMPxpButton;
    lblAppTitle: TLabel;
    Bevel1: TBevel;

    procedure FormCreate(Sender: TObject);
    procedure FormHidden(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ActionClick(Sender: TObject);
    procedure VolumeChange(Sender: TObject);
    procedure VolumeTick(Sender: TObject);
    procedure BalanceChange(Sender: TObject);
    procedure BalanceDblClick(Sender: TObject);
    procedure ZoneClick(Sender: TObject);
    procedure BrowserClick(Sender: TObject);
    procedure StreamTick(Sender: TObject);
    procedure FindHEOSDeviceClick(Sender: TObject);
    procedure HEOSDeviceChange(Sender: TObject);
    procedure btnStreamRdjAudioClick(Sender: TObject);
    procedure SettingsClick(Sender: TObject);
    procedure PlayerClick(Sender: TObject);
    procedure tbVolumeDblClick(Sender: TObject);
    procedure ToneClick(Sender: TObject);
    procedure ToneChange(Sender: TObject);
    procedure ToneDblClick(Sender: TObject);
    procedure MainCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnMinimizeClick(Sender: TObject);
    procedure btnExitClick(Sender: TObject);
    procedure Panel3MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure lblAppTitleMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure imgLogoMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);

  private
    FWorker: TDenonRequest;
    FUpdatingTone: Boolean;
    FToneKnown: Boolean;
    FToneEnabled: Boolean;
    FDesiredToneEnabled: Boolean;
    FDesiredBass: Integer;
    FDesiredTreble: Integer;
    FTonePending: Boolean;
    FBassPending: Boolean;
    FTreblePending: Boolean;
    FToneReadPending: Boolean;
    FToneRequest: Boolean;
    FToneMode: string;
    FDynamicEq: Boolean;
    FPowerText: string;
    FZone2PowerText: string;
    FMainZonePending: Boolean;
    FMainZoneDesired: Boolean;
    FZone2Pending: Boolean;
    FZone2Desired: Boolean;
    FZoneReadPending: Boolean;
    FZoneRequest: Boolean;
    FZoneRequestKind: Integer;
    FZoneRequestTarget: Boolean;
    FStartupZoneReadAttempts: Integer;
    FExpectedPowerReply: string;
    FVolumeText: string;
    FVolumePending: Boolean;
    FVolumeReadPending: Boolean;
    FInitialVolumeRead: Boolean;
    FReceiverCheck: TReceiverAvailabilityProbe;
    FReceiverCheckReadAll: Boolean;
    FReceiverCheckDiscover: Boolean;
    FDiscoveryReconnect: Boolean;
    FDiscoveryReadAll: Boolean;
    FDiscoveryComplete: Boolean;
    FVolumeRequest: Boolean;
    FUpdatingVolume: Boolean;
    FVolumeReady: Boolean;
    FDesiredVolume: Integer;
    FBalancePending: Boolean;
    FBalanceReadPending: Boolean;
    FBalanceRequest: Boolean;
    FBalanceReadingBase: Boolean;
    FStartupBalanceReadAttempts: Integer;
    FBalanceKnown: Boolean;
    FUpdatingBalance: Boolean;
    FBalanceBaseHost: string;
    FBalanceBaseInput: string;
    FBalanceLeft: Integer;
    FBalanceRight: Integer;
    FBalanceReplyLeft: Integer;
    FBalanceReplyRight: Integer;
    FBalanceLeftReceived: Boolean;
    FBalanceRightReceived: Boolean;
    FDesiredBalance: Integer;
    FMuteText: string;
    FInputText: string;
    FDiscovery: THEOSDiscovery;
    FDevices: TArray<THEOSDevice>;
    FMasterOutput: TRdjHeosOutput;
    FMasterWaiting: Boolean;
    FMasterDesired: Boolean;
    FMasterStopPending: Boolean;
    FMasterIssued: Boolean;
    FMasterConfirmed: Boolean;
    FStreamStartedTick: UInt64;
    FOnVisibilityChanged: TNotifyEvent;
    FHeos: THeosRequest;
    FLastHeosAction: THeosAction;
    FStreamReceiver: string;

    procedure DiscoveryFinished(Sender: TObject);
    procedure BeginReceiverCheck(ReadAll: Boolean = False;
                                  Discover: Boolean = True);
    procedure BeginDiscovery(Reconnect: Boolean; ReadAll: Boolean);
    procedure CompleteReceiverCheck();
    procedure ProcessMasterStream();
    procedure SendHeos(Action: THeosAction; const Url: string = '');
    procedure UpdateStreamButtons();
    function ValidAddress(): Boolean;

    procedure StartRequest(const Commands: array of string;
                            const ExpectedPowerReply: string = '');

    procedure RequestFinished(Sender: TObject);
    procedure ParseStatus(const Line: string);
    procedure SetVolumeBusy(Busy: Boolean);
    procedure StartBalanceRequest();
    procedure StartToneRequest();
    procedure UpdateToneDisplay();
    procedure UpdateBalanceDisplay();

    procedure QueueZoneChange(MainZone: Boolean;
                              Active: Boolean);

    procedure StartZoneRequest();
    procedure UpdateZoneButtons();
    procedure RetryStartupZoneRead();
    function ReceiverActionsPending(): Boolean;
    function VolumeCaption(HalfSteps: Integer): string;

  public

    destructor Destroy(); override;

    procedure BindOutput(AOutput: TRdjHeosOutput);
    property OnVisibilityChanged: TNotifyEvent read FOnVisibilityChanged write FOnVisibilityChanged;
  end;

  function GetTickCount64(): UInt64; stdcall;

var
  HeosRemoteFrm: TRdjHeosRemoteForm;


implementation

{$R *.dfm}

uses

  {System}
  WinApi.Windows,
  WinApi.ShellAPI,
  WinApi.Messages,
  {System}
  System.StrUtils,
  {Application}
  HEOSSockets;

const

  Kernel32Lib = 'kernel32.dll';

  SourceCommands: array[0..7] of string = ('SITV',
                                           'SIBD',
                                           'SIGAME',
                                           'SIMPLAY',
                                           'SISAT/CBL',
                                           'SICD',
                                           'SITUNER',
                                           'SINET');

constructor TReceiverAvailabilityProbe.Create(const Host: string);
begin

  inherited Create(True);
  FreeOnTerminate := False;
  FHost := Host;
end;


procedure TReceiverAvailabilityProbe.Execute();
begin

  FAvailable := ProbeReceiver(FHost,
                                23,
                                2000,
                                FErrorText);
end;


procedure TRdjHeosRemoteForm.FormShow(Sender: TObject);
begin

  SetWindowLong(Handle,
                GWL_STYLE,
                GetWindowLong(Handle,
                              GWL_STYLE) and not WS_CAPTION or WS_BORDER);

  Width := Width - 10;
  Height := Height - 30;

  if FInitialVolumeRead then
    Exit;

  FInitialVolumeRead := True;
  BeginReceiverCheck();
end;


procedure TRdjHeosRemoteForm.BeginReceiverCheck(ReadAll: Boolean;
                                                Discover: Boolean);
begin

  if Assigned(FReceiverCheck) then
    Exit;

  if Assigned(FWorker) and not FWorker.Finished then
    Exit;

  if Assigned(FDiscovery) and not FDiscovery.Finished and
     not FDiscoveryComplete then
    Exit;

  FReceiverCheckReadAll := ReadAll;
  FReceiverCheckDiscover := Discover;
  FReceiverCheck := TReceiverAvailabilityProbe.Create(Trim(edHost.Text));
  VolumeTimer.Enabled := False;
  FStatus.Caption := 'Checking receiver availability ...';
  lblStreamInfo.Caption := FStatus.Caption;
  FReceiverCheck.Start;
end;


procedure TRdjHeosRemoteForm.CompleteReceiverCheck();
var
  Available: Boolean;
  Host: string;
  ErrorText: string;
  ReadAll: Boolean;

begin

  if not Assigned(FReceiverCheck) or not FReceiverCheck.Finished then
    Exit;

  Available := FReceiverCheck.Available;
  Host := FReceiverCheck.Host;
  ErrorText := FReceiverCheck.ErrorText;
  ReadAll := FReceiverCheckReadAll;
  FreeAndNil(FReceiverCheck);

  if (Host <> Trim(edHost.Text)) then
    begin

      BeginReceiverCheck(ReadAll);
      Exit;
    end;

  if not Available then
    begin

      FVolumePending := False;
      FVolumeReadPending := False;
      FBalancePending := False;
      FBalanceReadPending := False;
      FMainZonePending := False;
      FZone2Pending := False;
      FZoneReadPending := False;
      FTonePending := False;
      FBassPending := False;
      FTreblePending := False;
      FToneReadPending := False;
      VolumeTimer.Enabled := False;

      FStatus.Caption := 'Receiver unavailable at ' + Host + ':23. ' +
                         'Status read skipped. Check power, IP and Network Control; ' +
                         'click Read status to retry.';

      lblStreamInfo.Caption := FStatus.Caption;
      memFLog.Lines.Add('! ' + FStatus.Caption + ' ' + ErrorText);

      if FReceiverCheckDiscover then
        BeginDiscovery(True,
                       ReadAll);
      Exit;
    end;

  FStatus.Caption := 'Receiver available. Reading settings ...';
  lblStreamInfo.Caption := FStatus.Caption;
  FVolumeReadPending := True;
  FBalanceReadPending := True;
  FZoneReadPending := True;
  FToneReadPending := True;
  // The timer also leaves time for the receiver to release the probe socket.
  VolumeTimer.Enabled := True;

  if ReadAll then
    StartRequest(['PW?', 'ZM?', 'Z2?', 'MV?', 'MU?', 'SI?']);
end;


procedure TRdjHeosRemoteForm.tbVolumeDblClick(Sender: TObject);
begin

  tbVolume.AnimateTrackBarToPosition(0,
                                     2);
end;


procedure TRdjHeosRemoteForm.FindHEOSDEviceClick(Sender: TObject);
begin

  BeginDiscovery(False,
                 False);
end;


procedure TRdjHeosRemoteForm.BeginDiscovery(Reconnect: Boolean; ReadAll: Boolean);
begin

  if not edHost.Enabled or Assigned(FReceiverCheck) then
    Exit;

  if Assigned(FDiscovery) and not FDiscovery.Finished then
    Exit;

  FreeAndNil(FDiscovery);
  FDiscoveryComplete := False;
  FDiscoveryReconnect := Reconnect;
  FDiscoveryReadAll := ReadAll;
  btnFindHEOSDevice.Enabled := False;
  btnFindHEOSDevice.Caption := 'Searching ...';
  FStatus.Caption := 'Searching local network interfaces for HEOS devices ...';
  lblStreamInfo.Caption := FStatus.Caption;
  memFLog.Lines.Add(FStatus.Caption);
  FDiscovery := THEOSDiscovery.Create;
  FDiscovery.OnTerminate := DiscoveryFinished;
  FDiscovery.Start;
end;


procedure TRdjHeosRemoteForm.DiscoveryFinished(Sender: TObject);
var
  I: Integer;
  Selected: Integer;
  ReceiverCount: Integer;
  ReceiverIndex: Integer;
  Description: string;

begin

  FDiscoveryComplete := True;
  FDevices := Copy(FDiscovery.Devices);
  cbxHEOSDevices.Items.Clear();
  Selected := -1;
  ReceiverCount := 0;
  ReceiverIndex := -1;

  for I := 0 to Length(FDevices) - 1 do
    begin

      Description := FDevices[I].Name + ' - ' + FDevices[I].Address;
      if FDevices[I].AvrAvailable then
        begin

          Inc(ReceiverCount);
          ReceiverIndex := I;
          if (FDevices[I].Address = Trim(edHost.Text)) then
            Selected := I;
        end
      else
        Description := Description + ' (HEOS only; AVR control unavailable)';

      cbxHEOSDevices.Items.Add(Description);
      memFLog.Lines.Add('Found HEOS device: ' + Description + ' (' +
                        FDevices[I].Model + ')');
    end;

  if (ReceiverCount = 1) then
    Selected := ReceiverIndex;

  cbxHEOSDevices.Visible := Length(FDevices) > 0;
  cbxHEOSDevices.ItemIndex := Selected;
  btnFindHEOSDevice.Caption := 'Find HEOS';
  btnFindHEOSDevice.Enabled := True;

  if (Selected >= 0) then
    begin

      HEOSDeviceChange(cbxHEOSDevices);
      Exit;
    end;

  if (FDiscovery.ErrorText <> '') then
    FStatus.Caption := 'Discovery: ' + FDiscovery.ErrorText
  else
    if (Length(FDevices) = 0) then
      FStatus.Caption := 'No HEOS device replied. Check power, Network Control and the local network; enter the IP or click Read status to retry.'
    else
      if (ReceiverCount = 0) then
        FStatus.Caption := 'HEOS devices found, but AVR control is unavailable. Check receiver Network Control and power.'
      else
        FStatus.Caption := 'Several HEOS receivers found. Select the receiver in the list above.';

  lblStreamInfo.Caption := FStatus.Caption;
  memFLog.Lines.Add(FStatus.Caption);
  if (ReceiverCount = 0) then
    FDiscoveryReconnect := False;
end;


procedure TRdjHeosRemoteForm.HEOSDeviceChange(Sender: TObject);
var
  Index: Integer;

begin

  Index := cbxHEOSDevices.ItemIndex;
  if not edHost.Enabled or (Index < 0) or (Index >= Length(FDevices)) then
    Exit;

  if not FDevices[Index].AvrAvailable then
    begin

      FStatus.Caption := 'This HEOS device has no reachable AVR control port. Receiver IP was not changed.';
      lblStreamInfo.Caption := FStatus.Caption;
      memFLog.Lines.Add(FStatus.Caption);
      Exit;
    end;

  edHost.Text := FDevices[Index].Address;
  FStatus.Caption := 'HEOS receiver found. Receiver IP updated to ' + edHost.Text;
  lblStreamInfo.Caption := FStatus.Caption;
  memFLog.Lines.Add(FStatus.Caption);

  if FDiscoveryReconnect then
    begin

      FDiscoveryReconnect := False;
      // One recovery attempt; a receiver disappearing must not cause a scan loop.
      BeginReceiverCheck(FDiscoveryReadAll,
                         False);
    end;
end;


procedure TRdjHeosRemoteForm.imgLogoMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin

  // Drag window
  ReleaseCapture;
  SendMessage(Handle,
              WM_SYSCOMMAND,
              SC_MOVE + HTCAPTION,
              0);
end;


procedure TRdjHeosRemoteForm.lblAppTitleMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin

  // Drag window
  ReleaseCapture;
  SendMessage(Handle,
              WM_SYSCOMMAND,
              SC_MOVE + HTCAPTION,
              0);
end;


function TRdjHeosRemoteForm.ValidAddress(): Boolean;
var
  Parts: TArray<string>;
  Part: string;
  Value: Integer;
  I: Integer;

begin

  Result := False;
  Parts := Trim(edHost.Text).Split(['.']);

  if (Length(Parts) <> 4) then
    Exit;

  for Part in Parts do
    begin
      if (Length(Part) = 0) or (Length(Part) > 3) then
        Exit;

      for I := 1 to Length(Part) do
        if not CharInSet(Part[I],
                         ['0'..'9']) then
          Exit;

        if not TryStrToInt(Part,
                           Value) then
          Exit;

        if (Value < 0) or (Value > 255) then
          Exit;
    end;
  Result := True;
end;


procedure TRdjHeosRemoteForm.StartRequest(const Commands: array of string;
                                          const ExpectedPowerReply: string);
var
  Command: string;

begin

  if Assigned(FWorker) and (not FWorker.Finished) then
    Exit;

  if not ValidAddress then
    begin
      ShowMessage('Enter an IPv4 address, for example 192.168.50.103.');
      Exit;
    end;

  FreeAndNil(FWorker);
  FExpectedPowerReply := ExpectedPowerReply;
  FVolumeText := '?';
  FMuteText := '?';
  FInputText := '?';

  FWorker := TDenonRequest.Create(Trim(edHost.Text),
                                  Commands);

  FWorker.OnTerminate := RequestFinished;
  edHost.Enabled := False;
  btnFindHEOSDevice.Enabled := False;
  cbxHEOSDevices.Enabled := False;
  FStatus.Caption := 'Contacting ' + Trim(edHost.Text) + ':23 ...';
  memFLog.Lines.Add(FormatDateTime('hh:nn:ss',
                                   Now) + '  ' + FStatus.Caption);

  for Command in Commands do
    memFLog.Lines.Add('> ' + Command);

  FWorker.Start();
end;


function TRdjHeosRemoteForm.VolumeCaption(HalfSteps: Integer): string;
begin

  Result := IntToStr(HalfSteps div 2) + '.' + IntToStr((HalfSteps mod 2) * 5) + '%';
end;


procedure TRdjHeosRemoteForm.SetVolumeBusy(Busy: Boolean);
begin

  edHost.Enabled := not Busy;
  cbxHEOSDevices.Enabled := not Busy;
  btnFindHEOSDevice.Enabled := not Busy and (not Assigned(FDiscovery) or FDiscovery.Finished);

  if not Busy then
    UpdateStreamButtons();
end;


procedure TRdjHeosRemoteForm.VolumeChange(Sender: TObject);
begin

  if not FVolumeReady or FUpdatingVolume or (csLoading in ComponentState) then
    Exit;

  FDesiredVolume := tbVolume.Position;
  FVolumePending := True;
  lblVolumePerc.Caption := VolumeCaption(FDesiredVolume);
  VolumeTimer.Enabled := False;
  VolumeTimer.Enabled := True;
end;


procedure TRdjHeosRemoteForm.UpdateBalanceDisplay();
var
  Amount: Integer;
  Direction: string;

begin

  Amount := Abs(FDesiredBalance);

  if (FDesiredBalance = 0) then
    lblBalance.Caption := 'Balance: Centre'
  else
    begin
      if (FDesiredBalance < 0) then
        Direction := 'Left'
      else
        Direction := 'Right';

      lblBalance.Caption := 'Balance: ' + Direction + ' ' + IntToStr(Amount div 2) +
                              '.' + IntToStr((Amount mod 2) * 5) + ' dB';
    end;

end;


procedure TRdjHeosRemoteForm.BalanceChange(Sender: TObject);
begin

  if not FVolumeReady or FUpdatingBalance or (csLoading in ComponentState) then
    Exit;

  FDesiredBalance := tbBalance.Position;
  FBalancePending := True;
  UpdateBalanceDisplay();
  VolumeTimer.Enabled := False;
  VolumeTimer.Enabled := True;
end;


procedure TRdjHeosRemoteForm.BalanceDblClick(Sender: TObject);
begin

  tbBalance.AnimateTrackBarToPosition(0,
                                      2);
end;


procedure TRdjHeosRemoteForm.UpdateToneDisplay();
var
  Available: Boolean;

  function ToneCaption(const Name: string; Value: Integer): string;
  begin

    Result := Name + ': ';

    if (Value > 0) then
      Result := Result + '+';

    Result := Result + IntToStr(Value) + ' dB';
  end;

begin

  FUpdatingTone := True;

  try
    if not FTonePending then
      btnTone.Checked := FToneEnabled;

    lblBass.Caption := ToneCaption('Bass',
                                   tbBass.Position);

    lblTreble.Caption := ToneCaption('Treble',
                                     tbTreble.Position);
    Available := (FPowerText = 'On') and
                  FToneKnown and not
                  ContainsText(FToneMode,
                               'DIRECT') and not
                  FDynamicEq;

    btnTone.Enabled := Available;
    tbBass.Enabled := Available and FToneEnabled and
                        not (FTonePending and not FDesiredToneEnabled);
    tbTreble.Enabled := tbBass.Enabled;

    if (FPowerText <> 'On') then
      lblToneStatus.Caption := 'Activate Main Zone to adjust tone.'
    else
      if ContainsText(FToneMode,
                      'DIRECT') then
        lblToneStatus.Caption := 'Tone is unavailable in Direct / Pure Direct mode.'
      else
        if FDynamicEq then
          lblToneStatus.Caption := 'Tone is unavailable while Dynamic EQ is on.'
      else
        if not FToneKnown then
          lblToneStatus.Caption := 'Reading receiver tone settings ...'
        else
          if not FToneEnabled then
            lblToneStatus.Caption := 'Enable Tone to adjust bass and treble.'
          else
            lblToneStatus.Caption := 'Bass / treble: -6 to +6 dB. Double-click for 0 dB.';

  finally
    FUpdatingTone := False;
  end;
end;


procedure TRdjHeosRemoteForm.ToneClick(Sender: TObject);
begin

  if FUpdatingTone or not FVolumeReady then
    Exit;

  FDesiredToneEnabled := btnTone.Checked;
  FTonePending := True;

  if not FDesiredToneEnabled then
    begin
      FBassPending := False;
      FTreblePending := False;
    end;

  UpdateToneDisplay();
  VolumeTimer.Enabled := True;
end;


procedure TRdjHeosRemoteForm.ToneChange(Sender: TObject);
begin

  if FUpdatingTone or not FVolumeReady or (csLoading in ComponentState) then
    Exit;

  if (Sender = tbBass) then
    begin
      FDesiredBass := tbBass.Position;
      FBassPending := True;
    end
  else
    if (Sender = tbTreble) then
      begin
        FDesiredTreble := tbTreble.Position;
        FTreblePending := True;
      end
    else
      Exit;

  UpdateToneDisplay();
  VolumeTimer.Enabled := False;
  VolumeTimer.Enabled := True;
end;


procedure TRdjHeosRemoteForm.ToneDblClick(Sender: TObject);
begin

  if (Sender = tbBass) then
    tbBass.Position := 0
  else
    if (Sender = tbTreble) then
    tbTreble.Position := 0;
end;


procedure TRdjHeosRemoteForm.StartToneRequest();
var
  Commands: TList<string>;
  Command: string;

begin

  Commands := TList<string>.Create;
  try
    if FTonePending then
      if FDesiredToneEnabled then
        Commands.Add('PSTONE CTRL ON')
      else
        Commands.Add('PSTONE CTRL OFF');

    if FBassPending then
      Commands.Add('PSBAS ' + Format('%.2d',
                                     [50 + FDesiredBass]));

    if FTreblePending then
      Commands.Add('PSTRE ' + Format('%.2d',
                                     [50 + FDesiredTreble]));

    Commands.Add('MS?');
    Commands.Add('PSDYNEQ ?');
    Commands.Add('PSTONE CTRL ?');
    Commands.Add('PSBAS ?');
    Commands.Add('PSTRE ?');

    FreeAndNil(FWorker);
    FExpectedPowerReply := '';
    FWorker := TDenonRequest.Create(Trim(edHost.Text),
                                    Commands.ToArray,
                                    23,
                                    False,
                                    False,
                                    False,
                                    True);

    FToneRequest := True;
    FTonePending := False;
    FBassPending := False;
    FTreblePending := False;
    FToneReadPending := False;
    FWorker.OnTerminate := RequestFinished;
    FStatus.Caption := 'Updating receiver tone settings ...';

    for Command in Commands do
      memFLog.Lines.Add('> ' + Command);

    SetVolumeBusy(True);
    VolumeTimer.Enabled := ReceiverActionsPending();
    FWorker.Start();

  finally
    Commands.Free;
  end;
end;


procedure TRdjHeosRemoteForm.StartBalanceRequest();
var
  Left: Integer;
  Right: Integer;
  LeftCommand: string;
  RightCommand: string;

  //Helper
  function ChannelValue(HalfSteps: Integer): string;
  begin
    if (HalfSteps < 76) then
      HalfSteps := 76;

    if (HalfSteps > 124) then
      HalfSteps := 124;

    Result := Format('%.2d',
                     [HalfSteps div 2]);

    if (HalfSteps mod 2 <> 0) then
      Result := Result + '5';
  end;

begin

  FreeAndNil(FWorker);
  FExpectedPowerReply := '';
  FBalanceRequest := True;
  FBalanceLeftReceived := False;
  FBalanceRightReceived := False;
  FBalanceReadingBase := not FBalanceKnown or FBalanceReadPending or (FBalanceBaseHost <> Trim(edHost.Text));
  FBalanceReadPending := False;

  if FBalanceReadingBase then
    begin
      Inc(FStartupBalanceReadAttempts);
      FWorker := TDenonRequest.Create(Trim(edHost.Text),
                                      ['SI?',
                                      'CV?'],
                                      23,
                                      False,
                                      True);

      FStatus.Caption := 'Reading front channel levels ...';
      memFLog.Lines.Add('> SI?');
      memFLog.Lines.Add('> CV?');
    end
  else
    begin
      Left := FBalanceLeft;
      Right := FBalanceRight;

      if (FDesiredBalance > 0) then
        Dec(Left,
            FDesiredBalance)
      else
        Inc(Right,
            FDesiredBalance);

      LeftCommand := 'CVFL ' + ChannelValue(Left);
      RightCommand := 'CVFR ' + ChannelValue(Right);

      FWorker := TDenonRequest.Create(Trim(edHost.Text),
                                      [LeftCommand,
                                       RightCommand,
                                       'CV?'],
                                      23,
                                      False,
                                      True);

      FBalancePending := False;
      FStatus.Caption := 'Setting receiver balance ...';
      memFLog.Lines.Add('> ' + LeftCommand);
      memFLog.Lines.Add('> ' + RightCommand);
      memFLog.Lines.Add('> CV?');
    end;

  FWorker.OnTerminate := RequestFinished;
  SetVolumeBusy(True);
  VolumeTimer.Enabled := ReceiverActionsPending();
  FWorker.Start();
end;


function TRdjHeosRemoteForm.ReceiverActionsPending(): Boolean;
begin

  Result := FVolumePending or
            FVolumeReadPending or
            FBalancePending or
            FBalanceReadPending or
            FMainZonePending or
            FZone2Pending or
            FZoneReadPending or
            FTonePending or
            FBassPending or
            FTreblePending or
            FToneReadPending;
end;


procedure TRdjHeosRemoteForm.UpdateZoneButtons();
begin

  if FMainZonePending then
    btnMainZone.Checked := FMainZoneDesired
  else
    if FZoneRequest and (FZoneRequestKind = 1) then
      btnMainZone.Checked := FZoneRequestTarget
    else
      btnMainZone.Checked := FPowerText = 'On';

  if FZone2Pending then
    btnZone2.Checked := FZone2Desired
  else
    if FZoneRequest and (FZoneRequestKind = 2) then
      btnZone2.Checked := FZoneRequestTarget
    else
      btnZone2.Checked := FZone2PowerText = 'On';
end;


procedure TRdjHeosRemoteForm.ZoneClick(Sender: TObject);
begin

  if (Sender = btnMainZone) then
    QueueZoneChange(True,
                    btnMainZone.Checked)
  else
    if (Sender = btnZone2) then
      QueueZoneChange(False,
                      btnZone2.Checked);
end;


procedure TRdjHeosRemoteForm.RetryStartupZoneRead();
begin

  if ((FPowerText = '?') or (FZone2PowerText = '?')) and
     (FStartupZoneReadAttempts < 3) then
    begin
      FZoneReadPending := True;

      if (FVolumeText = '?') then
        FVolumeReadPending := True;

      VolumeTimer.Enabled := True;
    end;
end;


procedure TRdjHeosRemoteForm.QueueZoneChange(MainZone: Boolean; Active: Boolean);
begin

  if MainZone then
    begin
      FMainZoneDesired := Active;
      FMainZonePending := True;

    end
  else
    begin
      FZone2Desired := Active;
      FZone2Pending := True;
    end;

  UpdateZoneButtons();
  VolumeTimer.Enabled := True;
  VolumeTick(nil);
end;


procedure TRdjHeosRemoteForm.StartZoneRequest();
var
  Command: string;
  Commands: TArray<string>;

begin

  Command := '';
  FZoneRequestKind := 0;

  if FMainZonePending then
    begin
      FMainZonePending := False;
      FZoneRequestKind := 1;
      FZoneRequestTarget := FMainZoneDesired;
      if FZoneRequestTarget then
        Command := 'ZMON'
      else
        Command := 'ZMOFF';
    end
  else
    if FZone2Pending then
      begin
        FZone2Pending := False;
        FZoneRequestKind := 2;
        FZoneRequestTarget := FZone2Desired;

        if FZoneRequestTarget then
          Command := 'Z2ON'
        else
          Command := 'Z2OFF';
      end;

  FZoneReadPending := False;

  if (Command = '') then
    begin
      Inc(FStartupZoneReadAttempts);
      Commands := TArray<string>.Create('ZM?',
                                        'Z2?');
    end
  else
    Commands := TArray<string>.Create(Command,
                                      'ZM?',
                                      'Z2?');

  FreeAndNil(FWorker);
  FExpectedPowerReply := Command;
  FZoneRequest := True;

  FWorker := TDenonRequest.Create(Trim(edHost.Text),
                                  Commands,
                                  23,
                                  False,
                                  False,
                                  True);

  FWorker.OnTerminate := RequestFinished;
  SetVolumeBusy(True);
  FStatus.Caption := 'Updating receiver zones ...';

  for Command in Commands do
    memFLog.Lines.Add('> ' + Command);

  UpdateZoneButtons();
  VolumeTimer.Enabled := ReceiverActionsPending();
  FWorker.Start();
end;


procedure TRdjHeosRemoteForm.VolumeTick(Sender: TObject);
var
  Command: string;

begin

  if Assigned(FReceiverCheck) or FDiscoveryReconnect then
    begin

      VolumeTimer.Enabled := False;
      Exit;
    end;

  if not ReceiverActionsPending() then
    begin
      VolumeTimer.Enabled := False;
      Exit;
    end;

  if Assigned(FWorker) and not FWorker.Finished then
    Exit;

  VolumeTimer.Enabled := False;

  if not ValidAddress() then
    begin
      FVolumePending := False;
      FVolumeReadPending := False;
      FBalancePending := False;
      FBalanceReadPending := False;
      FMainZonePending := False;
      FZone2Pending := False;
      FZoneReadPending := False;
      FTonePending := False;
      FBassPending := False;
      FTreblePending := False;
      FToneReadPending := False;
      UpdateZoneButtons();
      FStatus.Caption := 'Enter a valid receiver IPv4 address before setting volume.';
      Exit;
    end;

  if FMainZonePending or FZone2Pending or (FZoneReadPending and not FVolumeReadPending) then
    begin
      StartZoneRequest();
      Exit;
    end;

  if not FVolumePending and not FVolumeReadPending then
    begin
      if FBalancePending or FBalanceReadPending then
        StartBalanceRequest()
      else
        StartToneRequest();
      Exit;
    end;

  FreeAndNil(FWorker);
  FExpectedPowerReply := '';
  FVolumeRequest := True;

  if FVolumePending then
    begin
      Command := 'MV' + Format('%.2d',
                               [FDesiredVolume div 2]);

      if (FDesiredVolume mod 2 <> 0) then
        Command := Command + '5';

      FWorker := TDenonRequest.Create(Trim(edHost.Text),
                                      [Command,
                                      'MV?'],
                                      23,
                                      True);

      FStatus.Caption := 'Setting volume to ' + VolumeCaption(FDesiredVolume) + ' ...';
      memFLog.Lines.Add('> ' + Command);
    end
  else
    begin
      if FZoneReadPending then
        begin
          Inc(FStartupZoneReadAttempts);
          FWorker := TDenonRequest.Create(Trim(edHost.Text),
                                          ['ZM?',
                                           'Z2?',
                                           'MV?'],
                                          23,
                                          True,
                                          False,
                                          True);

          FZoneReadPending := False;
          FStatus.Caption := 'Reading receiver volume and zone states ...';
          memFLog.Lines.Add('> ZM?');
          memFLog.Lines.Add('> Z2?');
        end
      else
        begin
          FWorker := TDenonRequest.Create(Trim(edHost.Text),
                                          ['MV?'],
                                          23,
                                          True);

          FStatus.Caption := 'Reading receiver volume ...';
        end;
      memFLog.Lines.Add('> MV?');
    end;

  FVolumePending := False;
  FVolumeReadPending := False;
  VolumeTimer.Enabled := ReceiverActionsPending();
  FWorker.OnTerminate := RequestFinished;
  SetVolumeBusy(True);
  FWorker.Start();
end;


procedure TRdjHeosRemoteForm.ActionClick(Sender: TObject);
var
  Command: string;

begin

  if not (Sender is TComponent) then
    Exit;

  case TComponent(Sender).Tag of
    0: begin
         BeginReceiverCheck(True);
         Exit;
       end;
    1: begin
         QueueZoneChange(True,
                         True);
         Exit;
       end;
    2: begin
         QueueZoneChange(True,
                         False);
         Exit;
       end;
    5: begin
         if (Sender = btnMute) and not btnMute.Checked then
           Command := 'MUOFF'
         else
           Command := 'MUON';
       end;
    6: Command := 'MUOFF';
    8: begin
         QueueZoneChange(False,
                         True);
         Exit;
       end;
    9: begin
         QueueZoneChange(False,
                         False);
         Exit;
       end;
    7: begin
         if (FSource.ItemIndex < Low(SourceCommands)) or (FSource.ItemIndex > High(SourceCommands)) then
           Exit;

         Command := SourceCommands[FSource.ItemIndex];
       end;
  else
    Exit;
  end;

  StartRequest([Command,
                'ZM?',
                'Z2?',
                'MV?',
                'MU?',
                'SI?']);
end;


procedure TRdjHeosRemoteForm.RequestFinished(Sender: TObject);
var
  Line: string;
  PowerConfirmed: Boolean;

begin

  PowerConfirmed := (FExpectedPowerReply = '');

  for Line in FWorker.Lines do
    begin
      memFLog.Lines.Add('< ' + Line);
      ParseStatus(Line);

      if (Line = FExpectedPowerReply) then
        PowerConfirmed := True;
    end;

  RetryStartupZoneRead();

  if FToneRequest then
    begin
      FToneRequest := False;
      UpdateToneDisplay();
      if (FWorker.ErrorText <> '') then
        begin
          lblToneStatus.Caption := FWorker.ErrorText;
          memFLog.Lines.Add('! Tone: ' + FWorker.ErrorText);
        end;

      SetVolumeBusy(False);
      VolumeTimer.Enabled := ReceiverActionsPending();
      Exit;
    end;

  if FZoneRequest then
    begin
      FZoneRequest := False;
      UpdateZoneButtons();
      SetVolumeBusy(False);

      if (FWorker.ErrorText <> '') then
        begin
          FStatus.Caption := FWorker.ErrorText;
          memFLog.Lines.Add('! Zones: ' + FWorker.ErrorText);
        end
      else
        if not PowerConfirmed then
          begin
            FStatus.Caption := 'Receiver did not confirm the requested zone change.';
            memFLog.Lines.Add('! Zone change not confirmed: ' + FExpectedPowerReply);
          end
        else
          FStatus.Caption := 'Receiver zone states updated.';

      VolumeTimer.Enabled := ReceiverActionsPending();
      Exit;
    end;

  UpdateZoneButtons();

  if FBalanceRequest then
    begin
      FBalanceRequest := False;

      if (FWorker.ErrorText = '') and FBalanceLeftReceived and FBalanceRightReceived then
        begin
          if FBalanceReadingBase then
            begin

              // A centred balance has equal channel levels. Keep the louder
              // channel as the reference so the reported balance is reproduced.
              FBalanceLeft := FBalanceReplyLeft;

              if (FBalanceReplyRight > FBalanceLeft) then
                FBalanceLeft := FBalanceReplyRight;
              FBalanceRight := FBalanceLeft;
              FBalanceBaseHost := Trim(edHost.Text);
              FBalanceBaseInput := FInputText;
              FBalanceKnown := True;

              if not FBalancePending then
                begin
                  FDesiredBalance := FBalanceReplyRight - FBalanceReplyLeft;
                  if (FDesiredBalance < tbBalance.Minimum) then
                    FDesiredBalance := tbBalance.Minimum;
                  if (FDesiredBalance > tbBalance.Maximum) then
                    FDesiredBalance := tbBalance.Maximum;
                  FUpdatingBalance := True;

                  try
                    tbBalance.Position := FDesiredBalance;
                  finally
                    FUpdatingBalance := False;
                  end;

                  UpdateBalanceDisplay();
                end;
            end;
          FStatus.Caption := 'Receiver balance updated.';
        end
      else
        begin
          if FBalanceReadingBase and (FStartupBalanceReadAttempts < 3) then
            FBalanceReadPending := True
          else
            FBalancePending := False;

          if (FWorker.ErrorText <> '') then
            FStatus.Caption := FWorker.ErrorText
          else
            FStatus.Caption := 'Receiver did not return valid front channel levels.';

          memFLog.Lines.Add('! Balance: ' + FStatus.Caption);
        end;

      SetVolumeBusy(False);
      VolumeTimer.Enabled := ReceiverActionsPending();
      Exit;
    end;

  if FVolumeRequest then
    begin
      FVolumeRequest := False;
      SetVolumeBusy(False);

      if (FWorker.ErrorText <> '') then
        begin
          FStatus.Caption := FWorker.ErrorText;
          memFLog.Lines.Add('! ' + FWorker.ErrorText);
        end
      else
        FStatus.Caption := 'Receiver volume: ' + FVolumeText;
      VolumeTimer.Enabled := ReceiverActionsPending();
      Exit;
    end;

  if (FWorker.ErrorText <> '') then
    begin
      FStatus.Caption := FWorker.ErrorText;
      memFLog.Lines.Add('! ' + FWorker.ErrorText);
    end
  else
    if not PowerConfirmed then
      begin
        FStatus.Caption := 'Receiver replied, but the requested power change was not confirmed. Click Read status to check.';
        memFLog.Lines.Add('! Power change not confirmed: ' + FExpectedPowerReply);
      end
    else
      FStatus.Caption := 'Reply received at ' + FormatDateTime('hh:nn:ss',
                                                               Now) + '. Values below reflect receiver replies; click Read status to refresh.';
  pnlPlay.Enabled := True;
  edHost.Enabled := True;
  btnFindHEOSDevice.Enabled := not Assigned(FDiscovery) or FDiscovery.Finished;
  cbxHEOSDevices.Enabled := True;
end;


procedure TRdjHeosRemoteForm.Panel3MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin

  // Drag window
  ReleaseCapture;
  SendMessage(Handle,
              WM_SYSCOMMAND,
              SC_MOVE + HTCAPTION,
              0);
end;


procedure TRdjHeosRemoteForm.ParseStatus(const Line: string);
var
  Raw: string;
  Value: Integer;
  HalfSteps: Integer;

begin

  if (Line = 'PSTONE CTRL ON') or (Line = 'PSTONE CTRL OFF') then
    begin
      FToneKnown := True;
      FToneEnabled := Line = 'PSTONE CTRL ON';
      UpdateToneDisplay();
      Exit;
    end;

  if StartsText('PSBAS ',
                Line) or StartsText('PSTRE ',
                                    Line) then
    begin
      if TryStrToInt(Copy(Line,
                          7,
                          MaxInt), Value) and (Value >= 44) and (Value <= 56) then
        begin
          FUpdatingTone := True;

          try
            if StartsText('PSBAS ',
                          Line) then
              begin
                if not FBassPending then
                  tbBass.Position := Value - 50;
              end
            else
              if not FTreblePending then
              tbTreble.Position := Value - 50;

          finally
            FUpdatingTone := False;
          end;
          UpdateToneDisplay();
        end;
      Exit;
    end;

  if StartsText('MS', Line) then
    begin
      FToneMode := Copy(Line, 3, MaxInt);
      UpdateToneDisplay();
      Exit;
    end;

  if (Line = 'PSDYNEQ ON') or (Line = 'PSDYNEQ OFF') then
    begin
      FDynamicEq := Line = 'PSDYNEQ ON';
      UpdateToneDisplay();
      Exit;
    end;

  if (Copy(Line,
           1,
           5) = 'CVFL ') or (Copy(Line,
                                  1,
                                  5) = 'CVFR ') then
    begin
      Raw := Copy(Line,
                  6,
                  MaxInt);

      if not TryStrToInt(Raw, Value) then
        Exit;

      if Length(Raw) = 2 then
        HalfSteps := Value * 2
      else
        if (Length(Raw) = 3) and (Value mod 5 = 0) then
          HalfSteps := Value div 5
        else
          Exit;

      if (HalfSteps < 76) or (HalfSteps > 124) then
        Exit;

      if Copy(Line,
              1,
              5) = 'CVFL ' then
        begin
          FBalanceReplyLeft := HalfSteps;
          FBalanceLeftReceived := True;
        end
      else
        begin
          FBalanceReplyRight := HalfSteps;
          FBalanceRightReceived := True;
        end;

      Exit;
    end;

  if (Line = 'ZMON') then
    begin
      if (FPowerText <> 'On') then
        begin
          FToneReadPending := True;
          VolumeTimer.Enabled := True;
        end;
      FPowerText := 'On';
      UpdateToneDisplay();
    end
  else
    if (Line = 'ZMOFF') then
      begin
        FPowerText := 'Standby';
        UpdateToneDisplay();
      end;

  if (Line = 'Z2ON') then
    FZone2PowerText := 'On'
  else
    if (Line = 'Z2OFF') then
      FZone2PowerText := 'Standby';

  if (Line = 'MUON') then
    begin
      FMuteText := 'On';
      btnMute.Checked := True;
    end
  else
    if (Line = 'MUOFF') then
      begin
        FMuteText := 'Off';
        btnMute.Checked := False;
      end;

  if StartsText('SI', Line) then
    begin
      if (FInputText <> Copy(Line,
                             3,
                             MaxInt)) then
        begin
          FToneKnown := False;
          FTonePending := False;
          FBassPending := False;
          FTreblePending := False;
          FToneReadPending := True;
          VolumeTimer.Enabled := True;
          UpdateToneDisplay();
        end;
      FInputText := Copy(Line, 3, MaxInt);

      if FBalanceKnown and (FInputText <> FBalanceBaseInput) then
        begin
          FBalanceKnown := False;
          FStartupBalanceReadAttempts := 0;
          FBalancePending := False;
          FBalanceReadPending := True;
          VolumeTimer.Enabled := True;
        end;
    end;

  if StartsText('MVMAX ', Line) then
    begin
      Raw := Trim(Copy(Line, 7, MaxInt));

      if ((Length(Raw) = 2) or (Length(Raw) = 3)) and
         TryStrToInt(Raw, Value) then
        begin
          if (Length(Raw) = 2) then
            HalfSteps := Value * 2
          else
            if (Value mod 5 = 0) then
              HalfSteps := Value div 5
            else
              Exit;

          if (HalfSteps <= 0) or (HalfSteps > 196) then
            Exit;

          FUpdatingVolume := True;

          try
            tbVolume.Maximum := HalfSteps;

            if (FDesiredVolume > HalfSteps) then
              FDesiredVolume := HalfSteps;
            lblVolumePerc.Caption := VolumeCaption(tbVolume.Position);

          finally
            FUpdatingVolume := False;
          end;
        end;
      Exit;
    end;

  if StartsText('MV',
                Line) and (not StartsText('MVMAX',
                                          Line)) then
    begin

      Raw := Copy(Line,
                  3,
                  MaxInt);

      if ((Length(Raw) = 2) or (Length(Raw) = 3)) and TryStrToInt(Raw,
                                                                  Value) then
        begin
          if (Length(Raw) = 3) then
            begin
              if (Value mod 5 <> 0) then
                Exit;
              HalfSteps := Value div 5;
            end
          else
            HalfSteps := Value * 2;

          if (HalfSteps < 0) or (HalfSteps > 196) then
            Exit;

          FVolumeText := VolumeCaption(HalfSteps);

          if not FVolumePending then
            begin
              FUpdatingVolume := True;

              try
                tbVolume.Position := HalfSteps;
                lblVolumePerc.Caption := FVolumeText;

              finally
                FUpdatingVolume := False;
              end;
            end;
        end;
    end;
end;


procedure TRdjHeosRemoteForm.BrowserClick(Sender: TObject);
var
  URL: string;

begin

  if not ValidAddress then
    begin
      ShowMessage('Enter a valid receiver IPv4 address first.');
      Exit;
    end;

  URL := 'http://' + Trim(edHost.Text);

  if (ShellExecute(Handle,
                   'open',
                   PChar(URL),
                   nil,
                   nil,
                   SW_SHOWNORMAL) <= 32) then
    ShowMessage('Windows could not open the browser. Open ' + URL + ' manually.');
end;


procedure TRdjHeosRemoteForm.SettingsClick(Sender: TObject);
begin

  pnlPlay.Visible := False;
  pnlSettings.Visible := True;
  pnlSettings.BringToFront;
end;


procedure TRdjHeosRemoteForm.PlayerClick(Sender: TObject);
begin

  pnlSettings.Visible := False;
  pnlPlay.Visible := True;
  pnlPlay.BringToFront;
end;


procedure TRdjHeosRemoteForm.FormCreate(Sender: TObject);
begin

  PlayerClick(Self);
  FPowerText := '?';
  FZone2PowerText := '?';
  UpdateZoneButtons();
  FVolumeText := '?';
  lblVolumePerc.Caption := '--';
  lblBalance.Caption := 'Balance: --';
  FMuteText := '?';
  FInputText := '?';
  FVolumeReady := True;
  UpdateToneDisplay();
  UpdateStreamButtons();
end;


destructor TRdjHeosRemoteForm.Destroy();
begin

  StreamTimer.Enabled := False;
  VolumeTimer.Enabled := False;

  if Assigned(FReceiverCheck) then
    begin
      FReceiverCheck.Terminate;
      FReceiverCheck.WaitFor;
      FreeAndNil(FReceiverCheck);
    end;

  if Assigned(FDiscovery) then
    begin
      FDiscovery.OnTerminate := nil;
      FDiscovery.Terminate;
      FDiscovery.WaitFor;
      FreeAndNil(FDiscovery);
    end;

  if Assigned(FHeos) then
    begin
      FHeos.Terminate;
      FHeos.WaitFor;
      FreeAndNil(FHeos);
    end;

  if Assigned(FMasterOutput) then
    FMasterOutput.Stop();

  if Assigned(FWorker) then
    begin
      FWorker.OnTerminate := nil;
      FWorker.Terminate;
      FWorker.WaitFor;
      FreeAndNil(FWorker);
    end;
  inherited;
end;


procedure TRdjHeosRemoteForm.BindOutput(AOutput: TRdjHeosOutput);
begin

  FMasterOutput := AOutput;
  UpdateStreamButtons();
end;


procedure TRdjHeosRemoteForm.FormHidden(Sender: TObject);
begin

  if Assigned(FOnVisibilityChanged) then
    FOnVisibilityChanged(Self);
end;


procedure TRdjHeosRemoteForm.MainCloseQuery(Sender: TObject; var CanClose: Boolean);
begin

  CanClose := False;
  Hide;
end;


procedure TRdjHeosRemoteForm.btnExitClick(Sender: TObject);
begin

  Close();
end;


procedure TRdjHeosRemoteForm.btnMinimizeClick(Sender: TObject);
begin

  WindowState := wsMinimized;
end;


procedure TRdjHeosRemoteForm.btnStreamRdjAudioClick(Sender: TObject);
begin

  FMasterDesired := not FMasterDesired;

  if not FMasterDesired then
    begin
      FMasterStopPending := FMasterIssued;
      FMasterWaiting := False;

      if Assigned(FMasterOutput) then
        FMasterOutput.Stop();
    end;

  ProcessMasterStream();
  UpdateStreamButtons();
end;


procedure TRdjHeosRemoteForm.SendHeos(Action: THeosAction; const Url: string);
begin

  FLastHeosAction := Action;
  FHeos := THeosRequest.Create(FStreamReceiver, Action, Url);

  if (Action = haPlayUrl) then
    FMasterIssued := True;

  // Poll completion from StreamTimer; no callback destroys its own request.
  FHeos.Start;
end;


procedure TRdjHeosRemoteForm.ProcessMasterStream();
var
  Port: Integer;
  Text: string;

begin

  try
    if Assigned(FHeos) then
      begin
        if not FHeos.Finished then
          Exit;

        try
          if (FHeos.ErrorText <> '') then
            begin
              memFLog.Lines.Add('! HEOS: ' + FHeos.ErrorText);
              lblStreamInfo.Caption := FHeos.ErrorText;

              if (FLastHeosAction = haPlayUrl) then
                begin
                  FMasterDesired := False;
                  FMasterStopPending := FMasterIssued;
                  FMasterWaiting := False;
                  FMasterConfirmed := False;
                  FMasterOutput.Stop();
                end;
            end
          else
            begin
              memFLog.Lines.Add('HEOS: ' + FHeos.Summary);

              if (FLastHeosAction = haPlayUrl) and FMasterDesired then
                begin
                  FMasterConfirmed := True;
                  FStreamStartedTick := GetTickCount64();
                end;
            end;

          if (FLastHeosAction = haStop) then
            begin
              FMasterIssued := False;
              FMasterConfirmed := False;
              FStreamReceiver := '';
            end;
        finally
          FreeAndNil(FHeos);
        end;
      end;

    if FMasterStopPending then
      begin
        FMasterStopPending := False;

        if (FStreamReceiver <> '') then
          SendHeos(haStop);
        Exit;
      end;

    if not FMasterDesired then
      Exit;

    if not Assigned(FMasterOutput) then
      raise EInvalidOperation.Create('The RDJ Masterdeck output is not attached.');

    if not FMasterOutput.Active() then
      begin
        if not ValidAddress() then
          raise EInvalidOperation.Create('Enter a valid receiver IPv4 address.');

        if not TryStrToInt(StreamPortEdit.Text, Port) or (Port < 1024) or (Port > 65535) then
          raise EInvalidOperation.Create('Choose a streaming port between 1024 and 65535.');

        FStreamReceiver := Trim(edHost.Text);

        FMasterOutput.Start(FStreamReceiver,
                            Port,
                            Trim(PcAddressEdit.Text));

        FMasterWaiting := True;
        FMasterConfirmed := False;
        lblElapsed.Caption := 'Elapsed: 00:00:00';
        lblStreamInfo.Caption := 'Starting RDJ Masterdeck output...';
        memFLog.Lines.Add(lblStreamInfo.Caption);
      end;

    Text := FMasterOutput.ErrorText();

    if (Text <> '') then
      raise EInvalidOperation.Create(Text);

   if FMasterWaiting and FMasterOutput.Ready() then
      begin
        FMasterWaiting := False;
        memFLog.Lines.Add('Masterdeck URL: ' + FMasterOutput.Url());

        SendHeos(haPlayUrl,
                 FMasterOutput.Url());
      end;

    if FMasterConfirmed then
      lblStreamInfo.Caption := Format('RDJ Masterdeck | HTTP requests: %d | Dropped blocks: %d',
                                      [FMasterOutput.Requests(), FMasterOutput.DroppedBlocks()]);
  except
    on E: Exception do
      begin
        FMasterDesired := False;
        FMasterWaiting := False;
        FMasterConfirmed := False;
        FMasterStopPending := FMasterIssued;
        if Assigned(FMasterOutput) then
          FMasterOutput.Stop();
        memFLog.Lines.Add('! Masterdeck: ' + E.Message);
        lblStreamInfo.Caption := E.Message;
      end;
  end;
end;


procedure TRdjHeosRemoteForm.UpdateStreamButtons();
begin

  btnStreamRdjAudio.Enabled := Assigned(FMasterOutput);
  btnStreamRdjAudio.Checked := FMasterDesired;
end;


procedure TRdjHeosRemoteForm.StreamTick(Sender: TObject);
var
  Seconds: UInt64;

begin

  CompleteReceiverCheck();
  ProcessMasterStream();
  UpdateStreamButtons();
  if FMasterConfirmed and Assigned(FMasterOutput) and FMasterOutput.Active() and
     (FMasterOutput.Requests() > 0) then
    begin
      Seconds := (GetTickCount64() - FStreamStartedTick) div 1000;
      lblElapsed.Caption := Format('Elapsed: %.2d:%.2d:%.2d',
                                    [Seconds div 3600, (Seconds div 60) mod 60, Seconds mod 60]);
    end;
end;


function GetTickCount64; external Kernel32Lib name 'GetTickCount64';

end.
