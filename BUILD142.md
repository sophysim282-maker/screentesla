# Build 142 (0.21.05) - car stuck: reconnect without closing the app

User: first video sometimes slow, sometimes the app and the website must be restarted.
No log of a stuck case yet. Changes:
- `App/main.m` `fixCarLink:`: resumeListenersIfNeeded + refreshDiscovery + authorizeNextLocalViewer, logged as CAR RECONNECT.
  healthTick: media active + hotspot + car silent > 12 s for 20 s -> automatic fix (max once per 60 s), log CAR STUCK.
  Home: "Car is not answering" (red) in that state; the Start button runs the fix first.
- `App/CanvasShell.js` stuckCheck (in tick): handed over (mediaStartAt) but no first picture for 20 s -> reload once per
  media epoch (sessionStorage key), with a car log line. (Rule 7 area; changed on the user's report, all car tests pass.)
- Item 3 of the plan (prepare at app open) already existed: `active` -> resumeYouTubeOnReturn auto-starts unless the user
  pressed Disconnect all.
