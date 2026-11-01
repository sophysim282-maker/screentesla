# ScreenLink 0.9 device test

This version preserves the working 0.7 local-only VPN discovery. It changes the video transport and adds a separate, experimental iOS 26 background path. No native YouTube/HLS media receiver is included.

## Install and mirror

1. Install over the existing app using the same signing identity. Replacing it keeps receiver identity and defaults where the installer preserves app data.
2. Connect LocalDevVPN and Personal Hotspot; connect the viewer device to the hotspot. Stop old Mac DNS advertisers.
3. Choose **iPhone VPN**, start the receiver and copy its complete hotspot viewer link before casting.
4. Select **ScreenLink VPN Phone** in Control Center → Screen Mirroring.
5. Open the link on the viewer. Default **H.264** uses the original compressed video, without the JPEG 15–20fps cap. The source FPS is what arrived, and display FPS is the browser's video-frame counter.
6. Compare motion with the previous release. A 60fps source test passed on the muxer, but no physical-device 30/60fps or latency result has been measured for 0.9.

## Background without floating preview — experimental

1. Wait for actual video, then return to ScreenLink.
2. Tap **Start 30-minute background test**. Wait for **BACKGROUND SESSION ACTIVE**. A submitted request alone is not an active session.
3. Switch apps, leaving the floating preview off. Keep the viewer in **H.264** mode. The phone forwards compressed video without local VideoToolbox/JPEG work in this mode.
4. Observe continuously changing content for at least 2 minutes. Copy the test log after returning. A phone app log, accepted task or static browser image alone does not establish successful background streaming.
5. Cancel from the system's session controls. Sharing must stop. Also test **Stop sharing** while foregrounded, and normal session completion at 30 minutes.
6. iOS can reject, cancel or terminate the task early. There is no automatic renewal and no promise of indefinite operation or operation after force-quitting.

Background task identifiers must match the signed bundle ID. The IPA allows the original bundle ID and the known free-team signing forms for this project. An unfamiliar installer rewrite produces an explicit log; copy it rather than assuming that a task started. No custom VPN, App Groups or background GPU entitlement is requested.

If the session is rejected or the browser stops, use **Start floating preview** and wait for ACTIVE as before. Do not close or pause PiP when relying on it. Switching the browser to JPEG while using the no-PiP background session will not produce new JPEGs because that session deliberately avoids local decoding/GPU work.

## Recovery

- Reload or close/reopen the browser page while casting; it must obtain init data and start at the latest cached keyframe.
- Interrupt the viewer's Wi-Fi briefly, reconnect to the same hotspot, and wait for automatic compressed-video reconnection.
- Stop/start the receiver: the viewer token is retained, so the same link works if the phone's hotspot IP is unchanged. A new codec configuration or timestamp reset starts a new stream epoch.
- Returning to ScreenLink resumes an armed receiver after relaunch and refreshes discovery if no live video is arriving. Background grace expiry no longer explicitly tears down the receiver.
- If iOS ends the AirPlay session itself, the app cannot silently select an AirPlay destination on the user's behalf; reconnect using Control Center. The separately installed LocalDevVPN must remain connected.

## Implemented checks

- Portable MP4 init/fragment bounds checks, including ASan/UBSan (leak detection disabled in the ptrace-based Linux runtime).
- A generated 640×360, 60fps, one-second H.264 fixture was remuxed into 60 fMP4 samples. FFprobe counted all 60; decoded frame hashes matched all source frames exactly. This validates remuxing, not an end-to-end phone/network/browser frame-rate claim.
- Native Foundation tests exercise keyframe startup, fragment batching, timestamp rollback, epoch reset and stop.
- Mock MediaSource viewer tests exercise initialization, append, continuation and JPEG fallback. They do not validate a real browser's decoder.
- Existing JPEG viewer, multipart, cadence and real Mac local-only DNS tests remain.
- iOS build checks compilation and packaging. It cannot verify iOS background scheduling or same-phone AirPlay behavior.

## Video-only YouTube casting

Screen mirroring and a native AirPlay media receiver are separate protocols. The pinned RPiPlay core handles mirroring but lacks the native media/HLS handlers. Current UxPlay's experimental HLS implementation is a useful reference, but it is not ported here. This build does not claim that tapping AirPlay inside YouTube will send only its video. There is still no audio forwarding.

## Apple references

- https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados
- https://developer.apple.com/videos/play/wwdc2025/227/
- https://developer.apple.com/forums/thread/840384 (Apple DTS discussion of user-controlled continuous sessions; it is not a validation of this casting app)
