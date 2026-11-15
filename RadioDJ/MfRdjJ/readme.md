MfRdjJ

Version: 4.1.0

&#x20; 

Description:  
Requires Windows 10 with latest updates or later.

&#x20; 

NOTES:

This release is updated for compiler version 34 (Delphi 12).  
The minimum version for your compiler is Delphi XE7.  
SDK version 10.0.28000.2705 (Win 11)  
Minimum supported MfPack version: 4.0.0

&#x20; 

A dj mixer app based on MfPack/Media foundation/core audio/WasApi.  
The original code was a DirectSound application written about 25 years ago, so,  
we rewrote the code for Media Foundation and did some more...

&#x20; 

What it does:  

Uses MDI adding channeldecks, loopbackdecks, a microphonedeck, effectsdeck (mft's) and  
enddeck (pfl, recorder (saves to WAV or FLAC) and IceCast web broadcasting support),  
playlisteditor and a tag editor (currently mp3 only).  
It's capable of redirecting audio to every endpoint  
separately (phone. master or any extra device on your pc) and or IceCast.

## &#x20; 

## Web server choice

RDJ can use **FxServe** or **Caddy** for its browser page, artwork, metadata, and
secure Icecast proxy. FxServe is the smaller option made for RDJ. Caddy is useful
when the server also hosts other websites or when you need more proxy features.

&#x20; 

For setup paths, router settings, and switching instructions, see [RDJ Web Server Setup](../../FxServe/RDJ-Web-Server-Setup.md).  

&#x20; 

The aim of this project is: Combine all kinds of MfPack (coreAudio WASAPI ) challenges in a single project.  
Now, the example has become pretty large for a sample but usefull for audio knights..  
We tested it, and it works without issues on Delphi XE7 up to 13.1.

&#x20; 

NOTES:

* The code is not suitable for starters and knowledge of audio manipulation/ algo's is also required.
* Before opening the project, install the MfRdjJ controls (..\\Controls\\RDJControls.dpk)
and MfPack MfComponents (MfPack\\Samples\\MfComponents\\MfComponents.dpk)

&#x20; 

Project: MFPack - Samples - MfRdjJ

&#x20; 

Project location:  

https://github.com/FactoryXCode/FactoryX-RDJ  

https://github.com/FactoryXCode/MfPack  
https://sourceforge.net/projects/MFPack  

&#x20; 

First release date: 05-02-2026  
Final release date: 15/11/2026  

&#x20; 

Copyright (c) FactoryX. All rights reserved.

