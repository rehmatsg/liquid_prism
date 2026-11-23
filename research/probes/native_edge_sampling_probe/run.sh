#!/bin/sh
# Builds the macOS edge sampling probe, runs it, and leaves screenshots, layer
# dumps and meta.json in $1 (default: _research/edge_sampling/<timestamp>).
# The terminal needs Screen Recording permission for window captures.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
out=${1:-"$root/_research/edge_sampling/$(date +%Y%m%d-%H%M%S)"}
build="$here/build"
app="$build/EdgeProbe.app"

mkdir -p "$app/Contents/MacOS" "$out"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.liquidprism.edgeprobe</string>
  <key>CFBundleExecutable</key><string>EdgeProbe</string>
  <key>CFBundleName</key><string>EdgeProbe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
clang -fobjc-arc -c "$here/Sources/Extractor.m" -o "$build/Extractor.o"
swiftc -O -parse-as-library -import-objc-header "$here/Sources/Extractor.h" \
  "$here/Sources/EdgeProbeApp.swift" "$build/Extractor.o" \
  -framework QuartzCore -o "$app/Contents/MacOS/EdgeProbe"
# Run the binary directly so captures inherit the terminal's permission.
PROBE_OUT="$out" "$app/Contents/MacOS/EdgeProbe" -ApplePersistenceIgnoreState YES
echo "$out"
