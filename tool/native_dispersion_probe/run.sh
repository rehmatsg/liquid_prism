#!/usr/bin/env bash
# Builds the dispersion probe, runs tests on one simulator, screenshots the rest
# state and each held state when the app writes its marker, then copies dumps.
#   tool/native_dispersion_probe/run.sh <simulator-udid> <OUT> [testControlsVDark ...]
set -euo pipefail
UDID=$1; OUT=$(mkdir -p "$2" && cd "$2" && pwd); shift 2
cd "$(dirname "$0")"
TESTS=${@:-testControlsVDark testControlsVLight testControlsHDark testControlsHLight testTabsVDark testTabsVLight testTabsHDark testToolbarVDark testToolbarVLight}
BID=dev.prism.dispersionspec
xcodegen generate > /dev/null
xcodebuild build-for-testing -project DispersionSpecs.xcodeproj -scheme DispersionSpecs \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet
APP=$(find build/Build/Products -name DispersionSpecs.app -maxdepth 3 | head -1)
xcrun simctl install "$UDID" "$APP"
for t in $TESTS; do
  DATA=$(xcrun simctl get_app_container "$UDID" $BID data)
  rm -rf "$DATA/Documents/extracted"
  ( for state in rest touch1 touch2 touch3 touch4 touch5 touch6 touch7 touch8; do
      ok=0
      for _ in $(seq 1 400); do
        DATA=$(xcrun simctl get_app_container "$UDID" $BID data 2>/dev/null || echo "$DATA")
        if [ -e "$DATA/Documents/extracted/$state.done" ]; then ok=1; break; fi
        sleep 0.05
      done
      [ $ok = 1 ] || break
      xcrun simctl io "$UDID" screenshot "$OUT/$t-$state.png" >/dev/null 2>&1 || true
    done ) &
  xcodebuild test-without-building -project DispersionSpecs.xcodeproj -scheme DispersionSpecs \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
    -parallel-testing-enabled NO "-only-testing:DispersionSpecsTests/DispersionSpecsTests/$t" -quiet || true
  sleep 1; kill %1 2>/dev/null || true; wait || true
  DATA=$(xcrun simctl get_app_container "$UDID" $BID data)
  mkdir -p "$OUT/extracted"
  for f in "$DATA/Documents/extracted/"*.json; do cp "$f" "$OUT/extracted/$t-$(basename "$f")" 2>/dev/null || true; done
done
ls "$OUT" | head -100
