# ScreenLink build 79 — fast start

Car log (build 77): a 2-minute video played perfectly (`picture holds 0 · rebuffers 0`, no
`WEBSITE SILENT`). The next video froze in its first 10–15 s (`buffer-empty at 3.0s`, holds at 8.1 s
and 11.4 s, `video ahead 0.00s`): one-at-a-time segment downloads, each paced near playback speed by
YouTube, could not build a lead at the start.

Build 79 keeps two video segment downloads in flight (audio stays at one). Test with each request
slower than playback: build 78 froze in the first 20 s with 0 s ahead; build 79 had 16 s ahead and no
freeze. Includes builds 76–78.
