unit RDJ.RdjPro.MirrorPlaylist;

interface

// Publish HLS entries only inside the successfully mirrored contiguous run.
function RdjSafeMirrorPlaylist(const AText: string; const AFirst, ALast: Integer): string;

implementation

uses System.SysUtils, System.Classes;

function RdjSafeMirrorPlaylist(const AText: string; const AFirst, ALast: Integer): string;
var
  Lines, Header, Body, Entry: TStringList;
  I, Seq, FirstSelected, P: Integer;
  Line: string;
begin
  Result := '';
  if (AFirst <= 0) or (ALast < AFirst) then Exit;
  Lines := TStringList.Create;
  Header := TStringList.Create;
  Body := TStringList.Create;
  Entry := TStringList.Create;
  try
    Lines.Text := AText;
    FirstSelected := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Pos('#EXT-X-MEDIA-SEQUENCE:', Line) = 1 then Continue;
      if (Pos('#EXTINF:', Line) = 1) or
         (Pos('#EXT-X-PROGRAM-DATE-TIME:', Line) = 1) then
        Entry.Add(Line)
      else if Pos('patched_frag_', Line) = 1 then
      begin
        P := Pos('.m4s', Line);
        Seq := StrToIntDef(Copy(Line, Length('patched_frag_') + 1,
          P - Length('patched_frag_') - 1), 0);
        if (Seq >= AFirst) and (Seq <= ALast) then
        begin
          if FirstSelected = 0 then FirstSelected := Seq;
          Body.AddStrings(Entry);
          Body.Add(Line);
        end;
        Entry.Clear;
      end
      else if (Line <> '') and (Line <> '#EXT-X-ENDLIST') then
        Header.Add(Line);
    end;
    if FirstSelected = 0 then Exit;
    Header.Add('#EXT-X-MEDIA-SEQUENCE:' + IntToStr(FirstSelected));
    Result := Header.Text + Body.Text;
  finally
    Entry.Free;
    Body.Free;
    Header.Free;
    Lines.Free;
  end;
end;

end.
