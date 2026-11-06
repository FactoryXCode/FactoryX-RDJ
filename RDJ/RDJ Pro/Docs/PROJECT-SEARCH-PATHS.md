# RDJ Pro project search paths

Open `MfRdjJ.dproj`, then go to **Project > Options > Delphi Compiler > Search path**.
Select **All configurations / All platforms** so the paths apply to Win32 and Win64, Debug and Release.

Enter these absolute paths, one entry per line, in this order:

```text
D:\PROJECTS\FactoryX-HEOS-CLI\Source
D:\PROJECTS\FactoryX-HEOS-CLI\AVR\Source
D:\PROJECTS\FactoryX-HEOS-CLI\AVR\Samples\HEOSRemote\Controls
D:\PROJECTS\MfPack\src
D:\PROJECTS\MfPack\Cast
D:\PROJECTS\MfPack\Cast\Media
D:\PROJECTS\MfPack\Samples\MfComponents
D:\GitHub\FactoryX-RDJ\FactoryX-RDJ\RDJ\Controls
```

These provide the HEOS API, AVR API, TDn controls, MfPack units, Cast units and RDJ controls. Adjust the absolute paths if your checkouts are elsewhere.

Also enter `D:\PROJECTS\MfPack\src` under **Delphi Compiler > Include file search path**.

For the form designer, install these component packages once:

```text
D:\GitHub\FactoryX-RDJ\FactoryX-RDJ\RDJ\Controls\RDJControls.dpk
D:\PROJECTS\FactoryX-HEOS-CLI\AVR\Samples\HEOSRemote\Controls\HEOSControls.dpk
```

Keep Delphi's inherited library paths. After changing dependencies or updating the API, use **Project > Build**.
