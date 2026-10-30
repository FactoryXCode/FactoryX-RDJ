# RDJPro Technical Handout

Version: 4.0.0

RDJ Pro is the extended RDJ sample application. It combines MfPack, Microsoft Media Foundation, Core Audio, WASAPI, VCL, FxServe or Caddy, and browser Media Source Extensions into one live audio/video DJ and broadcast application.

The project is larger than a small sample because it shows how several real-time Windows media technologies can work together in one application: local DJ playback, microphone and loopback capture, audio processing, recording, playlist editing, and browser-based broadcasting.

## What RDJ Pro Does

RDJ Pro is an MDI DJ mixer application with channel decks, loopback decks, a microphone deck, an effects deck, an end deck, playlist editing, tag editing, local recording, and browser broadcast support.

The normal audio path is built around Windows audio devices and MfPack helpers. Deck audio is mixed inside RDJ Pro and sent to the selected master output. A separate PFL/cue/headphone output can be enabled for monitoring.

The broadcast path publishes the live program to a browser. The browser does not need Icecast for the RDJ Pro video path. FxServe or Caddy serves the web page, JSON metadata, artwork, and fragmented MP4 media files.

## Main Technologies

RDJ Pro uses these main Windows and web technologies:

- Delphi VCL for the desktop GUI.
- MfPack for Media Foundation and WASAPI access.
- Core Audio and WASAPI for device capture, playback, and audio routing.
- Media Foundation Source Reader for video/camera sample capture.
- Media Foundation Sink Writer and MPEG-4 media sink for MP4/fMP4 encoding.
- A custom IMFByteStream proxy to observe fragmented MP4 bytes while Media Foundation writes them.
- FxServe as the small RDJ-focused web server, or Caddy as a general web server and reverse proxy.
- Browser Media Source Extensions, usually called MSE, for live fMP4 playback in the browser.
- JSON files for now-playing metadata and the live stream manifest.
- HEOS CLI and AVR network control, with direct HTTP AAC streaming from the RDJ Pro Masterdeck.

## Local Audio And Video Flow

The local RDJ Pro application keeps the desktop side and browser side separate.

On the desktop side:

1. Decks, loopback inputs, and microphone input produce audio.
2. RDJ Pro mixes and processes the audio.
3. The result is sent to the selected master output.
4. Optional monitoring goes to the headphone/PFL output.
5. Optional local recording can save WAV, FLAC, or MP4 depending on the recorder path.

On the video side:

1. RDJ Pro can use a camera source or a static image source.
2. Video samples are normalized into a Media Foundation video stream.
3. Audio samples from the RDJ program output are batched and timestamped.
4. Audio and video are passed to the broadcast fMP4 recorder.

## HEOS Masterdeck Output

RDJ Pro can send its live stereo Masterdeck mix to a Denon or Marantz HEOS
device. The separate **HEOS Remote** window opens from the main **HEOS** button.
**Stream RDJ** is an on/off toggle: checked requests streaming, and clicking it
again stops the local sender and queues a HEOS stop command. A checked button is
not proof that the receiver is already audible; check the status/log and HTTP
request count while the receiver connects.

RDJ's channel decks and playlist editor manage playback. The embedded HEOS window
has no separate file player, playlist editor, transport buttons, seek bar or loop
mode. It retains discovery, connection settings, elapsed streaming time, receiver
volume, balance, zone power, input, mute and bass/treble controls where supported
by the receiver. Closing the window hides it and keeps streaming active; exiting
RDJ stops the sender.

### Audio Path And Volume Relationship

```text
RDJ decks / microphone / loopback inputs
  -> RDJ stereo mix -> Master FX
  -> network copy with RDJ Master L/R volume and balance
  -> Media Foundation AAC encoder -> HTTP AAC/ADTS stream
  -> HEOS receiver -> receiver volume / balance / sound settings -> speakers
```

