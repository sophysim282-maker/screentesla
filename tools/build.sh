#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null; then
  echo 'This source needs macOS with full Xcode, or the included GitHub Actions Mac runner.' >&2
  exit 1
fi
for tool in xcodegen autoconf automake glibtoolize; do
  command -v "$tool" >/dev/null || { echo "Missing $tool. Install prerequisites: brew install xcodegen autoconf automake libtool" >&2; exit 1; }
done
openssl_root="$(brew --prefix openssl@3)"
mkdir -p build/tls-test
"$openssl_root/bin/openssl" req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=car.tesla4khmer.com' -addext 'subjectAltName=DNS:car.tesla4khmer.com' -keyout build/tls-test/key.pem -out build/tls-test/cert.pem 2>/dev/null
cc -std=c11 -Wall -Wextra -Werror -I"$openssl_root/include" -L"$openssl_root/lib" -Wl,-rpath,"$openssl_root/lib" tools/test_local_tls.c App/LocalTLS.c -lssl -lcrypto -pthread -o build/tls-test/test
build/tls-test/test build/tls-test/cert.pem build/tls-test/key.pem
cc -std=c11 -Wall -Wextra -Werror -I"$openssl_root/include" -L"$openssl_root/lib" -Wl,-rpath,"$openssl_root/lib" tools/test_tls_failure_reason.c App/LocalTLS.c -lssl -lcrypto -o build/tls-test/failure-reason
build/tls-test/failure-reason build/tls-test/cert.pem build/tls-test/key.pem
cc -std=c11 -Wall -Wextra -Werror tools/test_web_watch.c -o build/tls-test/web-watch
mkdir -p build/tls-test/identity/out
"$openssl_root/bin/openssl" req -x509 -newkey rsa:2048 -nodes -days 30 -subj '/CN=other.example' -addext 'subjectAltName=DNS:other.example' -keyout build/tls-test/identity/wrong-key.pem -out build/tls-test/identity/wrong-cert.pem 2>/dev/null
python3 tools/make_identity_ipa.py build/tls-test/identity/good.ipa build/tls-test/cert.pem build/tls-test/key.pem good
python3 tools/make_identity_ipa.py build/tls-test/identity/raw.ipa build/tls-test/cert.pem build/tls-test/key.pem raw
python3 tools/make_identity_ipa.py build/tls-test/identity/wrong.ipa build/tls-test/identity/wrong-cert.pem build/tls-test/identity/wrong-key.pem good
cc -std=c11 -Wall -Wextra -Werror -I"$openssl_root/include" -L"$openssl_root/lib" -Wl,-rpath,"$openssl_root/lib" tools/test_identity_import.c App/ZipEntry.c App/LocalTLS.c -lssl -lcrypto -lz -o build/tls-test/identity/test
build/tls-test/identity/test build/tls-test/identity/good.ipa build/tls-test/identity/raw.ipa build/tls-test/identity/out build/tls-test/identity/wrong.ipa
build/tls-test/web-watch
cc -std=c11 -Wall -Wextra -Werror tools/test_local_dns.c -o build/tls-test/local-dns
build/tls-test/local-dns
cc -std=c11 -Wall -Wextra -Werror -I"$openssl_root/include" -L"$openssl_root/lib" -Wl,-rpath,"$openssl_root/lib" tools/test_keep_alive_tls.c App/LocalTLS.c -lssl -lcrypto -pthread -o build/tls-test/keep-alive
build/tls-test/keep-alive build/tls-test/cert.pem build/tls-test/key.pem
cc -std=c11 -Wall -Wextra -Werror -I"$openssl_root/include" -L"$openssl_root/lib" -Wl,-rpath,"$openssl_root/lib" tools/test_local_websocket.c App/LocalWebSocket.c -lcrypto -o build/test-local-websocket
build/test-local-websocket
mkdir -p build
cc -std=c11 -Wall -Wextra -Werror tools/test_local_viewer_header.c -o build/test-local-viewer-header
build/test-local-viewer-header
cc -std=c11 -Wall -Wextra -Werror -c RTC/SLStun.c -o build/local-stun.o
cc -std=c11 -Wall -Wextra -Werror tools/test_stun.c build/local-stun.o -o build/test-stun
build/test-stun
node tools/test_rtc_ice_diagnostics.cjs
python3 tools/fetch_webrtc.py
rtc_mac="$PWD/Vendor/WebRTC.xcframework/macos-x86_64_arm64"
codesign --force --sign - "$rtc_mac/WebRTC.framework"
xcrun --sdk macosx clang -fobjc-arc -fblocks -IRTC -F"$rtc_mac" tools/test_rtc_peer.m RTC/SLPingPeer.m RTC/SLTestVideo.m build/local-stun.o RTC/SLSignaling.m -framework CoreVideo -framework Foundation -framework WebRTC -Wl,-rpath,"$rtc_mac" -o build/test-rtc-peer
xcrun --sdk macosx clang -fobjc-arc -fblocks -IRTC -F"$rtc_mac" tools/test_rtc_gather.m RTC/SLPingPeer.m RTC/SLTestVideo.m build/local-stun.o -framework CoreVideo -framework Foundation -framework WebRTC -Wl,-rpath,"$rtc_mac" -o build/test-rtc-gather
build/test-rtc-gather
xcrun --sdk macosx clang -fobjc-arc -fblocks -IRTC tools/test_signaling_slow.m RTC/SLSignaling.m -framework Foundation -o build/test-signaling-slow
build/test-signaling-slow
xcrun --sdk macosx clang -fobjc-arc -fblocks -IRTC -F"$rtc_mac" tools/test_rtc_restart.m RTC/SLMediaSession.m RTC/SLMediaBridge.m RTC/SLPingPeer.m RTC/SLTestVideo.m build/local-stun.o RTC/SLSignaling.m -framework CoreVideo -framework Foundation -framework WebRTC -Wl,-rpath,"$rtc_mac" -o build/test-rtc-restart
build/test-rtc-restart
build/test-rtc-peer
xcrun --sdk macosx clang -fobjc-arc -fblocks -IRTC -F"$rtc_mac" tools/test_rtc_media.m RTC/SLMediaSession.m RTC/SLMediaBridge.m RTC/SLPingPeer.m RTC/SLTestVideo.m build/local-stun.o RTC/SLSignaling.m -framework CoreVideo -framework Foundation -framework WebRTC -Wl,-rpath,"$rtc_mac" -o build/test-rtc-media
for media_attempt in 1 2 3; do build/test-rtc-media; done
if [[ "${SCREENLINK_LIVE_SIGNALING_TEST:-0}" == 1 ]]; then
  build/test-rtc-peer --live
