# ScreenLink 0.8: browser streaming improvements

## Working baseline preserved

The user reports 0.7 works without a Mac advertiser. Their log shows local-only proxy lookup at 10.7.0.1, an AirPlay connection from that VPN peer to 10.7.1.1, decoded video, floating preview ACTIVE, and continued frames after backgrounding. This confirms that session; it does not establish all-device compatibility or long-term background stability.

Version 0.8 does not change VPNDiscovery.m, receiver identity, pairing, or the PiP controller. LocalDevVPN and active floating preview remain required.

## Changes

- Continuous multipart JPEG stream over one HTTP connection, with up to two concurrent continuous viewers and reserved capacity for status/other requests.
- New clients always select the latest frame. Per-client socket buffers and send timeouts limit backlog; disconnected idle viewers are detected while no frames are arriving.
- The existing long-poll snapshot viewer remains available via Compatibility mode.
- Fast: longest edge 720 pixels, JPEG quality 0.45, up to 20 source fps. Balanced: 960, quality 0.5, up to 15. Sharp: 1280, quality 0.68, up to 15. Profiles can change while sharing.
- Corrected cadence phase handling: a 30 fps source capped at 20 fps should average 20, rather than systematically dropping to 15 through arrival-based scheduling. Irregular timing still affects achieved output.
- Browser reconnect and full-screen controls, paused-source indication and token-expiry handling. Source FPS is measured from generated JPEGs, not browser-rendered FPS. Compatibility mode additionally reports the measured display loop rate.

## Validation

Portable C tests exercise non-divisible frame rates, source jitter, pause recovery, binary multipart JPEG framing, skipped sequence IDs and disconnected sockets. JavaScript tests cover mode selection, switching to compatibility, and expired links. The real macOS local-only DNS test remains a build prerequisite. iOS compilation checks integration; no physical speed improvement is claimed before comparing on the phone.

## Device test

1. Update in place; use the same iPhone VPN setup that worked on 0.7. Keep old Mac proxy helpers stopped.
2. Select Fast, start receiver, connect ScreenLink VPN Phone, then start floating preview and wait for ACTIVE.
3. Open the complete current hotspot viewer link in the other device browser. Continuous mode is the default. If the picture stays blank, click Compatibility mode; this returns to the snapshot path.
4. Compare scrolling delay and motion under the same network and content. Do not compare native source FPS with 0.7's displayed-browser FPS as if they were identical metrics.
5. Try Balanced for the previous image settings, or Sharp for more detail at a greater bandwidth/processing cost.
6. Reconnect the viewer and switch modes before and after actual video starts. A closed viewer must release its continuous-stream slot even while no video arrives.

No audio forwarding, protected-content support, lock-screen capture or new background entitlement is added. Hiding the floating preview at the screen edge may avoid showing a repeated screen-within-screen image; closing it can end background sharing.
