# FxRecord

Version: **4.2.0** · Documentation updated: **18 October 2026**

FxRecord is the FactoryX broadcast archive recorder for Windows. It records
published audio/video, rotates the archive into clock-aligned files, converts
audio when requested, and reports recorder health through FxAlert.

Run it on the broadcast server or on a separate PC at home or in the office.
Both input modes work in the desktop application and as a Windows service.
Recording and conversion run on the recorder PC.

## Input modes

| Mode in the application | INI value | What it reads |
| --- | --- | --- |
| HTTP/HTTPS stream (HLS) | `SourceMode=PublicUrl` | A public `.m3u8` playlist and its media over HTTP/HTTPS. |
| Local folder | `SourceMode=LocalFolder` | The published `live.json`, initialization file and fragments in `StreamPath`. |

HTTP recording uses standard HLS and does not require FxServe, Caddy, an RDJ Pro
recording component, or access to the broadcast server's folders. The station
still needs an HTTP server to deliver the broadcast. FxRecord downloads the
media directly; it does not render or record a browser window.

Local-folder recording reads the currently published stream. Neither mode uses
the removed RDJ recovery units, backup-spool subscriptions or historical
recording rebuild worker.

## Requirements

- Windows 10 or later.
- Windows Media Foundation components for profiles that convert audio.
- A writable configuration/log directory and sufficient archive disk space.
- For HTTP input: an accessible, supported HLS playlist.
- For folder input: read access to the published stream folder.

Supported HTTP input is unencrypted HLS with complete fragmented MP4 segments,
an `EXT-X-MAP` initialization file, and H.264 video/AAC audio together in the
selected rendition. The reader follows redirects and the first listed variant
in a master playlist. Relative, absolute and signed media URLs are supported.
Windows validates HTTPS certificates.

Encrypted/DRM streams, MPEG-TS segments, byte-range playlists and assembly of
separate audio/video renditions are not supported. A normal website HTML page
is not a playlist URL.

## Quick start: desktop HTTP recording

1. Place `FxRecord.exe` and your `FxRecord.ini` in a writable local directory.
   The supplied [FxRecord.PublicUrl.ini](FxRecord.PublicUrl.ini) is an HTTP-input
   example; copy it as `FxRecord.ini` before editing.
2. Start `FxRecord.exe`. Desktop startup waits for **Start**; it does not begin
   recording automatically.
3. Choose **HTTP/HTTPS stream (HLS)** and enter the playlist URL. For example:

   ```text
   http://factoryxradio.asuscomm.com/stream/live.m3u8
   ```

4. Choose an archive directory on the recorder PC. A local disk is useful when
   testing network reliability because archive writes then avoid the network.
5. Select the output profile, rotation interval and retention period. Choose
   **Save**, then **Start**.
6. Check the active filename and sequence progress in the log. Press **Stop**
   and allow finalization/conversion to finish before updating the executable.

Keep the desktop application open while recording. For unattended recording
without a signed-in user, use the Windows service instead.

An `http://` URL starts on port 80 unless a port is specified. If the host
redirects to HTTPS, recording continues over HTTPS; selecting HTTP does not
force the server to deliver media on port 80.

## Configuration

The default configuration is `FxRecord.ini` beside the executable, regardless
of the executable's filename. Select another INI explicitly with:

```bat
FxRecord.exe --config "C:\FxRecord\Station.ini"
```

Paths are interpreted on the recorder PC. Relative paths resolve beside the
selected INI. The following example records HTTP input to a local archive:

```ini
[Recorder]
Enabled=False
SourceMode=PublicUrl
StreamUrl=http://factoryxradio.asuscomm.com/stream/live.m3u8
ArchivePath=C:\ComplianceRecordings
PollIntervalMs=1000
RequireLiveStream=True
LiveStaleSeconds=15
WarningFreeGB=20
CriticalFreeGB=5

[Archive]
FragmentDuration=60
RetentionDays=14
OutputProfile=SourceCopy

[Audio]
Mp3SampleRate=44100
Mp3BitRateKbps=192
AacSampleRate=44100
AacBitRateKbps=160
```

