# Build 95 (0.20.58)

Continues build 94. From the build 94 car test (2026-11-09 14:19-14:25):

1. Late YouTube playlist answers (App/MediaCast.m). YouTube in the background answered playlist
   requests just after the 12 s timeout; the phone rejected them ("RESPONSE REJECTED"), asked
   again, and the same thing repeated. The car's browser connections all waited on these requests,
   so the phone saw no car requests for 55 s (WEBSITE SILENT, 8 connections open). Late answers
   for the same session and request are now kept and served from the cache.
2. Car page never stops recovering (App/CanvasShell.js). It used to stop after 3 tries and show
   "Playback recovery stopped. Press Retry video." It now keeps retrying (every 2-10 s) while the
   phone still has the video.
3. Not changed: 4K test. The log shows 4K starving (video ahead 0, buffer empty) and YouTube
   returning HTTP 502 for 4K pieces. Use Auto/1080p over the hotspot.
