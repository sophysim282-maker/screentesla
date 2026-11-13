# Build 132 (0.20.95) - Phone sound: try both sound keys (includes 131)

User log on 131 (Phone sound On): `kind 2 with 352 samples` (ALAC), 2508 packets / 20 s, every one
`could not be unpacked … error 560226676` = '!dat' = kAudioCodecBadDataError. Packets mostly 32 bytes.
Conclusion: data reaches the decoder but is not valid ALAC -> most likely wrong AES key. RPiPlay's
raop_buffer always uses SHA-512(aeskey || ecdh_secret)[0:16].
Change: patch keeps the plain key (`sl_rawkey`), global `sl_audio_rawkey` selects it; `SLAudioKey` (Receiver.m)
lets AirPlaySound.swift flip it after 60 bad packets in a row (logs the first 4 switches; fresh converter).
Not proven: if both keys fail, the cookie or packet framing is the next suspect.
