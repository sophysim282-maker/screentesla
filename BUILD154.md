# Build 154 (0.21.17): deep auto-reconnect (no app restart)

User log (weak phone->car Wi-Fi the whole drive): repeated "MEDIA PIECE TO CAR ... the car connection broke",
"CAR LEFT THE WI-FI", "WEBSITE STILL LOST" for minutes, "HTTPS HANDSHAKE FAILED". Complaint: the car shows
"connecting to phone" and never connects, so the app has to be turned off and on.

`App/main.m` healthTick: new deep auto-reconnect. When the Hotspot is ON but `carSeconds` stays > 15 for ~90 s
(`carLostSince`), it runs what an app restart does — `vpn connectRouteProbe` (full VPN reconnect) then
`resumeListenersIfNeeded` + `refreshDiscovery` + `authorizeNextLocalViewer` — at most once per 150 s
(`deepFixAt`), logging CAR DEEP RECONNECT. Never fires when the hotspot is off (car genuinely gone). The lighter
build 142 `fixCarLink` (20 s) still runs first; this is the escalation when that did not bring the car back.
Cannot fix weak Wi-Fi itself, only recover faster when it returns.
