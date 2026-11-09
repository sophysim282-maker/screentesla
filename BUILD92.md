# Build 92 (0.20.55)

Continues build 91. The VPN address moves from 240.3.3.3 to 3.3.3.3, plus four connection fixes.

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

Connection fixes (video player untouched):
1. Local DNS answer TTL 86400 s (1 day) instead of 60 s.
2. Website connections stay open up to 10 min idle (was 2 min) with up to 100000 requests
   (was 1000). When slots run low (<= 6 free), connections idle 15 s or more close first.
3. Car page: after 20 s without the phone, a button "Switch to 3.3.3.3" opens the HTTP
   fallback player at http://3.3.3.3:8080/ (the certificate covers only the name, so the
   secure page cannot switch by itself).
4. Phone log: "CAR DNS WATCH" / "CAR DNS: … answered by the phone VPN" every time the VPN
   answers the name (checked every 5 s).
5. Car log: "CAR PLAYER: lost phone HH:MM:SS–HH:MM:SS (N s) · reason" after reconnecting.
