# Build 100 (0.20.63)

Continues build 99 (Google look). The big car map is now used directly on the car screen.

Car page (map section of App/CanvasShell.js and App/CanvasShell.html):
- Big map: Google gestures on (drag, pinch, two-finger turn and tilt). The small corner map stays
  "tap to make big". On the big Google map a tap belongs to the map; tap the small video to go back.
- Moving the map by hand stops following the car; a "Re-centre" button follows again.
- Search pill ("Search here"). Focus shows Home / Work / recents. Typing sends `type` to the phone
  (250 ms debounce) and lists the phone's Google suggestions; Enter sends `search` and lists results.
  While driving the pill is a round button at the top right.
- Tapping a place name / icon on the map sends the new `poi` command with Google's place id, so the
  phone opens that place with its real name (the old picture map could only drop a pin).
- Place card: name, rating, type, open/closed, address, route choices (`route`), Start (`gostart`),
  close (`close`). The chosen place is drawn as a red dot with its name; the map shows the whole route.
- Exit button while driving (`exit`).
- State polling is 300 ms for 6 s after a command (and while searching) so answers feel immediate.
  A generation counter stops overlapping polls from multiplying.
- Faster start: preconnect to Google's map hosts, `loading=async`, and the Google script starts as
  soon as the key arrives (no longer waits for the first GPS point).

Phone:
- Maps/CarRemote.swift: `place` state has `lat` / `lng`; new commands `poi` (open by place id) and
  `gostart` (start now or when the route arrives).
- Maps/NavModel.swift: `startWhenReady()`; traffic / route / arrival refresh every 2 minutes while
  guiding (was 5). Off-route re-routing is unchanged (2 GPS fixes).

About "real Google navigation": routes, traffic and re-routing come from Google's Routes API
(TRAFFIC_AWARE). Lane guidance is not in any public Google web API (only in Google's own app and
the native Navigation SDK), so it is not shown.

Video files unchanged from build 97. Test: tools/test_car_map_js.cjs (stubbed Google).
NOT verified here: real Google tiles, real touch in the Tesla browser, the Tesla keyboard.
