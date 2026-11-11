# Build 112 TEST (0.20.75): TikTok stays inside ScreenLink

User's report on build 111: "it have 2 video it work" (TikTok videos reached the car through the
AirPlay hand-over), but (1) Gmail login did not work and (2) tapping things jumped to the TikTok app.

Maps/TikTokBrowser.swift only:
- `decidePolicyFor`: cancels every navigation that would leave the app (non-web schemes such as
  tiktok:// snssdk:// itms-apps://, onelink.me, app.link, App Store). A tapped main-frame link is
  cancelled and loaded programmatically, so iOS does not treat it as a universal link into the
  TikTok app. Log: `TIKTOK TEST: stopped a jump out of ScreenLink`.
- `WKUIDelegate`: a window the page opens (sign-in buttons use window.open) is shown as a second web
  view on top, created with the configuration WebKit passes in so the opener link works, with a
  "Close sign-in window" button; `webViewDidClose` removes it. Before, such windows were ignored,
  which is one reason sign-in did nothing.
- Google sign-in: Google deliberately refuses to sign in inside app web views. Nothing was added to
  get around that. If Google refuses, the user should sign in to TikTok with email / username and
  password (set a password in the TikTok app first).
- No change to MediaCast, the car page or YouTube.
Open questions for the user's next log: does every swipe hand over the next video; how long between
videos; any `MEDIA RESOURCE FAILED` from TikTok hosts.
