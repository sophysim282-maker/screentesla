# Handoff for the next Claude session (written 2026-11-10, after build 104)

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
6a. **China-version Tesla: the car page must not load anything from Google** (no script, tile,
   font or preconnect). Everything the car shows comes from the phone.
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

- **99 (0.20.62) built, never sent alone (it is inside 100).** Branch `release/build99-google-map`, workflow
  `googlemap99.yml`. Car map looks like Google Maps navigation (see `BUILD99.md`): 3D heading-up
  vector map, real day/night colours, traffic, route edge + red pin, glide, turn arrows, arrival card.
  Web-only change in the map section of `App/CanvasShell.js` / `.html`.
  - Watch in the car log / by eye: does the video stay smooth while the map moves? If not, lower
    the glide rate or remove the tilt. If the map is flat, Google gave a raster map (falls back
    to build 98 behaviour).
  - 98 and 99 can be car-tested together: 99 contains 98.

- **100 (0.20.63) is SENT, NOT YET CAR-TESTED.** Branch `release/build100-car-map-touch`, workflow
  `carmaptouch100.yml`. Contains 98 + 99. See `BUILD100.md`: big car map touched directly, car
  search with suggestions, tap a place name (`poi`), place card with routes and Start (`gostart`),
  Re-centre, Exit, traffic refresh every 2 minutes. Build 99 was never sent on its own.
  - The user asked for lane guidance "like Google Maps": not possible with public Google web APIs
    (told the user). Do not fake it.
  - Things only the car can show: touch feel, Tesla keyboard on the search box, video smoothness
    while the map moves, whether Google gives the vector (3D) map.

- **101 (0.20.64) is SENT, NOT YET CAR-TESTED.** Branch `release/build101-car-map-key`, workflow
  `carmapkey101.yml`. Contains 98–100. The user said the car map closes when they leave the app.
  Suspected (not proven, no log): Google refuses the key on the car website. 101 adds the phone
  status line + "Tap to fix" sheet that saves `carMapKey` (see `BUILD101.md`).
  - If the phone shows the green "Car draws the map ✓" line and the map still closes in the
    background, the cause is different: look at whether iOS suspends the app (no AirPlay/PiP and
    no GPS running) and at the `/map/state` answers.

- **102 (0.20.65) is SENT, NOT YET CAR-TESTED.** Branch `release/build102-start-timing`, workflow
  `starttiming102.yml`. Contains 98–101 + a `CAR PLAYER: start took …` log line (see `BUILD102.md`).
  - User's build 100 car test: connection no longer lost; first video slow to start (13 s), later
    ones about 3 s. Do not change the player before a log with the new line shows the slow step.
  - In that test the map question (does it keep running after leaving the app) was not answered;
    no `CAR MAP:` line was in the log part they sent.

- **103 (0.20.66) is SENT, NOT TESTED WITH A CUBE.** Branch `release/build103-orbit-cube`, workflow
  `orbitcube103.yml`. Contains 98–102 + "Orbit Cube (Bluetooth)" switch in Maps Settings: next
  turn, metres, minutes, road name over BLE (see `BUILD103.md`, `Maps/CubeLink.swift`).
  - The user wants a simple road line on the cube too. That needs the cube maker to add a
    characteristic; a packet proposal was given to the user. Wait for their UUID.
  - **Rule from the user: answer first and ask before building anything new.**

- **104 (0.20.67) is SENT, NOT YET CAR-TESTED.** Branch `release/build104-phone-map`, workflow
  `phonemap104.yml`. Contains 98–103. **The user's Tesla is a China version: its browser blocks
  Google. The car page must never contact Google** (see `BUILD104.md`). Map = pictures from the
  phone; `carGoogle` switch (off) keeps the Google-drawn map for other cars.
  - If the map still closes after leaving the app: the phone map screen shows an orange button
    with Google's answer for the Static-map picture (most likely Maps Static API is not enabled).
  - Cube (BLE): first test said "no navigation channel" → characteristic …0F13 missing on the
    cube. 104 lists the characteristics the cube offers; pass that to the cube maker.

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
