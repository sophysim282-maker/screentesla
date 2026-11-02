# ScreenLink AirPlay Lab

ScreenLink receives the iPhone's own AirPlay mirroring stream through a local VPN peer and serves video to another device's browser over the iPhone hotspot. The viewer only needs a browser. Version 0.11.0 embeds ScreenLink Local VPN, so a separately installed LocalDevVPN is no longer required with a compatible signing profile. Floating preview remains the tested background path; the timed background session and native YouTube playback still need device validation.

## Confirmed baseline and current change

The user confirmed version 0.7 displayed their iPhone screen in the browser without a Mac advertiser. Their log shows local-only DNS lookup at 10.7.0.1, an AirPlay connection from that peer to the iPhone's 10.7.1.1 VPN interface, decoded video, floating preview ACTIVE, and additional frames after the app entered background. This establishes that session, not long-term stability or compatibility with every iPhone/browser.

Version 0.8 preserves the working discovery and PiP controller source. It adds continuous multipart JPEG streaming, a snapshot compatibility viewer, three video profiles, corrected frame cadence, and browser reconnect/full-screen controls. Device performance improvements remain unverified until compared on the phone. See [TESTING-0.8.md](TESTING-0.8.md).

## Use

1. Install the unsigned IPA through your existing signing setup. An unsigned build still requires valid device signing; normal free-account expiry and app limits apply.
2. Sign the complete IPA with a profile supporting `com.apple.developer.networking.networkextension = [packet-tunnel-provider]` on both the app and embedded extension. Keep the extension when signing with KravaSign. Open the app, tap **Connect built-in VPN**, and accept the iOS VPN configuration prompt. Disconnect other VPNs first. The peer is 10.7.0.1; the interface is 10.7.1.1.
3. Enable Personal Hotspot and connect the viewing device to it. Stop any old Mac proxy advertisements.
4. In ScreenLink select **iPhone VPN**, choose **Fast**, and tap **Start receiver**. Copy the complete hotspot viewer link, including its token.
5. Open Control Center → Screen Mirroring → **ScreenLink VPN Phone**.
6. Return to ScreenLink. On iOS 26+, try **Start 30-minute background test** and wait for **BACKGROUND SESSION ACTIVE**. This new no-PiP mode needs a device test; iOS can reject/end it. Alternatively use **Start floating preview** and wait for **ACTIVE**, as in the previously confirmed session.
7. Open the complete viewer link on the other device. Default **H.264** forwards the original video. **JPEG fallback** and **Snapshot mode** are compatibility options and need PiP when backgrounded.

Keep the phone unlocked. Closing or pausing PiP can stop background sharing. Hiding the floating window at a screen edge is different from closing it and may help avoid repeated screen-within-screen content. Audio is not forwarded.

Viewer tokens persist across receiver restarts. Use the complete link and the actual hotspot address displayed by the app; do not assume every network uses the same address. A different device cannot use the iPhone's private VPN peer as its viewer address.

## Original video and JPEG fallback

The default H.264 viewer remuxes compressed video into fragmented MP4 for MediaSource, without JPEG conversion or a 15–20fps throttle. It retains source timing and resolution. Browser buffering, source frame rate, network conditions and thermal limits still affect performance. A generated 60fps fixture retained all 60 matching frames through the muxer; an end-to-end 60fps iPhone result is not yet established.

The following profiles apply only to JPEG fallback:

| Profile | Longest image edge | JPEG quality | Source-frame cap |
| --- | --- | --- | --- |
| Fast | 720 pixels | 0.45 | 20 fps |
| Balanced | 960 pixels | 0.50 | 15 fps |
| Sharp | 1280 pixels | 0.68 | 15 fps |

Profiles can change while sharing. Caps are not guaranteed achieved rates. H.264 reports incoming compressed-frame FPS and the browser video-frame counter. JPEG reports generated-frame FPS; snapshot mode additionally measures its display-loop FPS. A slow client receives the newest available frame rather than an unbounded queue. At most two continuous viewers are admitted.

## Discovery modes

