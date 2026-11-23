#!/bin/sh
# Builds the iOS edge sampling probe for the simulator, installs it on
# $SIM (an iOS 27 simulator UDID), screenshots every scene, and copies the
# layer dump and meta.json into $1 (default: _research/edge_sampling/ios-<ts>).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
: "${SIM:?set SIM to a booted iOS simulator UDID}"
out=${1:-"$root/_research/edge_sampling/ios-$(date +%Y%m%d-%H%M%S)"}
build="$here/build/ios"
app="$build/EdgeProbeIOS.app"
bundle=dev.liquidprism.edgeprobe.ios
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
target=arm64-apple-ios27.0-simulator

mkdir -p "$app" "$out"
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.liquidprism.edgeprobe.ios</string>
  <key>CFBundleExecutable</key><string>EdgeProbeIOS</string>
  <key>CFBundleName</key><string>EdgeProbe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>27.0</string>
  <key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
  <key>UIDeviceFamily</key><array><integer>1</integer></array>
  <key>UILaunchScreen</key><dict/>
  <key>UIApplicationSceneManifest</key><dict>
    <key>UIApplicationSupportsMultipleScenes</key><false/>
  </dict>
</dict></plist>
PLIST
xcrun --sdk iphonesimulator clang -target $target -isysroot "$sdk" -fobjc-arc \
  -c "$here/Sources/Extractor.m" -o "$build/Extractor.o"
xcrun --sdk iphonesimulator swiftc -target $target -sdk "$sdk" -O -parse-as-library \
  -import-objc-header "$here/Sources/Extractor.h" \
  "$here/Sources/EdgeProbeIOS.swift" "$build/Extractor.o" -o "$app/EdgeProbeIOS"
codesign --force --sign - "$app" >/dev/null 2>&1
xcrun simctl install "$SIM" "$app"
xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true

data=$(xcrun simctl get_app_container "$SIM" $bundle data)
rm -rf "$data/Documents/out"
xcrun simctl launch --terminate-running-process "$SIM" $bundle -scene soft_white -dump 1 >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$data/Documents/out/done" ] && break; sleep 1; done
cp -R "$data/Documents/out/." "$out/"
rm -f "$out/done"

scenes=$(python3 -c "import json,sys; print(' '.join(s['name'] for s in json.load(open(sys.argv[1]))['scenes']))" "$out/meta.json")
for scene in $scenes; do
  xcrun simctl launch --terminate-running-process "$SIM" $bundle -scene "$scene" >/dev/null
  sleep 2.5
  xcrun simctl io "$SIM" screenshot ${DISPLAY_ARG:-} --type=png "$out/$scene.png" >/dev/null 2>&1
done
xcrun simctl terminate "$SIM" $bundle >/dev/null 2>&1 || true
echo "$out"