fi
xcrun --sdk macosx clang -Wall -Wextra -Werror -fobjc-arc -fblocks -IApp tools/test_local_viewer_approval.m App/LocalViewerApproval.m -framework Foundation -o build/test-local-viewer-approval
build/test-local-viewer-approval
cc -Wall -Wextra -Werror tools/test_route_probe.c -o build/test-route-probe
build/test-route-probe
cc -Wall -Wextra -Werror tools/test_local_packet.c -o build/test-local-packet
build/test-local-packet
cc -Wall -Wextra -Werror tools/test_reverse_channel.c -o build/test-reverse-channel
build/test-reverse-channel
cc -Wall -Wextra -Werror tools/test_frame_cadence.c -o build/test-frame-cadence
build/test-frame-cadence
cc -Wall -Wextra -Werror tools/test_mjpeg.c -o build/test-mjpeg
build/test-mjpeg
cc -Wall -Wextra -Werror tools/test_hotspot_link.c -o build/test-hotspot-link
build/test-hotspot-link
cc -Wall -Wextra -Werror tools/test_fmp4.c -o build/test-fmp4
build/test-fmp4
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp tools/test_h264_stream.m App/H264Stream.m -framework Foundation -o build/test-h264-stream
build/test-h264-stream
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp tools/test_screen_privacy.m App/H264Stream.m -framework Foundation -o build/test-screen-privacy
build/test-screen-privacy
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp -IBroadcast tools/test_screen_encoder.m Broadcast/ScreenEncoder.m App/H264Stream.m -framework Foundation -framework VideoToolbox -framework CoreMedia -framework CoreVideo -o build/test-screen-encoder
build/test-screen-encoder
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp tools/test_bounded_download.m App/BoundedDownload.m -framework Foundation -o build/test-bounded-download
build/test-bounded-download
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp tools/test_video_inbox.m App/VideoInbox.m -framework Foundation -o build/test-video-inbox
build/test-video-inbox
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp tools/test_vpn_discovery.m App/VPNDiscovery.m -framework Foundation -o build/test-vpn-discovery
build/test-vpn-discovery | tee build/xcodebuild.log
python3 tools/prepare_receiver.py
python3 tools/fetch_hls.py
python3 tools/fetch_canvas.py
cc -IVendor/RPiPlay/lib tools/test_http_completion.c Vendor/RPiPlay/lib/http_request.c Vendor/RPiPlay/lib/http_response.c Vendor/RPiPlay/lib/llhttp/api.c Vendor/RPiPlay/lib/llhttp/http.c Vendor/RPiPlay/lib/llhttp/llhttp.c -o build/test-http-completion
build/test-http-completion
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp -IVendor/RPiPlay/lib tools/test_media_cast.m App/MediaCast.m App/BoundedDownload.m App/HLSPlaylist.m Vendor/RPiPlay/lib/http_request.c Vendor/RPiPlay/lib/http_response.c Vendor/RPiPlay/lib/llhttp/api.c Vendor/RPiPlay/lib/llhttp/http.c Vendor/RPiPlay/lib/llhttp/llhttp.c -framework Foundation -o build/test-media-cast
build/test-media-cast
root="$PWD"
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
compiler="$(xcrun --sdk iphoneos --find clang)"
mkdir -p .deps-src deps build
if [[ ! -f deps/lib/libcrypto.a || ! -f deps/lib/libssl.a ]]; then
  if [[ ! -d .deps-src/openssl ]]; then
    git clone --depth 1 --branch OpenSSL_1_1_1w https://github.com/openssl/openssl.git .deps-src/openssl
  fi
  (
    cd .deps-src/openssl
    ./Configure ios64-cross no-shared no-tests --prefix="$root/deps" --openssldir="$root/deps/ssl" -miphoneos-version-min=15.0
    make -j3 CC="$compiler" CROSS_TOP="$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer" CROSS_SDK="$(basename "$sdk")"
    make install_dev
  )
