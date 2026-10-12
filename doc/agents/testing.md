# Testing and verification

## Local checks

Use the installed Flutter version that satisfies `pubspec.yaml`.

```sh
flutter pub get
dart format lib test example/lib example/test
./tool/check.sh
flutter pub publish --dry-run
```

The check script verifies formatting, analyzes Dart, runs package and example
widget tests, then Python tooling tests. Inspect the final exit status; background
command startup is not completion. Publish dry-run validates packaging, not a
release authorization.

## Tests by contract

| Change | Relevant tests |
| --- | --- |
| Style/theme precedence | `test/appearance_api_test.dart`, `test/glass_theme_test.dart` |
| Controlled input, lift and velocity | `test/glass_controls_test.dart`, `test/pressable_test.dart` |
| Native sizes and endpoint fill | `test/native_input_geometry_test.dart`, `test/native_slider_fill_test.dart` |
| Compact tabs, keyboard, cancellation | `test/tab_bar_layout_test.dart`, `test/glass_tab_bar_test.dart` |
| Search controller/focus and toolbar | `test/chrome_test.dart` |
| Colors/shadows/contours | `test/native_control_palette_test.dart`, palette/shadow/shape tests |
| Menus | `test/menu/` |
| Showcase layout and composition | `example/test/` |

Prefer tests through the public barrel. Verify behavior, ownership and meaningful
edge cases; do not merely compare newly assigned fields. Use tester time for
minimum-lift windows, not wall-clock DateTime. Reset platform/channel overrides
in teardown. Await settling and remove listeners/resources.

## Real renderer

Headless tests use the fallback and do not establish GPU appearance. After API or
renderer changes, launch a fresh Impeller app:

```sh
cd example
flutter run -d <simulator-id> -t lib/main.dart
# Separate customization example:
flutter run -d <simulator-id> -t lib/api_main.dart
```

After Dart edits, hot reload/restart and observe the updated app. After GLSL or
shader uniform changes, terminate and rebuild; cached programs can survive a hot
restart. Check logs for shader, layout and range errors. Exercise light/dark,
narrow layout, large text, held/slow/fast drag, release and repeated interaction.

The driver fixture supports deterministic interaction and capture:

```sh
flutter run -d <simulator-id> -t test_driver/showcase.dart
# In another terminal, from example/:
DART_VM_SERVICE_URL=<printed-vm-uri> \
PRISM_SIMULATOR_ID=<simulator-id> \
PRISM_LENS_OUT=<absolute-output-directory> \
dart test_driver/unified_lens_video.dart
```

Use a fresh output directory. Optional `PRISM_LENS_CASES=tabs` selects a component;
`PRISM_LENS_DARK=true` checks dark appearance. Compare geometry from fixture layout
responses before comparing captures. See [native comparison](native-comparison.md).

## Documentation

Compile runnable examples as part of analysis. Verify local Markdown links after
moving guides. Keep snippets based on public exports. If a snippet omits app state
or context, say so instead of presenting it as a complete program. Report any
unrun platform check; do not describe a static screenshot as motion validation.
