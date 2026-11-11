# Build 110 (0.20.73)

Continues build 109. Build 109 car log (maps closed, internet fast: 635 ms for a 5.2 s piece):
the car lost the phone for 31 s, 6 s, 11 s, 15 s and 22 s, ten TLS handshakes failed in about a
minute, hotspot ON and 3.3.3.3 present the whole time. So not the map, not YouTube, not mobile
data: the phone was not answering the car. User: happens both parked and driving; Tesla
"Remain connected in Drive" is on.

Pattern across the logs of builds 100–109: the loss usually follows `YouTube PiP stopped` (or no
PiP) with the app in the background, and ends right after `App returned to foreground` /
`YOUTUBE PiP ACTIVE`. Suspect: iOS pauses or slows ScreenLink in the background without PiP even
with the location keep-alive of build 105. Not proven yet; this build measures it.

1. Heartbeat (Maps/KeepAwake.swift): two one-second timers, one on a user-interactive queue and
   one on a utility queue. A skip of more than 3.5 s is logged as
   `APP PAUSED BY iOS for N s`, `BACKGROUND WORK SLOWED by iOS for N s`, or `IPHONE SLEPT for N s`
   (when the uptime clock did not advance), with background/foreground and thermal state.
2. Cure, started only after such a skip: a looped silent sound (`KEEP AWAKE 2 ON`) with the app's
   usual audio session (playback, moviePlayback, mixWithOthers). An app playing audio keeps
   foreground-like scheduling in the background. If it does not start: `KEEP AWAKE 2 FAILED`.
3. App/Receiver.m: the accept loop for the car's connections ran at QOS_CLASS_UTILITY; now
   QOS_CLASS_USER_INITIATED like the request handlers.
4. App/CanvasShell.js: build 109's 4 s request deadline is back to 7 s and the page self-restart
   is removed. Both forced extra new TLS connections exactly when the phone was slow, and the 109
   log showed handshake failures rising fast. Auto quality step-down (109) stays.
- Maps stay closed (108). CanvasPlayer.js untouched.
- Reading the next log: `APP PAUSED` lines at the times the car was lost prove the theory. No such
  lines while the car is lost disprove it; then look at the Wi-Fi link itself or the TLS path.
- Not verified on a device: whether the silent sound disturbs YouTube AirPlay or PiP.
