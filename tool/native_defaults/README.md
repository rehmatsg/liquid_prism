# Native defaults comparison

Requires Xcode, xcodegen and Flutter; the gallery builder also requires Pillow.

The native fixture is `DefaultsFixture` in `../native_dispersion_probe`; the
Flutter counterpart is `example/test_driver/native_defaults.dart`. Both place the
same materials and controls over fixed semantic and sinusoidal backgrounds.

Build the native probe with `xcodegen generate` and `xcodebuild build-for-testing`
using its `project.yml`. Install it, then capture the resting matrix:

```sh
python3 tool/native_defaults/capture_native.py --device "$DEVICE" --out "$OUT/native"
```

Each native launch passes `-UIViewGlassTintAmount` as a process-local preference.
The capture runner checks the native getter against the requested amount before
saving a screenshot. `--period 64` checks another texture frequency; `--disabled`
captures disabled controls. `--selections` captures slider endpoints and the
other tab/segment selections (use `--patterns grouped --amounts 0.5` for the
focused state sweep). `--display` selects a display on an iPhone Duo.

For genuine native holds and released states:

```sh
python3 tool/native_defaults/capture_states.py --device "$DEVICE" \
  --build "$DERIVED_DATA" --out "$OUT/states/native"
```

The UI test writes release screenshots. The runner screenshots held states when
the app's touch marker arrives. It resolves the app container again while running
because XCTest may reinstall the app into a new container.

Launch Flutter on the same simulator, then use its printed VM service URL:

```sh
cd example
flutter run -d "$DEVICE" -t test_driver/native_defaults.dart
DART_VM_SERVICE_URL="$VM" PRISM_SIMULATOR_ID="$DEVICE" PRISM_DEFAULTS_OUT="$OUT/flutter" \
  dart test_driver/capture_native_defaults.dart "$OUT/native/manifest.json"
```

Captures and generated galleries belong under ignored `artifacts/`. Commit only
the tools, measurement summaries and source changes. Native filter inspection is
research instrumentation; it must not enter the shipping plugin.

Replay the held/released sequence in Flutter with `--states` after the manifest:

```sh
DART_VM_SERVICE_URL="$VM" PRISM_SIMULATOR_ID="$DEVICE" PRISM_DEFAULTS_OUT="$OUT/states/flutter" \
  dart test_driver/capture_native_defaults.dart "$OUT/states/native/manifest.json" --states
```

Build the portable gallery from the root. Optional disabled folders use the same
resting-manifest format; `--before` adds a prior Flutter revision for resting cases.

```sh
python3 tool/native_defaults/build_gallery.py \
  --native "$OUT/native" --flutter "$OUT/flutter" \
  --states-native "$OUT/states/native" --states-flutter "$OUT/states/flutter" \
  --disabled-native "$OUT/disabled/native" --disabled-flutter "$OUT/disabled/flutter" \
  --selections-native "$OUT/selections/native" --selections-flutter "$OUT/selections/flutter" \
  --showcase "$OUT/showcase" --showcase-before "$OUT/showcase-before" \
  --before "$OUT/before" --out "$OUT/gallery"
python3 -m http.server --directory "$OUT/gallery" 8080
```

The gallery keeps source resolution, removes the status bar from the displayed
viewport, and offers component crops, appearance/amount/state filters and an
overlay inspector. It reports measured coverage rather than claiming identical
pixels or continuous animation coverage.
