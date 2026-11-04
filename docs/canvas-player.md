# Local Canvas player — 0.20.0 / build 37

The HTTPS viewer at `https://car.tesla4khmer.com/` now uses Canvas and WebCodecs
for screen video and original YouTube media, with Web Audio for the latter.
It is intended for playback while parked and does not override vehicle policy.

## Implemented path

- Existing local VPN owns the virtual address; HTTPS stays on port 443.
- Static HTML/JavaScript and demuxer assets are served locally. No runtime CDN.
- Explicit code-free phone approval gates media, screen data and WebSocket access.
- `/stream` is an approved, same-origin, hotspot-only secure WebSocket. It pushes
  current screen metadata, the fMP4 initialization segment and bounded fMP4 batches
  from the existing ReplayKit/VideoToolbox H.264 stream.
- A masked `next` acknowledgement allows only one batch in flight. Fragmented,
  unmasked or oversized client messages are rejected. Server framing is capped
  at 2 MiB. Generation, approval, epoch and privacy are checked throughout.
- The Maps decoder demuxes compressed samples and passes them to VideoDecoder;
  decoded VideoFrames are drawn directly onto Canvas and closed. At most one
  decoded screen frame waits for drawing; compressed decode work is bounded.
- Original YouTube media still uses the existing local HLS resource server. Its
  demuxer feeds VideoDecoder and AudioDecoder, with scheduled Web Audio playback.
  It is not converted into phone screenshots and is not sent through a cloud.
- The active HTTPS viewer creates no HTML video/audio elements, including hidden
  or detached elements. Unsupported sources show an error instead of silently
  creating a compatibility media element. HTTP on 8080 retains the old viewer.

## Privacy, reconnect and caching

Capture starts hidden. Show requires the current phone privacy revision. Hide
clears the client decoder/frame immediately and reports whether the phone has
confirmed. A lost connection never claims that Hide is confirmed. The Disconnect button
revokes approval and hides capture when the phone confirms the request. WSS reconnects with bounded backoff; showing
screen content again requires an explicit Show after a lost connection.

A Service Worker caches only the static UI assets after a successful first load.
When the phone server is unavailable, an installed, retained cache can open the UI
with its connection guidance. Tokens, approval responses, screen/video segments,
HLS manifests and audio are never cached. First load still needs the phone server;
browser cache eviction, DNS and browser support can prevent offline availability.
The cache does not extend iOS broadcast runtime or provide media while offline.

## Use and limitations

Sign/install the personalized IPA with both extensions retained. Keep experimental
VPN and system screen broadcast active. Open the HTTPS hostname on a hotspot
client, press Connect phone and approve on the phone. Tap Play with sound to
unlock Web Audio. Open Maps before Show; Hide and wait for confirmation before
switching apps. The divider, orientation, pause/resume, seek, quality choices and
reconnect behavior remain available.

`ScreenLinkCanvasStatus()` exposes bounded diagnostic counters, not tokens.
The capture encoder keeps its existing target settings; 30/60 fps, a given HD
resolution, physical Tesla compatibility and uninterrupted capture are not
promised by configuration. HLS VOD/clear sources and supported browser codecs
are required by the direct media decoder. Encrypted/live variants may need future
support; the player reports that limitation. Navigation app audio is not a new
ReplayKit audio track in this change; original YouTube audio remains separate.
Online YouTube/Maps source content may still require cellular Internet, while
phone-to-viewer media stays on the local hotspot.

The private TLS identity is packaged after public CI as in build 36. No key is
committed to source or public build artifacts. Renew the certificate before expiry.

## Build 38 packed HLS audio repair

The player previously classified every non-TS segment as MP4. A valid AAC/ADTS segment (with or without an HLS ID3 prefix) reproduced the exact `No decodable samples in media segment` error. Container sniffing now sends packed AAC to the existing mux.js demux pipeline, then WebCodecs AudioDecoder and Web Audio. ID3-prefixed TS is supported too. MP4 empty-sample failures report bounded box types, track count and byte count; unknown formats fail explicitly. No URLs, credentials or sample contents enter diagnostics.

Regression fixtures cover packed AAC both directly and as an alternate HLS audio rendition alongside Canvas video. Existing TS/fMP4 and Maps tests remain required. This repair is not evidence that the user’s exact uncollected segment was AAC; physical playback remains to be confirmed.

## Build 39 Web Audio continuity repair

MacBook website audio was reported to cut out/crackle while video played. The old scheduler used a fresh currentTime reading for every packet and discarded all scheduled PCM on pause; muted scheduling also discarded future PCM. A deterministic jittered-clock/segment-boundary fixture reproduces gaps with the old scheduler. The new scheduler maps timestamps to a single absolute AudioContext clock, joins small AAC boundary discrepancies to the preceding sample end (bounded to 40 ms or 1.5 packet durations), keeps real source gaps, retains unplayed scheduled packets on pause, and prunes only expired PCM while muted. A 20 ms look-ahead timer runs independently of Canvas animation, with 350 ms maximum scheduling look-ahead. Large network/decode interruptions can still exhaust the buffer; this is not an unlimited buffering promise.

Validation includes a software PCM waveform regression and actual OfflineAudioContext rendering in Chrome 140 and newer Chrome. These measure silence and waveform discontinuity, rather than just counting decoded packets. Existing media, Maps/privacy and source format regressions remain required. Actual Mac/Tesla speaker playback still needs user confirmation.
