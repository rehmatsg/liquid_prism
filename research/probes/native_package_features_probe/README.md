# Package feature measurements (research only)

Use only **iPhone 17 Pro (iOS27)**, UDID
`75CB9880-0032-4922-A694-BEF70503D63F`.

From the repository root:

```sh
xcrun simctl list devices
xcrun simctl boot 75CB9880-0032-4922-A694-BEF70503D63F # if shut down
./tool/native_package_features_probe/run.sh _research/package_features
```

The script runs xcodegen, xcodebuild build-for-testing, test-without-building and
simctl screenshots. Build products and evidence stay local. The SwiftUI fixture
has icon-only tabs, count/space badges, a standard large navigation title, toolbar
symbols, an unframed segmented Picker and a separate fixedSize intrinsic Picker.
Additional UIKit fixtures use the public UIBarButtonItem.badge API with count
and indicator badges (separate from the bell.badge symbol). No private inspection ships.

JSON samples record direct UIView window frames, UILabel font/color/text, UIView/layer background colors,
UIScrollView offset/insets, model opacity and presentation opacity at 100 ms
intervals. Use visible tab button centers for pitch; identify badge label/container
bounds separately from the bell.badge symbol (a glyph is not a toolbar badge API).
A space tab badge is a native string badge fixture, not proof of a native tab dot
API; the toolbar fixture uses the public indicator badge.
If SwiftUI text is rendered without UILabel, that font remains unmeasured; do not
infer it from screenshots. Presentation frames are parent-relative, and cannot be
compared directly with window-space model frames.

Rest/slow/fast screenshots are approximate wall-clock samples; use JSON uptime
and scroll offsets to identify actual rest/collapse states. UI-test startup varies.
No fitted curve or constants are inferred automatically. Record OS build,
revision, appearance and font scale with results before updating defaults.

In the implementation sandbox, CoreSimulator refused its connection; no values
were measured. Package badge/title defaults are provisional. The 86-point tab
pitch remains unchanged. See `doc/package_features_spec.md`.

Navigation subtitle and sheet bars: `PROBE_CASES=Nav ./tool/native_package_features_probe/run.sh _research/nav_subtitle_sheet`
launches `--nav <mode>` fixtures (`.navigationSubtitle`, inline/large, long-text truncation,
and NavigationStack in a `.sheet` with large or medium+large detents, with/without
`.presentationDragIndicator(.visible)`, inline or large title). FrameSampler tracks the title
and subtitle labels plus the sheet `UIDropShadowView` presentation frame. Medium-detent
window frames include the sheet's scale; divide by sheet width/402 for sheet-local points.
