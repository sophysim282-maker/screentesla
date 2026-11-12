# Build 128 (0.20.91) - Phone sound, new way (and the first compiled build with 127's Google navigation)

User: with AirPlay to ScreenLink, other apps (Messenger, Telegram) are silent; modern AirPlay keeps them on
the phone. ScreenLink is an AirPlay 1 receiver (AppleTV3,2 profile), so iOS routes all app audio to it.
Build 124's "picture-only device" hid ScreenLink from the AirPlay list (user report on 126) -> removed
from the UI, `phoneSound` forced NO.

## Changes
- `tools/prepare_receiver.py`: patch `raop_handlers.h` to keep `ct` and `spf` of the audio stream
  (`sl_audio_ct`, `sl_audio_spf`).
- `App/Receiver.m`: the RAOP audio callback hands every packet to `SLAirPlaySound`.
- `Maps/AirPlaySound.swift`: AVAudioConverter (ALAC with a 24-byte cookie, AAC, AAC-ELD) -> PCM.
  Silence is ignored. On real sound: audio session `playAndRecord` + `mixWithOthers` + `defaultToSpeaker`
  (no `allowAirPlay`, so ScreenLink's own output does not go back to AirPlay), AVAudioEngine plays it.
  If the route still shows AirPlay, nothing is played (echo guard). After 8 s of quiet the normal
  `playback/moviePlayback/mixWithOthers` session is restored (PiP and keep-awake use it).
- Home line "Phone sound" now toggles `soundToPhone` (default OFF).

## Not proven / risks
- Whether Messenger's sound really arrives over RAOP (never confirmed by a log), which codec, and whether
  AAC-ELD decodes without a magic cookie.
- `playAndRecord` while a voice plays may disturb PiP or the YouTube AirPlay session (see build 91).
- Log line `AIRPLAY SOUND: …` every 20 s tells all of this.
