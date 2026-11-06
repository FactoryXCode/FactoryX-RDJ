# RDJ Pro project search paths

Open `MfRdjJ.dpr`, then - in the IDE - go to **Project > Options > Delphi Compiler > Search path**.
Select **All configurations / All platforms** so the paths apply to Win32 and Win64, Debug and Release.

Enter these absolute paths, one entry per line, in this order, for example:

```text
E:\PROJECTS\MfPack\src
E:\PROJECTS\MfPack\Samples\MfComponents
E:\PROJECTS\MfPack\Cast
E:\PROJECTS\MfPack\Cast\Media
E:\PROJECTS\FactoryX-RDJ\FactoryX-RDJ\RDJ\Controls
E:\PROJECTS\FactoryX-HEOS-CLI\Source
E:\PROJECTS\FactoryX-HEOS-CLI\AVR\Source
E:\PROJECTS\FactoryX-HEOS-CLI\AVR\Samples\HEOSRemote\Controls
```

These provide the HEOS API, AVR API, TDn controls, MfPack units, Cast units and RDJ controls. Adjust the absolute paths if your checkouts are elsewhere.

For the form designer, install these component packages once:

```text
E:\PROJECTS\MfPack\Samples\MfComponents\MfComponents.dpk
E:\PROJECTS\RDJ\Controls\RDJControls.dpk
E:\PROJECTS\FactoryX-HEOS-CLI\AVR\Samples\HEOSRemote\Controls\HEOSControls.dpk
```

Keep Delphi's inherited library paths. After changing dependencies or updating the API, use **Project > Build**.
