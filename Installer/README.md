# FactoryX Radio DJ binary installer

`Output/FactoryX-RadioDJ-4.0.1-Setup.exe` is the compiled Windows x64 installer.
It installs the selected precompiled applications, administrator tools, service
scripts, user manuals and optional Icecast/Caddy deployment packages. Users do
not need Delphi. See `InstallGuide.txt` for local, LAN and WAN deployment.

The current package is an unsigned acceptance-test candidate. Its existing
Win32 RDJ/RDJ Pro builds are dated August 17 / September 30, 2026; the recorder
is the October 10 debug build. All six application binaries have no imported
Delphi BPL dependencies. The dependency check resolves ordinary imports on
the packaging host; it does not replace testing on a clean target machine.
`Payload/BuildManifest.json` records input provenance and hashes.

Validation completed: Inno Setup 6.7.3 compilation, executable import checks,
and configuration/preservation checks for Local, LAN and WAN modes. No live
services, router, shares, firewall or remote server were changed during these
checks. Clean-machine installation/uninstallation, recording, audio devices,
Icecast, LAN publication and public HTTPS remain acceptance checks.

To recompile the staged package using an installed Inno Setup compiler:

```powershell
& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' .\FactoryXRadioDJ.iss
```

To stage refreshed binaries, move the existing `Payload` folder aside first,
then run `Build-Installer.ps1` with `-RadioDJRoot`, `-MfPackRoot`, `-RDJBinary`,
`-ProBinary`, `-RecorderBinary` and `-ISCC` paths as appropriate. Supply freshly
built self-contained Release executables for public distribution. The build
script copies only explicitly listed files, excluding personal INIs/databases,
recordings, log files and Delphi source or build intermediates.

Registered server services block replacement until they are stopped and
unregistered. Workstation-only installs can coexist with those services.
Uninstallation blocks removal of this installation's registered services until
they are unregistered. Existing configuration and generated user data remain.

The official compiler was obtained from
[Inno Setup](https://jrsoftware.org/isdl.php) and its Authenticode signature
was verified. Apply the applicable Inno Setup license for your packaging use.
