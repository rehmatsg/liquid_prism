#!/bin/sh
# Builds research/benchmarks/edge_probe_main.dart for the simulator, installs it on
# $SIM and screenshots every scene it steps through (handshake through
# Documents/edge_probe/current and ack). Output: $1 (default
# _research/edge_sampling/flutter-<timestamp>), readable by analyze.py.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
: "${SIM:?set SIM to a booted iOS simulator UDID}"
out=${1:-"$root/_research/edge_sampling/flutter-$(date +%Y%m%d-%H%M%S)"}
bundle=dev.rehmatsg.liquidPrismExample
mkdir -p "$out"

if [ -z "${SKIP_BUILD:-}" ]; then
  (cd "$root/research" && flutter build ios --simulator --debug -t benchmarks/edge_probe_main.dart >/dev/null)
fi
xcrun simctl install "$SIM" "$root/research/build/ios/iphonesimulator/Runner.app"
xcrun simctl terminate "$SIM" $bundle >/dev/null 2>&1 || true
data=$(xcrun simctl get_app_container "$SIM" $bundle data)
dir="$data/Documents/edge_probe"
rm -rf "$dir"
xcrun simctl launch "$SIM" $bundle >/dev/null

last=""
for _ in $(seq 1 1200); do
  if [ -f "$dir/done" ]; then break; fi
  if [ -f "$dir/current" ]; then
    cur=$(cat "$dir/current")
    if [ "$cur" != "$last" ]; then
      xcrun simctl io "$SIM" screenshot ${DISPLAY_ARG:-} --type=png "$out/$cur.png" >/dev/null 2>&1
      printf %s "$cur" > "$dir/ack"
      last=$cur
    fi
  fi
  sleep 0.2
done
cp "$dir/meta.json" "$out/meta.json"
echo "$out"
