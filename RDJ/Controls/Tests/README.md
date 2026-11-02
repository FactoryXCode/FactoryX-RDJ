# Button caption repaint regression checks

`TMPxpButton` and `TDnButton` paint their own captions. In Delphi XE7,
`TWinControl.CMEnabledChanged` updates the native enabled state without invalidating
the custom-painted client area. A gray disabled caption can therefore remain visible
after enabling the button until a mouse-enter or another repaint occurs.

Both components now handle `CM_ENABLEDCHANGED`, call the inherited handler and
invalidate their painting. Disabling also clears the hover/fade state. Normal and
hover font settings and disabled gray rendering are preserved. No form layout changes
or forced white font assignments are required.

Run with Delphi XE7 installed:

```powershell
python RunButtonCaptionTests.py `
  --heos-controls D:\PROJECTS\FactoryX-HEOS-CLI\AVR\Samples\HEOSRemote\Controls
```

Use `--delphi-root` for another Delphi installation and `--output-root` for an
alternative test output directory. Tests compile and run for Win32 and Win64.
They create hidden test controls, inspect repaint requests and render bitmap snapshots.
They verify initial white text, gray disabled text, enable/disable repainting without
mouse input, custom font colors and word wrapping. Running applications are untouched.

The original component sources fail the enable/disable repaint assertions. The
corrected sources pass, while their caption pixel colors remain unchanged.
