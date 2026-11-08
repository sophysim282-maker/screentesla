# ScreenLink build 85 — "ScreenLink Mission" Dynamic Island

Original characters only (no third-party characters or logos). iOS animates Live Activities on state
changes and with self-running timers/progress, and throttles frequent updates, so:

| Car state | Island |
|---|---|
| Waiting for YouTube | character on the pad + self-running T-minus 10 s |
| Car starts playing | "Liftoff!" 🔥 (slides in), then the character "in orbit" |
| Playing | ring + track that fill with the video by themselves, time left |
| Paused | 🛰️ "Hovering", fixed progress |
| Car not reachable | 📡 "Signal lost" |
| Stopped / stale | 🪂 "Landed" / "Open ScreenLink" |

Each new YouTube video switches the character: 🚀 rocket, 🛸 UFO, 🏎️ roadster, ☄️ comet.
The app reads `/local/widget/state` every 4 s while running and updates the activity only when the
stage or character changes (plus a 30–60 s resync). Video playback unchanged from build 83 (CI check).
