# Local alias playback experiment — 0.19.2 / build 34

The actual parked Tesla displayed the build 33 probe response at
240.3.3.3:8080, identifying phone endpoint 240.3.3.3 and client 172.20.10.2.
The hotspot-address probe at 172.20.10.1:8080 returned ERR_CONNECTION_REFUSED.
The user reconfirmed alias success. Do not ask for those probes again.
The route-status query returned no provider response; counters are unknown.
These results establish one HTTP/TCP request and response, not UDP, WebRTC,
HTTPS, media playback or a diagnosis of the earlier ICE failure.

This change reuses the existing split viewer, HTTP HLS and H.264 screen paths
on the owned alias. It does not change the receiver, capture encoder, normal
VPN, website WebRTC flow, public service or public deployment. No relay or
new cost. It is an HTTP experiment, not the requested eventual certified HTTPS
entry point. Browser codec capabilities can differ on HTTP; the existing HLS
compatibility decoder is retained. No certificate bypass is introduced.

Alias access requires the current hotspot subnet and actual phone alias ownership.
Opening the alias root serves only an approval page. Connect phone requests a
single bounded, 120-second pending session. The main app's new Approve / Reject
local viewer buttons operate through loopback-only app control. Approval is tied
to the current request ID, client address and random browser nonce. Only the same
client/nonce receives a new in-memory viewer token after phone approval; an old
global viewer token cannot bypass the alias gate. Media playlist/state response
copies use that approved token; the original MediaCast token is unchanged.
Disconnect local viewer revokes that token and hides capture. Stopping the
broadcast destroys the gate. Approved sessions expire after four hours.
Normal website phone approval and default-hidden Show/Hide behavior remain.

## Only after an iOS build succeeds and the complete IPA is correctly signed

1. Install build 34 retaining both embedded extensions. Build 33 remains the backup.
2. Start Experimental virtual-IP probe and the system ScreenLink Screen broadcast,
   as in the already successful route test. Stay parked and on the iPhone hotspot.
3. In Tesla open http://240.3.3.3:8080/ (no /local-route-probe).
4. Tap Connect phone in Tesla. Return to the ScreenLink main screen on iPhone and
   tap Approve local viewer. No website session or numeric code is required.
5. Open YouTube on iPhone and choose ScreenLink VPN Phone via AirPlay. In Tesla
   tap Play with sound. Observe whether video actually moves and sound plays.
6. Open Maps on iPhone, then Show phone screen in Tesla. Before switching apps,
   Hide phone screen and wait for its acknowledgement.
7. Report the first failing step and exact player text; copy the phone test log.
   No Tesla playback success is claimed until this physical test is reported.

If the approval screen opens but media fails, retain the route result and diagnose
that downstream failure; do not restart route probing. Disconnect local viewer
or Stop sharing revokes access. Local HTTP is not end-to-end TLS encryption.

## Validation in the continuation workspace

- Native macOS approval tests pass: token withheld before approval, nonce/client
  binding, stale decision rejection, expiry, reject and disconnect revocation.
- Media state/HLS response retokening and unchanged binary media tests pass.
- Existing native screen privacy and route-probe boundary tests pass.
- Browser tests are added to hosted CI. Local headless Chrome could not launch
  under this workspace's restrictions; no local browser pass is claimed.
- Full Xcode/iPhoneOS SDK is absent here. iOS build, embedded extension packaging
  and physical Tesla playback must still be verified.

## 0.19.3 / build 35: approval header correction

The build 34 Mac test loaded the local viewer but Connect phone displayed
"Local connection interrupted"; phone approval remained idle. The provided log
contained expiration of the separate website signaling session, which is not the
local HTTP approval path. Source inspection found a deterministic bug: the
20-character header prefix `x-screenlink-viewer:` was extracted at offset 19,
leaving `: request` instead of `request` and rejecting valid requests with 403.
This explains a valid client's rejection; the user's generic message alone did
not record its actual HTTP status.

Build 35 derives the header boundary from the full name in a shared production
parser, tested with exact browser-style headers and malformed variants. It keeps
the existing origin, owned-alias/hotspot, phone approval, and token checks.
Browser errors now display HTTP status or timeout; server rejections log only
boolean boundary results, never tokens or nonce values. Native media/capture,
VPN routes and website signaling are unchanged. Test local approval on the Mac
at home before any additional car visit. This is an approval fix, not verified
Tesla playback.
