# ScreenLink build 72 — import the website certificate once

Version 0.20.35 / build 72 = build 71 (browser video player on the car website, build 70
diagnostics) + a one-time website certificate import.

Why: the cloud IPA never contains the private HTTPS identity. Installing it without adding the
identity made https://car.tesla4khmer.com fail ("Connection needs attention") while 240.3.3.3 worked.

Use: ScreenLink → Developer → **Import website certificate** → pick the earlier ScreenLink IPA
where the website worked (or the certificate + private key files together). The app checks it is
for car.tesla4khmer.com, not expired, and that the key matches, then keeps it in its own storage
(not backed up, not uploaded). A running session starts HTTPS at once. Updates keep app data, so
later builds work without adding the identity. An identity inside the IPA still takes priority.

The Maps screen-broadcast extension cannot read the app's storage (no App Group); it still needs the
identity inside the IPA for HTTPS. YouTube-only mode runs in the app and uses the imported one.
