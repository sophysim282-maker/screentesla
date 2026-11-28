#!/bin/bash
# Build 171: screenshots of the real Home on the iPhone Duo simulator (Xcode 27.1).
# Usage: tools/preview_duo.sh  (needs the xcode-27 cloud Mac). Output: build/duo-ui/*.png
set -euo pipefail
mkdir -p build/duo-preview/DuoPreview.app build/duo-ui
app="$PWD/build/duo-preview/DuoPreview.app"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"; echo "SDK $sdk"
arch="$(uname -m)"
xcrun clang -fobjc-arc -fmodules -target "$arch-apple-ios16.0-simulator" -isysroot "$sdk" -IApp tools/duo_preview.m App/ScreenLinkHomeView.m App/SLCarLibrary.m -framework UIKit -framework Foundation -framework AVFoundation -framework PhotosUI -framework Vision -framework CoreImage -o "$app/DuoPreview"
cp App/CarPoster.jpg App/CarAmbient.mp4 "$app/"
python3 - "$app" <<'PY'
import pathlib,plistlib,sys
p={'CFBundleIdentifier':'local.screenlink.duo','CFBundleExecutable':'DuoPreview','CFBundleName':'Duo Preview','CFBundleVersion':'171','CFBundleShortVersionString':'0.23','CFBundlePackageType':'APPL','MinimumOSVersion':'16.0','UILaunchScreen':{},'UIDeviceFamily':[1],
 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UIRequiresFullScreen':False,
 'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False,'UISceneConfigurations':{'UIWindowSceneSessionRoleApplication':[{'UISceneConfigurationName':'Default','UISceneDelegateClassName':'DuoScene'}]}}}
pathlib.Path(sys.argv[1]+'/Info.plist').write_bytes(plistlib.dumps(p))
PY
codesign --force --sign - "$app"
xcrun simctl help | grep -iE "fold|hinge|posture" || echo "(no fold command in simctl)"
dev="$(xcrun simctl create duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1)"
xcrun simctl boot "$dev"; xcrun simctl bootstatus "$dev" -b
xcrun simctl ui "$dev" appearance dark
xcrun simctl status_bar "$dev" override --time 9:41 --batteryLevel 100 --cellularBars 4 || true
xcrun simctl install "$dev" "$app"
xcrun simctl launch "$dev" local.screenlink.duo
data="$(xcrun simctl get_app_container "$dev" local.screenlink.duo data)"
names=(outside-home inside-home inside-video inside-home-sideways inside-video-sideways)
for n in 0 1 2 3 4; do
  for i in $(seq 1 120); do test -f "$data/Documents/shot-$n.txt" && break; sleep 1; done
  echo "shot $n: window $(cat "$data/Documents/shot-$n.txt" 2>/dev/null || echo missing)"
  for d in 1 3; do xcrun simctl io "$dev" screenshot --display=$d "$PWD/build/duo-ui/${names[$n]}-d$d.png" >/dev/null 2>&1 && echo "  display $d ok" || true; done
  if [ $n = 0 ]; then
    # Open the phone with the Simulator app's Device menu (there is no simctl command for the fold).
    xcrun simctl ui "$dev" help 2>&1 | head -20 || true
    open -a Simulator --args -CurrentDeviceUDID "$dev"; sleep 12
    osascript -e 'tell application "System Events" to tell process "Simulator" to get name of every menu item of menu 1 of menu bar item "Device" of menu bar 1' 2>&1 || true
    osascript -e 'tell application "System Events" to tell process "Simulator"
      set found to ""
      repeat with m in (every menu item of menu 1 of menu bar item "Device" of menu bar 1)
        set t to name of m
        if t is not missing value and (t contains "Unfold" or t contains "Open" and t contains "Phone" or t contains "Fold") then
          click m
          set found to t
          exit repeat
        end if
      end repeat
      return "clicked: " & found
    end tell' 2>&1 || true
    sleep 10
    xcrun simctl io "$dev" screenshot --display=3 "$PWD/build/duo-ui/after-open.png" || true
  fi
  touch "$data/Documents/ack-$n.txt"
done
xcrun simctl spawn "$dev" log show --last 2m --style compact --predicate 'process == "DuoPreview"' 2>/dev/null | grep -iE "error|exception|constraint" | tail -20 || true
ls -la build/duo-ui
echo DUO_PREVIEW_DONE
