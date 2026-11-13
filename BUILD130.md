# Build 130 (0.20.93) - map proof and layout

User on 128/129 (screenshot): route, turn, distance work, map picture is empty grey (also satellite).
Key API list includes Maps SDK for iOS, Map Tiles API and Navigation SDK (user sent the list).
Cause NOT known. Candidates: key application restriction vs. app ID after FlareStore re-signing,
GoogleMaps + GoogleNavigation packages together, network path for tile hosts.

## Changes
- `Maps/GoogleNav.swift`: stderr is mirrored through a pipe; lines with google/gms/api key go to the log
  as `GOOGLE SAYS:` (max 40). `GoogleNav.line()` for map log lines. Connected at app start.
- `Maps/Maps.swift`: tile rendering watchdog -> `MAP PICTURE LOADED ✓` / `MAP PICTURE NOT LOADED` (with app ID
  and the last 4 characters of the key).
- `Maps/MapTiles.swift`: `MAP SQUARES FOR THE CAR: <Google's answer>`.
- `Maps/CarMapsRoot.swift`: back button + car-map switch in a black bar above the map (no overlap).
