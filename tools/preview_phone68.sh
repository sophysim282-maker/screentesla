#!/bin/bash
set -euo pipefail
mkdir -p build/phone-preview/ScreenLinkPreview.app build/ui
app="$PWD/build/phone-preview/ScreenLinkPreview.app"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun clang -fobjc-arc -fmodules -target x86_64-apple-ios15.0-simulator -isysroot "$sdk" -IApp tools/phone_controls_preview.m App/ScreenLinkHomeView.m -framework UIKit -framework Foundation -framework AVFoundation -o "$app/ScreenLinkPreview"
cp App/CarPoster.jpg App/CarAmbient.mp4 "$app/"
python3 - "$app" <<'PY'
import pathlib,plistlib,sys
p={'CFBundleIdentifier':'local.screenlink.preview68','CFBundleExecutable':'ScreenLinkPreview','CFBundleName':'ScreenLink Preview','CFBundleVersion':'68','CFBundleShortVersionString':'0.20.31','CFBundlePackageType':'APPL','MinimumOSVersion':'15.0','UILaunchScreen':{}}
pathlib.Path(sys.argv[1]+'/Info.plist').write_bytes(plistlib.dumps(p))
PY
codesign --force --sign - "$app"
device="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for k,v in d["devices"].items() if "iOS" in k for x in v if x["isAvailable"] and "iPhone" in x["name"]))')"
xcrun simctl boot "$device" || true
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app"
xcrun simctl ui "$device" appearance light
xcrun simctl launch "$device" local.screenlink.preview68
container="$(xcrun simctl get_app_container "$device" local.screenlink.preview68 data)"
for attempt in $(seq 1 30); do
  if test -f "$container/Documents/phone-controls-passed.txt"; then break; fi
  sleep 1
done
test "$(cat "$container/Documents/phone-controls-passed.txt")" = PHONE_UI_PASSED
xcrun simctl io "$device" screenshot build/ui/phone-controls-light.png
xcrun simctl ui "$device" appearance dark
sleep 1
xcrun simctl io "$device" screenshot build/ui/phone-controls-dark.png
xcrun simctl terminate "$device" local.screenlink.preview68
echo 'PHONE_UI_PASSED: actual UIKit controls trigger quality, volume, seek and pause; light/dark simulator screenshots captured.'
