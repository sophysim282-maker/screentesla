# Build 104 (0.20.67)

Continues build 103. The user's Tesla is a China version: its browser blocks Google, so the
Google-drawn car map of builds 98–100 cannot work there. New rule for this car: **the car browser
talks only to the phone, never to Google.**

Car page (map section of App/CanvasShell.js / .html):
- No Google address in the page (preconnect links removed). The Google Maps script is only loaded
  when the phone state has `carGoogle: true`; the key is only sent in that case.
- Default map = pictures from the phone: live pictures while the map screen is open, the GPS-moved
  Static-map picture when the app is left or the phone is locked (builds 87/88 code).
- The build 100 controls now also work on pictures: search pill, suggestions, place card, routes,
  Start, Exit. New for pictures: + / − (phone `zoom`), drag (phone `pan`, live pictures only),
  Re-centre (phone `recenter`), tap = new `tapplace` command (fraction of the live picture, or
  lat/lng worked out from the background picture when it is flat / north up).
- In big mode a tap always belongs to the map; tap the small video to go back.
- The "Map stopped" note shows the real reason (Google load failure, or the phone's `bgError`).

Phone:
- Maps/CarLink.swift: `carGoogle` (UserDefaults, default false); `bgProblem` + state `bgError`
  when the Static-map request fails (HTTP code and Google's text), retry after 15 s.
- Maps/CarMapsRoot.swift: orange "Car map stops when you leave the app · Tap to fix" button with a
  sheet explaining Maps Static API. The website-key sheet is only offered when `carGoogle` is on.
- Maps/Screens.swift: section "Car draws the Google map itself" (switch, off by default).
- Maps/NavModel.swift: `placeAt(_:)` — Places searchNearby (40 m, nearest) → select the real
  place; otherwise the street address becomes the name. Maps/CarRemote.swift: `tapplace`.
- Maps/CubeLink.swift: reads all characteristics and, when …0F13 is missing, lists the ones the
  cube offers. (User's first cube test: "Orbit Cube has no navigation channel" = the service was
  found but not characteristic …0F13 — a cube firmware / UUID matter.)

Unchanged: video player, recovery, rescue page, phone map.
NOT verified here: a real China-version Tesla, the Static-map picture with the user's key, a cube.
