# Build 103 (0.20.66)

Continues build 102. A third person asked (through the user) to show the map on an "Orbit Cube"
(ESP32-S3, 240x240 screen, own Wi-Fi hotspot "Orbit-Clip", http://192.168.9.1).

- Maps/CubeLink.swift (new): while the switch is on, copies the centre square of the live map
  (car map view, else phone map view), scales it to 80x80, converts to RGB565 little-endian, top
  row first (12800 bytes) and POSTs it to /frame as application/octet-stream. One request at a
  time, a 0.15 s timer (about 6 a second), Wi-Fi only (no mobile data). The last picture is sent
  again when no new one can be drawn so the cube does not fall back to its setup screen.
  Replies: 200 counted; 500 ignored; 409 / 403 / 400 / no answer shown as plain text and retried
  once a second.
- Maps Settings: section "Orbit Cube display" with the switch, the status and three steps.
  Off by default; saved in UserDefaults `cubeOn`.
- Limits: the live map can only be copied while the map screen is open on the phone (in the
  background the last picture is repeated). Not tested with a real cube. An iPhone that is joined
  to Orbit-Clip is probably not able to serve the Tesla over Personal Hotspot at the same time.
- Video and car page unchanged (only the version label).
