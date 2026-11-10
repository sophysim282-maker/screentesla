# Handoff for the next Claude session (written 2026-11-10, after build 99)

Read this first. It replaces reading the old 400k-token conversation.

## The project
ScreenLink is an iPhone app (repo `sophysim282-maker/screentesla`, **public**). It receives
YouTube over AirPlay with no screen recording, and serves it to a car browser:
- Main address: `https://car.tesla4khmer.com/video` (WebCodecs + canvas player, Web Audio).
- The built-in VPN owns `3.3.3.3`. HTTP fallback: `http://3.3.3.3:8080` (HLS.js + hidden video).
- DNS: `car.tesla4khmer.com` has one A record `3.3.3.3`, TTL 86400. The domain was bought through
  Lovable; the name servers are name.com.
- Car: Tesla Model 3 Highland 2024 (1920x1200 screen), joined to the iPhone Personal Hotspot.
  Use case: a parked car, a TV, or the boss's rear-seat screen.
- Car Maps (from repo `sophysim282-maker/carmaps`) is merged into ScreenLink in `Maps/`.

## The user
- Not a developer. Wants simple English, short answers and action. Gets angry when asked to
  test the same thing twice, or when things are explained instead of fixed.
- Signs IPAs with **KravaSigner**, keeping the Widgets, LocalTunnel and Broadcast extensions.
- Sends logs from the app's "Copy test log". Read them carefully: the `CAR PLAYER:` lines come
  from the car page; `WEBSITE SILENT/BACK/STILL LOST` and `CAR LINK DETAIL` come from the phone.

## Rules (keep all of them)
1. Keep YouTube AirPlay with **no screen recording**.
2. Preserve video, audio, PiP, VPN, widgets, the Developer controls and the HTTP fallback.
3. Keep builds 64/67/68/69 available. Keep `variant/vpn-3-3-3-3` (ScreenLink3333) separate.
4. **A new branch for each build**: `release/buildNN-short-name`, with its own workflow
   `.github/workflows/<name>NN.yml` (copy the previous one; it triggers on a push to its own path).
5. Compile only through GitHub Actions (cloud Mac). Bump the version in `project.yml` (4 places),
   `tools/build.sh` (assert), `App/CanvasShell.js` + `App/CanvasShell.html` (build label), and add
   a top line in `App/main.m` (`Version 0.20.xx / build NN: …`; rename the old one to `Earlier build`).
   The Developer title reads the real version from Info.plist (fixed in 97).
6. **Never put the private HTTPS identity or the Google API key in GitHub, a commit, an artifact or
   chat.** The repo is public. The Google key lives only on the phone (UserDefaults `googleKey`,
   optional `carMapKey`) and reaches the car through the token-protected `/map/state`.
7. **Video stability (build 97 is the stable baseline, see `HANDOFF-BUILD97.md`).** Do not change
   these unless a car log shows a problem there: `App/CanvasPlayer.js`, the recovery logic in
   `App/CanvasShell.js`, `App/CanvasServiceWorker.js` and the late playlist answers in
   `App/MediaCast.m`.
8. I won't help evade the Tesla driving video lockout (parked or passenger use only).

## Build status
- **97 (0.20.60) is STABLE**: 20 minutes in the car with no loss. It contains 92–97:
  - VPN 3.3.3.3, local DNS TTL 1 day, keep-alive 10 min with idle eviction;
  - player retries for ~30 s through Wi-Fi blackouts; the car page never gives up;
  - late YouTube playlist answers are kept;
  - a rescue service worker shows the saved page instead of "server IP address could not be found";
  - quiet warnings while the video plays;
  - `WEBSITE STILL LOST` every 30 s with hotspot status; 1440p/4K test quality (Auto is default);
  - map no longer drops AirPlay (91).
- **98 (0.20.61) is SENT, NOT YET CAR-TESTED.** Branch `release/build98-car-map`, workflow `carmap98.yml`.
  - The car draws the Google map itself (Maps JavaScript API) from phone GPS + route
    (`mapOn`, `mapKey`, `routeLine`, `routeId` in the map state), so it works with ScreenLink in
    the background or the phone locked.
  - Car map ON/OFF switch on the phone's map screen.
  - The car reports `carmap ok/failed` and the phone logs `CAR MAP: …`. If Google refuses the key,
    the car falls back to the phone map pictures.
  - Needs Maps JavaScript API enabled and the website restriction `https://car.tesla4khmer.com/*`
    on the key. If the user's key is restricted to "iOS apps", a second website key is needed:
    add a UI field that saves `carMapKey`.
  - Test: `tools/test_car_map_js.cjs` (stubbed Google).
  - CI note: the `native` job uses `macos-15` (the Intel runner did not start on 2026-11-09).
    GitHub had "Internal server error" outages that day; just re-run with `gh workflow run`.

- **99 (0.20.62) is SENT, NOT YET CAR-TESTED.** Branch `release/build99-google-map`, workflow
  `googlemap99.yml`. Car map looks like Google Maps navigation (see `BUILD99.md`): 3D heading-up
  vector map, real day/night colours, traffic, route edge + red pin, glide, turn arrows, arrival card.
  Web-only change in the map section of `App/CanvasShell.js` / `.html`.
  - Watch in the car log / by eye: does the video stay smooth while the map moves? If not, lower
    the glide rate or remove the tilt. If the map is flat, Google gave a raster map (falls back
    to build 98 behaviour).
  - 98 and 99 can be car-tested together: 99 contains 98.

## Next ideas the user agreed with (not started)
- **Smart helper (non-developers):**
  - a big status light on Home (green / yellow / red, each with a one-tap fix);
  - a step-by-step start guide that ticks itself green;
  - simple-word notifications (extend `App/StreamNotifier.m`);
  - hide the Developer screen behind a long-press.
  - Do not touch video files.
- Possible later: "one connection like TeslaMirror" (all car traffic over the existing WebSocket),
  so the car never needs new name lookups. Big change; only as a separate test branch.

## Making a ready-to-sign IPA (how every build is delivered)
1. Wait for the run: `gh run list --repo sophysim282-maker/screentesla --branch <branch>`, then
   `gh run watch <id> --exit-status` (in the background).
2. Download: `gh run download <id> -n ScreenLink-buildNN-RAW-NOT-FOR-INSTALL -D <new empty dir>`.
   If a storage host is blocked, the session's environment allows `productionresultssa0…39.blob.core.windows.net`.
3. The HTTPS identity is **not** in GitHub. **Ask the user to attach their build 69 IPA.** Extract
   `Payload/*.app/PrivateTLS/fullchain.pem` and `private.key` into a private temp folder (chmod 600,
   never print them).
4. Package:
   `SCREENLINK_TLS_FULLCHAIN="$(cat <dir>/fullchain.pem)" SCREENLINK_TLS_KEY="$(cat <dir>/private.key)" python3 -I tools/add_identity_ci.py <raw.ipa> <scratchpad>/ScreenLink-<ver>-buildNN-HTTPS-unsigned.ipa`
   (the certificate is valid until 1 Feb 2027).
5. Check the version inside the IPA (Info.plist), chmod 600, and send it with SendUserFile.
   Explain the changes and test steps in simple English.
