# Build 133 (0.20.96) - map test without the Google Navigation kit

User on 132 (screenshot + log): phone map is plain grey (pins and blue route show), `MAP PICTURE LOADED ✓`
was still logged (tile rendering callback fires), no `GOOGLE SAYS` lines, car squares `404 Requested entity
was not found`. Key lists Maps SDK for iOS, Map Tiles, Navigation SDK. Grey started with build 128, which
added GoogleNavigation 9.4.0 (GoogleMaps resolved 9.4.0 for both, so not a version mismatch).
A/B: GoogleNavigation package removed; `Maps/GoogleNav.swift` compiles a stub under
`#if !canImport(GoogleNavigation)` (log functions kept, `start` sets googleActive=false).
If the map shows in 133 -> the navigation kit (or its key/terms) causes it. If still grey -> key/account.
Also: map top bar chips no longer wrap (lineLimit(1).fixedSize()).

## Phone sound (added after the user's 132 log)
132 log: Phone sound On, `unpacker ready` twice a second (the key flip recreated the converter every 60 failures),
2508/2508 failed with '!dat'. Both keys rejected by AVAudioConverter. Now: key chosen by the ALAC element tag
(first 3 bits 000/001) over 100 pieces, logged with the first 8 bytes; if pieces look valid but do not decode,
cookie forms rotate: bare ALACSpecificConfig / 'alac' box / 'frma'+'alac'.
