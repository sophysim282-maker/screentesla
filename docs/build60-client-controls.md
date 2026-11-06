# ScreenLink 0.20.23 / build 60

Base: original repository feature/youtube-airplay-010 at
49f0ebf4a868d4bdfe43cfb143306a894fb2e65c (verified personalized build 59).
Build 59's media/discovery/HTTPS behavior is retained.

The default UIKit home offers Start YouTube + PiP, Disconnect All, website link,
clear setup/status text and a Developer entry. The original technical stack,
diagnostics, Maps broadcast, quality/discovery controls and previews remain
available in Developer, with a Home button. The same real preview layer moves
between home and developer containers so it remains eligible for PiP preparation.

Disconnect All suppresses automatic resume before stopping sources. Generation
checks cover outstanding setup, alias transition, viewer decisions and polling.
The own broadcast listener receives its stop command and is polled to confirm
closure; a request acknowledgement alone is not called a completed stop. The
VPN implementation reloads saved managers, stops only those matching the actual
embedded tunnel provider identifier and retains saved configurations. It waits
for a quiet disconnected interval, cancels stale setup/alias retries and stops
late Connected notifications while an explicit stop is still requested.
Unconfirmed broadcast/VPN teardown is shown as needing attention, not connected
or successfully disconnected. Returning to the app does not override a manual
disconnect; an explicit Start is required.

The existing project already had real WidgetKit Home Screen widgets as well as
a separate Live Activity. Build 60 adds ScreenLink Controls as the first widget:
small opens home controls; medium includes Start + PiP and Disconnect All links.
Privileged work runs after opening the app, with normal system consent. No App
Group entitlement is introduced. Widget extension identifiers and the other
existing launcher widgets/Live Activity are retained. Packaging validates
WidgetKit registration metadata, executable, route strings and parent prefixes.
An iOS simulator harness attempts gallery inspection; this is not a claim about
widget visibility after third-party signing on a physical iPhone.

Original icon/cover artwork is drawn from vector primitives in GitHub's Mac
runner. No external assets, Tesla logo, extra runtime library or placeholder
PiP media is introduced. The icon is opaque and supplied in all catalog sizes.
Dashboard screenshots use the same production UIKit view in an isolated simulator
harness, with fixture statuses explicitly identified in the preview README.

Required cloud checks: asynchronous teardown sequencing and stale completions,
VPN ownership/cancellation, widget route validation, simulator dashboard controls,
light/dark/large-text/landscape snapshots, gallery attempt, the existing native
discovery/HLS tests, actual 1080p video recovery with continuous audio, both
browser suites and full unsigned iOS packaging. Website cache/build labels are
updated to 60. Device gallery visibility, signing acceptance and background
endurance still require the user's phone.

Delivery remains a separate private HTTPS packaging workflow. Restore the exact
trusted identity from the private working-build57 IPA; check build/version, all
extensions, unchanged non-TLS payload, public trust/hostname/key/expiry and the
actual app TLS context with the identity extracted from the final IPA. A public
GENERIC-NO-HTTPS artifact is never a ready personalized download.
