# ScreenLink 0.6: iPhone-side VPN discovery test

Scope: remove the Mac advertiser from the startup path. Video transport, JPEG quality, output frame-rate cap and floating preview are unchanged from 0.5.

## What changed

The new iPhone VPN mode publishes an explicit A record for the LocalDevVPN peer 10.7.0.1 and points AirPlay and RAOP SRV records at that synthetic hostname. It uses DNSServiceCreateConnection, DNSServiceRegisterRecord and DNSServiceRegister with main-queue callbacks. The hostname includes the receiver identity; the visible name is ScreenLink VPN Phone. Stop and Refresh discovery explicitly deallocate the owned records. Native and Mac VPN modes remain available.

This is a hypothesis-driven test of same-phone discovery, not an established way around iOS filtering. Successful registration or visibility on a Mac does not prove that the same iPhone will list or connect to the service. The exact API errors and actual received frame count are the evidence to collect.

## Test without the Mac helper

1. Update ScreenLink in place to 0.6. Keep LocalDevVPN connected at its previously tested peer address, 10.7.0.1.
2. Stop every old Mac proxy advertisement with Control-C. Leave the Mac connected to the iPhone hotspot only as a browser viewer.
3. Select iPhone VPN in ScreenLink and tap Start receiver. Copy the complete viewer link before casting.
4. Open Control Center, then Screen Mirroring. Look for ScreenLink VPN Phone.
5. If present, connect and check for actual changing iPhone content in the browser. Return to ScreenLink and start floating preview; wait for ACTIVE before switching apps.
6. If absent, return to ScreenLink and tap Refresh discovery once. Save the test log, including the registration callback results, if it remains absent.

Do not interpret this test as a quality or frame-rate improvement. The separate LocalDevVPN app remains required; ScreenLink still has no VPN extension of its own. Continuous background operation still relies on the existing experimental PiP path.

## Fallback to the reported working route

Stop sharing, select Mac VPN, start receiver, copy the new viewer link, and run the existing Mac helper. Select ScreenLink VPN. Stop the helper before trying iPhone VPN again so advertisements for the same receiver identity do not compete.
