# Build 97 (0.20.60)

Continues build 96. The user saw the car's "server IP address could not be found" page: the car
reloaded the website while its name lookup failed, and no page code could run to reconnect.

- App/CanvasServiceWorker.js (/sw.js) now keeps a rescue copy of the car page and its /app/
  scripts. Network first: the phone's page is always used when reachable. Only when the page
  cannot be fetched at all is the saved copy shown; its code then reconnects automatically
  (autoConnect every 3 s, backup button after 20 s).
- Requests with a token (API, media, map) are never cached or answered by the worker.
- The old build 64 offline cache (screenlink-canvas-ui-*) is still deleted.
- tools/test_rescue_page.cjs: online reload uses the phone page, unreachable reload shows the
  saved page and runs its script, API never cached, saved copy follows the newest page.
- The car must open the website once while connected, so the copy is saved.
