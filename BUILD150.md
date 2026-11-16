# Build 150 (0.21.13): trip timer

User: the first start after getting into the car is slow (still after the build 146 warm-up). No log was
available (the app had been closed), so this build measures each step by itself.

- `App/main.m`: a trip begins when ScreenLink starts/opens after a pause or when the car joins the Hotspot.
  Marks: app (opened), car (Hotspot client appears, healthTick), page (car HTTPS request within 6 s),
  airplay ("AirPlay control connection received"), video ("MEDIA PLAY REQUEST"), picture ("CAR PLAYER: start
  took"). At the picture: `TRIP TIMING: <date> · App open 0:00 · Car joined 0:35 · …` in the log and in
  UserDefaults `tripTimings` (last 3).
- Every log line is also written to `Documents/screenlink-log.txt` (trimmed to 1 MB at 2 MB).
- Developer: "Copy trip log (last 3 trips)" copies the timings + the saved log.
