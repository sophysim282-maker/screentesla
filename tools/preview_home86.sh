#!/bin/bash
# Build 86: run the real Home view in an iPhone simulator, record its motion and take screenshots.
set -euo pipefail
mkdir -p build/phone-preview/ScreenLinkPreview.app build/ui
app="$PWD/build/phone-preview/ScreenLinkPreview.app"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
arch="$(uname -m)"; [ "$arch" = arm64 ] || arch=x86_64
xcrun clang -fobjc-arc -fmodules -target "$arch-apple-ios15.0-simulator" -isysroot "$sdk" -IApp tools/phone_controls_preview.m App/ScreenLinkHomeView.m -framework UIKit -framework Foundation -framework AVFoundation -o "$app/ScreenLinkPreview"
cp App/CarPoster.jpg App/CarAmbient.mp4 "$app/"
python3 - "$app" <<'PY'
import pathlib,plistlib,sys
p={'CFBundleIdentifier':'local.screenlink.preview86','CFBundleExecutable':'ScreenLinkPreview','CFBundleName':'ScreenLink Preview','CFBundleVersion':'86','CFBundleShortVersionString':'0.20.49','CFBundlePackageType':'APPL','MinimumOSVersion':'15.0','UILaunchScreen':{}}
pathlib.Path(sys.argv[1]+'/Info.plist').write_bytes(plistlib.dumps(p))
PY
codesign --force --sign - "$app"
device="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); c=[x for k,v in d["devices"].items() if "iOS" in k for x in v if x["isAvailable"] and "iPhone" in x["name"]]; c.sort(key=lambda x:("Pro Max" not in x["name"],"Pro" not in x["name"])); print(c[0]["udid"])')"
xcrun simctl boot "$device" || true
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app"
xcrun simctl ui "$device" appearance dark
xcrun simctl io "$device" recordVideo --codec=h264 --force build/ui/home-motion-dark.mp4 &
recorder=$!
sleep 1
xcrun simctl launch "$device" local.screenlink.preview86
container="$(xcrun simctl get_app_container "$device" local.screenlink.preview86 data)"
for attempt in $(seq 1 30); do
  if test -f "$container/Documents/phone-controls-passed.txt"; then break; fi
  sleep 1
done
test "$(cat "$container/Documents/phone-controls-passed.txt")" = PHONE_UI_PASSED
sleep 4
xcrun simctl io "$device" screenshot build/ui/home-dark.png
sleep 4
kill -INT "$recorder"; wait "$recorder" || true
xcrun simctl ui "$device" appearance light
sleep 2
xcrun simctl io "$device" screenshot build/ui/home-light.png
xcrun simctl terminate "$device" local.screenlink.preview86
ls -la build/ui
echo 'HOME_PREVIEW_PASSED: Cosmic Glass Home runs in the simulator; controls work; motion video and screenshots captured.'
