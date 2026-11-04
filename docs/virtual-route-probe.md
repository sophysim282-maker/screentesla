# Experimental virtual-address reachability probe — 0.19.1 / build 33

This is a diagnostic build, not a confirmed Tesla streaming repair. It preserves
normal VPN settings and existing media paths. It does not implement a production
HTTPS proxy or claim to reproduce TslaMirror internals.

## Purpose

Separate three questions: whether iOS accepts an additional tunnel address,
whether packets enter that tunnel, and whether an HTTP request reaches the
existing ScreenLink server. Successful website signaling is a different test.

## Changes

- Opt-in `routeProbe` provider setting adds owned address `240.3.3.3/32` alongside
  the existing local tunnel address. Adds only its /32 route; no Internet default
  route, DNS override, third-party server, TLS bypass or media relay.
- Main-app button refuses to replace an already connected normal VPN. Disconnect
  first. A normal reconnect after disconnect clears the experimental setting.
- Provider status reports settings accepted, alias found in interface enumeration,
  and packets to the alias observed in packetFlow. Packet counters do not identify
  their originating device and do not prove replies reached Tesla.
- Read-only GET `/local-route-probe` on the existing port 8080 returns version,
  actual accepted local/peer endpoints and a clear TCP-only success message.
  It returns no token, screen frames or media, and grants no control permission.
  Allowed sources are loopback or the current hotspot bridge subnet, and an alias
  destination is allowed only when that alias is actually owned by the phone.
- Packets reaching packetFlow continue through the existing strict local
  reflection logic. Alias packets are counted but not forwarded or answered by
  a new userspace TCP/IP stack. That limitation is intentional and observable.

## Physical test

1. While parked, connect the Tesla to this iPhone's Personal Hotspot.
2. Install/sign the complete IPA with both extensions and the existing approved
   packet-tunnel entitlement. An unsigned build cannot prove provisioning.
3. In ScreenLink, Disconnect VPN and wait for Disconnected. Tap **Experimental
   virtual-IP probe**. Start the system screen broadcast as instructed so the
   local server remains available. No website session, approval or YouTube is
   needed for this test. Capture remains hidden.
4. Tap **Route probe status**. Record settingsAccepted, experimentalAliasRequested
   and aliasPresentInInterfaces. A rejected configuration is a failed experiment.
5. Enter each FULL URL separately in Tesla (including `http://`):
   - `http://172.20.10.1:8080/local-route-probe`
   - `http://240.3.3.3:8080/local-route-probe`
6. Record the browser error or success page. Return to ScreenLink, tap Route probe
   status and Copy test log. No success is inferred from a spinner.
7. Disconnect VPN, wait, and use Connect built-in VPN to return to normal mode.

These plaintext pages contain only diagnostic status. They are not the eventual
HTTPS viewer. Do not accept certificate warnings or assume a failed IP navigation
means all local traffic is blocked. Tesla may reject direct navigation before a
packet is sent. Current TslaMirror documentation says its virtual address is now
internal and its browser entry point is HTTPS.

## Interpretation

| Observation | Established | Still unknown / next work |
|---|---|---|
| settings rejected | This configuration is not accepted on that installation | Entitlement, address or platform reason from the actual error |
| alias present only | iOS assigned the alias | Tesla reachability |
| alias packet counter advances | Traffic to alias entered packetFlow | Source device, TCP replies and browser playback |
| TCP success page on hotspot address | That HTTP/TCP path reaches the local server | UDP, HTTPS, WebRTC and video |
| TCP success page on alias | That HTTP/TCP alias path reaches the local server | Production DNS/TLS/proxy design |
| Both pages fail | No successful navigation was observed | Browser policy versus routing/firewall/listener; no blanket diagnosis |

Do not build a high-bitrate video transport on top of a route that has not passed
this test. A public hostname additionally needs correct DNS, a valid certificate
and proven local routing. A VPN on the phone does not configure Tesla's DNS or
browser policy automatically.

## Validation limits

The C access-boundary test covers bridge, alias ownership, loopback and rejected
unrelated routes. The iOS build checks both extensions compile. Hosted macOS or
Linux tests cannot establish iPhone tethering, reserved-address acceptance or
Tesla browser policy. Physical results must be recorded separately.

References:
- https://developer.apple.com/documentation/networkextension/neipv4settings
- https://teslamirror.com/faq-ios
