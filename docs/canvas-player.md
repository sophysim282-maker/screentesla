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

## Build 43 four-second native audio horizon and video-only stall isolation

The user reports build 42 still pauses approximately every 6–8 seconds and explicitly requests the developer-supplied longer native audio scheduling pattern. The prior player also stopped all scheduled audio as soon as videoEnd lagged behind the clock. That behavior defeats even a large native audio cushion.

The audible media clock now follows available audio, rather than clamping to videoEnd. Brief video-only shortages hold the last Canvas image while scheduled sound continues; late video catches up by timestamp. Actual audio exhaustion still freezes the shared playhead, fades/stops sources and waits for audio/video refill before restarting on the common 40 ms runway. First late-arriving audio cannot rewind an already-running silent video timeline. Decoded packets more than 800 ms stale, and data before an explicit seek/recovery position, are discarded rather than appended late.

Scheduling fills up to four seconds in the native audio graph, capped at 256 live source nodes. To make that cushion real across segment boundaries, audio and video now consume the playlist in independent lanes. A bounded six-entry prepared-segment cache shares downloads and demux results, preserves common source A/V offsets, and releases each entry after its owning lanes consume it. There is no duplicate muxed-segment download per lane. The pending PCM safety cap is 512 buffers, allowing a pause to restore the four seconds of already-scheduled PCM in addition to the existing 128-buffer decode backpressure window. Direct final-buffer copying, short stop fades, timestamp continuity and one audio timer per player are retained.

New regressions verify a full native lead above 2.5 seconds, survival of a 250 ms main-thread blockage without stop/restoration, video-only starvation leaving queued audio running, true audio starvation performing coordinated recovery, shared segment fetch/cache cleanup and bounded four-second scheduling. Existing negative-control delayed-segment and timestamp-gap tests, actual OfflineAudioContext waveform rendering, timer lifecycle, Maps/privacy and source-format checks remain required. These are controlled tests; actual Mac/Tesla playback must still be confirmed.

Copy playback diagnostics now also reports native lead, audio sample rate, bounded playback events, video hiccups, audio underruns, stale drops, maximum live nodes and segment-cache use. It contains no media URLs, tokens, nonce, private SDP, PCM or screen content.

The legacy muted-video starvation fixture now gates the third segment until the test explicitly releases it. A fixed four-second response delay no longer guarantees starvation because the new audio lane requests that segment earlier. The fixture still requires muted video to hold its playhead at the last decoded frame, then resume after release; audible video-only shortage is tested separately and must preserve native audio.

## Build 44 device-diagnostic-driven packed AAC repair

The physical Mac diagnostic shows native audio lead of approximately four seconds, no audio underruns or rebuffering, but positive scheduled audio gaps and repeated zero-based audio source timestamps. Increasing buffering cannot repair these already-scheduled gaps. Video is independently 1080p/60 with a substantial rendered-frame drop count; this patch does not silently reduce source quality or claim to resolve every visual stutter.

A 6.1-second 44.1kHz ADTS fixture reproduces a separate concrete conversion defect: the previous AAC -> mux.js fMP4 -> MP4Box path returns 263 samples from 264 complete ADTS frames. Direct ADTS extraction preserves all complete frames, strips only the ADTS header/CRC, supplies AudioSpecificConfig, rejects malformed/truncated payloads, and retains the first sample's 33-bit MPEG timestamp from ID3 PRIV. ID3 v2.3/v2.4 frame sizes are handled. Timing tags no longer vanish before audio demux.

When packed timestamps are genuinely absent or nonadvancing/reset, audio uses exact sample-count continuation across segment boundaries instead of reintroducing rounded EXTINF gaps. The diagnostic labels that fallback explicitly. Valid advancing ID3 timestamps remain authoritative and explicit discontinuities still reset the mapping; the player does not blindly flatten genuine timestamp gaps.

Regressions count all ADTS frames including the final frame, exercise ID3 timestamp variants and 33-bit values, reject truncation, verify sample-count fallback and play continuous 44.1kHz packed AAC across multiple boundaries in the native browser audio graph. Existing four-second cushion, waveform, video-only hold isolation, true network starvation, frame/queue/cache bounds, Maps and privacy checks remain required. Actual Mac/Tesla playback still needs confirmation.

## Build 45: YouTube-only one-second startup reserve

The HTTPS shell configures its YouTube player with bufferSeconds=1. Playback waits at least one second after load/seek, for one second of downloaded compressed video coverage and (when sound is enabled) decoded audio. Both tracks retain the same presentation clock and 40 ms scheduling runway. Short final tails need only their remaining duration. Video stays bounded at its existing decoded-frame limit; the extra reserve uses downloaded compressed segments, avoiding a one-second 1080p decoded-frame allocation. Four-second native audio scheduling remains. Maps capture, networking, decoding and latency are unchanged. This adds startup/seek latency, not an exact one-second live delay relative to YouTube on the phone, whose AirPlay/HLS buffering is independent. It cannot repair waveform defects.

## Build 46: optional YouTube-only viewer

The iPhone app offers YouTube only · website with a copyable /video link. The HTTPS viewer has a View menu for YouTube only or Maps + YouTube. /video explicitly selects YouTube-only; /split explicitly selects both. The root remembers the last local View choice. YouTube-only expands the video pane and hides Maps, divider and Show controls. It closes the screen socket and requests phone-confirmed Hide on an approved connection, while media polling and the existing Canvas/Web Audio player continue. A failed Hide request stays unconfirmed and can be retried with Hide screen; a layout change never claims confirmation. Returning to split starts a fresh screen socket but never automatically shows capture. No encoding, media buffering, EQ, VPN or AirPlay changes. The system broadcast is still required to keep the local receiver running.

## Build 47: continuous AAC coding state

A generated 14-second 44.1 kHz AAC tone produced 618,496 PCM samples in both decoder paths, but flushing every 220 packets changed the waveform: peak absolute difference 0.08695 and RMS difference 0.001665, with the peak near 10.217 seconds in the browser probe. Timing-only and packet-count tests cannot detect this. The player's audio decoder now remains configured across ordinary HLS segments; it flushes at rendition end or when a new configuration or explicit discontinuity requires a new decoder. A regression compares actual player PCM with uninterrupted AAC decoding and requires a peak difference below 1e-6. Video retains its existing segment flush behavior.

A second probe compares a continuous PCM source with separate 1,024-frame sources: same-rate rendering is effectively identical; 44.1-to-48 kHz conversion can introduce differences at node boundaries, especially for high frequencies. When creating the audio context, the player and shell now request the decoded source rate if known (44.1 kHz before a source is known). Existing shared contexts remain intact, so a later source at another rate can still be resampled. This change reduces avoidable conversion; it does not claim to eliminate every device/output or source-audio defect. AudioDecoder flush count is included in playback stats. Maps, the view selector and the one-second YouTube reserve are unchanged.

## Build 48: recovery and quick start

Phone Start ScreenLink configures alias VPN, presents the system broadcast picker, then arms a five-minute first-local-viewer authorization window through loopback control. Existing source/origin checks and per-peer tokens remain. User must still confirm iOS dialogs and may need a browser gesture for sound. Website automatically requests connection; explicit Disconnect stops retries. Playback retries at the last position up to three times, retains the exact sanitized error in diagnostics and uses smaller decoded-video queues at the same resolution. This targets resource pressure but does not establish the cause of the Tesla failure. Physical 30-minute behavior remains unverified.
