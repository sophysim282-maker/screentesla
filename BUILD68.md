# ScreenLink build 68 comparison test

Version 0.20.31/build68 branches from preserved build67. Normal HTTPS /video and root show only a fullscreen canvas, connection status when disconnected, and a user-gesture sound/fullscreen prompt when needed. No browser car artwork or animation. Explicit /split and ?developer=1 retain technical controls and Maps. The direct HTTP fallback remains available for diagnosis.

Native Home has car-player Auto/720p/1080p, volume, Normal/Music EQ, play/pause, ±10s and seek. Choose/change videos in the YouTube app over the existing AirPlay session. Phone controls use small state/command messages; they do not encode video or start recording. The car may need one tap for browser sound/fullscreen permission.

MediaCast delivery, HLS parsing, CanvasPlayer decoding/rendering, Web Audio scheduler, PiP, VPN and widgets are unchanged. ViewerControls is separate metadata: settings persist across videos, playback commands are scoped to epoch plus source-command generation and acknowledged so old seeks cannot replay on reload. Only native/loopback app control can mutate controls; car reports remain authenticated.

Discovery error -65570 is now marked unhealthy; references rebuild on explicit Start/Refresh or foreground. Denied permission does not trigger an automatic retry loop; healthy references and all media/authorization state remain intact. This cannot override an iOS policy denial. User restored build67 visibility by enabling/opening local-network access; no AirPlay components were absent in64/65/66/67.

This is an interface/control comparison, not proof that the first physical HTTPS disconnect is fixed. Preserve build67, accepted64, original63 and ScreenLink3333. Compile on GitHub cloud Mac only; restore preexisting private HTTPS identity locally into final IPA, never into public source/artifacts.
