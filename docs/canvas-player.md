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

Integration validation also exposed an initial sound-enable clock migration defect: the shell assigned the new AudioContext before the player captured its old performance-clock playhead. The player now accepts the shared context inside enableAudio, preserves its position before assignment, and then reanchors once the context is running. The playback regression requires audioScheduled rather than just audioDecoded.

## Build 40 audio timer lifecycle correction

Build 39 accidentally created its 20 ms audio timer both in the constructor and at the end of every Canvas paint callback. This caused unbounded timer growth while destroy could clear only the latest handle. That implementation defect can create escalating main-thread load and interruptions; it is a plausible cause of the reported approximately three-second playback pauses. Build 40 creates the timer only in the constructor and retains the existing destroy cleanup. It does not alter codecs, sample timestamps, resolution selection or the Maps decoder.

The deterministic regression runs 12000 real paint callbacks across 20 player lifetimes and asserts one interval per live player and no outstanding timers/animation callbacks after destroy. It fails against build 39. The real browser fixture additionally instruments setInterval/clearInterval and asserts one live interval during media playback/replacements and zero after disconnect. Existing waveform, shared-clock handoff, packed AAC and video/Maps/privacy regressions remain required. Physical MacBook playback still needs confirmation.

## Build 41 bounded segment prefetch

The user still reports approximately six seconds of playback followed by a short pause. The player had been waiting for a segment's bounded decoding loop and decoder flush before fetching the next segment. At that point only the small decoded-frame lead remained to hide transport delay. The new consume loop starts the next encoded-segment request before decoding the current prepared payload. It retains only one next segment per rendition, keeps decoded queues unchanged, reuses init data, and discards late results after seek/destroy. Init and media fetches remain serial within a rendition to avoid exceeding the broadcast server's resource slots. No media relay, extra video element or codec changes are introduced.

The browser fixture delays each TS response by 1.3 seconds, samples 7.3 seconds of active playback, and compares wall elapsed time to media progress. The pinned build 40 is a negative control and must reproduce at least 150 ms of accumulated stalls; the repaired player must stay below 100 ms of progress loss and buffer waiting under the same conditions. This is a controlled transport reproduction, not proof that the user's precise pauses share the same cause. The new bufferWaitMs diagnostic is sanitized and contains no media URLs or payloads. Existing audio waveform, timer lifecycle, privacy, queue-bound and source-format tests remain required.

## Build 42 requested audio engine changes and segment timeline continuity

The user reports the periodic 6–8-second, approximately 100 ms interruption still occurs on their MacBook with build 41. Prefetching fixed the controlled transport regression but did not establish the cause of this remaining physical symptom.

This version copies AudioData directly into final AudioBuffer channel storage, eliminating the intermediate Float32Array PCM copy. Buffers and source/gain nodes still allocate: this is not a zero-GC claim. Scheduling uses a bounded 600 ms lookahead and a shared 40 ms future startup anchor. The media clock clamps at the frozen position during that runway. Pause, seek, replacement and disconnect apply an 8 ms per-source gain fade before a delayed stop, then clean up old nodes/graphs. Buffer starvation freezes both timelines, restores queued PCM and waits for 120 ms of decoded video before restarting on the common runway. Late audio is not blindly appended three seconds behind video.

The prior decoder normalized every segment's minimum PTS onto EXTINF start independently. This can create periodic gaps or overlaps when metadata rounding or changing audio/video lead differs from actual continuous source timestamps. A per-rendition source offset now persists across continuous source PTS. Explicit HLS discontinuities and nonadvancing/reset source timestamps establish a new offset. Packed AAC with per-segment timestamp reset remains supported. Source discontinuities are not indiscriminately flattened.

The new timestamp fixture inflates EXTINF by 100 ms while retaining continuous TS source PTS. Browser instrumentation measures actual AudioBufferSourceNode start/end gaps: pinned build 40 must reproduce a gap above 50 ms; build 42 must keep gaps below 5 ms and total gap below 20 ms over the observation interval. A separate unit regression checks mapped audio/video sample continuity, source reset recovery, direct planar copy/handle release, startup runway and stop fade. Existing delayed-fetch, waveform, single-timer, privacy and queue-bound regressions remain required.

Copy playback diagnostics exports only bounded segment timing/sample counts, queue lead, counters and sanitized errors. It contains no SDP, media URL, capability token, viewer nonce, screen pixels or PCM content. It provides actual Mac/Tesla evidence if the remaining physical interruption is not resolved. Actual speaker playback still needs confirmation.

Muxed audio/video samples are consumed in independent asynchronous decode lanes, each preserving its own decode order and common mapped timeline. Audio can fill its 600 ms lookahead while video waits for bounded Canvas queue space. A regression holds the video queue full and verifies that audio still decodes, then releases the video lane and checks completion.
