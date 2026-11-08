# ScreenLink build 76 — WebCodecs read-ahead

Car log (build 75, 8 Nov 2026): `video-hold-audio-continues · video ahead 0.00s · sound ahead 4.00s`,
`decoder restarts 0`, then `WEBSITE SILENT` for 8 s and `buffer-empty`. The decoder was fine; the
video ran out. The WebCodecs player only fetched the next video segment ~2 s before it was needed,
while HLS.js on 240.3.3.3 keeps ~20 s buffered.

Build 76 downloads encoded video up to 20 s and audio up to 12 s ahead (max 8 segments per lane,
one download at a time per lane). Decoding stays 2 s / 4 s ahead as before, so decoder and canvas
timing are unchanged.

Test (`tools/test_network_pause.cjs`, car-like 70% real-time link, 10 s phone pause):
build 75 player froze (rebuffer, 10 s ahead); build 76 kept playing (20 s ahead, no hold/rebuffer).
Not yet verified on the real screen.
