# Build 134 (0.20.97) - Google's own navigation screen + key check

The grey map (128-133) was Google billing (key test: "You must enable Billing"). User has now paid and
asks for navigation "like Google Maps".
- `project.yml`: GoogleNavigation package back.
- `Maps/GoogleNav.swift`: no headless session; the phone `GMSMapView` gets `isNavigationEnabled`, header/footer,
  recenter button, speedometer, camera `.following`, Google voice (`alertsAndGuidance`, mute follows settings.voiceOn).
  Listener still fills NavModel for the car page and the cube. Fallback to own logic if it cannot start.
- `Maps/Maps.swift`: while Google drives the phone map: no own route line, arrow, camera or padding on it (car map unchanged).
- `Maps/Screens.swift` DriveOverlay: googleActive -> only round buttons (back, search, voice, car map, end X).
- `Maps/ContentView.swift` KeyCheckBanner: one computeRoutes call on map open; shows Google's error or "key OK ✓"; log MAP KEY CHECK.
Risk: Google voice may change the audio session (build 91 issue with PiP/AirPlay). Not tested on a phone.