fi
if [[ ! -f deps/lib/libplist-2.0.a ]]; then
  if [[ ! -d .deps-src/libplist ]]; then
    git clone --depth 1 --branch 2.2.0 https://github.com/libimobiledevice/libplist.git .deps-src/libplist
  fi
  (
    cd .deps-src/libplist
    CC="$compiler" CFLAGS="-arch arm64 -isysroot $sdk -miphoneos-version-min=15.0" LDFLAGS="-arch arm64 -isysroot $sdk -miphoneos-version-min=15.0" ./autogen.sh --host=aarch64-apple-darwin --prefix="$root/deps" --disable-shared --enable-static --without-cython
    make -j3
    make install
  )
fi
swift tools/render_brand.swift
xcodegen generate
xcodebuild -project ScreenLinkAirPlayLab.xcodeproj -scheme ScreenLinkAirPlayLab -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build 2>&1 | tee -a build/xcodebuild.log
mkdir -p build/Payload
cp -R build/DerivedData/Build/Products/Release-iphoneos/ScreenLinkAirPlayLab.app build/Payload/
# Embed the requested entitlement template so IPA re-signers can preserve it.
# Ad-hoc signatures are NOT device-authorized signing or provisioning profiles.
codesign --force --sign - --generate-entitlement-der --entitlements Tunnel/LocalTunnel.entitlements build/Payload/ScreenLinkAirPlayLab.app/PlugIns/ScreenLinkLocalTunnel.appex
codesign --force --sign - --generate-entitlement-der --entitlements Broadcast/Broadcast.entitlements build/Payload/ScreenLinkAirPlayLab.app/PlugIns/ScreenLinkBroadcast.appex
codesign --force --sign - build/Payload/ScreenLinkAirPlayLab.app/Frameworks/WebRTC.framework
codesign --force --sign - build/Payload/ScreenLinkAirPlayLab.app/PlugIns/ScreenLinkWidgets.appex
codesign --force --sign - --generate-entitlement-der --entitlements App/ScreenLink.entitlements build/Payload/ScreenLinkAirPlayLab.app
python3 - <<'VERIFY_VPN'
import plistlib, subprocess
from pathlib import Path
app=Path('build/Payload/ScreenLinkAirPlayLab.app')
plugins=list((app/'PlugIns').glob('*.appex'))
assert (app/'Frameworks/WebRTC.framework/WebRTC').is_file()
assert len(plugins)==3, 'Expected embedded VPN, broadcast and widget extensions'
vpn=next(p for p in plugins if p.name=='ScreenLinkLocalTunnel.appex')
broadcast=next(p for p in plugins if p.name=='ScreenLinkBroadcast.appex')
info=plistlib.loads((vpn/'Info.plist').read_bytes())
assert info['NSExtension']['NSExtensionPointIdentifier']=='com.apple.networkextension.packet-tunnel'
assert info['NSExtension']['NSExtensionPrincipalClass']=='PacketTunnelProvider'
assert (vpn/info['CFBundleExecutable']).is_file()
parent=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleIdentifier'].startswith(parent['CFBundleIdentifier']+'.')
assert info['CFBundleVersion']==parent['CFBundleVersion']
for bundle in [vpn,app]:
    result=subprocess.run(['codesign','-d','--entitlements',':-',str(bundle)],capture_output=True,check=True)
    entitlements=plistlib.loads(result.stdout)
    assert 'packet-tunnel-provider' in entitlements['com.apple.developer.networking.networkextension']
