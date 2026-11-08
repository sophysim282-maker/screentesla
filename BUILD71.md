# ScreenLink build 71 — browser video player on the car website

Version 0.20.34 / build 71 branches from build 70 (website diagnostics kept).

Physical finding (8 Nov 2026): on https://car.tesla4khmer.com/video the picture froze after about
30 s while sound continued, then jumped back, at Auto, 720p and 1080p, in build 64 as well.
http://240.3.3.3:8080 never stopped. The two addresses used different players:

- 240.3.3.3 (HTTP): HLS.js feeds the browser's own `<video>` decoder; each picture is drawn on a canvas.
- Website (HTTPS): ScreenLink's WebCodecs player decoded every frame and scheduled sound itself.

Build 71 makes the website use the 240.3.3.3 decoding path by default (`App/BrowserVideoPlayer.js`):
HLS.js + hidden `<video>` → canvas, sound through Web Audio with phone volume and Normal/Music.
The car page, approval, reconnect, fullscreen, and phone/widget quality, volume, pause and seek
are unchanged. Auto keeps the highest source up to 1080p, as before.

- WebCodecs player for comparison: https://car.tesla4khmer.com/video?engine=webcodecs
- `CanvasPlayer.js`, `MediaCast.m` and `MediaPlayer.html` are identical to build 64 (checked in CI).
- The status line in developer mode and Copy playback diagnostics show `engine`.

Not yet verified on the Tesla. Builds 64, 67, 68, 69 and 70 remain on their branches.
