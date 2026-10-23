# Radio DJ & DJSuite
  
  
**MfRDJ**  
This application is a multi-channel audio mixer with effects.  
The Mixer is fully adjustable for audio endpoint assignments, mixer decks and loopback decks.
This mixer is primarily intended for live music, but it's capable of internet broadcasting with Caddy/IceCast.
  
**Note:**  
 Before compiling this sample make sure, you have all needed components installed first (see instructions).  
  
![](https://github.com/FactoryXCode/FactoryX-Radio-DJ/blob/main/RadioDJ/Pic/RDJ_Interface_s.png)
  
  
**MfRDJ Pro**  
MfRDJPro is the extended version of MfRDJ.
  
Where MfRDJ mainly demonstrates DJ-style audio playback and mixing with MfPack,  
MfRDJ Pro adds a complete live broadcast layer around the mixer.  
MfRDJ Pro still provides the familiar RDJ functions: channel decks,  
loopback decks, microphone input, effects, PFL/cue monitoring, playlist editing,  
tag editing, and local recording.  
  
The Pro version expands this into an audio/video streaming application.  
It can combine the live program audio with camera video or a static video source,  
encode the result with Microsoft Media Foundation, and publish it as a browser-playable stream.  

The main technical difference is the broadcast pipeline.  
MfRDJ Pro uses Media Foundation Sink Writer and the MPEG-4 media sink to create fragmented MP4.
MfRDJ Pro observes the generated MP4 byte stream, extracts and patches fMP4 fragments,
writes a rolling live.json manifest, and serves the result through FxServe or an alternative proxy server like Caddy.
Modern browsers can then play the stream using Media Source Extensions.
MfRDJ Pro also writes now-playing metadata, artwork links, on-air state, and 
listener counts to JSON files for the web interface.

It includes safeguards for long-running broadcasts, such as bounded queues,  
fragment cleanup, FxServe mirroring, sleep prevention options, and clean shutdown handling.  
MfRDJ Pro supports casting to Cromecast devices on your local network using the  
MfPack Cast V2 protocols. 

An extra tool FxRecord is provided for broadcast stations that needs to record their broadcasts for a period by law.
FxRecord is designed to run on a local pc or server as a Windows service.
FxRecordAdmin is a tool that is able to control FxRecord within the local network.
An FxAlert App running on smartphones or pc's is provided to watch FxRecord and alert admins of the recording/server status.
  
**Note:**  
Before using this sample make sure, you have all needed components installed (see instructions).  
  
![](https://github.com/FactoryXCode/FactoryX-Radio-DJ/blob/main/RadioDJ/Pic/RDJPro_Interface_s.png)

 
## Dependencies for Delphi development
- [**MfPack**](https://github.com/FactoryXCode/MfPack) Version 4.0.0 or higher. 
- Delphi XE2 (minimum recommended version: Delphi XE7) up to and including Delphi 13.1.  
- Windows 10 or higher.  

**Important note:**  
The latest Windows 11 versions do not support Dolby AC-3 and H.265 (hvec) encoders.  
Those you can buy from Microsoft Store or download elsewhere.  

  
# Binaries

## DJSuite

DJSuite is a Windows setup application for installing RDJ or RDJ Pro and
the optional tools needed to broadcast, serve and record a radio station.
It can be used on a studio PC, server or another recording PC.
An installation includes either RDJ or RDJ Pro.
DJSuite applications run on Windows 10 22H2 and above.  
  
## What's included

* **RDJ** — audio radio broadcasting application.
* **RDJ Pro** — audio and video radio broadcasting application.
* **FxServe** — optional web and broadcast server (recommended for RDJ Pro only).
* **FxServe Admin** — optional FxServe administration tool (recommended for RDJ Pro only).
* **FxRecord** — optional broadcast recorder for desktop or Windows service use.
* **FxRecord Admin** — optional recorder administration tool.
* **Caddy** — optional web server.
* **Icecast** — optional streaming server, installed through its own setup wizard.
* **Web applications and supporting files** — player, FxAlert, website assets,
SQLite libraries and setup guides.
  
  
The applications include **32-bit and 64-bit releases**. Bundled
Caddy and Icecast packages are 64-bit. Users needing 32-bit versions should
check the [Caddy](https://caddyserver.com/download) and [Icecast](https://www.icecast.org/download/) sites for compatible downloadsand install them separately.
  
  
Setup lets users choose components, application and data folders, recording
locations, network access and optional service registration. Existing settings,
customized website files and recordings are preserved.

See the [user guide](https://github.com/FactoryXCode/FactoryX-Radio-DJ/blob/main/Binaries/Installer/USER-GUIDE.md) for installation instructions.

# Download the Windows Installer [here](https://github.com/FactoryXCode/FactoryX-Radio-DJ/blob/main/Binaries/Installer/FactoryX-DJSuite-4.0.0.1-Setup.exe)

---
  
**(c) FactoryX. All rights reserved.**
