# ScreenLink build 70 — website diagnostics

Version 0.20.33 / build 70 branches from build 69 (`7dbb0c6`). It only adds diagnostics for the
unresolved problem: https://car.tesla4khmer.com stops loading while http://240.3.3.3:8080 still plays.

Phone log (Copy test log) now records:

- `WEBSITE SILENT` — the car made no HTTPS request for 6 s. It lists what reached the phone since
  the last good HTTPS request: HTTP (240.3.3.3) requests, HTTPS handshake failures, wrong-address
  HTTPS requests, and connections refused because all 12 phone slots were busy.
  All HTTPS numbers 0 → the car is not reaching the phone over HTTPS (name lookup/network).
- `WEBSITE BACK` — HTTPS requests resumed, with the length of the silence.
- `HTTPS HANDSHAKE FAILED` — with the reason (browser closed, timed out, TLS protocol error).
- `WEBSITE BUSY` — all 12 connection slots in use; a new connection was closed unanswered.
- `HTTPS REQUEST REFUSED` — the request named a different address.

Repeating lines are limited to one per 5 s. The car page status also shows the browser's exact
error and time while reconnecting.

Unchanged: CanvasPlayer.js and MediaCast.m are identical to build 64 (checked in CI). Audio,
AirPlay media delivery, PiP, VPN, widgets, Developer controls and the HTTP fallback are unchanged.
Builds 64, 67, 68 and 69 remain on their branches. ScreenLink3333 is separate.
