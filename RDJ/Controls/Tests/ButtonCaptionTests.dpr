// FactoryX
//
// Copyright:  FactoryX. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: ButtonCaptionTests.dpr
// Kind: Pascal Unit Component
// Release date: 24-01-2019
// Language: ENU
//
// Version: 4.0.0
// Description: Caption repaint regression checks for MPxp and HEOS buttons.
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
// Remarks: To install the visual components, choose Install in the Project Manager.
//          Requires Windows 10 or later.
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
// Source: FactoryX.code
//
// Copyright (c) FactoryX. All rights reserved.
//==============================================================================
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
program ButtonCaptionTests;

{$APPTYPE CONSOLE}

uses

  WinApi.Windows,
  WinApi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Graphics,
  HEOSButton,
  MPxpButton;

type

  TButtonAccess = class(TCustomControl)
  public
    property Font;
    property Caption;
  end;

  TButtonProbe = class
  private
    FButton: TWinControl;
    FPrevious: TWndMethod;
    procedure WindowMessage(var Message: TMessage);
  public
    Invalidations: Integer;
    constructor Create(Button: TWinControl);
    destructor Destroy(); override;
  end;

constructor TButtonProbe.Create(Button: TWinControl);
begin

  inherited Create;
  FButton := Button;
  FPrevious := Button.WindowProc;
  Button.WindowProc := WindowMessage;
end;


destructor TButtonProbe.Destroy();
begin

  FButton.WindowProc := FPrevious;
  inherited;
end;


procedure TButtonProbe.WindowMessage(var Message: TMessage);
begin

  if (Message.Msg = CM_INVALIDATE) and (Message.WParam = 0) then
    Inc(Invalidations);
  FPrevious(Message);
end;


procedure Require(Value: Boolean;
                  const Text: string);
begin

  if not Value then
    raise Exception.Create(Text);
end;


function CountColor(Button: TWinControl;
                    Color: TColor;
                    const FileName: string): Integer;
var
  Bitmap: TBitmap;
  X: Integer;
  Y: Integer;

begin

  Result := 0;
  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Button.Width, Button.Height);
    Button.PaintTo(Bitmap.Canvas.Handle, 0, 0);
    for Y := 9 to Bitmap.Height - 10 do
      for X := 12 to Bitmap.Width - 13 do
        if ColorToRGB(Bitmap.Canvas.Pixels[X, Y]) = ColorToRGB(Color) then
          Inc(Result);
    if (FileName <> '') then
      Bitmap.SaveToFile(FileName);
  finally
    Bitmap.Free;
  end;
end;


function Check(Button: TWinControl;
               const Name: string): Boolean;
var
  Probe: TButtonProbe;
  White: Integer;
  Gray: Integer;

begin

  Button.SetBounds(0, 0, 220, 64);
  TButtonAccess(Button).Caption := 'CAPTION';
  TButtonAccess(Button).Font.Name := 'Arial';
  TButtonAccess(Button).Font.Size := 18;
  TButtonAccess(Button).Font.Style := [fsBold];
  TButtonAccess(Button).Font.Color := clWhite;
  TButtonAccess(Button).Font.Quality := fqNonAntialiased;
  Button.HandleNeeded;

  Probe := TButtonProbe.Create(Button);
  try
    Button.Enabled := True;
    White := CountColor(Button, clWhite, ParamStr(1) + Name + '-initial.bmp');
    Require(White > 50, Name + ': initial enabled caption is not white');
    Button.Enabled := False;
    Gray := CountColor(Button, clGray, ParamStr(1) + Name + '-disabled.bmp');
    Require(Gray > 50, Name + ': disabled caption is not gray');
    Require(TButtonAccess(Button).Font.Color = clWhite,
              Name + ': disabled painting modified the configured Font');
    Probe.Invalidations := 0;
    Button.Enabled := True;
    Result := Probe.Invalidations > 0;
    Require(IsWindowEnabled(Button.Handle), Name + ': native window remained disabled');
    White := CountColor(Button, clWhite, ParamStr(1) + Name + '-enabled.bmp');
    Require(White > 50, Name + ': enabled painting did not restore white text');
    Writeln(Name, ': enable schedules repaint=', Result,
              ', white pixels=', White, ', disabled gray pixels=', Gray);

    Probe.Invalidations := 0;
    Button.Enabled := False;
    Result := (Probe.Invalidations > 0) and Result;
    Require(not IsWindowEnabled(Button.Handle), Name + ': native window remained enabled');
    TButtonAccess(Button).Font.Color := clAqua;
    Button.Enabled := True;
    Require(CountColor(Button, clAqua, '') > 50,
              Name + ': re-enabling lost the configured caption color');
    Button.Enabled := False;
    Require(CountColor(Button, clGray, '') > 50,
              Name + ': a custom caption color bypassed disabled gray text');
    Require(TButtonAccess(Button).Font.Color = clAqua,
              Name + ': disabled painting changed the custom caption font');
  finally
    Probe.Free;
  end;
end;

var
  Form: TForm;
  Dn: TDnButton;
  Mpx: TMPxpButton;
  DnPassed: Boolean;
  MpxPassed: Boolean;

begin

  try
    Application.Initialize;
    Form := TForm.Create(nil);
    try
      Form.HandleNeeded;
      Dn := TDnButton.Create(Form);
      Dn.Parent := Form;
      Dn.Color := clBlack;
      Dn.ColorWhenUp := clBlack;
      Dn.LightColor := clBlack;
      Dn.ShadowColor := clBlack;
      Dn.Style := HEOSButton.bsModern;
      Mpx := TMPxpButton.Create(Form);
      Mpx.Parent := Form;
      Mpx.Color := clBlack;
      Mpx.ColorWhenUp := clBlack;
      Mpx.LightColor := clBlack;
      Mpx.ShadowColor := clBlack;
      Mpx.Style := MPxpButton.bsModern;
      DnPassed := Check(Dn, 'TDnButton');
      MpxPassed := Check(Mpx, 'TMPxpButton');
      Dn.WordWrap := True;
      Mpx.WordWrap := True;
      DnPassed := Check(Dn, 'TDnButton-wordwrap') and DnPassed;
      MpxPassed := Check(Mpx, 'TMPxpButton-wordwrap') and MpxPassed;
      Require(DnPassed and MpxPassed,
                'Enabled state changes did not repaint the custom button captions');
    finally
      Form.Free;
    end;
    Writeln('PASS initial caption, enable/disable repaint without hover and configured Font preservation.');
  except
    on E: Exception do
      begin
        Writeln(E.Message);
        Halt(1);
      end;
  end;
end.
