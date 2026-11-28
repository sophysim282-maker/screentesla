#!/bin/bash
# Build 165: the iPhone Duo version of the app. Takes the normal unsigned IPA and
# 1) adds a scene list to the app's Info.plist (apps built for iOS 27 must use scenes; main.m has SLSceneDelegate),
# 2) marks the main program as built with the iOS 27.1 SDK, so the iPhone Duo can show it full screen.
# Usage: tools/make_duo_ipa.sh <normal.ipa> <duo.ipa>
set -euo pipefail
in="$1"; mkdir -p "$(dirname "$2")"; out="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; work="$(mktemp -d)"; rm -f "$out"
unzip -q "$in" -d "$work"
app="$(ls -d "$work"/Payload/*.app | head -1)"
plist="$app/Info.plist"
exe="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"
/usr/libexec/PlistBuddy -c 'Delete :UIApplicationSceneManifest' "$plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :UIApplicationSceneManifest dict' "$plist"
/usr/libexec/PlistBuddy -c 'Add :UIApplicationSceneManifest:UIApplicationSupportsMultipleScenes bool false' "$plist"
/usr/libexec/PlistBuddy -c 'Add :UIApplicationSceneManifest:UISceneConfigurations dict' "$plist"
/usr/libexec/PlistBuddy -c 'Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication array' "$plist"
/usr/libexec/PlistBuddy -c 'Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0 dict' "$plist"
/usr/libexec/PlistBuddy -c 'Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneConfigurationName string Default' "$plist"
/usr/libexec/PlistBuddy -c 'Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneDelegateClassName string SLSceneDelegate' "$plist"
# Build 170: screens other than the main window (outside screen test) go to SLOuterSceneDelegate.
for role in UIWindowSceneSessionRoleExternalDisplayNonInteractive UIWindowSceneSessionRoleExternalDisplay; do
 /usr/libexec/PlistBuddy -c "Add :UIApplicationSceneManifest:UISceneConfigurations:$role array" "$plist"
 /usr/libexec/PlistBuddy -c "Add :UIApplicationSceneManifest:UISceneConfigurations:$role:0 dict" "$plist"
 /usr/libexec/PlistBuddy -c "Add :UIApplicationSceneManifest:UISceneConfigurations:$role:0:UISceneConfigurationName string Outside" "$plist"
 /usr/libexec/PlistBuddy -c "Add :UIApplicationSceneManifest:UISceneConfigurations:$role:0:UISceneDelegateClassName string SLOuterSceneDelegate" "$plist"
done
for key in DTPlatformVersion:27.1 DTSDKName:iphoneos27.1 DTSDKBuild:27B5000; do /usr/libexec/PlistBuddy -c "Set :${key%%:*} ${key#*:}" "$plist" 2>/dev/null || true; done
minos="$(otool -l "$app/$exe" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')"
vtool -set-build-version ios "${minos:-16.0}" 27.1 -replace -output "$app/$exe.duo" "$app/$exe"
mv "$app/$exe.duo" "$app/$exe"
otool -l "$app/$exe" | grep -A4 LC_BUILD_VERSION | head -6
rm -rf "$app/_CodeSignature"
(cd "$work" && zip -qry "$out" Payload)
echo "DUO_IPA_READY: $out (scene list added, built-with SDK marked 27.1, minimum iOS ${minos:-16.0})"