- **iPhone VPN**: local-only A, AirPlay and RAOP records point at the VPN peer. The app verifies browse, SRV resolve and IPv4 lookup separately. This is the mode confirmed by the user on 0.7.
- **Mac VPN**: suppresses phone advertisements; `bash tools/mac_vpn_discovery.command` advertises the peer from the Mac using metadata fetched from the current viewer link. This is the earlier working fallback. A Python helper is also included.
- **Native**: ordinary phone-host Bonjour advertisements, primarily useful for receiving from other senders. Same-phone behavior varies.

Stop sharing before changing discovery mode. Do not run the Mac advertiser while testing iPhone VPN mode. Successful DNS publication, Control Center visibility, handshake, and decoded video are distinct checkpoints.

## Build without Xcode on your own Mac

The included GitHub Actions workflow builds an unsigned arm64 IPA on a Mac runner when main changes, or via workflow_dispatch. Check the Actions result and your GitHub runner allowance. Free device signing is a separate installation step.

For a local build, use macOS with full Xcode and `brew install xcodegen autoconf automake libtool`, then run:

```bash
bash tools/build.sh
```

The build fetches pinned RPiPlay sources and cross-compiles its dependencies, runs portable cadence/multipart tests and a real local-only Bonjour lookup test on macOS, and native H.264 cache tests, then compiles the iOS app. The app embeds a packet-tunnel Network Extension; both targets request the packet-tunnel-provider entitlement. No App Groups entitlement or ReplayKit capture is needed. Unsigned builds cannot validate the signing profile or an installed VPN connection.

## Validation and limits

- Portable tests cover Annex B parsing, frame cadence under jitter, binary multipart framing and disconnected clients.
- Viewer JavaScript checks cover continuous mode, snapshot fallback, mode switching and expired-link cleanup.
- The native Mac test exercises local-only Bonjour registration, browse, service resolution, IPv4 lookup and teardown. It does not test the iPhone's AirPlay picker.
- Successful iOS compilation does not prove device signing, discovery, sustained background operation, or a frame-rate improvement.
- No audio forwarding, lock-screen capture or protected-content bypass is provided. The AirPlay protocol core is old; current-iOS compatibility is not established across devices.

Current disconnect fix and test: [0.9.1](TESTING-0.9.1.md). Video/background architecture: [0.9](TESTING-0.9.md). Native YouTube video-only/HLS casting is not implemented.

Earlier experiment details: [0.7](TESTING-0.7.md), [0.6](TESTING-0.6.md), [0.5](TESTING-0.5.md), [0.4](TESTING-0.4.md), [0.3](TESTING-0.3.md), [0.2](TESTING-0.2.md).

## Sources and licenses

