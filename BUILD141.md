# Build 141 (0.21.04) - car map like the phone map

User photos: phone (Google nav, satellite with big names, traffic) vs car (satellite with tiny names) - make them the same.
- `Maps/CarLink.swift`: map type and day/night follow the phone settings again (139 forced dark road map while navigating).
- `Maps/MapTiles.swift`: `scaleFactor2x` + `highDpi:false`: 256 px squares with 2x labels/icons. Tested with the
  user's key on Phnom Penh z16 (session OK; 50 KB per square instead of 185 KB; scaleFactor4x+highDpi gave 1024 px,
  600 KB, same label size -> not used).
- `App/CanvasShell.*`: route edge 19 / line 13 (was 11 / 7), brighter blue; arrow 76 px with white glow and shadow.
