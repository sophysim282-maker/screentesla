# ScreenLink 0.9.1 — one-second disconnect investigation

## User evidence from 0.9

At 16:19:03 UTC, the receiver decoded its first video frame. At 16:19:04, the mirror TCP socket closed, followed by both control connections. At 16:19:05, discovery records were republished. Only afterward did the background task request and ACTIVE messages appear (16:19:08–09). The background request was accepted, but this log does not establish background video operation. The first failure is an AirPlay disconnection, not a background permission denial.

## Changes

- Remove the automatic discovery refresh when returning to the app. Keep the working local-only records and receiver identity. Manual refresh is refused while AirPlay controls are connected or video transport is open.
- Restore asynchronous intake: the AirPlay network thread never waits for VideoToolbox decoding. A bounded 16 MiB/120-packet ordered inbox replaces synchronous dispatch. If processing overloads, an ordered discontinuity resets decoding/mux history and waits for a fresh keyframe, rather than silently decoding across a dropped reference packet.
- Track actual video-socket closure and control closure, clear live state immediately, and reset media state. Socket errors from established video receives are distinguished from errors on an idle listener.
- Background start requires at least 10 fresh frames, a received keyframe and a live socket; it is checked again when iOS launches the task. One old frame is no longer sufficient. ACTIVE is explicitly a background-runtime state, not proof of an AirPlay connection.
- Browser status distinguishes an AirPlay disconnect from waiting for browser output. Stable viewer token, H.264 passthrough, PiP fallback and background-task cancellation remain.

These changes address plausible regressions; the supplied log does not identify the sender's reason for closing its socket. They need a device test before claiming the one-second disconnect is fixed.

## Test sequence

1. Install 0.9.1 over the existing app. Keep LocalDevVPN connected and the Mac on the iPhone hotspot. Use the complete bridge100 link, including token.
2. Start receiver → select ScreenLink VPN Phone in Screen Mirroring → return to ScreenLink. Do not press Refresh discovery.
3. Leave ScreenLink visible for 30 seconds and view H.264 on the Mac. Check that source/display counters continue and screen motion appears. Returning to the app should not publish another copy of the discovery records.
4. Only after foreground video stays connected, tap Start 30-minute background test. Wait for BACKGROUND SESSION ACTIVE. No additional permission dialog is required for the task to reach this state.
5. Switch to another app for 2 minutes and verify continuing screen motion. On failure, copy the log from receiver start through socket closure and background transitions, plus the browser's exact status.
6. If background execution starts but live video stops, distinguish a closed AirPlay socket from a live source with a stalled browser decoder. The app cannot silently reselect an AirPlay destination after iOS closes the session.

## Validation

The Mac inbox test deliberately blocks the consumer while requiring offers to return promptly, verifies byte/packet bounds, packet ordering, the discontinuity marker and subsequent recovery. Existing H.264 history/epoch, fMP4 bounds, JPEG viewer, cadence, multipart and real local-only Bonjour tests remain. Compilation and these tests cannot establish same-phone iOS streaming or background behavior.
