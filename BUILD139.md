# Build 139 (0.21.02) - car map like Google Maps on CarPlay

User photos (car map 3D, far part still not clean; Google CarPlay screenshot): wants the CarPlay look with traffic
on the route, clean far area; phone: Exit hard to see, no way back to Home except Exit.
- `Maps/CarLink.swift`: while `nav.guiding`, map squares session = dark road map (night style), never satellite.
- `Maps/CarRemote.swift`: `routeTraffic` [[start,end,1|2]] from the Routes API route (Google re-routes drop it).
- `App/CanvasShell.js`: drawRoute adds `.jam.slow` / `.jam.red` polylines; stroke width follows zoom; redraw
  when traffic changes; far layer reach 6x.
- `App/CanvasShell.html`: tilt 40deg / perspective 900px; fog 16% with the map's own colours; jam colours.
- `Maps/Screens.swift`: pills "‹ ScreenLink" and red "End" above Google's footer; round back / X removed.
