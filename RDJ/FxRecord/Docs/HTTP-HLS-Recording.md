# HTTP/HTTPS stream recording

FxRecord 4.2 records a standard HLS stream over HTTP/HTTPS. It uses a native
Windows HTTP client to fetch the playlist and its media, without rendering a
web page. No FxServe API, live.json download, RDJ recording units, recovery
subscription or server-folder access is needed. Any HTTP server hosting the
supported media playlist can supply the recording. The broadcast still needs
an HTTP server to deliver its media to listeners and recorders.

On the Recorder tab choose **HTTP/HTTPS stream (HLS)** and enter the actual
media playlist URL. For FactoryXradio:

```text
http://factoryxradio.asuscomm.com/stream/live.m3u8
```

The request starts on port 80. If the website redirects to HTTPS, FxRecord
follows the redirect and uses Windows certificate validation. HTTP input does
not bypass errors in the server delivering the stream; the recorder retries
them and records the missing intervals in its log.

An example desktop/service configuration:

```ini
[Recorder]
Enabled=False
SourceMode=PublicUrl
StreamUrl=http://factoryxradio.asuscomm.com/stream/live.m3u8
ArchivePath=\\PCHP001\ComplianceRecordings
PollIntervalMs=1000
RequireLiveStream=True
LiveStaleSeconds=15

[Archive]
FragmentDuration=60
RetentionDays=14
OutputProfile=AVI-H264-MP3
```

`StreamPath` is ignored for this HTTP input. The existing `PublicUrl` INI value
is retained for compatibility; it now selects HLS. Old `/stream/live.json`
settings migrate to the sibling `live.m3u8`. A station-root URL is a convenience
for that layout; other stations should use their explicit `.m3u8` URL. Query
strings and relative/absolute media URLs are supported. A plain website HTML
page is not a media playlist.

`SourceCopy` saves received H.264/AAC media to MP4 without conversion.
`AVI-H264-MP3` and `MP4-H264-AAC` perform conversion on the recorder PC after
the interval closes. During AVI recording, the active file is a source MP4
with `.partial` suffix; the completed AVI appears at scheduled rotation or
when Stop is pressed.

## Connection losses and hourly files

- Brief and sustained connection errors keep the same interval file open.
- If the missing segments remain in the HLS window, they are retrieved on
  reconnection. Otherwise FxRecord logs the missing sequence range and resumes
  with available media in the same hourly file. Missing broadcast is not
  manufactured or described as complete coverage.
- A compatible encoder restart continues in the same hourly file with its
  decode timestamps rebased onto the existing timeline. Codec/track/timebase
  incompatibility requires a new file and is explicitly logged.
- Scheduled rotation still occurs while disconnected. Once the stream returns,
  recording starts in the current interval. An interval with no received media
  does not create a fake empty recording.
- Keep the desktop app open while recording. Use the Windows service only for
  unattended operation, and avoid simultaneously recording from both against
  the same configuration/archive.

## Supported HLS input

The independent reader supports unencrypted HLS with complete fMP4 segments and
an `EXT-X-MAP` initialization segment, with H.264 video and AAC audio together
in the selected rendition. It follows master playlists, HTTP redirects and
signed media URLs. It rejects incomplete initialization headers and retries
them instead of caching an unusable MP4 header.

Encrypted/DRM streams, MPEG-TS segments, byte-range playlists and separate
audio/video rendition assembly are not supported by this reader. Unsupported
input produces a specific error instead of a silent or malformed archive.

The playlist handling follows the relevant HLS structures in
[RFC 8216](https://www.rfc-editor.org/rfc/rfc8216.html). This is a media client,
not a general web-browser capture engine.