The HEOS source is tapped after `ProcessMasterFx` in `frmMainMDI.pas`.
`TMasterDeckFrm.SetVolumeChannels` forwards the Masterdeck's left/right faders and
balance to `TMainMDIFrm.SetHeosMasterGains`. `TRdjHeosOutput.PushFloat32` applies
those gains to its own PCM copy before encoding. It does not modify the original
mix buffer. PFL/cue and unrelated Windows sounds are excluded; a loopback deck
deliberately routed into the Masterdeck is included.

| Control | Where it acts | Effect on HEOS playback |
|---|---|---|
| RDJ Master Left/Right volume | PCM copy before AAC encoding; also controls the local master endpoint channels | Changes the level sent to the receiver. |
| RDJ Master balance | Left/right gains before AAC encoding | Changes the stereo balance already present in the stream. |
| HEOS Remote volume | Receiver main-zone volume through AVR commands | Changes receiver listening level without changing RDJ faders or encoded audio. |
| HEOS Remote balance and tone | Receiver processing, where available | Further adjusts the received sound without changing RDJ's mix. |
| RDJ PFL volume | Headphone/cue output | Does not change the HEOS stream. |

For centred RDJ balance, the network-copy gains are the absolute Master fader
positions divided by 100, clamped to 0..1. Moving balance left attenuates the
right channel; moving it right attenuates the left channel. Thus reducing both
Master faders from 100 to 50 halves each channel's PCM amplitude (about -6 dB),
while the receiver's volume setting stays unchanged. Setting both Master faders
to zero sends silence; raising receiver volume cannot restore that signal.

The receiver control currently displays its own volume scale with a `%` suffix.
That scale is not a linear PCM amplitude percentage. Do not multiply the two
displayed percentages or expect matching slider positions to mean equal gain.
RDJ Master and receiver volume are independent controls in sequence: RDJ sets
the outgoing program level, and the receiver sets listening level. Their balance
settings also act in sequence. Stream buffering delays audible RDJ fader changes
relative to local playback.

### Encoder, Network And Lifecycle

`RDJ.HeosOutput` uses a bounded, preallocated PCM queue. The audio callback does
not encode, access VCL controls or perform network I/O; if the queue is full or
its lock is unavailable, it drops the network-copy block without waiting. A
worker owns COM/Media Foundation and encodes stereo AAC at 192 kbit/s, served as
a continuous AAC/ADTS stream by `RDJ.HeosAudioServer`.

The current Masterdeck uses 44100 Hz float PCM; the sender also accepts 48000 Hz.
A sample-rate change during streaming is reported and requires a stream restart.
The compressed queue is bounded too, so a disconnected receiver cannot cause
unlimited buffering. Expected HTTP disconnects allow a new request to reconnect.

HEOS commands use receiver TCP port 1255. AVR settings use TCP port 23. The
receiver fetches the audio from the PC's configured HTTP port (default 8890).
Leave **PC IP** blank to select the interface routed to the receiver, or specify
the PC's reachable LAN IPv4 address. The PC and receiver must be able to reach
each other; allow RDJ through the private-network firewall for this HTTP stream.
This direct audio path does not require FxServe, Caddy or browser broadcasting.

Startup checks receiver availability before reading AVR settings and can search
for HEOS devices when the saved address is unavailable. Use **Find HEOS Device**
to select a receiver after an address change. Receiver network control must
remain reachable in standby for remote power commands to work. Removing mains
power prevents network control.

Streaming requests are serialized so a stop/restart can be queued while a HEOS
request is pending. During shutdown, RDJ stops its audio output threads before
freeing the HEOS window and sender. The window uses VCL DFM resources and TDn
controls from `HEOSRemote\Controls`; the separate FactoryX-HEOS-CLI repository
supplies `Heos.Sockets` through the `HeosCliRoot` project property.

The integration has been built and tested with Delphi XE7 for Win32 and Win64. Local mock
receiver checks cover the trimmed DFM, AAC delivery, elapsed display, queued
restart, close-to-hide and shutdown. Actual receiver buffering and listening
level depend on the device and network. See [HEOS integration notes](../HEOS-INTEGRATION.md)
for operation and troubleshooting.

