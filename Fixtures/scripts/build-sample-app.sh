#!/usr/bin/env bash
# Builds the SampleShop fixture app, version 1.0 or 2.0, for the iOS Simulator and writes
#
#   Fixtures/apps/SampleShop-<version>.ipa          (committed)
#   Fixtures/.build/<version>/stage/Payload/SampleShop.app   (not committed; install it in a
#                                                     simulator with `xcrun simctl install`)
#
# with swiftc, actool, lipo and codesign from Xcode, without an Xcode project, so the steps are
# all here. Both architectures the simulator runs (arm64 and x86_64) go into universal binaries.
# A simulator build has no App Store thinning or encryption; the tests and the README say so.
#
#   Fixtures/scripts/build-sample-app.sh 1.0
#   Fixtures/scripts/build-sample-app.sh 2.0
#
# macOS with Xcode only. Only the .ipa files are committed (the tests extract them), so tests on
# Linux do not need this script.
set -euo pipefail

version="${1:-}"
case "$version" in
  1.0) build_number=1 ;;
  2.0) build_number=2 ;;
  *) echo "usage: $0 <1.0|2.0>" >&2; exit 64 ;;
esac

fixtures="$(cd "$(dirname "$0")/.." && pwd)"
sources="$fixtures/SampleShop"
work="$fixtures/.build/$version"
out="$fixtures/apps"
app="$work/stage/Payload/SampleShop.app"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
minimum_os=17.0
archs=(arm64 x86_64)

rm -rf "$work"
mkdir -p "$work" "$app/Frameworks"

echo "== Resources"
swift "$fixtures/scripts/make-sample-resources.swift" "$version" "$work/resources"

frameworks=(ShopCore)
flags=()
if [ "$version" = 2.0 ]; then
  frameworks+=(Analytics)
  flags+=(-D SAMPLESHOP_2)
fi

swift_compile() {
  local arch="$1"
  shift
  xcrun --sdk iphonesimulator swiftc -target "$arch-apple-ios$minimum_os-simulator" -sdk "$sdk" \
    -O -whole-module-optimization -swift-version 5 "$@"
}

framework_plist() {
  local name="$1"
  plutil -create xml1 "$2"
  plutil -insert CFBundleExecutable -string "$name" "$2"
  plutil -insert CFBundleIdentifier -string "com.example.sampleshop.$name" "$2"
  plutil -insert CFBundleName -string "$name" "$2"
  plutil -insert CFBundlePackageType -string FMWK "$2"
  plutil -insert CFBundleShortVersionString -string "$version" "$2"
  plutil -insert CFBundleVersion -string "$build_number" "$2"
  plutil -insert CFBundleSupportedPlatforms -array "$2"
  plutil -insert CFBundleSupportedPlatforms.0 -string iPhoneSimulator "$2"
  plutil -insert MinimumOSVersion -string "$minimum_os" "$2"
  plutil -convert binary1 "$2"
}

echo "== Frameworks: ${frameworks[*]}"
for name in "${frameworks[@]}"; do
  slices=()
  for arch in "${archs[@]}"; do
    mkdir -p "$work/$arch/modules"
    swift_compile "$arch" -parse-as-library -emit-library -module-name "$name" \
      -emit-module -emit-module-path "$work/$arch/modules/$name.swiftmodule" \
      -Xlinker -install_name -Xlinker "@rpath/$name.framework/$name" \
      -o "$work/$arch/$name" "$sources/$name"/*.swift
    slices+=("$work/$arch/$name")
  done
  mkdir -p "$app/Frameworks/$name.framework"
  lipo -create "${slices[@]}" -output "$app/Frameworks/$name.framework/$name"
  framework_plist "$name" "$app/Frameworks/$name.framework/Info.plist"
done

echo "== Executable"
slices=()
for arch in "${archs[@]}"; do
  link=()
  for name in "${frameworks[@]}"; do link+=("$work/$arch/$name"); done
  swift_compile "$arch" -parse-as-library -module-name SampleShop "${flags[@]+"${flags[@]}"}" \
    -I "$work/$arch/modules" "${link[@]}" \
    -Xlinker -rpath -Xlinker @executable_path/Frameworks \
    -o "$work/$arch/SampleShop" "$sources/App"/*.swift
  slices+=("$work/$arch/SampleShop")
done
lipo -create "${slices[@]}" -output "$app/SampleShop"

echo "== Asset catalog"
xcrun actool "$work/resources/Assets.xcassets" --compile "$app" --platform iphonesimulator \
  --minimum-deployment-target "$minimum_os" --app-icon AppIcon \
  --target-device iphone --target-device ipad \
  --output-partial-info-plist "$work/assets-info.plist" --output-format human-readable-text \
  --errors --warnings > "$work/actool.log"

echo "== Resources into the bundle"
cp "$work/resources/catalog.json" "$app/catalog.json"
for folder in "$work/resources"/*.lproj; do
  cp -R "$folder" "$app/"
done
printf 'APPL????' > "$app/PkgInfo"

echo "== Info.plist"
plist="$app/Info.plist"
cp "$work/assets-info.plist" "$plist"
plutil -convert xml1 "$plist"
plutil -insert CFBundleDevelopmentRegion -string en "$plist"
plutil -insert CFBundleDisplayName -string "Sample Shop" "$plist"
plutil -insert CFBundleExecutable -string SampleShop "$plist"
plutil -insert CFBundleIdentifier -string com.example.sampleshop "$plist"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$plist"
plutil -insert CFBundleName -string SampleShop "$plist"
plutil -insert CFBundlePackageType -string APPL "$plist"
plutil -insert CFBundleShortVersionString -string "$version" "$plist"
plutil -insert CFBundleVersion -string "$build_number" "$plist"
plutil -insert CFBundleSupportedPlatforms -array "$plist"
plutil -insert CFBundleSupportedPlatforms.0 -string iPhoneSimulator "$plist"
plutil -insert DTPlatformName -string iphonesimulator "$plist"
plutil -insert DTSDKName -string "iphonesimulator$sdk_version" "$plist"
plutil -insert LSRequiresIPhoneOS -bool YES "$plist"
plutil -insert MinimumOSVersion -string "$minimum_os" "$plist"
plutil -insert UIApplicationSceneManifest -dictionary "$plist"
plutil -insert UIApplicationSceneManifest.UIApplicationSupportsMultipleScenes -bool YES "$plist"
plutil -insert UILaunchScreen -dictionary "$plist"
plutil -insert UIDeviceFamily -array "$plist"
plutil -insert UIDeviceFamily.0 -integer 1 "$plist"
plutil -insert UIDeviceFamily.1 -integer 2 "$plist"
plutil -convert binary1 "$plist"

echo "== Ad-hoc signature (enough for the simulator)"
for name in "${frameworks[@]}"; do
  codesign --force --sign - --timestamp=none "$app/Frameworks/$name.framework"
done
codesign --force --sign - --timestamp=none "$app"

echo "== .ipa"
mkdir -p "$out"
rm -f "$out/SampleShop-$version.ipa"
(cd "$work/stage" && zip -qry -X "$out/SampleShop-$version.ipa" Payload)

echo "Built $out/SampleShop-$version.ipa from $app"
du -sk "$app" "$out/SampleShop-$version.ipa"
