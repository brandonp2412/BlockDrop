#!/usr/bin/env bash
# Produces a verifiable, unsigned arm64 iPhone IPA for GitHub Actions.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${VERSION:?Set VERSION}"
: "${BUILD_NUMBER:?Set BUILD_NUMBER}"

# The existing iOS Xcode project integrates CocoaPods. Do not mix Flutter's
# automatic SPM migration with the CocoaPods-generated manifest/lockfile.
flutter --version
flutter config --no-enable-swift-package-manager
flutter precache --ios
flutter pub get --enforce-lockfile
(cd ios && pod install)
test -s ios/Podfile.lock
test -s ios/Pods/Manifest.lock
cmp ios/Podfile.lock ios/Pods/Manifest.lock

flutter build ios --release --no-codesign   --build-name="$VERSION" --build-number="$BUILD_NUMBER"

app="build/ios/iphoneos/Runner.app"
test -s "$app/Runner"
test "$(plutil -extract CFBundleIdentifier raw -o - "$app/Info.plist")" = "com.blockdrop.game"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$app/Info.plist")" = "$VERSION"
test "$(plutil -extract CFBundleVersion raw -o - "$app/Info.plist")" = "$BUILD_NUMBER"
lipo "$app/Runner" -verify_arch arm64

mkdir -p build/ios/ipa/Payload
cp -R "$app" build/ios/ipa/Payload/Runner.app
ipa="block_drop_ios_${VERSION}_unsigned.ipa"
(
  cd build/ios/ipa
  /usr/bin/zip -qry "$ipa" Payload
  unzip -tqq "$ipa"
  test "$(unzip -Z1 "$ipa" | grep -Fxc 'Payload/Runner.app/Info.plist')" = 1
)
cp "build/ios/ipa/$ipa" "$ipa"
test -s "$ipa"
echo "Packaged and verified: $ipa"
