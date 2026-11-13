# ScreenLink for Android (work in progress)

Shows an Android phone's screen in another device's browser (e.g. the Tesla
browser) over the phone's own Personal Hotspot. The viewing device only needs a
browser.

## Important: this is screen mirroring, NOT the Android Auto protocol

This app uses Android's `MediaProjection` (the normal "record/cast your screen"
permission) to capture and forward the phone's own screen. It shows whatever is
on the phone — Maps, music, anything you open. It does **not** produce the
Android Auto interface.

Getting the real **Android Auto** UI is a separate, two-device design and cannot
be done with a single phone:

- Android Auto always needs a **phone (source)** and a **separate head unit
  (receiver)**. Google Play Services refuses to project to the same device, so
  one phone cannot be both the Android Auto source and its own head unit.
- A real head-unit emulator (the `aasdk` / OpenAuto approach: TLS handshake +
  protobuf channels + H.264 video over wireless or USB) must run on a **second
  device** — a spare Android phone/tablet or a Raspberry Pi. The main phone then
  projects Android Auto to it, and that device re-serves the video here.

The H.264 → fragmented-MP4 → browser `MediaSource` pipeline in this folder is
reusable for that head-unit path if a second device is added later.

## What works now (single phone, screen mirror)

1. Turn on Personal Hotspot on this phone.
2. On the Tesla: Wi-Fi → join this phone's hotspot.
3. Open ScreenLink → **Start sharing** → allow "entire screen".
4. In the Tesla browser, open the short link or full link shown in the app.
5. Keep the phone unlocked.

Video is H.264 by default (sharp, smooth) with a JPEG fallback for browsers that
block `<video>` playback. Audio is not forwarded; it still plays over the car's
Bluetooth as usual.

## Build

Requires Android SDK (API 35) and JDK 17. From `android/`:

```bash
./gradlew :app:assembleRelease
```

The APK is signed with the debug key for direct sideloading (not Play Store).
Portable logic (fMP4 writer, Annex B parser) has JVM unit tests:

```bash
./gradlew :app:testReleaseUnitTest
```
