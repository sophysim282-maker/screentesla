# Build 124 (0.20.87) - Phone sound

User: with AirPlay to ScreenLink, Messenger/Telegram voice is silent and the car video stops.
Cause (reasoned, the log line AIRPLAY SOUND ARRIVING was never sent back): iOS routes all app audio to
the picked AirPlay device; ScreenLink discards RAOP audio.

## Change (experiment, switch `phoneSound`, default YES, Home line "Phone sound")
In media-only + Phone VPN mode:
- `App/VPNDiscovery.m`: no `_raop._tcp` registration when the profile has `noAudio`.
- `App/Receiver.m`: `features=` in the AirPlay TXT gets bit 0x200 (audio) cleared; profile `noAudio`.
- `App/MediaCast.m`: `/server-info` features 0x7B instead of 0x27B.
Takes effect at the next Start. Mirroring modes are untouched.

## Risks / not proven
- iOS or YouTube may not list or may not play to a device without the audio service. Then switch it off.
- The car video stopping when another app plays: Keep playing (119) should cover the pause; if it still
  stops with both switches on, the log (KEEP PLAYING / MEDIA lines) is needed.
