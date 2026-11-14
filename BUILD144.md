# Build 144 (0.21.07): fast start

User complaint: "when i start it take so long". Logs showed a 7.4 s first picture (the 1080p first piece took
3.3 s from YouTube over mobile data) and long waits where YouTube sent only sound.

1. Fast start (`App/CanvasPlayer.js`): when the chosen quality is above 720p and the sound is a separate list,
   the first piece plays from the 720p list. The full-quality list is fetched in the background
   (`ensureUpgrade`). At piece 1 the video downloader hands over to the full-quality list (`boundary`),
   the old decoder is flushed, and the new lane decodes on. Sound is not touched. Seeks after the switch stay
   on full quality. The car log shows `fast start: moved up from 720p to NNNNp`.
2. Phone warm-up (`App/MediaCast.m` `SLWarmPick`): warms the 720p list first, then the sound, then only the
   second piece of the full-quality list.
3. Warnings (`App/main.m`, `App/StreamNotifier.m`): vibration + Home message + notification for
   `YOUTUBE SENT SOUND ONLY` (pick ScreenLink from the TV icon inside YouTube) and new `CAR LEFT THE WI-FI`
   (first `WEBSITE STILL LOST`; cleared at `WEBSITE BACK`).

Test: `SCREENLINK_CHROME_BIN=<chrome with H.264> node --require ./tools/test_browser_engine.cjs tools/test_fast_start.cjs App <fixture>`
(fixture: master.m3u8 with v720/v1080 2 s TS lists and a separate a.m3u8).
