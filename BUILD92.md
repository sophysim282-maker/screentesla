# Build 92 (0.20.55)

Continues build 91. Only change: the VPN address moves from 240.3.3.3 to 3.3.3.3.

Why: 240.0.0.0/4 is a reserved range. Some DNS servers, routers and carrier networks
drop answers that point to reserved addresses, so the car could get "server not found"
for car.tesla4khmer.com while typing the address directly still worked. 3.3.3.3 is a
normal address, so DNS answers pointing to it are not filtered.

- Tunnel: VPN owns 3.3.3.3; local DNS answers car.tesla4khmer.com -> 3.3.3.3.
- Receiver: alias checks use 0x03030303; HTTP fallback origin http://3.3.3.3:8080.
- Maps: status text mentions 3.3.3.3.
- CanvasPlayer.js unchanged (build 83 video rule).
- Required outside the app: the public DNS A record for car.tesla4khmer.com must be 3.3.3.3.
- Trade-off: while the VPN is on, the phone cannot reach the real internet host at 3.3.3.3.
- ScreenLink3333 (variant/vpn-3-3-3-3) stays a separate app; only one VPN runs at a time.
