# Build 116 (0.20.79) - new Home screen

Asked by the user: "our UI is boring, follow this idea" (a dark car-app style screen).

## What changed (phone Home screen only)
- Always dark. Big name "ScreenLink", round link button and round menu button at the top.
- Status with the coloured light directly under the name.
- One big picture: the user's first waiting screen picture when there is one, else the car.
- Round quick buttons: Start, pause/play, video settings, waiting screen, Disconnect all (red).
- A list: Video, TikTok, Waiting screen, Maps (closed), Orbit Cube, Help.
  - Video opens the player controls (quality with 1440p and 4K is unchanged).
  - Help opens the three steps.
- Menu button (top right) = Developer screen and test log, as before.

## Not changed
Video, audio, AirPlay, PiP, VPN, widgets, car page, waiting screen, TikTok. No car page logic changed
(only the version label).

## Files
App/ScreenLinkHomeView.m/.h (layout, `moreAction`, `setSubtitle:forRow:`, `showHeroImage:`),
App/main.m (`openMore:`, `refreshHomeExtras`), Maps/WaitingScreen.swift (`summary`, `versionNumber`,
`firstPicture`).

## Not proven
Looked at only in the simulator preview from GitHub, not on the user's iPhone.
