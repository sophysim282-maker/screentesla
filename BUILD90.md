# ScreenLink build 90 — "YouTube sent sound only" detection

Phone log (build 87): after `MEDIA: sender stopped native playback`, YouTube started AirPlay audio
(`raop_rtp starting audio`, cover art) with no `MEDIA PLAY REQUEST` — it used ScreenLink as a speaker.
The car got no new video and PiP kept the previous item (looping a few seconds, no sound) until
another video was chosen.

Build 90: if AirPlay audio starts in YouTube mode and no video arrives within 5 s, ScreenLink logs
`YOUTUBE SENT SOUND ONLY`, shows it on Home ("Connection needs attention") and sends a notification:
in YouTube tap AirPlay → ScreenLink VPN Phone again, or play the video again. It clears on the next
`MEDIA PLAY REQUEST`. Includes builds 87–89.
