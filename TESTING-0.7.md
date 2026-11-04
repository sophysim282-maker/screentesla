# ScreenLink 0.7: local-only Bonjour proxy

The 0.6 phone log confirmed successful publication but no visible receiver. That does not prove a universal same-device AirPlay restriction. The 0.6 implementation used interface scope Any. This experiment uses LocalOnly for both the synthetic A record and AirPlay/RAOP services, matching a locally visible proxy rather than a network-wide advertisement.

The app additionally browses its own AirPlay service, resolves its SRV target, and verifies that the target address is 10.7.0.1. The log must distinguish registration, local DNS resolution, route-picker visibility, AirPlay handshake, and actual video. These are five separate checkpoints.

## Validation

The cloud build first compiles and runs tools/test_vpn_discovery.m as a native macOS program, exercising real local-only Bonjour browse, service resolution and IPv4 lookup. This verifies API integration on macOS only. The iOS build verifies compilation; physical iPhone discovery and video must still be tested. No extra signing entitlement is requested.

## Device procedure

1. Update to 0.7. Stop the Mac helper and all earlier dns-sd advertisements.
2. Keep LocalDevVPN connected and the viewer on the iPhone hotspot.
3. Select iPhone VPN, Start receiver, and wait for the log to say Local proxy address verified: 10.7.0.1. Copy the complete viewer link.
4. Open Screen Mirroring and look for ScreenLink VPN Phone.
5. If absent, save the complete log including the local browse/resolve results. Do not conclude AirPlay visibility from the DNS checks.
6. If connected, verify changing browser video, then start floating preview before switching apps as in 0.5/0.6.

Local-only advertisements deliberately need not appear in the Mac's dns-sd browser. The Mac VPN fallback still uses its original network-wide helper. Video quality is unchanged from 0.6.

## Basis and limits

Apple documents local-only DNS-SD scope: https://developer.apple.com/documentation/dnssd/kdnsserviceinterfaceindexlocalonly

An original 2017 implementation describes a local-only AirPlay proxy: https://nixwang.com/2017/03/05/airplay-without-bonjour/ . The same author later reported an iOS 11 visibility regression: https://stackoverflow.com/questions/46822512/airplay-service-registered-by-dnsserviceregister-cannot-be-discovered-by-ios-1 . These are historical leads, not evidence that this method works on iOS 27. AirServer's own documentation also describes on-device Bonjour discovery assistance for a separate receiver; that does not validate a VPN peer on the same phone: https://support.airserver.com/support/solutions/articles/43000512459-airserver-connect-hardware-network-and-security-information
