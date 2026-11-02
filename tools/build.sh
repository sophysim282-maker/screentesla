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
mkdir -p build
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
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp tools/test_video_inbox.m App/VideoInbox.m -framework Foundation -o build/test-video-inbox
build/test-video-inbox
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp tools/test_vpn_discovery.m App/VPNDiscovery.m -framework Foundation -o build/test-vpn-discovery
build/test-vpn-discovery | tee build/xcodebuild.log
python3 tools/prepare_receiver.py
python3 tools/fetch_hls.py
cc -IVendor/RPiPlay/lib tools/test_http_completion.c Vendor/RPiPlay/lib/http_request.c Vendor/RPiPlay/lib/http_response.c Vendor/RPiPlay/lib/llhttp/api.c Vendor/RPiPlay/lib/llhttp/http.c Vendor/RPiPlay/lib/llhttp/llhttp.c -o build/test-http-completion
build/test-http-completion
xcrun --sdk macosx clang -fobjc-arc -fblocks -IApp -IVendor/RPiPlay/lib tools/test_media_cast.m App/MediaCast.m App/HLSPlaylist.m Vendor/RPiPlay/lib/http_request.c Vendor/RPiPlay/lib/http_response.c Vendor/RPiPlay/lib/llhttp/api.c Vendor/RPiPlay/lib/llhttp/http.c Vendor/RPiPlay/lib/llhttp/llhttp.c -framework Foundation -o build/test-media-cast
build/test-media-cast
root="$PWD"
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
compiler="$(xcrun --sdk iphoneos --find clang)"
mkdir -p .deps-src deps build
if [[ ! -f deps/lib/libcrypto.a ]]; then
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
xcodegen generate
xcodebuild -project ScreenLinkAirPlayLab.xcodeproj -scheme ScreenLinkAirPlayLab -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build 2>&1 | tee -a build/xcodebuild.log
mkdir -p build/Payload
cp -R build/DerivedData/Build/Products/Release-iphoneos/ScreenLinkAirPlayLab.app build/Payload/
(cd build && zip -qry ScreenLink-AirPlay-Lab-unsigned.ipa Payload)
echo 'Unsigned IPA built. Free signing still required. Same-phone AirPlay has NOT been tested by this build.'
