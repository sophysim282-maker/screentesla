# Build 114 (0.20.77): faster video start

The user asked for the ideas for fast loading "all in one time". Built here: everything that does
not replace the player or the transport. Not built, and why:
- True pass-through streaming of a piece while it downloads, and showing a picture before a piece
  is complete: needs the phone's web server to send a body in parts and the player to unpack a
  stream. The warm-up below removes most of the same waiting at the start.
- Push line (phone tells the car): replaced by asking every 0.4 s while idle.
- Cover picture on the loading screen: the cover bytes arrive in the AirPlay C library and are not
  exposed to the app code yet.
- Seamless quality change inside the player, and one connection for everything: each replaces a
  core part and needs its own build and car test.

Where the start time went (from the user's logs, `start took` 1.5–6.3 s): the car noticed a new
video up to 1 s late; the phone fetched about 20 YouTube lists one at a time in the order YouTube
listed them; the phone downloaded a whole 5 s piece only after the car asked, then sent it.

App/MediaCast.m (phone):
- `SLWarmPick`: reads YouTube's master list and picks the picture list the car will use (same rule
  as `chooseVariant` in CanvasPlayer.js, using the phone's quality setting through
  `MediaCast.warmHeight`, set in `-[Receiver nativeMediaState]`) and its sound list.
- `prefetchChildren`: those two lists go to the front of the one-at-a-time list queue.
- `warmSegments`: when one of the two arrives, its first two pieces are downloaded at once in the
  background (`MEDIA WARM-UP` in the log; 16 MB per piece, 48 MB in total, dropped on a new video).
- `resource:range:`: a whole-piece request for a warmed piece is answered from memory; if that
  piece is still downloading the request waits for it (up to 8 s) instead of downloading it twice.
  Range requests and everything else take the old path. A wrong guess only wastes one download.
App/CanvasShell.js (car):
- media state is asked every 0.4 s while no video is active (1 s while playing, as before);
- smart first quality on Auto: a running average of piece download time / piece length; above 1.1
  at more than 720p makes the next video (within 3 minutes) start at 720p. Log: `auto quality: …`.
CanvasPlayer.js unchanged.

Checked here: all car page tests. The phone code could only be compiled by CI and bracket-checked;
it has not run against YouTube. Watch `CAR PLAYER: start took …` and `MEDIA WARM-UP` in the log.
If the first piece line shows a download of a few ms, the warm-up hit.
