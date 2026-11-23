#!/usr/bin/env bash
# Hard edge hairline probe: builds the app, launches it directly per variant
# (no UI test), screenshots each state when the app writes its marker, then
# copies the JSON out.
#   tool/native_scroll_edge_probe/hairline.sh <simulator-udid> <OUT> ["--light" "--light --bottom" ...]
set -euo pipefail
UDID=$1; OUT=$(mkdir -p "$2" && cd "$2" && pwd); shift 2
cd "$(dirname "$0")"
[ $# -gt 0 ] && VARIANTS=("$@") || VARIANTS=("--light" "" "--light --bottom" "--bottom" "--light --bottombar" "--bottombar")
xcodegen generate > /dev/null
xcodebuild build -project ScrollEdgeSpecs.xcodeproj -scheme ScrollEdgeSpecs \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet
APP=$(find build/Build/Products -name ScrollEdgeSpecs.app -maxdepth 3 | head -1)
xcrun simctl install "$UDID" "$APP"
mkdir -p "$OUT/extracted"
for v in "${VARIANTS[@]}"; do
  mode=light; [[ "$v" == *--light* ]] || mode=dark
  variant=top; [[ "$v" == *--bottombar* ]] && variant=bottombar; [[ "$v" == *"--bottom "* || "$v" == *--bottom ]] && variant=accessory
  xcrun simctl terminate "$UDID" dev.prism.scrolledgespec 2>/dev/null || true
  DATA=$(xcrun simctl get_app_container "$UDID" dev.prism.scrolledgespec data)
  rm -rf "$DATA/Documents/extracted"
  # shellcheck disable=SC2086
  xcrun simctl launch "$UDID" dev.prism.scrolledgespec --hairline $v > /dev/null
  for state in rest plain grey back; do
    for _ in $(seq 1 300); do
      [ -e "$DATA/Documents/extracted/h-$state-$variant-$mode.done" ] && break; sleep 0.1
    done
    xcrun simctl io "$UDID" screenshot "$OUT/h-$state-$variant-$mode.png" > /dev/null 2>&1
  done
  sleep 1
  cp "$DATA/Documents/extracted/"*.json "$OUT/extracted/"
done
xcrun simctl terminate "$UDID" dev.prism.scrolledgespec 2>/dev/null || true
ls "$OUT" "$OUT/extracted"
