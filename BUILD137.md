# Build 137 (0.21.00) - car map like Google Maps

User on 136: phone navigation now looks like Google Maps; car map is slow and plain; wants traffic colours,
fast updates, and to move the small map to the 4 corners.
- `Maps/MapTiles.swift`: Map Tiles session with `layerTraffic`; every 240 s the phone cache is cleared and the
  version bumped so traffic is fresh.
- `App/CanvasShell.js`: a version change (not night) builds a fresh layer over the old one, old kept 12 s
  (no blank map); loads/errors reset so the picture fallback still works. Driving poll 450 ms also while the video
  plays (was 900). Glide time = real time between positions (250-1200 ms) instead of a fixed 600 ms.
  Small map: drag (>14 px) and drop snaps to the nearest corner (`corner-tl/tr/bl`, default bottom right),
  saved in localStorage; the drag does not count as a tap.
- Tests: car map, map mini, reconnect, recovery, browser video, pure canvas all pass locally.
Uses more Map Tiles requests (traffic refresh); the daily limit 3000 can be reached on long drives.

- On-time arrow: phone sends `speed` and `fixAge`; car extrapolates (point + speed x age + 0.15 s) every frame and eases toward it (k 0.22). Stops when speed < 0.5 m/s and converged.
