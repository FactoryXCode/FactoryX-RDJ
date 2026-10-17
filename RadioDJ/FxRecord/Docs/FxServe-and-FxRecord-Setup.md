# FxServe and FxRecord: server and remote-recorder setup

This guide covers the public-URL capable FxRecord and FxRecord Admin builds.
FxServe is an example HTTP host in this guide. FxRecord's HTTP reader now uses
standard HLS and works with other HTTP servers; see [HTTP/HLS recording](HTTP-HLS-Recording.md).

## Choose where recording runs

| Setup | FxServe location | FxRecord location and input | Main reason to choose it |
| --- | --- | --- | --- |
| Server recording | Broadcast server | Same server; **Local folder** | Local recording without public internet dependency |
| Remote recording | Broadcast server | Home/office PC; **Public FxServe URL** | Records the stream received over the internet; conversion and archive storage are on that PC |
| Remote recorder service | Broadcast server | Home/office PC; Windows service with **Public FxServe URL** | Unattended remote recording, including after a reboot without signing in |
| Remote desktop recording | Broadcast server | Home/office PC; FxRecord desktop application with **Public FxServe URL** | Manual Start/Stop while FxRecord stays open |

The recording input and service/desktop operation are independent choices. A service on the broadcast server can also use Public URL, but that does not move recording work off the server. Keep your existing RDJ Pro installation. Public-URL recording requires only its normal public stream; no FxRecord integration in RDJ Pro is needed. Existing queued backups and recordings are preserved on disk.

**Recommended remote profile: SourceCopy.** It saves the published H.264 video and AAC audio directly to MP4. It avoids audio conversion and its temporary source/work files. AVI-H264-MP3 and MP4-H264-AAC remain available, with conversion performed on the recorder computer. Recording from a URL does not inherently reduce the size of the original media.

## 1. Prepare FxServe on the broadcast server

Keep RDJ Pro publishing its web files and live media to the FxServe web root. For example:

```text
C:\FxServe\www\nowplaying.json
C:\FxServe\www\Artwork\
C:\FxServe\www\Stream\live.json
C:\FxServe\www\Stream\init.mp4
C:\FxServe\www\Stream\patched_frag_*.m4s
```

In FxServe.ini, the corresponding LAN settings are:

```ini
[Server]
BindAddress=0.0.0.0
Port=8080
WebRoot=C:\FxServe\www
```

The public host needs WAN access. Preserve existing working settings and certificates when updating an installation. Example:

```ini
[Wan]
Enabled=True
HostName=factoryxradio.asuscomm.com
HttpEnabled=True
HttpPort=80
HttpsEnabled=True
HttpsPort=443
RedirectHttp=True
```

For a new FxServe service installation, run an elevated Command Prompt in C:\FxServe:

```bat
FxServe.exe --install --config "C:\FxServe\FxServe.ini"
sc.exe start FxServe
```

Use FxServe's WAN deployment/setup procedure for the HTTP.sys reservations, Windows firewall and certificate provisioning. Do not reinstall an already functioning service just to add a remote recorder. See [FxServe's WAN deployment guide](../../FxServe/Deploy/YourRemoteServer/README-Deploy.md) and [FxServe README](../../FxServe/README.md).

On the router, forward TCP 80 and 443 to the **FxServe server's actual LAN address**. Reserve that address in DHCP so forwarding does not point to a previous address after a reboot. For the current PCHP001 setup, the server address established during troubleshooting was **192.168.50.83**; verify it on that server before applying any forwarding changes. Keep port 8080 for LAN use.

From outside the server LAN, check:

```powershell
curl.exe -I https://factoryxradio.asuscomm.com/stream/live.json
```

While RDJ Pro is broadcasting, expect HTTP 200. Open the website and test playback too. HTTP port 80 redirects to HTTPS in this configuration; configure the recorder with HTTPS to avoid the extra redirect requests. The recorder validates the TLS certificate through Windows. A certificate or hostname error must be corrected on the server or in the URL.

If live.json returns 404, verify that RDJ Pro broadcasting is running and publishing to the same Stream folder FxServe serves. Song-title updates alone do not prove that live audio/video is being published.

FxServe does not need a second instance, a special recorder port or access to the remote archive. It only serves the public stream. Serving another listener still uses some network/CPU capacity; archiving and conversion move off the server when FxRecord is moved.

## 2. Run FxRecord manually on a home or office PC

1. Copy FxRecord.exe, FxRecordAdmin.exe and the supplied configuration examples into a local folder such as **C:\FxRecord**. Use the new recorder and Admin together.
2. Start **FxRecord.exe**. It waits for you to press Start.
3. Open **Recorder** and choose **HTTP/HTTPS stream (HLS)** under **Recording input**.
4. Enter the media playlist URL, for example **http://factoryxradio.asuscomm.com/stream/live.m3u8**. A station-root URL is a convenience for this stream layout. An old live.json setting migrates to the sibling live.m3u8. Other HTTP servers can supply the standard supported HLS/fMP4 format; no FxServe API is used.
5. Set **Archive folder** to a real local disk on this recorder PC, such as **D:\RadioArchive**. Create/select a drive that exists on that PC.
6. Select **SourceCopy**, **60** minutes for fragment duration, and the required retention days. Choose disk warning/critical thresholds appropriate to that disk. Polling at **1000 ms** is a useful remote starting point.
7. Select **Save**, then **Start**. Check the Status log for a broadcast session and recording filename. Stop after a short test and play the completed MP4 from the archive folder.

