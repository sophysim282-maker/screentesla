# ScreenLink build 75 — car playback log on the phone

Version 0.20.38 / build 75 = build 74 + the car page sends its playback problems to the phone.
The fullscreen /video page has no buttons, so on-screen diagnostics were not reachable.

The phone log (Developer → Copy test log) now includes `CAR PLAYER:` lines: decoder restarts and
their reason, picture holds while sound continues, the software decoder switch, player errors,
connection interruptions (sent after reconnecting), and a summary each minute. Text only, at most
six lines per report, no tokens or URLs, sent with the existing authenticated playback report.
