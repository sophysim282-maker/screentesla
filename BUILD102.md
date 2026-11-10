# Build 102 (0.20.65)

Continues build 101. The user reported (build 100 car test) that the connection is no longer lost,
but the first video takes long to start; the next ones are normal. Their log: play request to
"MEDIA BROWSER PLAYING" took 13 s and 14 s for two videos and 3 s for a third.

- App/CanvasShell.js only: a new log line per video,
  `CAR PLAYER: start took N s to the first picture · WxH · first pieces: <kind> <download ms> + <unpack ms>, …`
  (from startMedia to the first drawn picture, 1 s resolution, plus the player's own records of the
  first four pieces). Measuring only: no change to CanvasPlayer.js, recovery, or the phone.
- Next step, only with this line from a car log: decide whether the slow part is the phone's
  download of the first pieces (YouTube, mobile data) or the car (decoder start).
- Also from that log: the user tried "4K test"; the car drew 61 pictures in 26 s. Auto / 1080p was clean.
