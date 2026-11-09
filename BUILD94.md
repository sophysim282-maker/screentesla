# Build 94 (0.20.57)

Continues build 93 (3.3.3.3, connection fixes, 1440p/4K test).

Car test of build 92 (2026-11-09 13:24-13:34): the car repeatedly lost the phone for 1-15 s
("Failed to fetch"); the phone saw no requests at all (WEBSITE SILENT: 0 handshake failures,
0 refused, 2 connections open). The player gave up after 5 retries (~6 s) with
"Phone/media transport unavailable after retries" although 20 s of video was buffered.

Fix: CanvasPlayer.js retries the same bytes for ~30 s (17 attempts, 2 s apart) before giving up.
Decoders, sound and the playback clock are kept, so a short blackout is invisible.
Test: tools/test_network_pause.cjs with BLACKOUT=1 drops every connection for 12 s;
build 93's player fails exactly like the car, build 94's plays through (CI runs both).
