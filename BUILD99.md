# Build 99 (0.20.62)

Continues build 98 (the car draws the map itself). Only the look of the car map changed.

- Car page (App/CanvasShell.js, App/CanvasShell.html), map section only:
  - asks Google for the vector (3D) map; while driving it is tilted 55 degrees, the travel
    direction is up (unless the phone's heading-up setting is off) and the car sits in the lower
    part of the map so more road ahead is visible;
  - real Google day / night colours (colorScheme); the map is rebuilt when day/night changes
    because Google only accepts the colour scheme when a map is created;
  - live traffic layer; satellite follows the phone's map type;
  - blue route with a dark edge, red Google pin at the destination, blue navigation arrow with a halo;
  - glides between GPS points (about 14 pictures a second, only while the car moves; a parked
    car or hidden page draws once);
  - Google-style green turn banner with a drawn arrow (maneuver), a "Then" chip, and a white /
    dark arrival card (time left, distance, arrival clock) placed above the Google logo.
- If Google gives a flat (raster) map, north stays up and the arrow turns, as in build 98.
- No phone (Swift / Objective-C) logic changed; the state already had maneuver, then, arrival,
  night, mapType and headingUp.
- Video files unchanged from build 97 (CanvasPlayer.js, recovery, rescue page).
- tools/test_car_map_js.cjs covers vector, flat and refused-key cases with a stubbed Google.
- NOT verified here: the real Google tiles and the 3D map speed in the Tesla browser. If the video
  stutters while the map moves, lower the glide rate (interval in updateCarMap) or turn the tilt off.
