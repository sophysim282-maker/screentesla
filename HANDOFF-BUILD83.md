# Handoff after build 83 (8 Nov 2026)

Current accepted build: **0.20.46 / build 83**, branch `release/build83-stable-keep-alive`.
User test with the phone locked: playback good, PiP stays active.

## User rule for the next update
- **Do not change video playback.** `App/CanvasPlayer.js` (WebCodecs + canvas + Web Audio, 20 s
  read-ahead, two video downloads, quality cap, decoder fallback) stays exactly as in build 83.
- Only if the user's next test still loses the website connection, change the connection side
  (phone HTTPS server / keep-alive / name lookup), nothing in the player.

## Open items (only if asked)
- Website drops: watch for `WEBSITE SILENT`, `WEBSITE BUSY`, `Failed to fetch`, `-65569` in the log.
- Developer → Route probe status always shows "No provider response", so `localDNSAnswers`
  (build 77 local name lookup) cannot be confirmed.

## Packaging
Cloud builds never contain the private HTTPS identity. A ready-to-sign IPA is made by adding the
user's PrivateTLS (from their own earlier IPA) with `tools/add_identity_ci.py`, outside GitHub.
Sign with KravaSigner keeping Widgets, LocalTunnel and Broadcast.
