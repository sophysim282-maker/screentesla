# ScreenLink build 89 — notifications to keep the stream playing

While ScreenLink is not on screen, notifications explain what to do (tap opens ScreenLink, which
resumes PiP and the receiver). Rules (`App/StreamNotifier.m`, tested by `tools/test_stream_notifier.m`):

| Log event | Notification |
|---|---|
| YouTube PiP stopped | Video window closed — tap to bring back PiP |
| PIP NOT ACTIVE | PiP is not running — wait for “YOUTUBE PiP ACTIVE” before leaving |
| background grace expired | ScreenLink may be paused — tap to keep streaming |
| WEBSITE SILENT | Car screen lost the connection — keep hotspot Wi-Fi, reload the car page |
| Built-in VPN disconnected/failed/timed out | ScreenLink VPN is off — tap and press Start |
| Local HTTPS not started | Website certificate missing/expired |
| AIRPLAY DISCOVERY BLOCKED | Allow Local Network |
| car transport unavailable after retries | Car video stopped |
| backgrounded with PiP / without PiP | One-time tip: keep PiP open / start PiP |

Each kind has a cooldown and replaces its previous alert. Normal and user-initiated events
(Disconnect All, WEBSITE BACK, new video) stay quiet. Permission is asked on Start.
