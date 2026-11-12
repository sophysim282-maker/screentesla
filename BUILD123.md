# Build 123 (0.20.86) - TikTok auto scroll: more ways + proof

User on 122: Auto ON but no auto scroll (For You and Following); For You shows only 2 videos.
tiktok.com is not reachable from the build sandbox, so the page could not be inspected here.

## Changes (`Maps/TikTokBrowser.swift` only)
- `S.next` verifies movement (`S.key()` = src tail + position + index of the centre video) and escalates:
  scrollIntoView/scrollBy -> next button + ArrowDown -> synthetic swipe (PointerEvent + TouchEvent + wheel).
  `S.lastMove` holds what worked or `NOTHING MOVED THE PAGE (reasons)`.
- `S.describe()` -> `TIKTOK PAGE (...)` log lines: video count, doc height, each video (top/height/kind/loop),
  the ancestor chain of the centre video (overflow, transform, scroll-snap, sizes), data-e2e names,
  dialogs on top, what the nag remover hid. Written after page load, Auto toggle, Send to car, failed move.
- Helper is versioned (`v:123`) so an open page gets the new copy.

## Next
The user's log decides: if only one <video> exists and nothing moves it, the feed needs real touches
(not possible from page script) or another approach. "Only 2 videos in For You" should show as a
dialog on top or as an element ScreenLink hid.
