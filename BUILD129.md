# Build 129 (0.20.92) - Phone sound fix

User on 128: other apps' sound still silent with Phone sound.
Found in code (no log yet): `AirPlaySound.swift` gave AVAudioConverter no magic cookie for AAC-ELD (ct 8),
so every packet failed. Now: ELD cookie F8 E8 50 00 (44.1 kHz stereo 480), AAC-LC 12 10.
`KeepAwake.startSilentSound` no longer resets the category to playback while `SLAirPlaySound.playing`.
First AIRPLAY SOUND line at the first packet; unpack errors are logged with the error code.
Not proven on a phone.
