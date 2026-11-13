# Build 136 (0.20.99) - routes and traffic like Google Maps

User: route choice with times, traffic colours, delay/early, faster route offer, all Google; 3D car map while driving.
- `Maps/NavModel.swift`: TRAFFIC_AWARE_OPTIMAL + extraComputations TRAFFIC_ON_POLYLINE; fields staticDuration,
  routeToken, travelAdvisory.speedReadingIntervals -> RouteOption.staticSeconds/token/traffic. `checkFasterRoute`
  every 180 s while Google guides (offers >= 3 min saving). `trafficDelay`, `fasterRoute`.
- `Maps/Maps.swift`: orange/red traffic segments on the chosen route; bubbles "· fastest", "· +N min traffic".
- `Maps/GoogleNav.swift`: `setDestinations(_:routeToken:callback:)` with the chosen route; `takeFaster`; delay from navInfo.
- `Maps/Screens.swift`: faster-route banner (Take / ✕) and delay chip over Google's screen. Car state `delay`.
- `App/CanvasShell.*`: `#tilePlane` wrapper; `.tilt` (perspective rotateX 48deg) while driving heading-up; wider square reach.
Routes calls: Pro SKU (traffic-aware optimal). Not tested on a phone.
