# Build 54: receiver recovery and Auto quality

Problem: the HTTPS viewer could remain marked connected after repeated failed health requests. Auto-connect then never ran. Old Maps privacy revisions and screen decoder faults also survived a new receiver session. A changed hotspot peer address could not reuse the approved session.

Changes:
- After at least three failed health requests and eight seconds without drawn-frame progress, clear the dead connection and reauthenticate automatically. Preserve buffered playback while actual frames keep advancing. Resume the same media epoch at its last position; a new song starts normally.
- Session generation guards discard stale responses. Playback reports no longer block health polling; only one report is in flight. Old screen decoder/revisions are reset on a new authenticated session; capture stays hidden.
- Allow a changed peer only with both the same nonce and the previous valid token. Rotate the token and revoke the old peer. Credentials remain in memory, never in diagnostics/cache.
- Complete duplicate VPN start callbacks with failure so the app's Start guard can clear. Do not restart a healthy VPN automatically.
- Default Auto source selection chooses the highest offered resolution up to 1080p; SD is permitted. 720p/1080p preference buttons fall back to available lower sources. Unknown manifest resolutions are checked against actual decoded-track dimensions. No mid-song quality switching or audio resampling changes.
- Background expiration now records elapsed time and thermal state. This does not identify the exact OS termination cause or extend the OS grant.

Unchanged constraints: YouTube-only starts without ReplayKit recording; PiP is optional/manual. iOS can cancel/expire continued work before 30 minutes. This build does not promise uninterrupted background runtime. A suspended or terminated app cannot serve media until resumed. Cached website UI is not proof of a live VPN/server.

Validation: Node transport regression verifies bounded 1 MiB range downloads, transient retry without decoder/PCM replacement, auth cancellation, SD fallback and 1080p cap. Shell regression verifies outage reauthentication, fresh screen generation, old credential handoff and retention of healthy buffered playback. Native approval regression adds peer-change credential and old-token revocation checks. Browser and iOS builds run in CI. Physical Tesla/Wi-Fi recovery and long-run iPhone background operation remain unverified.

Widget: no signing or registration repair is claimed. Bundle-presence logs do not prove iOS registered the widget. Inspect the KravaSigner-exported signed IPA before changing its signing configuration. Home-screen shortcut fallback remains screenlink://start-youtube.
