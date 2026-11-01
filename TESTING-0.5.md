# ScreenLink 0.5: VPN discovery and lower latency

This build follows a user-reported successful same-iPhone AirPlay session through LocalDevVPN and a Mac proxy advertisement. That report does not establish reliable discovery or continuous background operation.

## Changes

- JPEG conversion runs on a separate bounded queue, outside the decoder callback. Decoding still consumes every admitted compressed frame to preserve H.264 references.
- Default browser output is capped at 15 fps, 960 pixels on the longest edge, JPEG quality 0.5. The browser long-polls for a new frame instead of adding 100 ms after each request.
- Native NV12 decoder output avoids requesting a full BGRA surface for every decoded frame.
- The viewer reports stale output instead of presenting an old image as live video.
- Mac VPN discovery mode prepares protocol TXT records but suppresses the phone's competing Bonjour advertisements. A Mac helper reads the exact current identity and advertises both AirPlay and RAOP at the configured VPN peer. This mode still requires the Mac for discovery.
- Native discovery remains available by disabling the Mac VPN discovery switch before starting the receiver.

## Test procedure

1. Keep LocalDevVPN connected and the Mac on the iPhone hotspot.
2. Update the IPA in place; leave Mac VPN discovery enabled. Start receiver and copy the viewer link.
3. Stop old dns-sd proxy commands with Control-C.
4. Run `bash tools/mac_vpn_discovery.command` on the Mac and paste the full viewer link when asked. It uses built-in macOS tools; Python and Xcode are not needed. Its default peer is 10.7.0.1; pass the viewer URL and a second IP argument to override. The Python helper is also available. It publishes ScreenLink VPN and the matching RAOP identity. Keep it running.
5. Open Control Center immediately, select ScreenLink VPN, then verify changing content in the Mac browser.
6. Return to ScreenLink and start floating preview. Wait for ACTIVE before switching apps. Try swiping the floating window to the edge; if sharing stops, restore it. This behavior still requires a device test.
7. Compare motion delay and the viewer's frame-age status with 0.4 under the same network conditions. Do not infer improvement from a successful compile alone.

The helper only advertises services. Video remains between iPhone and browser. The helper does not make the browser use the VPN peer: the Mac viewer must use the phone's hotspot address.

## Remaining limits

No audio forwarding. The receiver still uses an old AirPlay core. iOS may invalidate the manual decoder or suspend the host when PiP ends. The separate VPN does not grant background execution to ScreenLink. Mac-free discovery, modern codec compatibility and sustained background playback are not established by this change.
