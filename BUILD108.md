# Build 108 (0.20.71)

The user asked: "build 108 for close the map, close all system map". All map systems are closed so
the video runs alone (also the cleanest test of whether the map disturbed the video).

- Car page (App/CanvasShell.js): `MAPS_CLOSED=true`. `mapStateLoop` / `mapFrameLoop` are never
  started, so the car makes **no** `/map/…` request (no state, squares or pictures) and never shows
  the map. The summary log line says `map closed`. The map code is kept and still tested through a
  test-only switch (`self.ScreenLinkMapsForTest`).
- Phone (App/main.m `showMaps`): the Maps button shows "Maps are closed" and logs `MAPS CLOSED`.
  The map screen is never created, so no GPS navigation, no tile session, no map pictures.
- Side effect to tell the user: the **Orbit Cube** switch lives in the Maps settings and the cube
  shows turns of the ScreenLink route, so the cube feature is unreachable in 108.
- Kept from 105–107: keep-awake, status light, self-repair, internet come-back, quality choices.
- To open maps again: set `MAPS_CLOSED=false` and remove the two lines in `showMaps`.
