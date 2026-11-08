# Native material and navigation probes

Generate the project with `xcodegen generate --spec project.yml`. Use Xcode's
current SDK and an installed iOS simulator; generated projects, derived data,
recordings and raw captures stay out of git.

The navigation scene renders an ordinary SwiftUI `NavigationStack` and records
public label geometry, presentation-layer opacity/position, active Core Animation
parameters and scroll insets with `CADisplayLink`. It does not hook constructors
or alter the navigation bar.

```sh
xcodebuild -project DispersionSpecs.xcodeproj -scheme DispersionSpecs \
  -destination 'platform=iOS Simulator,id=<id>' \
  -derivedDataPath /tmp/prism-navigation \
  -resultBundlePath /tmp/prism-navigation.xcresult \
  -only-testing:DispersionSpecsTests/NavigationTests test
```

Launch arguments: `--scene navigation --light --title-mode large|inline|inlineLarge
--minimization never|automatic|onScrollDown|onScrollUp`, optionally
`--restore-at-edge` or `--fixed-insets`. Tests export screenshots and geometry as
XCTest attachments. Per-frame traces are written to the app container's
`Documents/navigation-<title-mode>-<minimization>-<restoration>.json`.

`uv run ../fit_navigation_titles.py <trace-directory>` fits opacity responses
with separate onset and initial velocity. Keep these fits distinct from the
large title's directly recorded Core Animation timing.

`testTitleTiming` exercises slow crossings, pauses, reversal and fast crossings.
`testNavigationModes` compares resting, scrolled-down and reversed states.
`testRestorationAtEdge` follows the inset feedback through the content's top.

The Flutter counterpart is `example/test_driver/navigation.dart`; run
`navigation_check.dart` with `DART_VM_SERVICE_URL`, `PRISM_SIMULATOR_ID` and
`PRISM_NAVIGATION_OUT` set. Optionally pass `PRISM_NAVIGATION_REFERENCE` as the
exported native measurements JSON to align content scroll positions, or
`PRISM_NAVIGATION_TRACES_ONLY=true` to capture just motion. It captures both app-bar implementations, light/dark,
minimization/restoration states, RTL/large text and per-frame enter/exit traces.
See [the native spec](../../doc/navigation_bar_spec.json) for measured constants,
renderer fits and remaining differences.