## Browser Broadcast Flow

The browser broadcast path is designed as a rolling live fMP4 stream.

The high-level flow is:

1. RDJ Pro receives live video samples and live program audio samples.
2. RDJ Pro feeds those samples to a Media Foundation Sink Writer.
3. Media Foundation encodes H.264 video and AAC audio into fragmented MP4.
4. A custom byte-stream wrapper observes the MP4 boxes as Media Foundation writes them.
5. RDJ Pro extracts init data and moof+mdat fragments.
6. RDJ Pro patches fragment sequence and decode-time metadata for browser MSE playback.
7. Several small internal Media Foundation fragments are grouped into larger public fragments.
8. RDJPro writes `init.mp4`, `patched_frag_XXXXXX.m4s`, and `live.json`.
9. A mirror thread copies those files to the Caddy server folder.
10. The browser polls `live.json`, fetches the fragment files, and appends them to a MediaSource SourceBuffer.

The public browser stream is therefore not one endlessly growing MP4 file. It is a moving set of small files:

- `init.mp4`
- `live.json`
- `patched_frag_000001.m4s`
- `patched_frag_000002.m4s`
- and so on

The browser uses `live.json` as the scoreboard for the current live window.

## Why Fragmented MP4

A normal MP4 file is not ideal for live browser playback because important metadata is often finalized at the end of the file. A browser cannot reliably play a file whose final index is not available yet.

Fragmented MP4 solves this by splitting media into independent fragments. Each fragment contains timing and sample information that the browser can append while the stream is still being produced.

RDJ Pro uses the typical fMP4/MSE pattern:

- The init segment contains codec and track setup information.
- Each media fragment contains one or more `moof` and `mdat` box pairs.
- `moof` describes the samples and timestamps.
- `mdat` contains the encoded media bytes.

The browser receives the init segment first, then receives new media fragments as they become available.

## Media Foundation Implementation

The broadcast implementation lives mainly in:

- `RDJ.RdjPro.BroadcastFmp4Recorder.pas`
- `dlgMediaServer.pas`

The recorder uses cautious Media Foundation settings:

1. RDJ Pro creates target media types for H.264 video and AAC audio.
2. RDJ Pro creates a byte stream for Media Foundation output.
3. RDJ Pro creates an MPEG-4 media sink with `MFCreateFMPEG4MediaSink`.
4. RDJ Pro creates a Sink Writer from that media sink.
5. RDJ Pro writes video samples and audio samples to the Sink Writer.
6. Media Foundation writes fragmented MP4 bytes to the byte stream.

The important RDJ Pro trick is that the byte stream is not only a file stream. RDJ Pro wraps it in `TRdjProFmp4CaptureByteStream`, which implements `IMFByteStream`.

That wrapper forwards writes to the real Media Foundation file stream, but it also observes the bytes. This lets RDJPro parse top-level MP4 boxes while Media Foundation is writing.

The wrapper watches for:

- `ftyp`
- `moov`
- `moof`
- `mdat`

Once it has a matching `moof` and `mdat`, it builds a complete fMP4 fragment for the live browser path.

## Fragment Patching

Media Foundation produces valid fMP4, but the browser live path needs fragments to appear as a clean rolling sequence.

RDJPro therefore patches selected fragment metadata before publishing the fragment to Caddy. In particular, it tracks decode times per track and rewrites the relevant sequence/timing information so the browser can append fragments consistently.

This patching is done inside `TRdjProFmp4CaptureByteStream.PatchFragmentForMse`.

The original Media Foundation bytes are treated as the source. RDJ Pro produces a patched public fragment for MSE. This keeps the Media Foundation encoder path simple, while allowing the browser stream to stay live and appendable.

## Public Fragment Grouping

Media Foundation can emit small internal fragments. Very small public fragments are expensive for a browser and for a file-server mirror, because they create many file writes, many web requests, and many MSE append operations.

