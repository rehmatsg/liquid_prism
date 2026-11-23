# Testing and verification

## Local checks

```sh
./tool/check.sh
flutter pub publish --dry-run
```

`tool/check.sh` runs:
1. `flutter pub get`
2. `dart format --output=none --set-exit-if-changed lib test example/lib example/test`
3. `flutter analyze --fatal-infos` (root and `example/`)
4. `flutter test --timeout=30s` (root and `example/`)
5. `python3 -m unittest discover -s test/tooling -p 'test_*.py'`
6. `python3 tool/check_versions.py`

## Native iOS checks

```sh
xcodebuild test -scheme liquid_prism-Package -destination 'platform=iOS Simulator,id=<simulator-id>'
pod ipc spec ios/liquid_prism.podspec > /dev/null
cd example && flutter build ios --simulator --debug
```

## Test structure

Tests mirror `lib/src/`:
- `test/core/` — materials, shapes, palette, theme, value equality & non-rebuild guarantees, API surface contract, badges, haptics
- `test/rendering/` — surface fallback, grouping, fill sharing, shadows, transitions, edge blur, chromatic fringe, HDR display, frame budget
- `test/controls/` — buttons, switches, sliders, segmented controls, search fields, gesture ownership, pressable, selection
- `test/navigation/` — scaffold, sliver app bar, navigation title motion/minimization, tab bars, toolbars, scroll edges, refresh, system chrome
- `test/menu/` — native platform interface, wire serialization, fallback menu, menu regions
- `test/tooling/` — developer script and version check tests

## Real renderer verification

Headless widget tests exercise the frosted fallback and do not prove GPU shader output. After renderer or shader changes, run the showcase on a real Impeller simulator or device:

```sh
./tool/run_example.sh <device-id>
```

Hot reload/restart works for Dart changes; stop and rebuild the app after GLSL changes.

## Research harnesses

Benchmarks, parity fixtures and simulator drivers live in the unpublished
research app under `research/`, which depends on the package and the example by
path and carries the research-only native channels. See the
[research README](../../research/README.md) for every harness command, and run
`flutter analyze` and `flutter test` inside `research/` after changing them.
