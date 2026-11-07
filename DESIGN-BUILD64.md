# ScreenLink 0.20.27 / build 64

Visual refresh of the original app from accepted build63 (3b1e19ecfd6e76f5e1c7b8dc69e248f79a6eee9a). Build63 and the independent ScreenLink3333 branch remain separate.

Light/dark glass home and car website; user-supplied car clip converted to a muted bundled home animation and a small decorative animated WebP for the website waiting state. The app releases decorative AVPlayer resources before sharing, when hidden/backgrounded, or for Reduce Motion. The browser switches to a static poster before actual YouTube playback and uses no HTML audio/video elements. Fullscreen preserves video-only display and exit.

Medium/large Home Screen controls, Lock Screen Resume PiP widget, and expanded Dynamic Island/Live Activity now expose explicit app-opening Start, Resume PiP, Open, Disconnect actions. Compact Island remains one app-opening target. No additional background execution is granted or claimed. Dog/cat/Roadster launcher kinds retained.

CanvasPlayer, audio scheduler, MediaCast, YouTubePiP, local VPN and packet tunnel implementations remain identical to accepted build63. Existing receiver web asset routing is extended only with static image resources. App identifier/scheme, three extensions, widget registration names, icon, personalized HTTPS delivery and Developer controls are retained. No screen-recording fallback.