b=plistlib.loads((broadcast/'Info.plist').read_bytes())
assert b['NSExtension']['NSExtensionPointIdentifier']=='com.apple.broadcast-services-upload'
assert b['NSExtension']['NSExtensionPrincipalClass']=='SampleHandler'
assert b['NSExtension']['RPBroadcastProcessMode']=='RPBroadcastProcessModeSampleBuffer'
assert b['CFBundleVersion']==parent['CFBundleVersion']
assert b['CFBundleIdentifier'].startswith(parent['CFBundleIdentifier']+'.')
assert (broadcast/b['CFBundleExecutable']).is_file()
for name in ['SplitViewer.html','MapPlayer.html','MediaPlayer.html','HLSPlayer.js','BrowserVideoPlayer.js']:
    assert (broadcast/name).is_file(),name
widget=next(p for p in plugins if p.name=='ScreenLinkWidgets.appex')
w=plistlib.loads((widget/'Info.plist').read_bytes())
assert w['NSExtension']['NSExtensionPointIdentifier']=='com.apple.widgetkit-extension'
assert w['CFBundleVersion']==parent['CFBundleVersion']
assert w['CFBundleIdentifier'].startswith(parent['CFBundleIdentifier']+'.')
assert (widget/w['CFBundleExecutable']).is_file()
assert w.get('CFBundlePackageType')=='XPC!'
widget_binary=(widget/w['CFBundleExecutable']).read_bytes()
for kind in [b'ScreenLink.Controls',b'ScreenLink.CarPlayer',b'CarPlayerIntent',b'start-youtube',b'disconnect-all']:
    assert kind in widget_binary, 'Widget control route/configuration missing: '+str(kind)
assert parent['CFBundleVersion']=='99' and parent['CFBundleShortVersionString']=='0.20.62'
assert parent.get('CFBundleIcons',{}).get('CFBundlePrimaryIcon',{}).get('CFBundleIconName')=='AppIcon'
assert (app/'Assets.car').is_file() and (app/'ScreenLinkCover.png').is_file()
assert parent['NSSupportsLiveActivities']
assert any('screenlink' in u.get('CFBundleURLSchemes',[]) for u in parent['CFBundleURLTypes'])
print('Embedded widget, VPN and broadcast extension packaging verified:',w['CFBundleIdentifier'])
print('Existing extensions:', info['CFBundleIdentifier'],b['CFBundleIdentifier'])
VERIFY_VPN
(cd build && zip -qry ScreenLink-AirPlay-Lab-unsigned.ipa Payload)
echo 'Unsigned IPA built. Free signing still required. Same-phone AirPlay has NOT been tested by this build.'


