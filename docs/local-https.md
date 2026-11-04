# Local HTTPS transport checkpoint — build 36

Adds TLS on port 443 to the existing embedded server. HTTP on port 8080 is kept.
The TLS listener uses the same accepted socket and request handlers, preserving
actual client/source address checks, per-viewer tokens, explicit phone approval
and default-hidden capture. HTTPS approval requires the exact HTTPS origin and
Host for the configured hostname. Local loopback control remains local.

Identity files are not part of this repository or public Actions artifacts.
The listener expects `PrivateTLS/fullchain.pem` and `PrivateTLS/private.key` in
the app/broadcast bundle. It rejects absent/expired/mismatched identities or a
certificate that does not cover the configured hostname. TLS 1.2 minimum.

`tools/package_private_tls.py` is an optional private post-build step; sign the
complete resulting IPA afterward, preserving both extensions. This keeps private
keys out of public CI. The resulting personalized IPA contains a private key and
must be kept private. Certificate renewal requires repackaging this checkpoint.
Future work can replace packaging with a per-installation identity import flow.

Start the experimental alias VPN and system screen broadcast as in build 35.
Open `https://car.tesla4khmer.com/capabilities` on the hotspot client, then `/`.
A trusted HTTPS page and secureContext:true establish the prerequisites only.
The report includes VideoDecoder, AudioDecoder and example codec support. It
contains no viewer token, screen data or media. Approve the viewer on the phone
before media access. Do not ignore certificate warnings.

The existing YouTube player can select its existing WebCodecs path when browser
APIs are available; it retains its original fallback. The Maps player still uses
its existing decoder. This checkpoint does not add a WebSocket `/stream`, a new
Maps WebCodecs decoder, Service Worker registration, or guaranteed playback.
Legacy MJPEG streaming is available on HTTP; the HTTPS endpoint returns 501 for
that legacy multipart path because its old writer does not use TLS.

Validation: a real in-process client/server TLS handshake with a temporary test
identity checks hostname verification and encrypted request/response. Public CI
uses an ephemeral identity, not a private production key. iPhone binding to port
443, real hostname trust and browser API support require physical-device checks.
