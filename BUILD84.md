# ScreenLink build 84 — live widget and Control Center

User rule after build 83: video playback stays unchanged (CI checks CanvasPlayer.js against build 83).

- **Car Player widget** (small / medium / large) reads live state from the phone
  (`GET /local/widget/state`, loopback only): On/Off, car connected, playing/paused, time,
  quality and volume. Selected quality and sound are highlighted. Buttons: play/pause,
  ±10 s, volume −/+, mute, Auto/720p/1080p, Normal/Music; Large adds a progress bar and
  Open/Stop. When ScreenLink is off it shows Start.
- **Control Center (iOS 18+)**: ScreenLink On/Off toggle (opens ScreenLink to start YouTube + PiP
  or to disconnect all — iOS only allows PiP/VPN from the app), Car Play/Pause and Car Mute
  (run without opening the app).
