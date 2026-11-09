# ScreenLink build 87 — ScreenLink Maps (Car Maps inside ScreenLink)

Use: a rear-seat passenger screen shows the video plus a small navigation map.

- Car Maps (sophysim282-maker/carmaps) screens copied into `Maps/` unchanged: Google Maps, voice
  search, routes, re-routing, traffic, voice directions. Opened from Home → **Navigation map**
  (the controller is kept, so navigation continues after going back to ScreenLink Home).
- One VPN, one server: Car Maps' own 240.3.3.3 VPN and port-8080 server collided with ScreenLink.
  `Maps/CarVPN.swift` now only reports ScreenLink's VPN; `Maps/MapFeed.swift` replaces Car Maps'
  server with a store that ScreenLink's website serves at `/map/frame.jpg`, `/map/bg.jpg`,
  `/map/state`, `/map/cmd` with the same viewer approval/token as the video.
- Car page: a small map window in the corner of the video with the next turn, distance, arrival
  and time left; tap to swap (big map, small video) and tap the small video to swap back. Hidden
  when the phone is not producing map pictures. The video player (CanvasPlayer.js) is unchanged.
- Google Maps API key is entered once in the app (not stored in GitHub).
- App target now requires iOS 16; adds location (incl. background), microphone and speech
  permissions for navigation and voice search.

Test: `tools/test_map_mini.cjs` (map shown with turn/ETA, live pictures, swap and back, hides when
navigation stops, video keeps playing). Not yet verified on the iPhone or car.
