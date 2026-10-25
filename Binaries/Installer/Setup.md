# FactoryX DJSuite Setup
  
This Windows installer contains RDJ and RDJ Pro plus optional broadcast,
recording and administration tools. Delphi is not needed on the destination PC.
Every installation includes **one mixer: RDJ or RDJ Pro**.
  
Use Windows 10 22H2 or later. Windows N editions and Windows Server may need the corresponding media features enabled.
After installing, choose the actual audio devices and broadcast settings in the
mixer's setup; personal device assignments are not bundled.
  
## Install
  
1. Run `FactoryX-DJSuite-x.x.x-Setup.exe` on the PC being installed.
2. Choose the application folder, for example `D:\Radio\Applications`.
3. Choose **RDJ Pro** (audio/video) or **RDJ** (audio).
4. Choose a 64-bit or 32-bit application.
   A PC running 32-bit Windows requires the 32-bit release. A PC running 64-bit Windows can run both releases.
   The 64-bit release can address more memory, which may benefit demanding workloads, but it does not automatically improve playback quality or performance.
6. Select the optional components. The two administrator tools are independent:
   installing an administrator does not require installing its server locally.
7. Choose the data folder and compliance recording folder. The website is
   created below the data folder as `Web`. Recordings and data are kept
   separately from program files and are retained when uninstalling. New
   FxServe/FxRecord INIs and logs live below this writable data folder; shortcuts
   and service registrations pass their actual INI paths explicitly.
8. For a web server, select local-only, private LAN or public HTTPS access.
   Public HTTPS needs a real hostname, DNS pointing to the server and router
   forwarding. Setup does not change your router or DNS.
9. For FxRecord, select HTTP/HTTPS HLS or a published Stream folder, then enter
   the actual source. Use the station's `.m3u8` URL for a remote/home recorder.
   FxRecord currently needs the supported fMP4 HLS format; an Icecast MP3 mount
   alone is not that format.
10. Choose optional service registration and firewall rules only when wanted.
   They are off by default. Review the summary, then install.
  
The **Studio PC** preset installs the mixer and guides. **Studio PC with FxServe
and recording tools** selects the FactoryX tools too. Custom selection gives
individual choices while keeping the mixer required.
  
## Components
  
| Component | Installation behavior |
| --- | --- |
| RDJ / RDJ Pro | The selected edition and architecture, including its SQLite DLL, needed for Delphi versions that does not have FireDac. |
| FxServe | Native HTTP/HTTPS server, optional Windows service. |
| FxServe Admin | Independent local/LAN administration tool. |
| FxRecord | Desktop recorder, optionally registered as a Windows service. |
| FxRecord Admin | Independent service settings/status tool for the recorder PC. |
| Caddy | Official 64-bit executable and license; configured console launcher. |
| Icecast | Official 64-bit installer; its own setup opens after the suite wizard. |
| Web applications | Player, FxAlert and static assets for selected web servers. |

The included official Caddy and Icecast packages require 64-bit Windows. They
can serve a 32-bit mixer on a 64-bit PC. These optional packages do not turn
into 32-bit applications when the mixer architecture changes.
  
If you require **32-bit Caddy or Icecast**, leave their bundled components
unchecked. Visit the [Caddy download site](https://caddyserver.com/download)
or [Icecast download site](https://www.icecast.org/download/) to check for a
compatible 32-bit release and install it separately. Availability depends on
the vendor; Setup does not bundle or download those 32-bit packages.
  
Icecast's own installer asks for its destination and configuration. It manages
its own uninstall entry; removing the radio suite does not remove an independent
Icecast installation. Silent suite installation does not run that second wizard.
Caddy is launched through **Caddy console**; this package does not pretend that
`caddy.exe` is a native Windows service or install an unlisted service wrapper.
  
## Local PC, server and split installations

Setup installs on the PC where it is running. Copy the same setup EXE to another
Windows PC and run it there for a split installation. It does not remotely deploy
Windows services to a server or NAS. As requested, even a server installation
includes a selected RDJ/RDJ Pro edition; you can leave that mixer closed.

For a split studio/server arrangement:

- On the studio PC, install your mixer and any administrator tools you need.
- On the Windows server, install a mixer edition plus FxServe or Caddy and,
  optionally, FxRecord. Leave the server's mixer closed if broadcasting from
  the studio PC.
- Configure RDJ Pro's publication paths to the server's writable website/share.
  Setup creates local paths, not SMB shares or network credentials. Choose
  audio devices and station settings in RDJ/RDJ Pro after installation.
- A home recorder can instead use the public HLS URL and its own local archive.
  
FxServe's LAN port is **8080**. Caddy's local/LAN example uses **8081** to avoid
that default port. Public HTTPS uses **80/443**: enable public serving in only
one web server on a given machine/address. Installing both executables does not
make it safe to run both public listeners on the same ports.
  
## Desktop or service recording
  
The FxRecord desktop shortcut opens the recorder ready for configuration;
press **Start** to begin. Keep its window open during desktop recording.
  
The optional FxRecord service starts recording without a signed-in user. Do
not run desktop and service instances against the same archive/configuration.
Closing a desktop window does not stop an already running Windows service.
Use FxRecord Admin, Windows Services or `sc.exe query FxRecord` to verify it.
  
Service executables must be on a local disk. The default LocalSystem account
does not inherit a signed-in user's mapped drives or share credentials. For
network archives, configure the service account and permissions manually before
starting it. The wizard's automatic service registration uses local archives.
  
## FxAlert
  
When FxServe and FxRecord are installed together, new settings point FxServe's
public FxAlert status URL at the selected local recorder's actual status file.
HTTP-input status is beside `FxRecord.ini`; folder-input status is beside the
published Stream folder. Status is not cached.
  
A recorder on another PC does not automatically upload its heartbeat. Point
the hosting server at an accessible, explicitly selected heartbeat source or
use FxRecord Admin to monitor that recorder over the LAN. An alive broadcast
does not establish that the monitored recorder is alive.
  
## Updates and uninstall
  
- Back up your settings and data. Close selected desktop applications before
  updating. Stop an installed FxServe/FxRecord service before replacing its EXE.
- Existing INIs, databases and recordings are preserved. Wizard choices create
  defaults for new INIs; they do not silently rewrite an existing configuration.
  Review it in the corresponding application/administrator after an update.
- Existing services in this installation retain their account/registration.
  Clear the register/start task on an update, then restart them yourself. A
  service belonging to another directory blocks conflicting replacement.
- Unmodified managed website files can be updated. Customized files are kept;
  compare them with the new templates in `WebApps` when adopting website updates.
- Unregister this installation's services before uninstalling. Program files
  are removed; generated INIs, data, recordings and customized website content
  remain. Optional firewall rules are retained for administrator review.
  
Read `Setup-configuration.log`, `Setup-plan.json` and the application logs if
configuration or startup needs attention. The package's `BuildManifest.json`
records bundled files, architectures, sources and SHA256 hashes.
  
Test installation, sound/video devices, service operation and uninstall on
a spare PC or VM before distributing it as a signed production installer.
The build machine's active broadcast, recorders and Windows services are
not used as installation test targets.
  
  
Copyright © FactoryX. All rights reserved.
  
