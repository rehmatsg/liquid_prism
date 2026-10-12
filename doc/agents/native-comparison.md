# Comparing native behavior

The SwiftUI app under `tool/native_showcase/` is the visual/interaction reference.
Measurement probes under `tool/native_*` expose native geometry, optical and
animation properties. Do not ship their inspection code.

## Evidence hierarchy

Use direct model/presentation-layer or shader-uniform measurements for specs.
Use timestamped touch/animation traces to fit response. Use screenshots/videos to
check the resulting composition, clipping and feel. A nice screenshot does not
prove a spring or velocity law, and an intercepted animation constructor does not
prove which property it drives.

Record OS/build, simulator model, screen points/DPR, theme, font scale, fixture
values, capture method and revision. Repeat static, slow, fast, paused, release
and recontact cases. Separate captured constants from fitted laws in prose and
JSON; preserve unresolved questions instead of upgrading an approximation to fact.

## Existing specifications

- [Tab optical and motion inputs](../native_tab_bar_spec.md),
  [compact layout measurements](../native_tab_layout_spec.json).
- [Control sizes/timing](../native_controls_spec.md),
  [continuous slider endpoint fill](../native_slider_fill_spec.json).
- [Toolbar/search geometry](../native_chrome_spec.md).
- [Palette](../native_colors.md), [shadows](../native_shadows.md).
- [Showcase comparison](../native_showcase_comparison.md).

Read the probe's source/README for current scheme and capture flags before running
it. Use `xcrun simctl list devices` and `xcodebuild -list -project <project>` rather
than assuming a previous personal simulator ID is available. Build native and
Flutter apps on the same simulator/OS with matching fixture values.

## Regression checks

1. Tabs stay compact unless expanded is explicit. The three-tab native fixture is
   274×62 points under its specified typography; that is not a universal width.
2. Lifted switch, segment and tab lenses reveal a smaller underlay. Slider knobs
   grow, but their tracks retain scale. Customization may opt out explicitly.
3. Fast motion deforms the lens and decays/recoils while stationary. Check the
   trajectory, not just the held bounds. Tab and small-control fits differ.
4. Slider fill reaches both endpoints continuously over the outer 2%; there is no
   special final-frame snap to 100%.
5. Lens shadows soften/scale without a clipped extra capsule inside the lens.
   Dark tabs must not gain a concentrated white halo.
6. Tab icon/label refraction is a separate transparent foreground pass. Glyphs
   near the rim bend; flat-center text and content outside the pill stay stable.
7. Quick switch taps keep the lift window long enough to complete the cycle.
   Toggle values arrive promptly; haptics need a physical iPhone to assess.

If a custom style changes captured dimensions, compare default fixtures first,
then assess custom behavior against its documented contract. Do not retune native
fallbacks to compensate for app layout or recording differences.
