# Build 98 (0.20.61)

Continues build 97 (stable video). The car draws the navigation map itself.

- Car page (App/CanvasShell.js): loads Google Maps JavaScript with the key from the phone's
  /map/state (token-protected; the key is never in GitHub). Draws the route line, a car arrow
  turned by the heading, and follows the car (zoom 17 while driving). Map is non-interactive so
  tap still swaps map and video. Reports carmap ok/failed to the phone every 10 s.
- If Google refuses the key or cannot load, the car falls back to the phone's map pictures and
  the phone log says CAR MAP failed with the fix.
- Phone (Maps/CarLink.swift, CarRemote.swift): state adds mapOn, mapKey, routeLine (cached),
  routeId. While the car draws the map, the phone stops drawing map pictures (less work, works
  in the background because only GPS + route are sent).
- Car map ON/OFF switch on the phone's map screen (Maps/CarMapsRoot.swift), saved.
- Key: uses carMapKey if set, otherwise the app's Google key. The key needs Maps JavaScript API
  and website restriction https://car.tesla4khmer.com/*.
- Video files unchanged from build 97 (CanvasPlayer.js, recovery, rescue page).
- tools/test_car_map_js.cjs: stubbed Google Maps; draw, follow, decode route, report, OFF, fallback.
