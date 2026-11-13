# Build 135 (0.20.98) - Maps switch on Home + background navigation (includes 134)

User: a button to show or close the map; map and video together; fast turn updates; smooth like Google Maps;
keep running when the app is left or the phone is locked.
- `App/ScreenLinkHomeView.m/.h`: UISwitch on the Maps row (`home.mapsSwitch`, moreAction mapsOn/mapsOff), arrow hidden.
- `App/main.m`: mapsOn/mapsOff set `mapsOpen`; `showMaps` opens maps directly (no alerts).
- `Maps/GoogleNav.swift`: `roadSnappedLocationProvider.allowsBackgroundLocationUpdates = true`,
  `sendsBackgroundNotifications = true`. Turn speed and animation come from Google's navigation UI (134).
Not proven on a phone. The car map from phone pictures stops while the app is in the background (GMSMapView
does not render); car map squares (Map Tiles) keep working.
