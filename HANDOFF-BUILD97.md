# Handoff: build 97 (0.20.60) is the stable baseline

Car test 2026-11-09 (20 min, user): "not broke, strong, no loss".
Log: short car silences (6-7 s) recovered automatically (WEBSITE BACK), hotspot ON and 3.3.3.3
present throughout, 4K test played (2880x2160, 0 holds) and one 4K stream moved to the software
decoder and kept playing.

Do not change these without a car log that shows a problem:
- App/CanvasPlayer.js (17 retries ride-through, 1440p/4K test choices)
- App/CanvasShell.js recovery (never gives up, quiet while video plays, rescue page registration)
- App/CanvasServiceWorker.js (network-first rescue copy, never caches tokens/API/media)
- App/MediaCast.m late playlist answers
DNS: car.tesla4khmer.com A 3.3.3.3, TTL 86400 (name.com, bought through Lovable).