RDJ Pro groups several internal source fragments into one public `.m4s` file.

The default grouping is approximately four source fragments per public fragment. The exact public fragment duration is controlled by the broadcast setup values and the constants in `dlgMediaServer.pas`.

This grouping reduces:

- file-system pressure
- web-server request count
- browser SourceBuffer churn
- UNC mirror traffic
- debug/log noise

## The Web Server Mirror

RDJPro can publish directly to a local web root or mirror files to a web root on
another machine. The normal FxServe path is for example:

```text
\\PCHP001\FxServe\www\Stream
```

The older Caddy path is:

```text
\\PCHP001\Caddy\stream
```

The mirror is handled by `TRdjProMseMirrorThread`.

The mirror thread copies media fragments and writes `live.json` safely. It does not publish a fragment in `live.json` until that fragment was successfully mirrored to the public side.

That rule is important. If `live.json` announces a fragment before the file is present, the browser can request a file that does not exist yet and stall.

The mirror thread also has recovery logic. If a fragment gap becomes stale and is already outside the public live window, the thread resynchronizes to the newest successfully mirrored fragment. This prevents the public manifest from being pinned forever to an old fragment number.

## Browser Playback

The browser page uses JavaScript and Media Source Extensions.

The basic browser behavior is:

1. Fetch `live.json`.
2. Fetch `init.mp4`.
3. Create a MediaSource.
4. Add a SourceBuffer with the codec string from `live.json`.
5. Fetch missing `patched_frag_XXXXXX.m4s` files.
6. Append them to the SourceBuffer.
7. Keep polling `live.json` and append newer fragments.
8. Drop old buffered ranges so playback stays near live.

The browser also reads `nowplaying.json` for artist, title, cover art, DJ name, and listener count.

## Now Playing And Listener Count

RDJPro writes `nowplaying.json` for the browser page.

Typical fields are:

- `onAir`
- `onAirLock`
- `djName`
- `show`
- `artist`
- `title`
- `coverUrl`
- `listeners`
- `displayListeners`

The current listener-count reader understands the Caddy JSON access-log format.
When this count is needed, Caddy must be configured with JSON access logging:

```caddyfile
log {
    output file C:\Caddy\Caddy.log
    format json
}
```

RDJPro reads recent Caddy log entries, counts unique recent client IP addresses that request live stream URLs, and writes that count into `nowplaying.json`.

## Reliability Measures

Several safeguards are built into the current RDJPro broadcast path.

### Sleep And Lid Close

RDJPro can request Windows execution-state protection to avoid accidental sleep during broadcasting. There is also a setup option for overriding lid-close sleep behavior where supported.

This matters because system sleep can stop audio and device pipelines in ways that do not always recover cleanly.

### Memory Control

The live broadcast path is designed to avoid unbounded memory growth.

Important controls include:

- bounded video and audio queues
- stale audio/video trimming
- limited MSE fragment queues
- public fragment grouping
- mirror jobs using filenames instead of copying large media payloads into queued byte arrays
- explicit shutdown of Media Foundation sinks and byte streams

### Shutdown Cleanup

Media Foundation objects are explicitly finalized and shut down. The MPEG-4 media sink is shut down so it releases its byte-stream reference. The capture byte stream releases its live queues during shutdown.

This avoids the shutdown leaks that can otherwise appear after stopping the app while broadcasting.

### Atomic File Publishing

JSON and manifest files are written through temporary files and then replaced. This prevents the browser or web server from reading half-written JSON.

RDJPro uses retry logic for file replacement because the web server, browsers, SMB, or antivirus software can briefly hold a file handle.

### Debug Output Throttling

Long-running broadcasts can produce a huge amount of debug text. When running inside the Delphi IDE, the IDE debug-output buffer can become a problem by itself.

High-frequency logs are therefore throttled. Important state changes, errors, and occasional progress markers remain visible, but per-fragment debug output is reduced.

## Operational Checklist

