# Build 105 (0.20.68)

Continues build 104. From the user's build 104 car test:
- "need to go back to the app, then it plays; waits so long": the log shows `BACKGROUND RUNTIME
  ENDED … iOS may suspend this app without PiP`, then a play request at 13:03:14 that the car only
  picked up at 13:03:55, after the app was opened again. Once awake the player started in 2.2 s.
- The picture map of 104 was unusable (slow, bad touch). Google is blocked in the car's browser
  (China-version Tesla; https://www.google.com/maps does not open there).
- At 13:04:29 the phone lost internet (502 from every YouTube host) and the car left the hotspot at
  the same moment; `thermal state 2` later. Cause not known.

1. Keep awake (Maps/KeepAwake.swift, App/main.m): when the receiver starts, low-accuracy location
   updates run with background updates allowed (blue mark), so iOS keeps ScreenLink running without
   PiP. Stopped by Stop / Disconnect all. Log lines `KEEP AWAKE ON` / `KEEP AWAKE NOT ACTIVE`.
   Not proven on a device yet.
2. Car-drawn map from phone squares:
   - Maps/MapTiles.swift: Google Map Tiles API session (roadmap or satellite+roads, night styles,
     2x high-DPI) and `/map/tile/z/x/y` (App/Receiver.m) fetched by the phone with a 300-square
     memory cache. Squares may be cached by the car for a day (`Cache-Control` only for this route).
   - Car page `tileMap` (App/CanvasShell.js): own renderer, no library. Squares as images in a
     layer moved with CSS transforms; local drag, pinch, wheel, + / −; follow mode with travel
     direction up and the car below the middle while driving; route as SVG lines; car arrow and
     place name in screen space; smooth glide with requestAnimationFrame; old zoom level stays
     under the new one for 1.6 s; at most 3 square downloads at a time (the video shares the
     browser's connections). Tap → `tapplace` lat/lng (phone finds the real place).
   - Order on the car: Google JS (only if `carGoogle`) → squares (`tiles`) → live pictures →
     background picture. If 6 squares fail and none load, it falls back to pictures and reports.
   - While the car draws, it reports `carmap ok=1`, so the phone stops making map pictures (heat).
   - Phone map screen: orange "Car map is slow · Tap to fix" with Google's answer and the steps
     for **Map Tiles API**; green "Car draws the map ✓" when it works.
- Video player, recovery and rescue page unchanged.
- NOT verified here: real Google squares with the user's key, a real China-version Tesla, keep-awake.
- Still open: "the road it gives is bad" — need one example from the user (start, destination,
  what was wrong) before changing routing.
