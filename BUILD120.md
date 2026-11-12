# Build 120 (0.20.83) - TikTok stays inside ScreenLink

User on 119: TikTok still opens outside the app.

## Change
`Maps/TikTokBrowser.swift`, `decidePolicyFor`: every allowed navigation is answered with
`WKNavigationActionPolicy(rawValue: allow + 2)` ("allow, but do not hand to another app"), instead of
only re-loading tapped links. Page-driven jumps to tiktok.com (universal links) were the gap.
Other schemes, onelink.me, app.link and the App Store are still cancelled as before.

## Not proven
Not tested on an iPhone. If it still leaves the app, the log line "TIKTOK TEST: stopped a jump" /
"TIKTOK: page moved to" before the jump shows which address did it.
