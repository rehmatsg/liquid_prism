#!/usr/bin/env bash
set -euo pipefail
UDID=75CB9880-0032-4922-A694-BEF70503D63F
OUT=$(mkdir -p "${1:?Provide evidence output directory}" && cd "$1" && pwd)
git rev-parse HEAD > "$OUT/revision.txt"
cd "$(dirname "$0")"
xcodegen generate
xcodebuild build-for-testing -project PackageFeaturesSpecs.xcodeproj -scheme PackageFeaturesSpecs -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO
# Navigation subtitle/sheet cases: SubtitleInline SubtitleInlineDark SubtitleLarge
# SubtitleLargeDark SubtitleLong SubtitleScrub SheetLarge SheetLargeIndicator SheetMedium
# SheetMediumIndicator SheetLargeTitle SheetMediumLargeTitle (PROBE_CASES=... or PROBE_CASES=Nav).
NAV_CASES="SubtitleInline SubtitleInlineDark SubtitleLarge SubtitleLargeDark SubtitleLong SubtitleScrub SheetLarge SheetLargeIndicator SheetMedium SheetMediumIndicator SheetLargeTitle SheetMediumLargeTitle"
CASES=${PROBE_CASES:-Light Dark ToolbarLight ToolbarDark Tabs4 Tabs5 Scrub}
[ "$CASES" = Nav ] && CASES=$NAV_CASES
# Clear/regular glass outline fixture: PROBE_CASES=Glass (white, #F2F2F7, #C7C7CC).
[ "$CASES" = Glass ] && CASES="GlassWhite GlassGrey GlassMid"
for appearance in $CASES; do
  # The UI test writes rest, slow up/down and fast collapse screenshots itself
  # (TEST_RUNNER_PROBE_OUT reaches the runner as PROBE_OUT).
  DATA=$(xcrun simctl get_app_container "$UDID" dev.prism.packagefeatures data 2>/dev/null || true)
  [ -n "$DATA" ] && rm -rf "$DATA/Documents/measurements"
  TEST_RUNNER_PROBE_OUT="$OUT" xcodebuild test-without-building -project PackageFeaturesSpecs.xcodeproj -scheme PackageFeaturesSpecs -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO "-only-testing:PackageFeaturesSpecsTests/PackageFeaturesSpecsTests/test$appearance"
  DATA=$(xcrun simctl get_app_container "$UDID" dev.prism.packagefeatures data)
  mkdir -p "$OUT/$appearance"
  rm -rf "$OUT/$appearance/measurements"
  cp -R "$DATA/Documents/measurements" "$OUT/$appearance/"
  # Each per-case directory keeps frames.json (per-frame sampler) beside the 100 ms dumps.
done
