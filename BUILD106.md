# Build 106 (0.20.69)

Continues build 105. The user confirmed in the car that 105 keeps working with no PiP window
(keep-awake works) and asked for more stability. Approved: A, B and D. **Not approved: removing
the 4K / 1440p quality choices — they stay.**

A. Status light on Home (App/main.m `updateHome`, App/ScreenLinkHomeView `healthLevel`): while
   sharing, the existing status card shows, in this order: red "Link to the car is off" (3.3.3.3
   missing), red "Hotspot is off or the car left it", yellow "No internet on the phone", yellow
   "Phone is hot" (thermal state serious or worse), yellow "Waiting for the car" (no HTTPS request
   for 12 s), green "Car connected". Each has one plain sentence saying what to do.
B. Self-repair (App/main.m `healthTick`, every 5 s, also in the background): calls the existing
   `resumeListenersIfNeeded`, and when 3.3.3.3 is missing on two checks reconnects the VPN with
   `connectRouteProbe` (at most every 30 s). Log lines start with `SELF-REPAIR:`. Never runs after
   Disconnect all.
D. Internet watch (nw_path_monitor): log `PHONE INTERNET LOST` / `PHONE INTERNET BACK`; the media
   state carries `internetBack` (a counter) and the car page sets `retryAt=0` when it changes while
   the player is in its failed/retry state, so the video is retried at once.
- New: `-[Receiver linkHealth]`, `Receiver.internetBackCount`. Network.framework linked.
- Player (CanvasPlayer.js), rescue page and maps unchanged. The only car-page change is the one
  retry line above.
- Compiled by CI only; the status texts and self-repair are not proven on a device yet.
- Advice given to the user (no code): charge by cable not the wireless pad, keep the phone cool,
  PiP no longer needed, hotspot "Maximize Compatibility", Low Power Mode off.
