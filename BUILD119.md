# Build 119 (0.20.82) - Keep playing

User: when a Telegram voice message plays, the car video pauses, and the voice message has no sound.

## Changes
- `App/MediaCast.m`: with UserDefaults `keepPlaying` (default YES, set in main.m; NO in tests and the
  extension) `/rate?value=0` and `/stop` from the sender are answered 200 but ignored. Log `KEEP PLAYING: …`
  with `isOtherAudioPlaying` and `secondaryAudioShouldBeSilencedHint`, to make a smarter rule later.
- Home: new line "Keep playing" (key `keep`) toggles it.
- `App/Receiver.m`: RAOP audio callback logs `AIRPLAY SOUND ARRIVING` (at most every 20 s). Sound is NOT played.

## Not done / not proven
- The missing Telegram sound is not fixed. If the log shows AIRPLAY SOUND ARRIVING during the voice
  message, iOS is sending that sound to ScreenLink; playing it on the phone speaker needs a decoder
  (AAC-ELD or ALAC) and a way to avoid sending it back to AirPlay. Decide after the user's log.
- Whether YouTube keeps the AirPlay session after iOS interrupts it.
