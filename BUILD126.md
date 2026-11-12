# Build 126 (0.20.89) - background without PiP

User: wants the app to run well in the background with no PiP window.

## Changes
- `Maps/KeepAwake.swift`: silent sound starts in `begin()` (at Start) and when leaving the screen;
  checked every 5 s and restarted if stopped. `BACKGROUND:` line when leaving (PiP switch, silent sound,
  location allowed) and `BACKGROUND REPORT:` when returning (seconds away, pauses, slow-downs).
- `App/YouTubePiP.m`: with UserDefaults `pipOff` the PiP start is skipped.
- Home: line "Small window (PiP)" (key `pip`) toggles `pipOff` (default: PiP On).

## Not proven
iOS gives no promise for background running without PiP. The BACKGROUND REPORT line is the proof either way.
The preview player in ScreenLink still exists with PiP off; only the floating window is not opened.
