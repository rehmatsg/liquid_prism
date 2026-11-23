# Liquid Prism research app

Benchmarks, native parity fixtures, simulator drivers and measurement probes
for maintaining Liquid Prism. Nothing here ships: `.pubignore` excludes
`research/` from the package archive, the root analysis excludes it, and the
example app carries none of its channels or dependencies.

`research/` is a Flutter app package, `liquid_prism_research`
(`publish_to: none`). It depends on:

- `liquid_prism` (path `..`), the package under test;
- `liquid_prism_example` (path `../example`), so the showcase drivers can run
  the shipped showcase with a driver extension;
- `liquid_glass_easy: 4.3.0`, for `bench_main.dart`'s `lge` and `lgeblur` modes;
- `flutter_driver` and `flutter_test` (dev).

Its iOS runner (`ios/Runner/AppDelegate.swift`) registers the research-only
method channels: `liquid_prism/bench` (device telemetry), `liquid_prism/parity`
(SwiftUI glass overlay, tint amount, filter dumps) and
`liquid_prism/hdr_probe` (Metal layer EDR state). Its macOS runner (Impeller
enabled) hosts the GPU benchmark. The iOS app keeps the example's bundle id,
`dev.rehmatsg.liquidPrismExample`, and team, so the existing provisioning
profiles and every script that launches that id keep working without an Xcode
account. Installing it replaces the showcase app on that simulator or phone;
reinstall the example afterwards when you need it.

| Path | Contents |
| --- | --- |
| `benchmarks/` | Entry points: benchmarks, parity and probe fixtures, focused demos |
| `test_driver/` | Driver-extension fixtures and the host scripts that drive them |
| `test/` | Widget tests of the demos (`flutter test`) |
| `probes/` | Native SwiftUI/UIKit probes and capture/analysis scripts |
| `specs/` | Measured native values and the notes that record them |
| `ios/`, `macos/` | Runners for the research app |

## Setup and checks

```sh
cd research
flutter pub get
flutter analyze
flutter test
```

Run Flutter commands below from `research/` and Python or shell scripts from
the repository root, unless a section says otherwise. After included GLSL
changes, `rm -rf research/.dart_tool/flutter_build` before building; a hot
restart cannot replace a cached shader program.

## Benchmarks and fixtures

| Entry point | Run | Native side |
| --- | --- | --- |
| `benchmarks/bench_main.dart` | `flutter run --profile -d <iphone> -t benchmarks/bench_main.dart --dart-define=MODE=prism` | `liquid_prism/bench` |
| `benchmarks/gpu_bench_main.dart` | `research/probes/gpu_bench/run.py` ([README](probes/gpu_bench/README.md)) | macOS runner |
| `benchmarks/parity_main.dart` | `python3 research/probes/glass_parity/capture.py sim --udid <sim> --build` ([README](probes/glass_parity/README.md)) | `liquid_prism/parity` |
| `probes/hdr_probe/main.dart` | `python3 research/probes/hdr_probe/run.py --device <id>` ([README](probes/hdr_probe/README.md)) | `liquid_prism/hdr_probe`, `liquid_prism/parity` |
| `benchmarks/edge_probe_main.dart` | `SIM=<udid> research/probes/native_edge_sampling_probe/run_flutter_ios.sh` ([README](probes/native_edge_sampling_probe/README.md)) | none |
| `benchmarks/transform_main.dart` | `flutter run -t benchmarks/transform_main.dart --dart-define=PRISM_TRANSFORM_MODE=filter` | none |
| `benchmarks/scroll_edge_main.dart` | `flutter run -t benchmarks/scroll_edge_main.dart` | none |
| `benchmarks/chrome_main.dart` | `flutter run -t benchmarks/chrome_main.dart` | none |
| `benchmarks/controls_main.dart` | `flutter run -t benchmarks/controls_main.dart` | none |
| `benchmarks/composition_main.dart` | `flutter run -t benchmarks/composition_main.dart` | none |

`bench_main.dart` modes: `none`, `prism`, `prismnoscale`, `prismnoblur`,
`chrome`, `lge`, `lgeblur`. `DURATION` sets the scripted seconds (default 600)
and `IDLE=true` holds a static frame for cooldown. It prints `BENCH {json}`
every 10 s and mirrors the lines to the app's `tmp/bench.log`, readable with
`devicectl device copy from --domain-type appDataContainer`. It needs the iOS
runner's channel, so it does not run on macOS.

`transform_main.dart` also reads `PRISM_TRANSFORM_T` (0 to 1, or -1 to animate)
and `PRISM_TRANSFORM_HOLD=true`.

## Simulator drivers

Launch a fixture with `flutter run -d <simulator> -t <fixture>`, then run the
host script from `research/` in another terminal with the printed VM service
URL in `DART_VM_SERVICE_URL`, the simulator in `PRISM_SIMULATOR_ID`, and the
output directory variable the script names. Use a fresh output directory.

| Fixture | Host scripts |
| --- | --- |
| `test_driver/showcase.dart` (the example's showcase) | `showcase_video.dart`, `showcase_screenshots.dart`, `unified_lens_video.dart`, `switch_tap_video.dart`, `control_refinement_video.dart`, `capture_refresh.dart`, `native_showcase_compare.dart` |
| `test_driver/controls.dart` | `controls_video.dart`, `gesture_ownership.dart` |
| `test_driver/chrome.dart` | `chrome_video.dart` |
| `test_driver/composition.dart` | `composition_check.dart` |
| `test_driver/navigation.dart` | `navigation_check.dart` |
| `test_driver/native_defaults.dart` | `capture_native_defaults.dart` ([README](probes/native_defaults/README.md)) |
| `benchmarks/readme_demos_main.dart` | `record_readme_demos.dart` |

For example:

```sh
flutter run -d <simulator> -t test_driver/showcase.dart
DART_VM_SERVICE_URL=<printed-vm-uri> PRISM_SIMULATOR_ID=<simulator> \
PRISM_LENS_OUT=<absolute-output-directory> dart test_driver/unified_lens_video.dart
```

`gesture_ownership.dart` prints PASS/FAIL per case and exits non-zero on a
failure; its native counterpart is `ControlGestureTests` in
`probes/native_control_probe`. `native_showcase_compare.dart` also needs the
SwiftUI reference from `probes/native_showcase` installed and launched with
`--inspect`.

## Native probes

Each directory under `probes/` documents its own build and capture steps:
[glass parity](probes/glass_parity/README.md),
[GPU benchmark](probes/gpu_bench/README.md),
[HDR rim](probes/hdr_probe/README.md),
[native defaults](probes/native_defaults/README.md),
[dispersion and navigation](probes/native_dispersion_probe/README.md),
[edge sampling](probes/native_edge_sampling_probe/README.md),
[package features](probes/native_package_features_probe/README.md),
[scroll edge](probes/native_scroll_edge_probe/README.md),
[native showcase](probes/native_showcase/README.md),
[rim contrast](probes/rim_contrast/README.md) and
[title motion](probes/title_motion_probe/README.md). The XcodeGen probes
(`native_chrome_probe`, `native_control_probe`, `native_menu_ui_probe`) are
described in their specs under `specs/`. `native_menu_ui_probe` drives the
shipped example app, not this one.

Captures, recordings and generated reports stay in the ignored `artifacts/`
and `_research/` folders at the repository root.
