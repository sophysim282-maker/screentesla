# Build 57: explicit no-recording YouTube PiP setup

Adds a Start YouTube + PiP button. It starts or preserves the app-owned receiver and remembers the user's PiP request even before a YouTube AirPlay media item exists. It never invokes ReplayKit or generates a dummy/placeholder video.

Sequence: press the PiP option in ScreenLink; wait for receiver startup; open YouTube and select ScreenLink VPN Phone through AirPlay; return once to ScreenLink. The existing local HLS item prepares a muted AVPlayer preview, and PiP is requested while ScreenLink is foregrounded. Wait for the actual PiP-start delegate acknowledgement before leaving again. Starting the ordinary YouTube-only option remains without PiP or recording.

The PiP controller/player are retained across a temporarily inactive media source instead of being deliberately reset between songs. Playback pauses while the source is missing and the next actual media epoch replaces the item. This does not promise that iOS will retain PiP when media ends. Stop sharing resets the pending request and player. No PiP is started without the dedicated user request; automatic-from-inline remains disabled.

The preview is muted and disallows external playback, retaining the existing mixing audio-session configuration. Preview quality preference remains at most 720p; Tesla's Auto selection remains capped at 1080p including SD. There is additional local video decoding; no claim of zero heat is made.

Apple's documented custom-player PiP path is actual video playback, with an audio playback background mode, PiP-supported/possible checks, and user initiation. A static status/dummy PiP is not offered as a reliable runtime exemption. Another app's PiP may prevent this one from starting. Real YouTube AirPlay/PiP coexistence, interruptions and long-run iPhone thermal/background behavior remain physical-device tests, not CI claims.

Retains build 56's response-body deadlines and build 55's session preservation/reconnection. Native compilation is required; source inspection alone does not validate actual PiP on iPhone. Missing widget signing/registration is unchanged. No guaranteed 30-minute runtime.
