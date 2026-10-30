// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: HEOS Remote.
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: HeosStartupReferenceTests.dpr
// Kind: Pascal Unit
// Release date: 24-01-2026
// Language: ENU
//
// Revision Version: 1.0.0.1
// Description: Regression test for the RDJ and HEOS startup reference collision.
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
// Remarks: Requires Windows 10 22H2 or higher.
//          Please, read documentation carefully!
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
program HeosStartupReferenceTests;

{$APPTYPE CONSOLE}

uses

  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  // Keep the HEOS window after frmMainMDI to verify the main-form reference.
  frmMainMDI,
  dlgHeosRemote;

type

  TStartupProbe = class(TForm)
  public

    constructor Create(AOwner: TComponent); override;
  end;

constructor TStartupProbe.Create(AOwner: TComponent);
begin

  inherited CreateNew(AOwner);
end;

var

  Probe: TForm;

begin

  try
    if (Pointer(@MainMDIFrm) <> Pointer(@frmMainMDI.MainMDIFrm)) then
      raise Exception.Create('MainMDIFrm does not resolve to RDJ.');

    Application.Initialize;
    // Exercise CreateForm's untyped var reference without opening audio devices.
    Application.CreateForm(TStartupProbe, frmMainMDI.MainMDIFrm);
    Probe := TForm(frmMainMDI.MainMDIFrm);
    try
      if not Assigned(Probe) or (Probe.ClassType <> TStartupProbe) then
        raise Exception.Create('VCL startup did not initialize the RDJ form reference.');
    finally
      Probe.Free;
      frmMainMDI.MainMDIFrm := nil;
    end;
    Writeln('PASS startup resolves and initializes the RDJ main-form global independently of the HEOS window.');
  except
    on E: Exception do
      begin
        Writeln(E.ClassName + ': ' + E.Message);
        Halt(1);
      end;
  end;
end.
