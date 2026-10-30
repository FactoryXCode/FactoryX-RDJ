program VisualizerLevelChecks;

{$APPTYPE CONSOLE}

uses

  WinApi.Windows,
  System.SysUtils,
  System.Math,
  WinApi.WinMM.MMeApi,
  WinApi.WinMM.MMReg,
  Vcl.Forms,
  RdjAudioMixVisualizer;

procedure CheckWaveFormatLayout();
var
  Format: WAVEFORMATEXTENSIBLE;
  RawFormat: array[0..39] of Byte;
  FloatSubtype: TGUID;

begin

  Writeln(System.SysUtils.Format('WAVEFORMATEX=%d WAVEFORMATEXTENSIBLE=%d',
                                   [SizeOf(WAVEFORMATEX), SizeOf(WAVEFORMATEXTENSIBLE)]));

  if (SizeOf(WAVEFORMATEX) <> 18) or (SizeOf(WAVEFORMATEXTENSIBLE) <> 40) or
     (NativeUInt(@Format.Samples) - NativeUInt(@Format) <> 18) or
     (NativeUInt(@Format.dwChannelMask) - NativeUInt(@Format) <> 20) or
     (NativeUInt(@Format.SubFormat) - NativeUInt(@Format) <> 24) then
    raise Exception.Create('Wave format layout does not match the Windows ABI.');

  FillChar(RawFormat, SizeOf(RawFormat), 0);
  RawFormat[0] := $FE;
  RawFormat[1] := $FF;
  RawFormat[2] := 2;
  RawFormat[14] := 32;
  RawFormat[16] := 22;
  RawFormat[18] := 32;
  RawFormat[20] := 3;
  FloatSubtype := KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;
  Move(FloatSubtype, RawFormat[24], SizeOf(FloatSubtype));
  Move(RawFormat, Format, SizeOf(RawFormat));

  if (Format.Format.wFormatTag <> WAVE_FORMAT_EXTENSIBLE) or
     (Format.Format.wBitsPerSample <> 32) or
     (Format.Samples.wValidBitsPerSample <> 32) or
     (Format.dwChannelMask <> 3) or
     (Format.SubFormat <> KSDATAFORMAT_SUBTYPE_IEEE_FLOAT) then
    raise Exception.Create('A Windows-format float header was decoded incorrectly.');
end;

procedure CheckLoopback();
var
  Visualizer: TRdjAudioMixVisualizer;
  StartTick: DWORD;
  SampleTick: DWORD;
  Level: TMfLevels;
  Spectrum: TMfSpectrum;
  HighestBar: Single;
  Bar: Integer;

begin

  Visualizer := TRdjAudioMixVisualizer.Create(nil);
  try
    Visualizer.InputTrimDb := 14;
    Visualizer.BarCount := 64;
    Visualizer.FftSize := 2024;
    Visualizer.AttackMs := 30;
    Visualizer.ReleaseMs := 30;
    Visualizer.DispatchEveryMs := 30;

    if (ParamCount > 1) then
      Visualizer.DeviceId := ParamStr(2);

    Visualizer.Active := True;
    StartTick := GetTickCount();
    SampleTick := StartTick;

    while (GetTickCount() - StartTick < 5000) do
      begin
        Application.ProcessMessages();

        if (GetTickCount() - SampleTick >= 30) then
          begin
            SampleTick := GetTickCount();
            Level := Visualizer.Levels;
            Spectrum := Visualizer.Spectrum;
            HighestBar := 0;

            for Bar := 0 to Length(Spectrum) - 1 do
              HighestBar := Max(HighestBar, Spectrum[Bar]);

            Writeln(Format('tick=%d peak=%.6f rms=%.6f maxBar=%.6f sampleRate=%d channels=%d',
                             [SampleTick, Level.PeakL, Level.RmsL, HighestBar,
                              Visualizer.SampleRate, Visualizer.Channels]));
          end;

        Sleep(1);
      end;
  finally
    Visualizer.Free();
  end;
end;

var
  Viz: TRdjAudioMixVisualizer;
  Samples: array[0..4095] of Single;
  Levels: TMfLevels;
  Bars: TMfSpectrum;
  Amplitude: Single;
  Expected: Single;
  MaxBar: Single;
  TrimIndex: Integer;
  AmplitudeIndex: Integer;
  I: Integer;
  Pass: Integer;

begin

  try
    CheckWaveFormatLayout();

    if (ParamStr(1) = '--loopback') then
      begin
        CheckLoopback();
        Exit;
      end;

    for TrimIndex := 0 to 1 do
      for AmplitudeIndex := 1 to 3 do
        begin
          Amplitude := Power(10.0, -AmplitudeIndex);
          Viz := TRdjAudioMixVisualizer.Create(nil);
          try
            Viz.InputSource := isExternalFeed;
            Viz.InputTrimDb := TrimIndex * 14;
            Viz.BarCount := 64;
            Viz.FftSize := 2048;
            Viz.AttackMs := 30;
            Viz.ReleaseMs := 30;
            Viz.DispatchEveryMs := 1;
            Viz.Active := True;
            Viz.BeginExternalFormat(48000, 2, True);

            for I := 0 to 2047 do
              begin
                Samples[I * 2] := Amplitude * Sin(2 * Pi * 64 * I / 2048);
                Samples[I * 2 + 1] := Samples[I * 2];
              end;

            for Pass := 1 to 12 do
              begin
                Viz.PushFloat32Interleaved(@Samples[0], 2048);
                Sleep(2);
              end;

            Levels := Viz.Levels;
            Bars := Viz.Spectrum;
            MaxBar := 0;

            for I := 0 to Length(Bars) - 1 do
              MaxBar := Max(MaxBar, Bars[I]);

            Expected := Amplitude * Power(10.0, Viz.InputTrimDb / 20.0);

            if (Abs(Levels.PeakL - Expected) > 0.0001) or
               (Abs(Levels.RmsL - Expected / Sqrt(2.0)) > 0.0001) then
              raise Exception.Create('Peak/RMS calibration differs from the input tone.');

            Writeln(Format('trim=%d amplitude=%.3f peak=%.6f rms=%.6f maxBar=%.6f',
                             [TrimIndex * 14, Amplitude, Levels.PeakL, Levels.RmsL, MaxBar]));
          finally
            Viz.Free();
          end;
        end;

    Writeln('PASS: known-tone peak and RMS calibration.');
  except
    on E: Exception do
      begin
        Writeln('FAIL: ', E.Message);
        Halt(1);
      end;
  end;
end.
