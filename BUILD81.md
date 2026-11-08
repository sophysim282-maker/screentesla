# ScreenLink build 81 — long YouTube playlists

Car/phone log (build 79): `MEDIA PLAYLIST CAPACITY: active/in-flight references fill bounded registry`
repeated, the car got HTTP 503, PiP failed twice (`PiP recovery paused`), then `PiP is inactive and
background grace expired` and the log was silent for a minute: iOS suspended ScreenLink, so the website
lost its connection. The video's playlists were ~100 KB each (about 1000 segments per quality, six
qualities), more than the 4096-reference registry.

Build 81: the main app allows 16384 references (the broadcast extension keeps 4096 for memory).
Includes build 80 keep-alive and builds 76–79.
