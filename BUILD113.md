# Build 113 TEST (0.20.76): TikTok without "Open app" asking, with auto scroll

User on build 112: "it still asks to open the app; fix it and make it have auto scroll".

Maps/TikTokBrowser.swift only. A small helper script runs inside the TikTok page (installed as a
user script and re-applied every 2 s because TikTok changes pages without reloading):
- "Open app" asking: every 0.4 s it presses "Not now" / "Maybe later" / "Continue on web" style
  buttons, but only inside a box whose text talks about opening or getting the app, and hides small
  buttons whose whole text is "Open app", "Open TikTok", "Get app" and similar. Text matching, so a
  TikTok redesign or another language can get past it.
- Auto scroll (button "Auto off / Auto ON" in the top bar, remembered in UserDefaults
  `tiktokAuto`): watches the video in the middle of the screen; when its time reaches the end,
  jumps back to the start (TikTok loops videos), or it has been on screen longer than its length
  plus 4 s, it scrolls the feed by one screen. Log: `TIKTOK TEST: auto scroll moved to the next video`.
- Unknown until tested: whether iOS hands each next video to the car by itself after the scroll,
  and whether the page's video clock keeps running while the video plays on the car.
No change to MediaCast, the car page or YouTube.
