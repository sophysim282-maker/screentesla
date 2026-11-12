# Handoff for the next Claude session (written 2026-11-10, after build 115)

Read this first. It replaces reading the old 400k-token conversation.

## WHERE WE ARE NOW (read this part first)

- **Build 121 (0.20.84), branch `release/build121-lighter-4k`:** 4K painted at screen size + car speed in the summary line. Waiting for a 4K car log. See BUILD121.md.

- **Build 120 (0.20.83), branch `release/build120-tiktok-stay`:** TikTok navigations use the allow-without-app-links policy. See BUILD120.md.

- **Build 119 (0.20.82), branch `release/build119-keep-playing`:** Keep playing switch (ignore sender pause/stop) + `AIRPLAY SOUND ARRIVING` log. Telegram sound itself not fixed yet; waiting for the user's log. See BUILD119.md.

- **Build 118 (0.20.81), branch `release/build118-unstick-downloads`:** retry stuck downloads + `MEDIA PIECE …` log lines. Waiting for the user's car log. See BUILD118.md.

- **Build 117 (0.20.80), branch `release/build117-entrance`: cinematic entrance.** The four car pictures are NOT in the repo; add them to the IPA at packaging as `Payload/<app>/entrance-1..4.jpg` (see BUILD117.md).

- **Build 116 (0.20.79), branch `release/build116-new-home`: new dark Home screen** (status under the name, big picture, round quick buttons, list). See BUILD116.md. Waiting for the user's opinion.
Latest build sent: **115 (0.20.78)**, branch `release/build115-waiting-screen` (`BUILD115.md`): the
user's own pictures / GIFs / videos as the car's waiting screen, with transitions.
Before: **114 (0.20.77)**, branch `release/build114-fast-start` (`BUILD114.md`): phone
warm-up of the two needed YouTube lists and the first pieces, 0.4 s idle polling, smart first quality.
Before: **113 TEST (0.20.76)**, branch `release/build113-tiktok-auto` (`BUILD113.md`): hides the
"Open app" asking and adds auto scroll in the TikTok page.
Before: **112 TEST (0.20.75)**, branch `release/build112-tiktok-stay` (`BUILD112.md`): TikTok page
stays in the app and shows sign-in windows. **The user confirmed build 111's TikTok hand-over works
("2 videos worked").** Do not add anything to get around Google's refusal to sign in inside apps.
Before: **111 TEST (0.20.74)**, branch `release/build111-tiktok-test`: TikTok inside the app
without screen recording (`BUILD111.md`). An experiment; read the `TIKTOK TEST:` log lines.
The user refuses screen recording / mirroring for TikTok.
Latest stability build sent to the user: **110 (0.20.73)**, branch `release/build110-awake-proof`
(`BUILD110.md`): heartbeat that proves iOS pausing the app + silent-sound keep-alive + listener
priority; removes 109's 4 s deadline and page reload. **The map-steals-connections theory was
wrong for the main failure: build 109 (maps closed, fast internet) still lost the phone for up to
31 s.** Current suspect: iOS pauses/slows the app in the background without PiP.
Before that: **109 (0.20.72)**, branch `release/build109-stable-video`
(108 + auto quality step-down on "Auto", 4 s request deadline, page self-restart; `BUILD109.md`).
108 was also sent. **108 (0.20.71)**, branch `release/build108-maps-closed`:
**all map systems closed at the user's request** (`BUILD108.md`; `MAPS_CLOSED` in CanvasShell.js,
`showMaps` in main.m). The Orbit Cube switch is unreachable while maps are closed.
Before that: **107 (0.20.70)**, branch `release/build107-video-first`
(107 = 106 + "video first" map budget + proof facts in the car summary line, `BUILD107.md`;
made after two build 106 logs with picture freezes and "6 connections open").
Before that: **106 (0.20.69)**, branch `release/build106-stability`
(same commits on `claude/build-98-car-map-handoff-tlhw9w`). 106 = 105 + status light,
background self-repair, retry when the phone internet returns (`BUILD106.md`). The user tested
105 in the car: **it keeps working with no PiP** (keep-awake confirmed). The user wants to keep
the 4K / 1440p quality choices: do not remove them. 98–104 are inside 106 or replaced.

What the user has said, in order of importance:
1. **Ask before building.** "I ask first and tell me before build." Explain the plan in simple
   English, wait for "go". A bare "continue" is not a clear go: confirm in one line.
2. **The Tesla is a China version. Its browser blocks Google** (google.com/maps does not open).
   The car page must talk only to the phone.
3. The video link itself is good now ("never loses connection"). Tesla cannot play the 4K test
   quality; use Auto / 1080p.
4. The map is the big complaint: slow, bad touch, turn stays on screen after turning, no lanes,
   "not like Google Maps". Build 104's picture map was called unusable.
