# Build 125 (0.20.88) - Maps switch

User: make a button that starts the maps only when tapped; maps and video must not disturb each other;
working together would be best.

## Changes
- UserDefaults `mapsOpen` (default NO). `App/main.m` `showMaps`: closed -> asks "Open maps"; open ->
  first tap shows the map, next tap offers "Show the map" / "Close all maps". Home subtitles follow.
- `App/Receiver.m` `nativeMediaState`: `maps` = the switch.
- `App/CanvasShell.js`: `MAPS_CLOSED` constant replaced by `mapsSwitch(next.maps===true)` in `tick`
  (one call after the state is read). Closed: no map loop runs, no `/map/...` request. Open: `mapStateLoop`
  and `mapFrameLoop` run as before 108, with `videoBudget()` giving the video first place.
  Tests (`ScreenLinkMapsForTest`) run the loops as before.

## Not proven
Video stability with maps open in the car. The summary log line shows "map closed/squares/…".