`FragmentDuration` is the archive rotation interval **in minutes**. It is
separate from the broadcast's HLS fragment duration, which is measured in
seconds. `RetentionDays` controls archive cleanup.

For local-folder input, replace the source settings with:

```ini
[Recorder]
SourceMode=LocalFolder
StreamPath=C:\FxServe\www\Stream
ArchivePath=F:\ComplianceRecordings
```

In HTTP mode, `StreamPath` is ignored. Older `/stream/live.json` URL settings
are normalized to the sibling `live.m3u8`. A station-root URL is a convenience
for the FactoryX `/stream/live.m3u8` layout; use an explicit playlist URL for
other layouts.

## Output profiles

| Profile | Completed file | Processing |
| --- | --- | --- |
| `SourceCopy` | MP4 | Preserves the received H.264/AAC media without re-encoding. |
| `MP4-H264-AAC` | MP4 | Copies H.264 video and encodes stereo AAC audio. |
| `AVI-H264-MP3` | AVI | Copies H.264 video and encodes stereo MP3 audio. |

Source video dimensions, frame rate and quality are preserved. AVI output no
longer forces video to 25 fps or re-encodes it at a fixed video bitrate.
Conversion uses Windows Media Foundation/MfPack and FxRecord's own AVI writer;
FFmpeg is not a runtime dependency.

Supported audio settings:

| Audio | Sample rates | Bitrates | Default |
| --- | --- | --- | --- |
| MP3 | 32, 44.1 or 48 kHz | 128, 160 or 192 kbps | 44.1 kHz / 192 kbps |
| AAC-LC | 44.1 or 48 kHz | 96, 128, 160 or 192 kbps | 44.1 kHz / 160 kbps |

MP3/AAC controls apply to their matching profiles and retain separate settings.
`SourceCopy` preserves the source audio settings.

While recording, the filename ends in `.mp4.partial` for `SourceCopy`, or
`.mp4.source.mp4.partial` / `.avi.source.mp4.partial` for conversion profiles.
At rotation or Stop, conversion runs in the background and publishes the final
`.mp4` or `.avi`. New recording can continue while conversion finishes.

Allow enough disk space for active media, conversion work files and completed
archives. Conversion failures preserve the source/work files and are logged.
Unfinished recordings are recovered where possible at startup; inspect warnings
rather than assuming every interrupted file is complete. An existing encoded
work file can block a retry to avoid overwriting recoverable data.

The built-in AVI writer supports files below 2 GiB. Reduce the rotation interval
if your media would exceed that limit. A failure preserves the source recording.

## Interruptions, restarts and coverage

- HTTP connection failures keep the current interval file open. FxRecord retries
  and retrieves missed fragments if they remain in the server's HLS window.
- Expired fragments cannot be recovered from that window. Skipped sequences and
  interruptions are logged; missing broadcast content is not reconstructed.
- A compatible broadcast restart can continue in the same file with rebased
  decode timestamps. An incompatible codec, track layout or timebase requires
  a new file and is logged.
- Scheduled rotation still takes place during an outage. Recording resumes in
  the current interval when media returns. An interval with no received media
  does not produce a fake empty recording.
- The first file usually covers only the remainder of its clock interval. For
  example, starting at 12:39 produces an approximately 21-minute first file.
- Rotation uses the recorder's clock. Delayed fragments can fall into the next
  interval, so adjacent files can differ from exactly 60 minutes.

A near-hour file duration does **not** prove uninterrupted coverage. MP4 can
preserve timing gaps, while AVI duration reflects its stored frames differently.
Use the recorder log, sequence progress and playback checks together.

## Windows service

