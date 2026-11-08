# ScreenLink build 83 — stable keep-alive

Phone log (build 81): `Failed to fetch … after 1 failed checks` about every 5 s while the phone was
running, and some video pieces failed five times in a row (`Phone/media transport unavailable after
retries`). With keep-alive the phone closed idle connections after 10 s (build 82: 5 s); the browser
sometimes reused one just as it closed. Also: locking the iPhone stops PiP and iOS suspends ScreenLink,
so the website stops — keep the phone unlocked (Auto-Lock: Never) while watching.

Build 83: idle website connections stay open up to 2 minutes (1000 requests), and the car retries a
failed check once immediately before counting it. Includes builds 76–82.
