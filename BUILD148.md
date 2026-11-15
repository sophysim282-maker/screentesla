# Build 148 (0.21.11): glass Home

Build 147 (Apple-style Home) was rejected; the user went back to 146, rejected several mockups, then sent a
Dribbble video (plant-care app: full photo background, frosted glass cards, black Dynamic-Island card, bottom
bar) and chose the ScreenLink version of that style, with names on the bottom bar and ON/OFF badges.

`App/ScreenLinkHomeView.m` (everything else as build 146):
- Full-screen car photo (`self.car` + `heroImage`, the entrance target), dark gradient.
- Home page (`home.scroll`): black island card (Car Status, LIVE, Help, link, round car picture, status,
  detail, Open YouTube), help steps, big car-video time, glass bar (connection words + Pause/Play), glass tiles
  Phone sound / Keep playing / Maps / Small window (ON/OFF from `setSubtitle:forRow:`), Waiting screen / TikTok
  (OPEN), Start / Stop ScreenLink.
- Video page: Player / Waiting screen pills, ON THE CAR time, big Pause, ±10 s, timeline, glass card with
  Quality, Sound, Car volume.
- Bottom bar: Home · Video · Map (`home.maps`, opens Maps) · Menu (`home.developer`).
- `screenPreview` (main.m sets it from broadcastArmed): the phone-screen box only shows in screen sharing.
