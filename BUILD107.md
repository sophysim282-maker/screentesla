# Build 107 (0.20.70)

Continues build 106. Two build 106 car logs: videos play cleanly for minutes, then the picture
stops while sound continues (`video-hold-audio-continues`, video ahead 0.00 s, sound ahead 4 s) or
the car stops answering, with "6 connections open". Earlier log: two 10 s stalls while the first
video was starting. User: "YouTube sometimes good, sometimes bad; loading so long; sometimes lost".

Likely cause (not proven; the logs did not record it): a car browser has 6 connections per host.
Since 105 the car map shares them with the video: up to 3 map squares at once, each able to hang
6 s on the phone, plus `/map/state` about twice a second while driving. Mobile data dips are the
other candidate.

Part 1, video first (App/CanvasShell.js `videoBudget`, Maps/MapTiles.swift):
- Map square downloads: 3 at a time with no video, 1 while a video plays, 0 while a video is
  starting or has less than 1.5 s of picture ready (retried every 0.7 s). Paused / ended / near
  the end of a video: normal.
- Live map pictures from the phone follow the same budget (300 ms apart, or paused).
- `/map/state` is asked less often while a video plays (900 ms driving, 1500 ms otherwise).
- The phone gives up on a map square after 2 s (was 5–6 s), so no car connection is held long.

Part 2, proof in the log: the `CAR PLAYER: summary` line ends with
`· map off|squares (loading N, waiting M)|phone pictures|google · last picture piece X ms for Y s of video`.
A piece that takes longer to download than it lasts means the phone's internet was too slow.

CanvasPlayer.js, recovery logic and the quality choices (incl. 1440p / 4K test) are unchanged.
Not car-tested. If freezes continue with `map off`, the cause is mobile data or the car's Wi-Fi.
Idea not built: start a video at a lower quality and step up (faster first picture).
