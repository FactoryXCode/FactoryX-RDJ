# RDJ Pro HEOS output

Open the HEOS window with the **HEOS** button beside **Broadcast**. Find/select your receiver, then click **Stream RDJ** in the Console panel. The checked button requests streaming from RDJ's Masterdeck; the status and log report connection progress. Clicking Stream RDJ again ends the stream. Closing or hiding this window keeps streaming; exiting RDJ stops the sender. Stopping this stream does not stop local RDJ playback.

The source is RDJ's stereo Masterdeck mix after Master FX. Masterdeck left/right volume and balance are applied to the network copy. Cue/PFL and unrelated Windows sounds are excluded. The receiver's volume control changes the receiver volume independently. HEOS buffers network audio, so receiver playback has a delay relative to RDJ's local output.

## RDJ Master Volume and receiver volume

These controls work in sequence and remain independent:

| Control | Effect |
|---|---|
| RDJ Master Left/Right volume | Changes the PCM level sent to HEOS before AAC encoding, as well as the local master output level. |
| RDJ Master balance | Applies left/right attenuation to the outgoing stream. |
| HEOS Remote volume | Changes the receiver's main-zone listening level without moving RDJ's Master faders or changing encoded audio. |
| HEOS Remote balance and tone | Apply additional receiver-side processing where supported; RDJ's mix stays unchanged. |
| PFL/cue volume | Changes headphone monitoring only. |

With centred RDJ balance, lowering both Master faders from 100 to 50 halves the
stream's PCM amplitude (about -6 dB). The HEOS Remote volume slider stays at the
receiver's setting. At RDJ Master zero the stream carries silence; increasing
receiver volume cannot recover it. Both RDJ and receiver balance affect the
final stereo image.

The receiver's current display uses a `%` suffix for its volume scale. This is
not a linear audio-amplitude percentage and cannot be multiplied by RDJ's fader
percentage to calculate output level. Use RDJ Master for the program level you
want to send and receiver volume for listening level. Allow for HEOS buffering
when judging a change to RDJ Master Volume.

## Streaming implementation

`RDJ.HeosOutput` copies PCM into a bounded preallocated queue. The render callback does not encode, perform network I/O, access VCL controls or wait for the encoder. A background worker initializes COM/Media Foundation and produces AAC/ADTS. `RDJ.HeosAudioServer` serves that stream on the PC interface routed to the selected receiver, using the PC address and TCP port configured in the HEOS remote. Allow the RDJ application through the private-network firewall if the device cannot fetch the stream.

The current RDJ engine uses 44100 Hz stereo float PCM; the sender also accepts 48000 Hz. Changing sample rate while streaming is reported in the HEOS log and requires restarting the sender. Queue overflow drops network-copy blocks instead of delaying local playback; the window displays a dropped-block count.

The separate window uses the TDn controls and glyphs from `FactoryX-HEOS-CLI/AVR/Samples/HEOSRemote`. It contains the Masterdeck stream toggle, elapsed streaming time, receiver discovery and connection settings, zone power, volume, balance, input, mute and bass/treble. All controls are designed in the DFM. Closing the window hides it while streaming continues.

This embedded remote has no file browser, playlist editor, file transport, seek bar or loop controls. RDJ Pro manages the music and playlists; the HEOS window sends the resulting Masterdeck mix. Its embedded HEOS request worker only starts the live URL or ends that stream. The standalone HEOS Remote sample is maintained separately.

The integration was checked with Delphi XE7 Win32/Win64, a local mock HEOS receiver and the actual Windows AAC encoder/HTTP stream. Validation covers gain application without altering the local PCM buffer, bounded queues, format-change reporting, device selection, close-to-hide behavior, normal HTTP disconnects and shutdown. Final listening/latency verification should be done with your receiver and normal RDJ audio setup.

## Connection and troubleshooting

- Start the RDJ audio engine and play music through its decks, then enable **Stream RDJ**. Files and playlists are selected in RDJ.
- Use **Find HEOS Device** if the receiver address is unknown or has changed. Check receiver power, network access and standby network-control settings if it cannot be reached.
- HEOS control uses receiver TCP port 1255 and AVR controls use port 23. The receiver connects back to the PC's HTTP port, default 8890. **PC IP** may be blank for automatic routing.
- If commands succeed but the HTTP request count remains zero, check the PC IP, configured port and private-network firewall access. FxServe and Caddy are not involved in this audio path.
- If HTTP requests arrive but audio is silent, check RDJ playback, both Master faders, receiver zone power, receiver mute and receiver volume.
- Receiver buffering creates a delay from the local master output. HEOS is not a replacement for the immediate PFL/cue output.

See the [technical handout](<Docs/RDJPro TechStuff.md>) for the full signal path
and source-unit responsibilities, and the [setup guide](<Docs/RDJPro Step-by-Step Setup.md>)
for component packages and project search paths.
