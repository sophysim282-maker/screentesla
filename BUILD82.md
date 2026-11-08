# ScreenLink build 82 — more connection slots

Phone log (build 80): playback was smooth across four videos (`picture holds 0 · rebuffers 0`; one
rebuffer came from YouTube's own `HTTP 502`), and the website dropped only once. But with kept-open
website connections, `WEBSITE BUSY: all 12 phone connection slots in use` refused an HTTP connection
and PiP stopped shortly after (local `HTTP 504`).

Build 82: the app has 32 connection slots (the broadcast extension keeps 12) and idle kept-open
website connections close after 5 s (was 10 s). Includes build 81 (long playlists) and 76–80.