For a stable RDJPro browser broadcast:

1. Use Windows 10 22H2 or later.
2. Configure the RDJ Pro web-server paths correctly.
3. Make sure FxServe or Caddy serves the RDJ Pro web folder.
4. Enable Caddy JSON access logging if its listener count is needed.
5. Make sure the selected stream folder is writable by RDJ Pro.
6. Keep the machine awake while broadcasting.
7. Use HTTPS if browsers require secure media or PWA behavior.
8. Watch `live.json` and `nowplaying.json` when diagnosing browser issues.
9. Watch RDJ Pro MSE memory heartbeat lines for queue growth or mirror stalls.

## Important Files

Main RDJPro files:

- `frmMainMDI.pas` handles application-level setup, now-playing JSON, listener count, and global state.
- `dlgMediaServer.pas` handles broadcast controls, web file publishing, live MSE manifest generation, and the mirror thread.
- `RDJ.RdjPro.BroadcastFmp4Recorder.pas` handles Media Foundation fMP4 recording, byte-stream observation, fragment extraction, and fragment patching.
- `RDJ.JSon.pas` writes and reads browser JSON state.
- `dlgHeosRemote.pas/.dfm` implements the separate HEOS Remote window and receiver controls.
- `RDJ.HeosOutput.pas` queues the Masterdeck PCM copy and manages the AAC worker.
- `RDJ.HeosAacEncoder.pas` encodes PCM to AAC/ADTS with Media Foundation.
- `RDJ.HeosAudioServer.pas` serves the live AAC stream directly to the receiver.
- `HEOSRemote` contains the embedded HEOS/AVR command, socket and discovery units and TDn controls.

Browser and web-server files:

- `Deploy\Server\Caddy\caddy.cff`
- `Deploy\Server\Caddy\index.html`
- `Deploy\Server\Caddy\nowplaying.json`
- `Deploy\Server\Caddy\stream\rdj_stream.html`

Typical runtime public stream files:

- `init.mp4`
- `live.json`
- `patched_frag_XXXXXX.m4s`

##Hardware

The software runs on a single laptop or PC without the need for extra hardware.

The needed hardware as a minimum pretty to work configuration is:
- Laptop/PC
- 2 screens with one has a build-in audio device, or a second soundcard in your PC or laptop.
- Headphone
- Microphone 
- Camera

The needed hardware as the best configuration is:
- Laptop/PC running RDJ
- 1 wide (touch) screen that displays the application
- 1 normal screen which has a build-in audio device, or a second soundcard in your PC or laptop.
- Headphone
- Studio microphone 
- Studio camera
- Internet connection
- Remote server that has as minimum Windows 10 22H2 running on it, running FxServe or Caddy.
- Router that supports DDNS or your own registered domain.
- An amplifier + speakers for master sound. If your amplifier supports HEOS, you do not need hardware connection and you are able to use the RDJ Pro build inn HEOS Remote from the masterdeck.

## Test conditions
  
- RDJ Pro has been tested on long runs (max a month), 
- Hard/software: HP laptop with i7-10510U CPU 1.80GHz (2.30 GHz), 16 gb memory, NVIDIA GeForce MX330 (2 GB) Intel(R) UHD Graphics (128 MB), Windows 11 Pro 64 bit.
- HP monitor with build-in audio
- Remote server: HP dual core PC Windows 10
- Wireless WIFI (on bad router connection, 15% signal strength)
- Wireless internet 4G and 5G (20% signal strength)
  
  
## Summary
  
RDJ Pro uses Media Foundation for the hard media work: capture, encode, mux, and write fragmented MP4.
RDJ Pro adds the live-broadcast layer around it: observing the fMP4 byte stream, extracting and patching fragments, grouping fragments for practical browser delivery, publishing a rolling manifest, mirroring to the web server, and feeding a browser MSE player.

The result is a Windows desktop DJ application that can broadcast synchronized audio/video to modern browsers using standard web playback technology and FxServe or Caddy.
