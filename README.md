# ScreenLink AirPlay Lab — experimental iPhone app

Goal: on ONE iPhone, choose ScreenLink in Control Center → Screen Mirroring, then deliver the received video to another device's browser over the iPhone hotspot.

**This goal has not been demonstrated. This archive is a real receiver prototype for testing the blocking assumptions, not a working or verified replacement for APTV.** The unsigned iOS device build passed on GitHub's Mac runner: https://github.com/sophysim282-maker/screentesla/actions/runs/41287018360 . A physical-iPhone test has NOT been performed. Successful compilation does not establish that same-phone AirPlay works.

## Implemented in source

- Native UIKit interface with start/stop, local browser links, and copyable test logs.
- Vendored RPiPlay AirPlay protocol core: Bonjour advertisements, RTSP, pairing, encrypted mirror-stream handling.
- H.264 Annex B parsing and VideoToolbox decode into JPEG snapshots.
- A local token-protected browser viewer at port 8080, up to 10 frames per second, video only.
- Status messages distinguish listener startup, control connections, decoder configuration, and actual decoded video frames.
- Bounded incoming-video queue, HTTP request limits and socket timeouts, stop clears frames.
- Brief standard background-task grace only. There is NO sustained background workaround.

## Not established or implemented

- iOS discovering its own advertised receiver on the same iPhone.
- A same-phone AirPlay handshake and actual video delivery.
- Compatibility of this older receiver core with your current iOS version.
- Continuous operation while other apps are foreground; iOS can suspend this app.
- Personal Hotspot allowing the other device to reach port 8080.
- Audio forwarding, VPN routing, a VPN extension, or a signed IPA. The cloud build produces an UNSIGNED IPA that needs device signing.
- No captured-screen fallback: this app does not use ReplayKit.

## Free build routes

### Mac with full Xcode

1. Install full Xcode and accept its license. Xcode is free; this does not require buying Apple Developer Program membership.
2. Install Homebrew prerequisites: `brew install xcodegen autoconf automake libtool`.
3. In this folder run `bash tools/build.sh`. This fetches and cross-compiles OpenSSL and libplist and generates the Xcode project with XcodeGen.
4. If the build succeeds, open `ScreenLinkAirPlayLab.xcodeproj` in Xcode.
5. In Signing & Capabilities select your free Personal Team and a unique bundle identifier, connect your iPhone, and run.
6. Enable Developer Mode on the iPhone if Xcode asks. Standard free profiles expire after seven days and must be renewed.

This project intentionally requests no Network Extension, App Groups, or paid capability. That does not guarantee free signing or runtime success on your specific setup.

### No Xcode on your own computer

The included `.github/workflows/build.yml` can build an UNSIGNED IPA on a GitHub Mac runner. Upload the contents of this folder to the root of a repository you control; then Actions → Build unsigned iPhone AirPlay lab → Run workflow. GitHub runner availability and charges depend on your account/repository; check your allowance before running it. The workflow also runs when main is updated. Check the Actions tab for the actual build result.

A successful cloud build is NOT an installation. An unsigned IPA still needs valid device signing. An existing compatible free sideloading setup could sign it with your Apple account, with its normal expiry and extension limits. Do not purchase a certificate on the assumption this experimental design works.

## Physical-device test — do these in order

1. Enable Personal Hotspot and connect the viewing device.
2. Launch ScreenLink Lab; tap Start receiver. Allow Local Network access.
3. Open Control Center → Screen Mirroring. Does ScreenLink appear? Copy the app log either way. A published Bonjour name is NOT proof that iOS discovered it.
4. If present, select ScreenLink. A control connection is NOT proof that video works. Look for `Actual video received` in the app log.
5. Tap Show browser links. On the other device open the complete link including `?token=...`. If several interface addresses are shown, test the hotspot bridge first. Do not assume a fixed hotspot IP.
6. Confirm the browser shows actual changing screen content, not just the waiting page.
7. Leave the app for another app. Check whether frames continue. Expect that iOS may suspend the receiver after a short background grace period. That result means the complete requested app is NOT working yet.
8. Stop sharing when finished. The link token changes the next time you start.

If test 3 fails, do not assume that changing the advertised name or toggling a generic VPN will fix it. The receiver discovery/routing design needs further investigation. A custom packet-tunnel extension requires Apple's Network Extension entitlement, unavailable to free Personal Team signing. Another VPN app does not lend its entitlement to this app.

## Validation performed here

- Portable Annex B parser compiled with warnings as errors and AddressSanitizer/UndefinedBehaviorSanitizer; range, mixed start-code, truncated-input and capacity tests passed (LeakSanitizer disabled because of container restrictions).
- Build script shell syntax checked.
- XcodeGen configuration parsed as YAML and receiver webpage JavaScript syntax checked.
- GitHub macOS runner successfully cross-compiled dependencies, compiled the Objective-C/C app, linked it for arm64 iPhone, and packaged an unsigned IPA. Initial Linux-specific TCP options and macOS-only Bonjour linkage were corrected.
- Device signing, AirPlay discovery, same-phone pairing, live decoding, sustained background reception and hotspot browser streaming remain untested.

## Sources and licenses

The build fetches the receiver library from https://github.com/FD-/RPiPlay at commit 64d0341ed3bef098c940c9ed0675948870a271f9 (the upstream project is GPL-3.0; subcomponents retain their own notices). See LICENSE and the downloaded Vendor/RPiPlay/LICENSE. tools/prepare_receiver.py fetches the pinned revision and applies the DNS error-handling change. Source modifications: dnssd.c now returns immediate DNSServiceRegister errors; raop_rtp_mirror.c maps Linux TCP keepalive option names to Darwin equivalents. The application advertises the actual control-listener port for both AirPlay and RAOP. It does not copy APTV's code or claim to reproduce its undocumented internals.

OpenSSL 1.1.1w and libplist 2.2.0 are fetched at build time; their licenses remain applicable. This uses an older protocol core and dependencies for an isolated feasibility test, not a production release. No dependency security audit was performed.
