# Version 0.2: floating preview test

The prior device test verified Mac -> iPhone AirPlay receiver -> browser video. The user also reports seeing ScreenLink in a casting list, but sustained same-iPhone capture has not been independently established.

The old version explicitly stopped its receiver when the finite background task expired. Version 0.2 adds an actual live video preview and AVKit Picture in Picture (PiP) source. It requests the documented audio/AirPlay/PiP background mode and a playback audio session. It does not generate silence or substitute a fake video for a received stream. While PiP is actually active, the app no longer stops the receiver merely because a background transition task expires. Without active PiP, the finite grace and stop behavior remain.

## Install

Sign the new IPA with the SAME Apple account and bundle ID as the installed ScreenLink Lab to update it. Do not delete the old app first unless the signing tool explicitly requires it. Version 0.2.0, build 2, iOS 15+; no custom VPN entitlement.

## Test sequence

1. Start receiver and connect the browser viewing device to the iPhone hotspot.
2. Tap Copy viewer link. It copies only the complete URL with token, preferring a hotspot bridge address over other interfaces. Transfer/open that link on the viewing device BEFORE starting mirroring. The button itself does not leave ScreenLink. Copy does not guarantee Universal Clipboard is available; use a supported transfer method on your devices.
3. Connect AirPlay from the desired sender. If this is the same iPhone, quickly return to ScreenLink before its temporary background time expires.
4. Wait until the inline preview shows actual received video. Tap Start floating preview. If not ready, wait for more frames and try again. It cannot start before real frames arrive.
5. Wait for the floating video window and the `Floating preview ACTIVE` message. A button press alone does not prove activation.
6. Switch to another app, leaving the floating video playing. Observe the browser for at least 90 seconds and change on-screen content to ensure frames update instead of merely displaying the last frame.
7. Repeat with the Mac as sender if the same-iPhone source cannot connect. Record the sender and network used.
8. Return and Copy test log. If PiP fails, paste the exact failure message. If video freezes, record whether PiP was visible or paused, whether the receiver logged stopping, and approximately how many seconds elapsed.
9. Stop sharing and confirm the browser no longer receives new frames.

## Limits

This is an experiment, not a verified background fix. iOS may reject PiP, suspend parts of the video pipeline, or treat simultaneous AirPlay sending and PiP receiving differently. Closing or pausing the floating video can end background execution. Protected content may not be captured. Audio is not forwarded. Long-lived background reception and lock-screen behavior require real-device testing.
