# Build 115 (0.20.78): My waiting screen

User request: let the user upload their own picture / video / GIF to show while waiting for a video,
with a good cut (transition) to the YouTube video and back. "Upload all these in the app."

Phone:
- Maps/WaitingScreen.swift: `WaitingScreenView` (Home → Maps button → "Waiting screen"). PhotosPicker,
  up to 6 files at a time. Pictures are scaled to at most 1920 px and saved as JPEG; GIFs are kept
  (20 MB limit); videos are exported to 720p mp4, first 15 s, network-optimised. Files live in
  Application Support/WaitingScreen; list and settings in UserDefaults (`waitingItems`,
  `waitingTransition`, `waitingFit`, `waitingHold`, `waitingVersion`).
- App/Receiver.m: `/waiting/list` (JSON: v, transition, fit, hold, items) and `/waiting/item/<id>`
  (file with Range support, cacheable for a day; the address carries the version). Same token
  check as the other car routes.
Car page (App/CanvasShell.js / .html): `#waitLayer` over the video canvas.
- Asks `/waiting/list` every 15 s. With files: shown while no video picture is on screen; several
  files rotate (hold seconds each, a video for its length); a waiting video is paused the moment a
  video starts loading; when the first video picture is drawn the layer leaves with the chosen
  transition (fade, zoom, slide, flash, dark dip) and the files are released; it returns when the
  video stops. Without files nothing changes from build 114.
- Uses a repeating setTimeout (the page keeps one setInterval only, the audio clock).
Tests: tools/test_waiting_screen.cjs (picture + video slideshow, freeze, zoom / dip / flash, release,
return, removal). The iPhone picker and the video export cannot run here; first real test is the user.
Note: after a quality change or a recovery the waiting screen shows again until the next picture.
