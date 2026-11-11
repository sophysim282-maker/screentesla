# Build 111 TEST (0.20.74): TikTok inside ScreenLink, no screen recording

The user asked for TikTok "in my app", explicitly without recording the screen. This is an
experiment on top of build 110; it may not work, and the user was told so.

How it is meant to work:
1. Home → Maps button (maps are closed) → "Open TikTok (test)". `Maps/TikTokBrowser.swift` shows
   TikTok's website in a WKWebView (mobile Safari user agent, AirPlay allowed, login kept by iOS).
2. The user plays a video and taps **Send to car** (calls `webkitShowPlaybackTargetPicker()` on the
   centred video) or the system AirPlay button (AVRoutePickerView) and picks "ScreenLink VPN Phone".
   iOS then hands the video's address to ScreenLink's own AirPlay receiver: the same `/play`
   hand-over YouTube uses, which already accepted http(s) addresses.
3. `App/MediaCast.m`: media state gets `kind` ("hls" for YouTube's mlhls / any .m3u8, otherwise
   "file"); a log line `MEDIA SOURCE: a web video from <host> …`; downloads for TikTok hosts only get
   Referer, the web view's user agent and the page's TikTok cookies from `SLMediaHeaders`
   (memory only). Every other host, including YouTube, is requested exactly as before.
4. Car page: `kind: "file"` selects the browser engine with `file:true`
   (`App/BrowserVideoPlayer.js` sets `video.src` instead of using hls.js) and draws to the same
   canvas. The phone already serves `/media/resource/…` with byte ranges.

Unknowns this build is meant to answer (watch the `TIKTOK TEST:` log lines):
- Does TikTok's page use a plain file (`file|…`) or a blob (`blob|…`)? A blob cannot be handed over.
- Does the page allow AirPlay, and does iOS offer "ScreenLink VPN Phone" from inside ScreenLink?
- Does TikTok's server accept the phone's download (else `MEDIA RESOURCE FAILED: HTTP 403 from …`)?
- Does the car play the file (`CAR PLAYER` lines; a file over 32 MB is refused by the download cap)?
- Each swipe is a new video; whether iOS re-hands each one is unknown.

Limits told to the user: swipe on the phone, not on the car; parked / passenger use.
Tested here: `tools/test_file_video.cjs` (car page plays a plain mp4 through the phone-style
resource address) and the existing car page tests. Nothing about the iPhone side could be run here.
Maps stay closed; build 110 content unchanged.
