# Build 121 (0.20.84) - lighter 4K

User: some 4K videos freeze; the sound keeps playing while the picture stops (so not the internet).

## Changes
- `App/CanvasPlayer.js` `paint()`: frames above 1440p are drawn to a canvas of screen size
  (at least 1920x1080, canvas client size x devicePixelRatio), not 3840x2160. `sourceWidth/Height` keep
  the real size. Frames up to 1440p take the old path unchanged. (Rule 7: changed on the user's report,
  not on a car log; the summary line below is there to prove or disprove it.)
- `App/CanvasShell.js`: summary line shows real size + "painted at", paint ms, screen step ms, unpack
  waits, and LIKELY CAR TOO SLOW / LIKELY INTERNET TOO SLOW.

## Already there (not new)
Late pictures are skipped at paint time, and a decoder that falls 1.5 s behind is restarted at the
next key picture. So "skip instead of freeze" needed no new code.

## Not proven
If the car is slow at unpacking (decoding) 4K rather than painting it, this helps little; the summary
line of the next 4K test will show it.
