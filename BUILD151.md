# Build 151 (0.21.14): fix the stuck video switch

User: "sometimes click another video it shows waiting but not play, then click the next video it shows loading
and plays." Logs show `CAR PLAYER: player error: Media HTTP 404 at 0.0s` right after a new MEDIA PLAY REQUEST:
the phone dropped the old video's registry the instant the new video arrived, so the car's first request for a
new piece 404s for a moment. The car then backed off 2→4→8→10 s ("waiting"); picking another video reset it.

Fix (`App/CanvasShell.js` playbackFault / tick): a non-transport fault within 15 s of `mediaStartAt` and at
position < 2 s is a "fresh start" fault; it retries after ~900 ms (up to 8 times, `freshRetry`) instead of the
exponential 2–10 s, and the cover says "Loading this video…". `freshRetry` resets on a new epoch. Mid-video
faults keep the old exponential backoff.
