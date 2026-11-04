ScreenLink 0.20.13 / build 50 — native iPhone widgets

Home Screen: long-press → Edit → Add Widget → ScreenLink. Choose Dog, Cat or Roadster, small or medium. Tap Start YouTube. The shortcut opens ScreenLink and starts/resumes the existing YouTube-only receiver. Enable Personal Hotspot first. iOS VPN setup may require confirmation on first use. YouTube may require selecting ScreenLink in AirPlay.

The launcher is static and never claims live connection state. A separate local ActivityKit Live Activity shows READY / PLAYING / Return to ScreenLink with an elapsed timer. Dynamic Island shows a Roadster and YT; expanded view includes dog/cat/Roadster. Short transitions occur on real state changes. No continuous pet animation, push server, App Group, new recording, or background animation timer is used. Status becomes stale after 90 seconds without a heartbeat and asks to open ScreenLink rather than claiming playback continues.

Widget tap preserves a healthy receiver and its viewer token. Explicit Stop sharing disables automatic resume and removes the Live Activity. A late async start callback remains guarded by the existing generation counter.

The background task is labelled ScreenLink · YouTube. Its existing 30-minute ceiling and iOS cancellation remain unchanged; a widget cannot grant unlimited runtime. Apple's task UI is separate from the custom Live Activity.

Installation must preserve the ScreenLinkWidgets.appex extension. Widget visibility, Live Activity permissions, and Dynamic Island rendering require a physical iPhone check after sideloading. No physical result is claimed by CI.

Video, AAC/audio scheduling and Maps transport are unchanged. Viewer build identifiers/cache version are updated only to identify this package.
