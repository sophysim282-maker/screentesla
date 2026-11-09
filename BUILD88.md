# ScreenLink build 88 — rear-screen map always on

Build 87 sent live map pictures only while the Navigation map screen was open on the phone; after
going back to ScreenLink Home (or another app, or locking) the small map disappeared.

Build 88: whenever the live map cannot be drawn (`CarLink.liveMapUsable` false: app not active, map
screen not on the phone, or black snapshots), Car Maps' background mode is used — one Google Static
Maps picture around the car, re-fetched after ~250 m, that the car page moves, tilts and turns with
GPS, with a car marker, next turn and arrival. Car Maps' ReplayKit in-app capture fallback is not
used in ScreenLink (no screen recording). Test: `tools/test_map_mini.cjs` background case.
