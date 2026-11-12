# Build 117 (0.20.80) - cinematic entrance

Asked by the user with a storyboard (Open, Scroll, Reveal, Home) and four car pictures.

## What it does
When the app opens, a black cover shows the car. Scrolling drives the camera:
back of the car (close, pulling away) -> along the side -> three-quarter view -> the colour picture,
the status appears, then the picture flies into the Home card and the Home parts come in one by one.
A tap plays the rest alone. Skipped with Reduce Motion, in the background, or without the pictures.

## The pictures are NOT in this repository
The repository is public and the four car pictures are the user's files. They are added to the app
when the IPA is packaged (same step as the HTTPS identity), as `entrance-1.jpg` ... `entrance-4.jpg`
in the app folder. `entrance-4.jpg` is also the Home picture. A build without them behaves like 116.

## Files
App/ScreenLinkHomeView.m only (`startCinematicEntrance`, `entranceProgress:`, `finishEntrance`).

## Not proven
The GitHub simulator preview has no pictures, so the entrance itself was only checked as drawn frames,
not on a real iPhone.
