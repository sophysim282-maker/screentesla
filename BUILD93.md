# Build 93 (0.20.56)

Continues build 92 (VPN 3.3.3.3 and connection fixes). Adds an optional quality test:

- Home player quality switch: Auto, 720p, 1080p, **1440p**, **4K**. The car page follows it.
- 1440p picks the best variant up to 2560x1440; 4K up to 3840x2176.
- Auto, 720p and 1080p pick exactly the same variants as build 83 (tools/test_quality_cap.cjs).
- CanvasPlayer.js change is limited to the variant choice and the decoder size limit for these
  two test choices; read-ahead, downloads and decoding are unchanged.
- Model 3 Highland screen is 1920x1200, so 4K mostly costs Wi-Fi and decoding power.
  If it freezes or shows a player error, go back to Auto.
