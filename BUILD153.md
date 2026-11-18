# Build 153 (0.21.16): car map looks like the phone map

User: make the car (website) map look like the phone map (the phone map is the real Google Maps and looks
good); and on weak internet keep showing what the app has.

Key fact: the phone already renders its real GMSMapView and sends it to the car as a JPEG (`CarLink.snapshot()`)
whenever `liveMapUsable` (app active/foreground). The car page, though, preferred the flat Google Map Tiles over
that snapshot.

- `App/CanvasShell.js` map loop: `snapLive = s.mapLive && !useJs && mapOn` (the phone is actively sending its
  real map). When snapLive, `useTiles` is suppressed and `mapLive` (the phone picture) is shown — so the car map
  equals the phone map while ScreenLink is open. In the background iOS blocks the live map, `s.mapLive` goes
  false after ~3 s, and the car falls back to the Map Tiles as before.
- Weak internet: tile errors only drop the one failed tile (existing behavior), cached tiles stay, and the car
  extrapolates the car position from GPS speed/heading (build 137), so the map keeps its picture and the pointer
  keeps moving without internet.
