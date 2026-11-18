# Build 155 (0.21.18): car map works on slow / no internet

User: the map stops when the internet is slow; make it work offline. Log showed MAP PICTURE NOT LOADED.

Root cause in `Maps/MapTiles.swift`: `tile()` cleared the ENTIRE tile cache every 240 s for a traffic refresh,
and on a failed fetch returned empty (blank). So a slow moment during the 4-min clear blanked the whole map.

Fix: a second store `offline: [String: Data]` (LRU 2000, `offlineOrder`) keeps the last good image for each
square. It is NOT cleared by the traffic refresh — only when the Google key changes (`offlineKey`). Every
successful fetch writes it. When a fresh fetch fails or there is no session, `tile()` returns the offline copy
instead of blank. So the car keeps the map already loaded when the internet is slow/gone, and the car arrow
keeps moving from GPS (build 137 extrapolation). Brand-new areas never loaded still need internet once; a full
pre-download-an-area feature is the follow-up if the user wants true from-cold offline.
