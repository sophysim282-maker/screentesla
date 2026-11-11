# Build 109 (0.20.72)

Continues build 108 (maps closed). The user asked for "the most stable video" and said to do all
the ideas now. What was real and what was not:

- Idea "bigger buffer": **already exists**. CanvasPlayer.js keeps `READ_AHEAD_VIDEO=20` s of video
  downloaded (8 pieces, 2 parallel). The "4 s" in the logs is only the decoded part. Not changed.
  (An earlier message to the user said the car keeps only 4 s; that was wrong and was corrected.)
- Idea "fast start at low quality": **not built**. The player cannot change quality without
  restarting the video, so it would add a visible restart to every video.

Built, all in App/CanvasShell.js (CanvasPlayer.js is still untouched):
1. Automatic quality step-down, only when Quality is "Auto": two picture pieces in a row taking
   longer than 1.6x their length to download, with less than 6 s of video ready and more than 30 s
   left, restart the same video at its position one step lower (above 720p → 720p, else → 480p),
   using the existing quality-restart path. Only if YouTube offers that lower step. The step is
   kept for 3 minutes. Log: `CAR PLAYER: auto quality: …`. A quality chosen by the user (720p,
   1080p, 1440p test, 4K test) is never changed.
2. `raw()` request deadline 4 s (was 7 s). tools/test_live_reconnect.cjs updated for it.
3. Self-restart: no successful answer from the phone for 45 s and no picture progress for 20 s →
   `location.reload()`, at most once per 2 minutes (sessionStorage `screenlink-self-restart`).

Checked here: all car page tests, network pause / blackout / start-up tests. **Not** checked: the
step-down itself under real slow mobile data (no multi-quality slow test exists yet), and nothing
in a car. If videos restart when they should not, look for the `auto quality` log line.

Note on the build 106 freeze (10:57:54): `video-hold-audio-continues` followed by
`video-recovery-output-stall` means the decoder stopped giving pictures; with "6 connections open"
and TLS handshakes timing out, the car browser itself was struggling. The map (GPU work and
connections) is the main suspect; 108/109 run without it.
