# Build 138 (0.21.01) - tilted car map: far part filled

User photo on 137: the 3D car map works (satellite), but far away the map is empty.
- `App/CanvasShell.js` tileMap.renderFar: while `.tilt`, a layer at zoom tz-2 (4x the area per square) under the
  near layers, reach 4.5x the screen radius, queued after all near squares (d + 1e9). Removed when not tilted;
  kept out of `reset` leaks.
- `App/CanvasShell.html`: tilt 46deg; `#mapTiles.tilt::after` fog gradient at the top (day #dfe6ee, night #1d2430).
Car map tests pass locally. Uses more map squares on long drives (daily limit 3000 can be reached).
