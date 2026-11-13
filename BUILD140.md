# Build 140 (0.21.03) - car map auto zoom

User: zoom in before a turn, zoom out a little when fast, smooth.
- `Maps/CarRemote.swift`: `distM` (metres to the next turn while guiding, else -1).
- `App/CanvasShell.js` tileMap.camera: base 17.2 minus up to 1.6 between 8 and 28 m/s; from 300 m before a turn
  it ramps up to 18.0; user +/- is an offset; eased 6 % per frame; the glide loop runs until the zoom settles.
  Without speed/distM data (tests, old phones) the old fixed zoom is used.
