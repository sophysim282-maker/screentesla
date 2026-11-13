# Build 131 (0.20.94) - Google Maps style driving screen (includes 130)

User: buttons on the map cover the turn banner; make it like Google Maps.
- `Maps/Screens.swift` DriveOverlay rewritten: green banner (lanes inside, "Then" chip under), right column of
  48 pt white round buttons (back to ScreenLink, compass, search, voice, car-map switch), Re-centre pill,
  bottom sheet with round X (end), time/distance/arrival, route-overview button.
- `NavUI.shared` (CarMapsRoot.swift): `guiding` mirrors NavModel.guiding; the top bar from 130 is hidden while
  guiding; `close` lets the drive screen go back to ScreenLink.
Map picture: the user reported after following the key steps that the map shows (message "it show").

- `Maps/KeepAwake.swift`: silent keep-awake sound only when `pipOff`; the 5 s restart and the pause-triggered start skip while `isOtherAudioPlaying` / `secondaryAudioShouldBeSilencedHint` (user: ScreenLink's own sound may cut other apps' voice).