5. "The road it gives is bad": still unclear whether the chosen route is wrong or only the line
   looked bad. Asked for one example (start, destination, what was wrong). No answer yet.

What 105 changes (see `BUILD105.md`):
- Keep-awake without PiP (low-accuracy background location, blue mark). Log: `KEEP AWAKE ON`.
- Car draws the map from squares the phone fetches (Google Map Tiles API) at `/map/tile/z/x/y`.
  **The user must enable "Map Tiles API" on the Google key**; otherwise the car falls back to
  slow pictures and the phone shows an orange "Car map is slow · Tap to fix" button.
- Turn guidance follows the car along the route line (fixes "already turned, still shows turn").
- Squares are kept only as long as Google's Cache-Control allows (Map Tiles policy).

Waiting on the user:
- Car test of 105 + "Copy test log" (look for `KEEP AWAKE`, `CAR MAP`, `CAR PLAYER: start took`).
- One example of a bad route.

Orbit Cube (third person, through the user), Bluetooth LE, `Maps/CubeLink.swift`:
- App is central; writes the turn packet to characteristic …0F13 (see `BUILD103.md`).
- First test said "no navigation channel". Cube maker says firmware v18+ has …0F11 command,
  …0F12 status, …0F13 navigation, **…0F14 road line**, and that iOS cached the old list. User
  was told: forget the device, restart the phone, read the status line (104+ discovers all
  characteristics and lists what it gets).
- Asked the cube maker to confirm the road-line packet for …0F14 (proposal: byte0 version 1,
  byte1 N points 2–16, then N × int8 x,y; car at 0,0, forward up, 1 unit = 3 m; ≤ 1 per second)
  and to send the GATT Service Changed indication after firmware updates.
- Road line is NOT built. Ask the user before building it.
- **Cube maker's answer (2026-11-11), confirmed format for …0F14 (road line):** byte 0 = 1;
  byte 1 = N (2–16); then N points, x then y, signed 8-bit; car at 0,0; forward is up (+y);
  +x is right; 1 unit = 3 m; length must be exactly 2 + 2N or it is ignored; write with
  response; at most once per second, at least every 4 s while navigating (cube hides the line
  after 5 s); maneuver code 0 on …0F13 also clears the line; the cube scales the line to fit, so
  the full −128..127 range may be used and points behind the car (negative y) are allowed.
- Cube firmware v23 sends GATT Service Changed after a firmware update; they ask the app to
  handle `peripheral(_:didModifyServices:)` by discovering the service and characteristics again.
- **Proposed build 106 (told the user, waiting for "go"):** road line sender on …0F14 (route
  ahead of the car, about 350 m, heading-up, ≤ 16 points, once per second) + didModifyServices.
  Nothing else to be touched.
- Still wanted from the user: the cube status line after "forget device + restart"
  ("Cube connected ✓" or "It offers: …").
- An earlier Wi-Fi picture sender for the cube was removed (never approved).

Research done for the user (told them, nothing built):
- Good navigation apps: map matching, dead reckoning between GPS fixes, glide, progress along
  the route, adaptive off-route checks, honest "weak signal" state.
- Lane guidance IS available to apps, just not from the Google Routes API we use: Google
  Navigation SDK for iOS (draws on the phone; ~0.05 USD per destination after 1,000 free a
  month), TomTom routing (`sectionType=lanes`), Mapbox directions. Earlier statement to the user
  that lanes were impossible was corrected.
- Suggested order after 105: (1) dead reckoning so the arrow is not ~1 s late, (2) smarter
  off-route check, (3) lane guidance via Navigation SDK or TomTom/Mapbox — each needs a go.

Things a new session needs from the user:
- **The HTTPS identity is not in GitHub.** Ask the user to attach an older HTTPS IPA (they
  attached `ScreenLink-0.20.48-build85-HTTPS-unsigned.ipa`; it holds `PrivateTLS/fullchain.pem`
  and `private.key`, valid until 1 Feb 2027). Never print or commit them.
- A new account must have GitHub access to `sophysim282-maker/screentesla`.
- First push of a new release branch often does not start its workflow; push one more small
  change to the workflow file (the "Run N." comment) to start it.

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

- **105 (0.20.68) is SENT, NOT YET CAR-TESTED.** Branch `release/build105-awake-tiles`, workflow
  `awaketiles105.yml`. Contains 98–104. See `BUILD105.md`: (1) keep-awake without PiP through
  location updates; (2) the car draws the map from squares the phone fetches (Map Tiles API).
  - User must enable **Map Tiles API** on the Google key; the phone shows an orange button if not.
  - If the user says the app still sleeps: look for `KEEP AWAKE ON` / `NOT ACTIVE` in the log.
  - Build 104's picture map was rejected by the user as unusable. Do not go back to it as the
    main map; it is only the fallback.

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
