# Build 147 (0.21.10): Apple-style Home, auto start, map widget

User: make the UI easy to see and touch, start by itself when the app opens, and a widget with the map.
Design chosen: "Apple style" picture (like iPhone Settings + the Home app).

- `App/ScreenLinkHomeView.m`: new `initWithFrame` (follows light/dark): large title + link button; car card
  (picture, status dot/label/detail at the bottom, YouTube button top right, LIVE badge); four tiles
  (Maps, Phone Sound, Keep Playing, TikTok; tap = On/Off, state comes from `setSubtitle:forRow:` text);
  car player card shown only while a video plays; grouped list (Video Quality menu, Small Window switch,
  Waiting Screen, Open Map / Help, More = Developer); Start / Stop ScreenLink at the bottom (one shown).
  Test names kept: home.start, home.disconnect, home.developer, home.copy, home.maps, player.*.
- `App/main.m`: auto start in `active` once per foreground, unless Stop was used in the last 5 minutes
  (`stoppedAt` in UserDefaults, also set by the widget Stop). Home fills the whole screen.
- Map widget: `Widgets/MapWidget.swift` (medium, large) reads `http://127.0.0.1:8080/local/widget/map`
  (Receiver.m, loopback only) → `Maps/WidgetMap.swift` builds a 640×640 picture from the Google map squares
  (SLMapTiles, zoom 16 driving / 15), draws the route and the blue dot, plus next turn, arrival, car video.
  The app asks iOS to refresh the widget when the next turn changes (at most ~1/min). Tap → screenlink://maps.
