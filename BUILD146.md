# Build 146 (0.21.09): fast first start when you get into the car

User: the first video after getting into the car takes long; later videos start fast.
Logs: first video 7.4 s to the first picture (first piece 3.3 s), next video 1.1 s (0.7 s). Everything is cold
at the first start: phone mobile radio, YouTube connections, car connections, car video decoder.

Phone (`App/main.m` healthTick, every 5 s):
- `CAR ARRIVED`: the car page comes back after being away (hotspot off, never seen, or silent > 30 s). With no
  video playing: resume listeners and publish AirPlay again.
- `WARM-UP`: while the car is there and no video plays, every 25 s `SLWarmDownloads` asks youtube.com /
  googlevideo.com `generate_204` (mobile radio awake, name lookup, secure connections). Home shows **Car ready**.
- `App/BoundedDownload.m`: first tries use one long-lived session (connections stay open between pieces and
  videos); retries still use a new connection, as in build 118.

Car page (`App/CanvasShell.js`):
- reconnect every 1 s for the first 30 tries (then 3 s), and at once when the page becomes visible.
- `carWarmUp()` on connect and every minute with no video: 3 parallel fetches of `/app/canvas.js?warm=…`
  (opens connections, gets the Wi-Fi up to speed), and one H.264 decoder configure (closed after 1.5 s).

Not fixable by the app: iOS hides the Personal Hotspot when nothing is connected for a while. Tip: open
Settings → Personal Hotspot when getting in until the car joins.
