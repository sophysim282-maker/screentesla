# Version 0.4: invalid decoder-session recovery

The user reported repeated synchronous VideoToolbox decode errors -12903 on version 0.3. The iOS SDK assertion verifies this maps to kVTInvalidSessionErr. The previous code logged it for each frame and retained the failed session until new SPS/PPS arrived, so a foreground return with unchanged format could remain stuck.

Version 0.4 discards invalid/malfunctioning/unavailable sessions, retains valid H.264 configuration, and waits for an IDR/keyframe before recreating. It does not submit inter frames to a freshly created decoder. A one-second retry delay and at most two failed recovery attempts per background entry prevent continuous background recreation. Returning to active clears the retry delay and background failure count. Error logs are bounded to one message per two seconds. Only actual JPEG output increments the browser frame counter. Bonjour/receiver identity and the 0.3 lazy-PiP flow are unchanged.

Test: connect and confirm video; enable floating preview; leave app while PiP is visible; watch whether the browser continues updating. If errors occur, return to ScreenLink and check for Decoder accepted a keyframe followed by an advancing actual-video frame counter. If no keyframe arrives, reconnect Screen Mirroring. Record whether the error happened before/after Floating preview ACTIVE, not just the repeated error number. Capture 20 log lines before the first error and the recovery messages afterward.

This fixes an observed recovery/logging defect; it does not prove continuous same-iPhone background decoding is permitted. A browser holding the last image is not evidence of a live stream. No silent audio, VPN or fake frames are added.
