# ScreenLink 3333 — independent source variant

Created 2026-11-07 from working version 0.20.26 / build63, commit 3b1e19ecfd6e76f5e1c7b8dc69e248f79a6eee9a.

This variant is independent of release/build63. Change this branch only when developing the 3.3.3.3 app. Original build63 remains the user-accepted baseline (30-minute Tesla test, two freezes).

- Branch: variant/vpn-3-3-3-3.
- Display name: ScreenLink 3333.
- App bundle identifier: local.screenlink.vpn3333. VPN, Broadcast and Widgets use this prefix with their existing suffixes.
- Widget/app URL scheme: screenlink3333. Original screenlink URLs are rejected by this variant.
- VPN display name: ScreenLink 3333 VPN. AirPlay target: ScreenLink 3333 VPN Phone.
- Experimental owned virtual alias changed from 240.3.3.3 to 3.3.3.3: /32 address and route, packet counters, interface ownership checks, route-probe access checks and HTTP-origin strings updated together.
- Internal AirPlay transport remains 10.7.1.1 / 10.7.0.1. Those are distinct from the experimental alias.
- Packet reflection remains restricted to the existing internal peer. This copy does not add a general TCP proxy or change the hotspot client's routes or DNS.
- 3.3.3.3 is in public IPv4 space, not RFC1918 private space. While this experiment is active, the single-IP alias/route may shadow the real address; it is not ownership of a public IP. No default Internet route was added.
- Original playback, audio scheduler, PiP and build63 recovery fixes retained.
- All workflows in this branch are manual-only. No compilation, IPA packaging or installation authorized/performed for this change. Device routing/connectivity remains unverified.
- A future build must sign the distinct app/extension identifiers and preserve the personalized HTTPS identity privately. No TLS keys or signing credentials are copied into this public source.

The HTTPS viewer hostname is retained for compatibility with the existing certificate; these apps are separate installations but use the same local server ports. They are not designed to operate their VPN/receiver simultaneously.
