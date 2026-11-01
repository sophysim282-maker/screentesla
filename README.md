# ScreenLink AirPlay Lab

ScreenLink receives the iPhone's own AirPlay mirroring stream through a local VPN peer and serves video to another device's browser over the iPhone hotspot. The viewer only needs a browser. The phone app needs LocalDevVPN and an active floating preview for the tested background path.

## Confirmed baseline and current change

The user confirmed version 0.7 displayed their iPhone screen in the browser without a Mac advertiser. Their log shows local-only DNS lookup at 10.7.0.1, an AirPlay connection from that peer to the iPhone's 10.7.1.1 VPN interface, decoded video, floating preview ACTIVE, and additional frames after the app entered background. This establishes that session, not long-term stability or compatibility with every iPhone/browser.

Version 0.8 preserves the working discovery and PiP controller source. It adds continuous multipart JPEG streaming, a snapshot compatibility viewer, three video profiles, corrected frame cadence, and browser reconnect/full-screen controls. Device performance improvements remain unverified until compared on the phone. See [TESTING-0.8.md](TESTING-0.8.md).

## Use

1. Install the unsigned IPA through your existing signing setup. An unsigned build still requires valid device signing; normal free-account expiry and app limits apply.
2. Connect [LocalDevVPN](https://apps.apple.com/us/app/localdevvpn/id6755608044). The tested peer is 10.7.0.1; the interface address is a separate address.
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

The build fetches pinned RPiPlay sources and cross-compiles its dependencies, runs portable cadence/multipart tests and a real local-only Bonjour lookup test on macOS, and native H.264 cache tests, then compiles the iOS app. There is no custom Network Extension, App Groups entitlement, or ReplayKit capture in this app. LocalDevVPN supplies the separately signed VPN provider.

## Validation and limits

- Portable tests cover Annex B parsing, frame cadence under jitter, binary multipart framing and disconnected clients.
- Viewer JavaScript checks cover continuous mode, snapshot fallback, mode switching and expired-link cleanup.
- The native Mac test exercises local-only Bonjour registration, browse, service resolution, IPv4 lookup and teardown. It does not test the iPhone's AirPlay picker.
- Successful iOS compilation does not prove device signing, discovery, sustained background operation, or a frame-rate improvement.
- No audio forwarding, lock-screen capture or protected-content bypass is provided. The AirPlay protocol core is old; current-iOS compatibility is not established across devices.

Current device procedure and limits: [0.9](TESTING-0.9.md). Native YouTube video-only/HLS casting is not implemented.

Earlier experiment details: [0.7](TESTING-0.7.md), [0.6](TESTING-0.6.md), [0.5](TESTING-0.5.md), [0.4](TESTING-0.4.md), [0.3](TESTING-0.3.md), [0.2](TESTING-0.2.md).

## Sources and licenses

The build fetches [RPiPlay](https://github.com/FD-/RPiPlay) at commit `64d0341ed3bef098c940c9ed0675948870a271f9`. Its GPL-3.0 license and subcomponent notices apply; see LICENSE and the downloaded Vendor/RPiPlay/LICENSE. `tools/prepare_receiver.py` surfaces registration errors, adds Darwin socket compatibility, and supports external discovery metadata without competing advertisements. The app advertises the actual listener port and uses matching receiver metadata. It does not copy APTV code or claim to reproduce its undocumented implementation.

OpenSSL 1.1.1w and libplist 2.2.0 are fetched at build time; their licenses remain applicable. This is an experimental receiver based on older dependencies, with no completed security audit.
