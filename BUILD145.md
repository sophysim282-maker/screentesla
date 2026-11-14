# Build 145 (0.21.08): phone sound of other apps

Log from 144 with Phone sound On: every Apple Lossless packet (kind 2, 352 samples) failed in AVAudioConverter
with '!dat', with all three settings-block forms.

1. `ThirdParty/ALAC/`: Apple's open-source ALAC decoder (Apache 2.0, github.com/macosforge/alac, commit in
   SOURCE-COMMIT), decoder files only, plus a bound check on partial-frame sample counts. `sl_alac.cpp` wraps it
   (zero-padded input copy), `SLALAC.m` exposes it to Swift. `Maps/AirPlaySound.swift` uses it for kind 2.
2. `tools/prepare_receiver.py`: reads the sound stream's `shk` (32 bytes) and the list of setup fields. When `shk`
   is present, `raop_buffer_decrypt` opens packets with ChaCha20-Poly1305 (nonce = last 8 bytes, tag = 16 bytes
   before, extra data = RTP header bytes 4..11); if that fails it falls back to the old AES way.
3. Log: the 20 s `AIRPLAY SOUND` line adds "sound setup fields", "newer lock key sent", opened / not opened counts.

Tests: `tools/test_audio_chacha.c` (in build.sh), `tools/test_alac_decode.cpp` (bit-exact against ffmpeg ALAC
packets: ffmpeg -c:a alac to .caf, packets extracted from the pakt/data chunks; frame size 4096).
