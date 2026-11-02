# Background AAC broadcast

Starting RDJ Pro's normal public broadcast also starts an independent AAC/ADTS
audio stream. There are no extra buttons or panels. Stopping the broadcast,
losing broadcast ownership, choosing video-only mode, or exiting RDJ stops AAC.
Hiding Media Server leaves broadcasting active. Cast-only output does not start
the public AAC endpoint.

The browser/PWA continues using fragmented MP4. AAC uses a separate encoder,
queue and HTTP server, so MP4 recorder recovery does not restart AAC. An AAC
failure is logged and retried after 30 seconds without stopping MP4 publication.
The sender waits for the Masterdeck to supply a valid 44100/48000 Hz format.

The audio source is the stereo Masterdeck mix after FX, with RDJ Master volume
and balance applied before encoding. The private HEOS output remains independent;
its receiver volume changes listening level, not the audio sent to the public URL.

## Address and configuration

The default endpoint is `http://<RDJ-PC-IP>:8098/radio/live.aac`, AAC stereo at
192 kbps. Allow RDJ through the appropriate Windows firewall rule if necessary.
The listener defaults to all IPv4 interfaces. No receiver commands are sent by
this background service, and it does not turn a receiver on or start playback.

Optional settings in the executable's existing INI (`MfRdjJ.ini`) are read when
RDJ starts. No keys are written automatically:

```ini
[AudioRadio]
Enabled=True
Bind=0.0.0.0
Port=8098
```

Set `Enabled=False` to keep only the MP4 broadcast. Changing these settings
requires restarting RDJ. If the port is already in use, MP4 continues and the
existing Media Server log reports the AAC error and retry.

FxServe already supports the separate `[Radio]` upstream. Its host and port must
match the RDJ PC and AAC listener. The verified existing deployment points to
192.168.50.114:8098 and publishes:

`https://factoryxradio.asuscomm.com/radio/live.aac`

Use this complete audio URL for a HEOS custom station. The website root is HTML
and cannot itself be played by the receiver. Background AAC does not change the
website player, manifests, certificates or FxServe configuration.

## Source and verification

- `RDJ.BackgroundAudio.pas`: INI defaults, automatic lifecycle, format deferral,
  bounded retry and log events.
- `RDJ.HeosOutput.pas`: bounded PCM queue, Master gain application and background
  AAC encoding, shared implementation with the independent private HEOS output.
- `RDJ.RadioAudioServer.pas`: bounded multi-listener `/radio/live.aac` HTTP server.
- `frmMainMDI.pas`: owns the background sender, forwards PCM/gains and detaches
  callbacks before destruction.
- `dlgMediaServer.pas`: follows public broadcast ownership and video-only mode,
  keeps AAC running through MP4 recovery and logs transitions. Its DFM is unchanged.

`Tests/RunBackgroundAudioTests.py` checks the actual lifecycle unit against a
deterministic encoder fixture on Win32 and Win64. `Tests/Run-RadioStreamTests.py`
checks actual AAC frames, concurrent listeners, a concurrent private HEOS sender,
normal disconnects and bounded shutdown. `Tests/RunBroadcastRecoveryTests.py`
continues checking the separate MP4 recovery paths. These are regression checks;
long-run listening should still be checked with the normal broadcast setup.