The service can run on the broadcast server or any separate recorder PC. Install
locally on that PC from an elevated Command Prompt:

```bat
C:\FxRecord\Install-FxRecord.cmd
```

The script expects `FxRecord.exe` and `FxRecord.ini` beside it, registers the
service as **FxRecord**, and starts it. Installation configures delayed automatic
startup where supported and failure-recovery restart attempts. Reinstalling can
repair an existing stopped registration while retaining its service account.

For a custom configuration, register it explicitly, then start the service:

```bat
"C:\FxRecord\FxRecord.exe" --install --config "C:\FxRecord\Station.ini"
sc.exe start FxRecord
```

The service enables recording regardless of the desktop INI's `Enabled` value.
Closing a desktop window does not stop an independently running service. Check
which instances are active before conducting a local-only or server-only test.
Do not point simultaneous desktop/service instances at the same archive/INI.

Use local drive paths for archives on the service PC. For a remote archive,
configure a service account with the required share and filesystem permissions;
mapped drive letters from an interactive login are not service drive mappings.

Useful commands:

```bat
sc.exe query FxRecord
sc.exe qc FxRecord
sc.exe stop FxRecord
sc.exe start FxRecord
```

`--service` is used by Windows' Service Control Manager, not as a desktop start
command. To remove the registration while retaining files, run
`Uninstall-FxRecord.cmd` as administrator.

Before replacing an executable, stop its desktop/service instance and allow
recording closure and pending conversions to finish. Back up the existing EXE
and INI, replace the EXE, then start with the same configuration. A service
uninstall/reinstall is unnecessary when its registered path is unchanged.

## FxRecord Admin

[FxRecord Admin](FxRecordAdmin/README.md) manages the recorder PC's Windows
service, settings, status and logs. Its target is the **recorder PC**, which can
be different from the broadcast server. For a service on the same PC, use `.`
and a local INI path. Remote administration uses Windows authentication, service
control and an SMB share for the recorder's configuration/log directory.

Archive paths belong to that recorder PC. For example, on PCHP001 use
`F:\ComplianceRecordings` inside its recorder configuration. On another PC,
`\\PCHP001\ComplianceRecordings` is usable only if that share exists and the
recording account has access. A share's existence is not implied by a local
folder with the same name.

## FxAlert and heartbeat location

FxRecord publishes health independently from whether listeners can play the
broadcast. A live stream does not prove that a recorder is running.

- **HTTP input:** `FxAlert\status.json` is beside the selected recorder INI/log.
- **Local-folder input:** status remains in the FxAlert directory beside the
  published Stream directory, normally the website's FxAlert folder.

For a standalone recorder on the same server as FxServe, configure the FxServe
instance hosting the public FxAlert page to read the current recorder file:

```ini
[FxAlert]
StatusFile=C:\FxRecord\FxAlert\status.json
```

This setting belongs in **FxServe.ini**, not FxRecord.ini. The FxServe service
account must be able to read the file. Relative paths resolve beside FxServe.ini.
The `/FxAlert/status.json` endpoint disables caching and returns 404 if the
configured file is missing, without falling back to an obsolete web-root copy.

If recording moves to a home/local PC, the public FxAlert page does not
automatically switch to that recorder. The hosting server must have an explicitly
configured, accessible heartbeat source; FxRecord does not automatically upload
its local status file. FxRecord Admin can read the selected recorder's status
directly over the LAN.

Open the hosted FxAlert application over HTTPS, for example
`https://factoryxradio.asuscomm.com/FxAlert/`. Enable alerts and allow browser
notifications. The current application polls every five seconds and distinguishes
a stale recorder heartbeat from repeated failures to retrieve the status feed.
Its current stale-heartbeat threshold is 45 seconds; repeated fetch failures
use a 60-second connection-loss threshold with a startup/wake grace period.

