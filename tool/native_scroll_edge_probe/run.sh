#!/usr/bin/env bash
# Builds the probe, runs variants on a simulator, screenshots each state the
# moment the app writes its extraction marker, then copies the app's JSON and
# images to OUT.
#   tool/native_scroll_edge_probe/run.sh <simulator-udid> <OUT> [testSoftLight ...]
set -euo pipefail
UDID=$1; OUT=$(mkdir -p "$2" && cd "$2" && pwd); shift 2
cd "$(dirname "$0")"
TESTS=${@:-testSoftLight testSoftDark testHardLight testAutoLight}
mkdir -p "$OUT"
xcodegen generate > /dev/null
xcodebuild build-for-testing -project ScrollEdgeSpecs.xcodeproj -scheme ScrollEdgeSpecs \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet
APP=$(find build/Build/Products -name ScrollEdgeSpecs.app -maxdepth 3 | head -1)
xcrun simctl install "$UDID" "$APP"
DATA=$(xcrun simctl get_app_container "$UDID" dev.prism.scrolledgespec data)
for t in $TESTS; do
  rm -rf "$DATA/Documents/extracted" "$DATA/Documents/images"
  ( for state in rest scrolled stripes; do
      for _ in $(seq 1 300); do
        # The test runner reinstalls the app, which can move its container.
        DATA=$(xcrun simctl get_app_container "$UDID" dev.prism.scrolledgespec data 2>/dev/null || echo "$DATA")
        ls "$DATA/Documents/extracted/$state-"*.done >/dev/null 2>&1 && break
        sleep 0.1
      done
      xcrun simctl io "$UDID" screenshot "$OUT/$t-$state.png" >/dev/null 2>&1 || true
    done ) &
  xcodebuild test-without-building -project ScrollEdgeSpecs.xcodeproj -scheme ScrollEdgeSpecs \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
    -parallel-testing-enabled NO "-only-testing:ScrollEdgeSpecsTests/ScrollEdgeSpecsTests/$t" -quiet || true
  wait
  DATA=$(xcrun simctl get_app_container "$UDID" dev.prism.scrolledgespec data)
  mkdir -p "$OUT/extracted" "$OUT/images"
  cp "$DATA/Documents/extracted/"* "$OUT/extracted/" 2>/dev/null || true
  cp "$DATA/Documents/images/"* "$OUT/images/" 2>/dev/null || true
done
ls "$OUT" "$OUT/extracted"
