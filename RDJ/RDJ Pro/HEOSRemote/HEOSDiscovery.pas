// FactoryX
//
// Copyright: FactoryX. All rights reserved.
//
// Project: Media Foundation - MFPack - Samples
// Project location: https://sourceforge.net/projects/MFPack
//                   https://github.com/FactoryXCode/MfPack
// Module: HEOSDiscovery.pas
// Kind: Pascal Unit
// Release date: 24-01-2026
// Language: ENU
//
// Revision Version: 1.0.0.1
// Description: Native SSDP discovery for HEOS network devices.
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
unit HEOSDiscovery;

interface

uses

  {WinApi}
  WinApi.Windows,
  {System}
  System.Classes,
  System.SysUtils;

type
  THEOSDevice = record
    Address: string;
    Name: string;
    Model: string;
    AvrAvailable: Boolean;
  end;

  THEOSDiscovery = class(TThread)
  private
    FDevices: TArray<THEOSDevice>;
    FError: string;

  protected
    procedure Execute(); override;

  public
    constructor Create();

    property Devices: TArray<THEOSDevice> read FDevices;
    property ErrorText: string read FError;
  end;

  function SsdpLocation(const Response: string): string;
  function ParseHEOSDescription(const Xml: string;
                                const Address: string;
                                out Device: THEOSDevice): Boolean;

implementation

uses
  {WinApi}
  WinApi.WinSock,
  WinApi.WinInet,
  {System}
  System.StrUtils,
  System.Diagnostics,
  System.Generics.Collections,
  {Application}
  HEOSSockets;

function SsdpLocation(const Response: string): string;
var
  Line: string;
