# Build 143 (0.21.06) - video first on the Wi-Fi

138 log: pieces to the car took 5-15 s while the map loaded big squares; then 186 HTTPS requests with no Host were
refused silently and the video hung ~1 min. 142 log: car left the hotspot (Wi-Fi link drop, not the app).
- `App/CanvasShell.js`: `farAllowed()` - far squares only with no video (budget 3) or >= 8 s of picture ready.
- `App/Receiver.m`: wrong/no Host over HTTPS -> immediate `421 Misdirected Request` + close (was: no answer);
  log shows method + path (query cut off).
