# Build 101 (0.20.64)

Continues build 100. Reason: the user reported that the car map closes when they leave the app.
Most likely cause (no log yet): Google refuses the phone's key on the car website (an iOS-app key,
or Maps JavaScript API not enabled), so the car falls back to the phone's map pictures, which stop
in the background.

- Phone map screen (Maps/CarMapsRoot.swift): under the Car map switch a green line "Car draws the
  map ✓ works when you leave the app", or an orange "Car map stops when you leave the app · Tap to
  fix" button. The fix sheet shows the reason from the car, the Google Cloud steps and a box that
  saves `carMapKey` (UserDefaults, phone only). The same rows are in Maps Settings.
- Maps/CarRemote.swift, CarLink.swift: `carMapProblem` keeps the car's failure reason.
- Car page: after a refusal it keeps reporting the failure every 10 s; when the phone sends a
  different key it reloads the page once so Google starts clean; Google's own grey error box also
  counts as a refusal; if no map of any kind is left it shows a short note instead of closing.
- Video files unchanged from build 97.
