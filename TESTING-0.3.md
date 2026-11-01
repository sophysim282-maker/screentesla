# Version 0.3: connect first, create PiP later

The user reports version 0.1 now appears in the iPhone casting list and the iPhone screen reaches the Mac browser. Leaving the receiver app stops sharing. Treat that as the current reported behavior; do not call the same-phone design impossible or assume the old visibility report was only about the Mac.

Version 0.3 leaves the AirPlay receiver, receiver identity and Bonjour registration code unchanged. Unlike 0.2, it does not instantiate the sample-buffer preview view or AVPictureInPictureController at app launch. Incoming frames are bounded by the existing delivery queue and the UI retains only one latest decoded pixel buffer. Only after the user presses Start floating preview with actual video available does the app create the preview view, configure playback and request PiP. It waits up to five seconds for PiP to become possible and logs failures. An active PiP session keeps the old finite-grace handler from stopping the receiver. Without active PiP, the normal background limit remains.

Device test:
1. Install build 3 over ScreenLink with the same signing account/bundle ID.
2. Start receiver. Copy/open the viewer link on the Mac before mirroring.
3. Select ScreenLink in the iPhone's mirroring list and return to ScreenLink promptly.
4. Confirm the Mac browser receives the iPhone screen. Tap Start floating preview.
5. Wait in ScreenLink for a visible floating window and Floating preview ACTIVE. Then switch apps, leaving it playing.
6. Check browser updates for 90 seconds with changing content. Copy the phone test log if PiP fails, the mirroring disconnects, or frames freeze. Distinguish the PiP activation failure from an AirPlay disconnection after activation.

This is an experimental background fix, not a verified one. The user must test simultaneous same-iPhone AirPlay and PiP. No VPN, silent-audio keepalive, fake frames or ReplayKit fallback is included. Audio forwarding is still absent.