begin

  Result := '';
  if not StartsText('HTTP/1.1 200', Response) then
    Exit;

  for Line in Response.Split([#10]) do
    if StartsText('LOCATION:', Trim(Line)) then
      Exit(Trim(Copy(Trim(Line), 10, MaxInt)));
end;

function XmlText(const Xml, Tag: string): string;
var
  StartAt: Integer;
  EndAt: Integer;
  Lower: string;
begin

  Result := '';
  Lower := LowerCase(Xml);
  StartAt := Pos('<' + LowerCase(Tag) + '>', Lower);
  if StartAt = 0 then
    Exit;

  Inc(StartAt, Length(Tag) + 2);
  EndAt := PosEx('</' + LowerCase(Tag) + '>', Lower, StartAt);
  if EndAt <= StartAt then
    Exit;

  Result := Trim(Copy(Xml, StartAt, EndAt - StartAt));
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
end;

function ParseHEOSDescription(const Xml: string;
                               const Address: string;
                               out Device: THEOSDevice): Boolean;
var
  Description: string;
begin

  Device := Default(THEOSDevice);
  Description := LowerCase(Xml);
  Device.Model := XmlText(Xml, 'modelName');
  Result := IPv4Valid(Address) and
            (Pos('urn:schemas-denon-com:device:act-denon:1', Description) > 0);
  if not Result then
    Exit;

  Device.Address := Address;
  Device.Name := XmlText(Xml, 'friendlyName');
  if Device.Name = '' then
    Device.Name := Device.Model;
end;


function FetchDescription(const Url: string): string;
var
  Session: HINTERNET;
  Request: HINTERNET;
  Timeout: DWORD;
  Count: DWORD;
  Buffer: array[0..4095] of Byte;
  Data: TBytes;
  OldLength: Integer;
  Clock: TStopwatch;

begin

  Result := '';
  Session := InternetOpen('DenonRemote',
                          INTERNET_OPEN_TYPE_DIRECT,
                          nil,
                          nil,
                          0);
  if (Session = nil) then
    Exit;
  try
    Clock := TStopwatch.StartNew;
    Timeout := 1200;

    InternetSetOption(Session,
                      INTERNET_OPTION_CONNECT_TIMEOUT,
                      @Timeout,
                      SizeOf(Timeout));

    InternetSetOption(Session,
                      INTERNET_OPTION_RECEIVE_TIMEOUT,
                      @Timeout,
                      SizeOf(Timeout));

    InternetSetOption(Session,
                      INTERNET_OPTION_SEND_TIMEOUT,
                      @Timeout,
                      SizeOf(Timeout));

    Request := InternetOpenUrl(Session,
                               PChar(Url),
                               nil,
                               0,
                               INTERNET_FLAG_RELOAD or
                               INTERNET_FLAG_NO_CACHE_WRITE or
                               INTERNET_FLAG_NO_AUTO_REDIRECT or
                               INTERNET_FLAG_NO_COOKIES,
                               0);
    if (Request = nil) then
      Exit;

    try
      repeat

        if (Clock.ElapsedMilliseconds > 2500) then
          Exit;

        Count := 0;

        if not InternetReadFile(Request,
                                @Buffer[0],
                                SizeOf(Buffer),
                                Count) then
          Exit;

        if (Count = 0) then
          Break;

        OldLength := Length(Data);

        if OldLength + Integer(Count) > 262144 then
          Exit;

        SetLength(Data,
                  OldLength + Integer(Count));

        Move(Buffer[0],
             Data[OldLength],
             Count);

      until False;
      Result := TEncoding.UTF8.GetString(Data);

    finally
      InternetCloseHandle(Request);
    end;

  finally
    InternetCloseHandle(Session);
  end;
end;

constructor THEOSDiscovery.Create();
begin

  inherited Create(True);
  FreeOnTerminate := False;
end;

procedure THEOSDiscovery.Execute();
const
  Targets: array[0..0] of string = ('urn:schemas-denon-com:device:ACT-Denon:1');

var
  Sockets: TList<TSocket>;
  Locations: TStringList;
  Addresses: TStringList;
  Known: TStringList;
  Host: array[0..255] of AnsiChar;
  Entry: PHostEnt;
  Addr: TSockAddrIn;
  Peer: TSockAddrIn;
  Group: TSockAddrIn;
  Local: TInAddr;
  S: TSocket;
  I: Integer;
  N: Integer;
  PeerSize: Integer;
  Buffer: array[0..8191] of AnsiChar;
  Response: AnsiString;
  Search: AnsiString;
  Target: string;
  Location: string;
  Address: string;
  Authority: string;
  Xml: string;
  Device: THEOSDevice;
  Clock: TStopwatch;
  ErrorText: string;

begin

  Sockets := TList<TSocket>.Create;
  Locations := TStringList.Create;
  Addresses := TStringList.Create;
  Known := TStringList.Create;

  try
    try
      FillChar(Host,
               SizeOf(Host),
               0);

      SocketCheck(gethostname(Host,
                  SizeOf(Host)),
                  'Get local host');

      Entry := gethostbyname(Host);

      if Entry = nil then
        raise Exception.Create('Could not enumerate network interfaces');

      FillChar(Group,
               SizeOf(Group),
               0);

      Group.sin_family := AF_INET;
      Group.sin_port := htons(1900);
      Group.sin_addr.S_addr := inet_addr('239.255.255.250');

      I := 0;
      while Entry.h_addr_list[I] <> nil do
        begin
          Local := PInAddr(Entry.h_addr_list[I])^;
          Inc(I);

          if (Integer(Local.S_un_b.s_b1) = 127) then
            Continue;

          S := socket(AF_INET,
                      SOCK_DGRAM,
                      IPPROTO_UDP);

          if (S = INVALID_SOCKET) then
            Continue;

          FillChar(Addr,
                   SizeOf(Addr),
                   0);

          Addr.sin_family := AF_INET;
          Addr.sin_addr := Local;

          if (bind(S,
                   Addr,
                   SizeOf(Addr)) = SOCKET_ERROR) then
            begin
              closesocket(S);
              Continue;
            end;

        setsockopt(S,
                   IPPROTO_IP,
                   IP_MULTICAST_IF,
                   PAnsiChar(@Local),
                   SizeOf(Local));
        Sockets.Add(S);

        for Target in Targets do
          begin
            Search := AnsiString('M-SEARCH * HTTP/1.1'#13#10 +
                                 'HOST: 239.255.255.250:1900'#13#10 +
                                 'MAN: "ssdp:discover"'#13#10 + 'MX: 2'#13#10 +
                                 'ST: ' + Target + #13#10#13#10);
            sendto(S,
                   Search[1],
                   Length(Search),
                   0,
                   Group,
                   SizeOf(Group));
          end;
      end;

      if (Sockets.Count = 0) then
        raise Exception.Create('No active IPv4 network interface was found');

      Clock := TStopwatch.StartNew();

      while (Clock.ElapsedMilliseconds < 4500) and not Terminated do
        for S in Sockets do
          begin
            if not SocketReady(S,
                               False,
                               20) then
              Continue;

          PeerSize := SizeOf(Peer);

          N := recvfrom(S,
                        Buffer,
                        SizeOf(Buffer),
                        0,
                        Peer,
                        PeerSize);

          if (N <= 0) then
            Continue;

          SetString(Response,
                    Buffer,
                    N);

          Location := SsdpLocation(string(Response));
          Address := string(AnsiString(inet_ntoa(Peer.sin_addr)));

          // Follow only an HTTP description hosted by the responding device.
          if not StartsText('http://', Location) then
            Continue;

          Authority := Copy(Location,
                            8,
                            MaxInt);

          N := Pos('/',
                   Authority);

          if (N > 0) then
            SetLength(Authority,
                      N - 1);

          N := Pos(':',
                   Authority);

          if (N > 0) then
            SetLength(Authority,
                      N - 1);

          if (Authority <> Address) or (Locations.Count >= 32) then
            Continue;

          if (Locations.IndexOf(Location) < 0) then
            begin
              Locations.Add(Location);
              Addresses.Add(Address);
            end;
          end;

      for I := 0 to Locations.Count - 1 do
        begin
          if Terminated or (Clock.ElapsedMilliseconds > 15000) then
            Exit;
          Address := Addresses[I];

          if (Known.IndexOf(Address) >= 0) then
            Continue;
          Xml := FetchDescription(Locations[I]);

          if ParseHEOSDescription(Xml,
                                   Address,
                                   Device) and
             ProbeReceiver(Address, 1255, 800, ErrorText) then
        begin
          // HEOS speakers also advertise the CLI; AVR control is separate.
          Device.AvrAvailable := ProbeReceiver(Address, 23, 800, ErrorText);
          Known.Add(Address);
          SetLength(FDevices, Length(FDevices) + 1);
          FDevices[High(FDevices)] := Device;
        end;
        end;
    except
      on E: Exception do
        FError := E.Message;
    end;
  finally
    for S in Sockets do
      closesocket(S);
    Known.Free;
    Locations.Free;
    Addresses.Free;
    Sockets.Free;
  end;
end;

end.

