# ScreenLink build 86 — "Cosmic Glass" Home

Home dashboard only (Developer screen and video playback unchanged; CI checks the player against 83).

- Animated space background: slowly shifting deep-space gradient, drifting/twinkling stars
  (CAEmitterLayer) and a moving aurora glow; a soft dawn sky in light mode.
- 3D car stage: perspective tilt with the phone (motion effects) and with the finger (spring back),
  gentle floating, a light sheen sweep, and a pulsing LIVE badge while sharing.
- Glass status card with a pulsing status dot and a rotating glowing border while sharing.
- Start button: flowing gradient, moving shine, press bounce and haptic tap.
- Sections rise in one after another on first appearance.
- Reduce Motion turns all of it off.

CI runs the real Home view in an iPhone simulator (`tools/preview_home86.sh`), checks the controls,
records a motion video and takes dark/light screenshots (artifact ScreenLink-build86-HOME-PREVIEW).