Recovered conditions leave the active alarm automatically. A historical last
warning can remain visible; pending Windows updates can keep the current state
at warning even when recording is healthy. Browser/background push behavior
depends on the installed FxServe/FxAlert build, notification permissions and
platform support.

## Logs and troubleshooting

The selected INI determines the regular log path: `C:\FxRecord\Station.ini`
writes `C:\FxRecord\Station.log`. Resource diagnostics are written beside it
with the `.diagnostics.log` suffix.

| Message or symptom | Meaning / action |
| --- | --- |
| Windows error `12002` | An HTTP operation timed out. FxRecord retries; check network/server availability and subsequent recovery. The code alone does not identify the cause. |
| HTTP `502` | The HTTP host/proxy returned an error. Compare its logs with recorder timestamps. |
| Recording fragment gap | Expected segments expired or became unavailable; inspect coverage around that interval. |
| Heartbeat dated days ago | Verify which recorder/file FxAlert is reading and whether that recorder is still running. |
| Windows updates waiting | The recorder PC has updates available; plan maintenance separately from recording. |
| Windows restart pending | An installed update requires a restart. |
| Small first hourly file | May be the expected remainder of the current clock interval; check start/rotation times. |
| Completed AVI/MP4 not visible yet | Check the active source file and pending conversion; final output appears after closure/conversion. |
| Shared server path unavailable | RDJ Pro may be unable to publish fresh media even while FxRecord itself remains running. |

Resource diagnostics include process/system CPU, private/working-set/peak memory,
threads, handles, monitor activity and converter state. Sampling occurs every
five seconds, with normal baselines about once a minute and extra entries for
spikes or stalls. The monitor activity age is not the age of the stream playlist.
Peak working set is a historical maximum, not current memory consumption.

The diagnostics log rotates at 10 MiB and keeps one `.previous` file. Collect
both files together with the regular recorder log when investigating an issue.
Do not assume the regular recorder log has the same size limit.

Windows update checks report restart requirements and available updates; they
do not install updates or restart the PC. The available-update scan runs in a
separate helper process.

## Building and source layout

Open `FxRecord.dproj` in Delphi and build Win32 or Win64. Clean builds have been
verified with Delphi XE7 (compiler 28.0). The project uses its own units and the
MfPack core units in `../../src`; no RDJ Pro source search paths or old recovery
DCUs are needed. Normal outputs are `Win32\Release` / `Win64\Release` (or the
selected Debug directories). FxRecord Admin has its own project under
`FxRecordAdmin`.

| Unit | Responsibility |
| --- | --- |
| `FxRecord.Http` | Native Windows HTTP/HTTPS requests and URL resolution. |
| `FxRecord.Hls` | HLS playlist parsing and supported-format validation. |
| `FxRecord.PublicSource` | Playlist/media fetching, source identity and media validation. |
| `FxRecord.Fmp4` | Fragment validation and timestamp rebasing. |
| `FxRecord.Recorder` | Archive writing, interval rotation and conversion scheduling. |
| `FxRecord.Converter` | Audio encoding and completed MP4/AVI output. |
| `FxRecord.Monitor` | Recording supervision, health checks and FxAlert status. |
| `FxRecord.Diagnostics` | Process/resource sampling. |
| `FxRecord.Service` | Windows service installation and operation. |

FFmpeg used by test fixtures/output checks is not required by deployed FxRecord.

## Further documentation

- [FxServe and FxRecord setup guide](Docs/FxServe-and-FxRecord-Setup.md)
- [HTTP/HLS recording details](Docs/HTTP-HLS-Recording.md)
- [FxRecord Admin](FxRecordAdmin/README.md)
- [MfPack on GitHub](https://github.com/FactoryXCode/MfPack)
- [FactoryX Radio DJ](https://github.com/FactoryXCode/FactoryX-Radio-DJ)
- [MfPack on SourceForge](https://sourceforge.net/projects/MFPack)

Copyright © FactoryX. All rights reserved.
