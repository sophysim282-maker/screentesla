# Build 149 (0.21.12): read-ahead store for weak internet

User log (build 148, quality 4K): 9.5 MB pieces took 10–29 s from YouTube over mobile data, some failed
("no data for 5 s", HTTP 502), so the car waited. The Hotspot link was fine.

- `App/MediaCast.m`: when a media playlist is served, its pieces and their seconds are remembered
  (`notePieces`). Each time the car asks for a piece, the phone keeps downloading the following pieces
  (up to 180 s ahead, 3 at once, 900 MB at most) into `tmp/ScreenLinkAhead/<epoch>/` (`aheadAfter`). The car's
  requests are answered from there; a piece being loaded is waited for (no double download). Pieces 3 behind
  the car are deleted; a new video or Stop empties the store. Not used in the broadcast extension.
  The media state carries `phoneAhead` (seconds ready on the phone).
- `App/CanvasShell.js` `updateLoadingNote()`: when the picture runs dry it says "Phone internet is slow · still
  loading…" or "Wi-Fi to the car is slow · N s ready on the phone".
- Slow-internet check (`noteDownload`): if the last 3 pieces took >1.3× their playing time and quality is
  1440p/4K, log `INTERNET TOO SLOW FOR 4K` → main.m asks once per video "Use Auto / Keep 4K"; a notification when
  ScreenLink is in the background. Never switches by itself.
