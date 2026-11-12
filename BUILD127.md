# Build 127 (0.20.90) - Google navigation engine (Navigation SDK)

User: "make it the real Google map / as close to Google Maps as possible".
The map, search and routes were already Google (Maps SDK, Places, Routes API). The turn-following logic
was ScreenLink's own (NavModel.progress). This build puts Google's Navigation SDK in as the engine.

## How
- `project.yml`: package `GoogleNavigation` (github.com/googlemaps/ios-navigation-sdk, from 9.0.0).
- `Maps/GoogleNav.swift`: headless `GMSNavigationSession` (no Google UI). `start(model:)` shows Google's
  terms once, sets the destinations (stop + destination), turns guidance on, voice `.silent`
  (ScreenLink speaks, so AirPlay/PiP audio is not interrupted - see build 91).
  Listener fills NavModel: `googleStep` (instruction, maneuver, then, lanes, road), `distanceToNext`,
  `remainingMeters/Seconds`, road-snapped `carCoordinate/Bearing`, new route line on route change, arrival.
- `Maps/NavModel.swift`: `googleActive`, `googleStep`; `nextInstruction/nextManeuver/thenManeuver` prefer
  Google; `progress()` returns early while Google guides; `startGuidance/endGuidance/fetchRoutes` call GoogleNav.
- Lanes: row under the phone banner (`Screens.swift`); `lanes` + `engine` in the car state (`CarRemote.swift`).
  The car page does not draw lanes yet.
- Fallback: any failure -> `googleActive=false`, old logic, log line `GOOGLE NAVIGATION: …` with the reason.

## Needs
The user's key must have **Navigation SDK** enabled in Google Cloud (billing on).

## Not proven
Compiled only. No drive test. Google UI look (header/puck/camera) is NOT used yet; this is the engine only.
Check Google's Navigation SDK terms about showing guidance on a vehicle screen.