Keep the desktop app running while recording. Keep this PC awake and its internet connection available. Closing FxRecord stops desktop recording. Do not run desktop recording and the FxRecord service simultaneously against the same archive/configuration.

## 3. Run the remote recorder as a Windows service

Configure and save FxRecord.ini on the **recorder PC** first, then close the desktop application. An example for a PC with a D: archive drive is:

```ini
[Recorder]
Enabled=False
SourceMode=PublicUrl
StreamUrl=http://factoryxradio.asuscomm.com/stream/live.m3u8
ArchivePath=D:\RadioArchive
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
Mp3BitRateKbps=128
AacSampleRate=44100
AacBitRateKbps=160
```

The service starts recording regardless of the desktop Enabled value. PublicUrl does not use StreamPath. It does not need SMB access to the broadcast server and does not write a recovery subscription or spool there.

On the recorder PC, open an elevated Command Prompt in C:\FxRecord and run:

```bat
Install-FxRecord.cmd
```

This installs and starts the FxRecord service with automatic startup and failure recovery. Check:

```bat
sc.exe query FxRecord
```

The service uses the configuration path registered at installation. Its account needs write access to its configuration/log folder and the archive folder, and outbound HTTP/HTTPS access. A Windows service uses the machine's network/proxy settings; it does not inherit a browser's signed-in session or browser proxy authentication.

For an existing service, stop it cleanly before replacing FxRecord.exe. Wait for finalization/conversion to complete. Preserve FxRecord.ini and the archive, replace only the program files, and start the service again. Uninstalling is unnecessary.

## 4. Administer the recorder with FxRecord Admin

**Recorder PC means the machine running FxRecord**, which may be your home PC. It does not necessarily mean the machine running FxServe.

When Admin runs on that same recorder PC:

```text
Recorder PC: .
Recorder INI: C:\FxRecord\FxRecord.ini
```

Run Admin elevated if required for local service control. Select **Connect / reload**. **Service INI** shows the configuration used by the registered service. In **Recorder settings**, choose the input, set the public URL/local folder and archive profile, then use **Save (stopped)** or **Save & restart**. If the service was stopped, explicitly select Start after saving. Closing Admin leaves the service running.

When Admin runs on another PC on the recorder's trusted LAN, use the recorder's computer name and its shared configuration path. For example:

```text
Recorder PC: HOME-RECORDER
Recorder INI: \\HOME-RECORDER\FxRecord\FxRecord.ini
```

The administrator needs Windows service-control rights and access to that share. Do not expose SMB or Windows service-control ports on the public router to administer the recorder. Public-URL recording itself needs only outbound access to FxServe. See [Admin's LAN access instructions](../FxRecordAdmin/README.md).

## 5. Keep recording on the broadcast server instead

Install/configure FxRecord on that server, using its own local paths:

```ini
[Recorder]
SourceMode=LocalFolder
StreamPath=C:\FxServe\www\Stream
ArchivePath=F:\ComplianceRecordings
```

Select the actual archive drive available on the server. Admin can connect locally with `.` or over its trusted LAN. Existing INIs without SourceMode retain LocalFolder behavior. Both input modes record the published stream only. The former RDJ archive-recovery subscriptions, backup spool and historical rebuild worker have been removed from FxRecord. Previously stored recordings and backup data are left on disk.

To move recording entirely off the broadcast server, first verify a remote test recording. Then stop the server's FxRecord service cleanly and arrange for only the intended remote recorder to start automatically. Merely starting another recorder at home does not stop the existing server recorder. Disabling automatic startup on the old recorder is an administrator choice after the move is verified. Keep FxServe running.

## 6. Interruptions, gaps and verification

The remote recorder records what it receives from the public stream. If the server, internet connection or recorder PC is unavailable, it cannot manufacture the missing broadcast.

- HTTP or media-download failures keep the hourly recording open. FxRecord retries and retrieves missing fragments while they remain available; expired sequence ranges are logged. The scheduled boundary still closes the interval even if disconnected.
- If the next fragment is still in FxServe's rolling public window, the recorder can retrieve it when access resumes. Otherwise it logs the expected and first available sequence and resumes from the available material.
- A playlist that stops advancing becomes stale after the configured timeout even if HTTP requests still return 200. The warning is logged and the interval stays open while awaiting recovery.
- A compatible broadcast restart refreshes the initialization segment and continues the hourly recording with rebased timestamps. Incompatible codec/track/timebase changes start a new file.
- A small amount of media remains available briefly in the live window. There is no guarantee of recovery for a long outage in PublicUrl mode. Keep a separate local recorder if filling such gaps is essential.

For a trial, record a few minutes, stop and play the file. Then test a brief interruption while noting its disconnect/reconnect times. Check the log, completed files and actual media timelines afterward; a running service or an hourly filename alone is not evidence that every minute was captured.

## 7. Logs and status

On the recorder PC:

- FxRecord.log records sessions, filenames, interruptions, skipped sequences and conversion results.
- FxRecord.diagnostics.log records CPU, memory, handles and recorder/converter activity.
- PublicUrl status is written to **FxAlert\status.json beside the recorder INI**, and Admin reads that local-recorder status. This does not automatically publish the home recorder's status on the broadcast website or send its alerts through the broadcast server's push service.
- LocalFolder mode keeps its existing web-root FxAlert status location.

The old server-recovery worker and historical rebuild loop identified in the 15 October long-run review are no longer part of FxRecord. LocalFolder and PublicUrl use the same current-fragment recorder; neither rebuilds historical recordings from an RDJ backup spool.

