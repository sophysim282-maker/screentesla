# Build 122 (0.20.85) - TikTok: auto scroll and next video ready

User: TikTok shows only 2 videos in the car, auto scroll does not work, make the next video ready.
(No log was sent; cause of "only 2 videos" is NOT proven.)

## Changes
- `App/MediaCast.m`: `+currentProgress` (position, duration, active, epoch, kind of the current cast);
  `+prefetchFile:` downloads a whole file video (max 40 MB, 4 files / 96 MB kept) with the TikTok
  headers; `resource:range:` answers whole or byte-range requests from that memory copy (206 + Content-Range).
  The handed-over file video is prefetched too.
- `Maps/TikTokBrowser.swift`: timer 1 s. `followCar()` scrolls once per cast epoch when the car's
  position reaches the end. `S.next` = scrollIntoView of the next video, else scrollBy, then (if the
  page did not move) the page's own next button, then ArrowDown. `prepareNext()` sends the next two
  video addresses on the page to `prefetchFile:`.
- Still AirPlay hand-over only: a video reaches the car only when iOS hands it to ScreenLink. The
  prefetch is a cache for that same address, nothing is sent to the car without the hand-over.

## Open
If iOS does not hand over the 3rd video by itself, the log shows `video on the page: …|local|…` after
the scroll. That would need a different idea.