The build fetches [RPiPlay](https://github.com/FD-/RPiPlay) at commit `64d0341ed3bef098c940c9ed0675948870a271f9`. Its GPL-3.0 license and subcomponent notices apply; see LICENSE and the downloaded Vendor/RPiPlay/LICENSE. `tools/prepare_receiver.py` surfaces registration errors, adds Darwin socket compatibility, and supports external discovery metadata without competing advertisements. The app advertises the actual listener port and uses matching receiver metadata. It does not copy APTV code or claim to reproduce its undocumented implementation.

OpenSSL 1.1.1w and libplist 2.2.0 are fetched at build time; their licenses remain applicable. This is an experimental receiver based on older dependencies, with no completed security audit.

## 0.9.2: bookmark the hotspot viewer

On the iPhone Personal Hotspot, bookmark `http://172.20.10.1:8080/` (or the actual bridge address shown at the top of ScreenLink). The root address redirects hotspot clients to the current viewer token automatically. Start the receiver first. Anyone connected to this hotspot can use the short viewer address. Other Wi-Fi interfaces and media/API requests still require the token. This changes link convenience only; the 0.9.1 video/background fixes remain.

## Built-in VPN (0.11.0)

ScreenLink Local VPN routes only 10.7.0.1/32, reflects IPv4 packets between that peer and 10.7.1.1, and leaves Internet routes and DNS unchanged. No external VPN server is used. The app discovers the installed extension bundle ID, including signer rewrites, before saving the configuration with NETunnelProviderManager. iOS presents its own consent prompt; there is no separate mobileconfig to install. The Disconnect VPN button retains the saved profile for reuse.

KravaSign advertises VPN entitlement support, but the actual provisioning profile must authorize packet-tunnel-provider for the app and extension. A certificate alone does not grant this entitlement. Do not strip PlugIns/ScreenLinkLocalTunnel.appex or remove its entitlements. The app logs missing-extension, permission and connection failures. This build has not been tested on a physical iPhone or with the user's KravaSign profile.

The built-in VPN **does not keep the containing receiver app running indefinitely**. The existing floating preview/timed runtime requirements still apply. YouTube media compatibility is also separate.

The local peer approach is based on [LocalDevVPN](https://github.com/jkcoxson/LocalDevVPN) by jkcoxson, Stossy11 and the SideStore Team. ScreenLink implements its own restricted packet reflection and VPN manager. See the bundled `LocalVPN-Attribution.txt` for the upstream license.

## Canvas player (0.12.0)

The video-only viewer now displays frames on Canvas with pause/play, seek, full screen and Normal/Music sound controls. On secure contexts exposing both VideoDecoder and AudioDecoder it uses bundled MP4Box.js 0.5.4 and mux.js 6.3.0 for fMP4/TS demux, WebCodecs for video/audio decoding, timestamped Canvas painting and Web Audio scheduling. Frame and audio queues are bounded; seeks, reconnects and page exits release decoders, VideoFrames, fetches and audio nodes. Libraries are integrity-pinned and bundled with licenses, with no runtime CDN requests. Hardware decoding depends on browser/codec/device availability and is not guaranteed.

**The standard http://172.20.10.1:8080 hotspot link is not a secure context.** Browsers normally withhold WebCodecs there. That link uses the existing native/HLS.js decoder with a hidden video element, Canvas presentation and optional Web Audio EQ. This is a display fallback, not direct WebCodecs. Unsupported codecs, encrypted/live HLS and direct decoder failures also fall back to compatible playback. Matroska files are not accepted by this AirPlay HLS endpoint. Canvas does not conceal video activity from the browser or guarantee compatibility with any car/browser restriction. This version does not change the iOS background runtime or VPN behavior.

## Live Maps + YouTube screen broadcast (0.13.0)

A new ReplayKit Broadcast Upload extension owns the AirPlay receiver, media proxy and hotspot HTTP server for the duration of a user-started system screen broadcast. This removes the main app's continued-processing timer/PiP dependency in this mode; it does not guarantee iOS will never interrupt capture. The VPN remains a separate signed extension. No App Groups entitlement is used: the main app probes/controls only the loopback listener with a non-CORS custom header. It never automatically starts capture, and returning to the app does not start a competing receiver.

Setup: retain BOTH embedded extensions when signing. Connect ScreenLink Local VPN, choose **Maps + YouTube · prepare screen broadcast**, tap the actual round system broadcast picker, choose ScreenLink Screen and Start Broadcast. Wait for SCREEN BROADCAST ACTIVE in the app log. Select ScreenLink VPN Phone inside YouTube AirPlay, then open Google Maps. Open the existing hotspot root URL (or /split) on the Mac. The default viewer for the broadcast receiver is a two-panel dashboard. Drag the divider, use its arrow/Home/End keys, reset to 50/50, or toggle stacked layout. Ratios persist locally. Switching into this mode replaces the regular receiver; reconnect YouTube AirPlay once after starting the broadcast.

The left panel is the **whole currently visible iPhone screen**, not a Google Maps SDK embed or selective app capture. Other apps and system UI can appear when you switch apps. Microphone and ReplayKit app audio are ignored; YouTube audio remains on the native AirPlay media path. Screen frames are scaled to at most 960 pixels on the longest edge, encoded as H.264 up to 30 fps with two frames in flight, and served as bounded fMP4 history. The screen player handles orientation, epochs and transient network failures. Broadcast-hosted mirroring skips local video decoding/JPEG encoding, and screen/forwarded H.264 histories use smaller memory limits.

The screen broadcast and YouTube's native AirPlay must coexist on the actual iPhone: this cannot be established by CI. iOS/sender policies may interrupt either mode; lock, calls, user cancellation, network loss or extension memory pressure can stop a broadcast. The app does not promise or attempt silent capture restart. Stop with Control Center or Stop sharing; normal sharing modes remain available. CI verifies extension compilation/packaging, independent screen/media panels, moving/persisted/keyboard divider, live H.264 Canvas pixels, orientation and epoch reconnects, plus all existing video-only and mirroring tests. Physical device capture, VPN discovery from the extension, signed entitlement behavior and sustained YouTube + Maps playback remain unverified.

## Manual screen privacy (0.13.1)

Screen broadcasts start hidden. The viewer has Hide phone screen and Show phone screen controls. Open Google Maps first, then Show; before leaving Maps, Hide and wait for the server-confirmed HIDDEN status. YouTube's independent media/audio path is unchanged. This is manual privacy control, not automatic identification of Google Maps; showing while another app is open shares that app.

Hide blocks new screen samples at input, blocks encoded output under the H.264 stream lock, clears pending/history data and advances the stream epoch. Show requires the latest privacy revision, rejects stale in-flight encoder permits, excludes captures older than the Show timestamp, and waits for a fresh keyframe. Privacy revisions also reject stale delayed Show requests after Hide. Viewer startup is covered; Hide clears the video source and Canvas, while a short policy lease hides screen output if privacy status cannot be refreshed. A failed request never claims server-side Hide was confirmed. These controls do not prevent a different authorized viewer from deliberately pressing Show.

## WebRTC milestone 1 (0.14.0)

The main app has a foreground-only **WebRTC pairing test · no video yet** screen. With Personal Hotspot active and the viewer connected, Start pairing test gathers local host candidates without STUN/TURN, creates a v2 signaling session at tesla4khmer.com, and displays the six-digit code. The phone explicitly approves/rejects a pending join. The current-revision answer is applied before testing the ordered data channel named `ping`. The protocol is UTF-8 `ping` → `pong`, with JSON ping replies also supported. A local-route/traffic/ping check determines verification; SDP submission alone never means connected. The phone only publishes its 172.20.10.1 host candidates in this user-facing test. Failure to find a hotspot candidate is reported without publishing a session.

Server-generated Device secrets are held only in memory and only sent as HTTPS Authorization headers to the fixed signaling origin. Redirects are denied. Existing local viewer tokens are never sent to signaling. Diagnostics omit SDP, pairing codes and role secrets. Heartbeats, approval/answer polling, revision-checked ICE restart offers and explicit session cleanup follow the attached v2 contract. Signaling failures or expiration retain an established local peer connection. The app must remain foreground for this initial test. No Maps, YouTube, audio or camera/screen capture is attached to WebRTC in milestone 1. Local AirPlay/VPN/broadcast/Hide-Show modes remain separate. Native iPhone↔Tesla connectivity and all vehicle-browser capabilities remain unverified.

The app embeds WebRTC M156.0.0 from the community stasel/WebRTC distribution (upstream commit 2a990ce0ccd00a3ad449f2201a8e5c2dad53177d). The archive SHA-256 is pinned to the publisher's Swift package manifest. CI verifies a real native-to-native DTLS/SCTP ping on one Mac; a production-signaling integration test uses a short-lived session with real SDP and closes it afterward. Those are not physical iPhone/Tesla tests. See docs/screenlink-signaling-contract-v2.txt for the provided contract.

The self-contained reference browser client is `docs/webrtc-ping-viewer.html`. Lovable can publish it as an HTTPS test route (for example `/screenlink-ping`) before the physical-device test. Its Chromium fixture test uses real data-channel peers with controlled signaling, including explicit approval, state reports, signaling expiry, stale-ping detection and Stop. This reference file has not been deployed to the public website by this repository.
