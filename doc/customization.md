# Customization

Import `package:liquid_prism/liquid_prism.dart`. The entry point exposes the public
widgets, styles and menus. Add `package:liquid_prism/primitives.dart` for
`PrismOptics`, `PrismLensStyle`, `PrismSelection`, `PrismPressable` and
`PrismSystemChrome`. Files under `lib/src/` are implementation details.

Call `await Prism.initialize()` after initializing Flutter bindings to load
the shaders and enable adaptive HDR rim lighting on supported iOS displays.
`await Prism.initialize(enableHDR: false)` keeps SDR rim lighting for the
engine. Subsequent calls without that option preserve the explicit choice.
See [rendering requirements](rendering.md) for platform support.

## Materials and surfaces

`PrismSurface(shadow: false)` disables exterior and inset material shadows while
retaining its optical rims and HDR lighting. Use
`PrismThemeData(shadow: false)` for a subtree; an explicit widget value
wins. Lifted control lenses use their separate `PrismLensStyle.shadow` setting.

```dart
PrismSurface(
  glass: PrismGlass.clear.interactive(),
  shape: const PrismShape.rect(cornerRadius: 24),
  child: content,
)
```

`PrismGlass.regular` is the standard material; `PrismGlass.clear` is more transparent.
Both follow the device Liquid Glass setting: regular keeps the backdrop sharp
under a blended blur fill as native does, and clear has no frost at the
clearest setting. Regular retains its own face grading, highlights and shadows. Leave bars on
regular for the standard treatment; choose clear explicitly for a different material.
`PrismGlass.identity` draws only the child. `.tint(color)` changes material color;
`.tint(null)` explicitly removes inherited material tint. `.interactive()` adds
spring touch feedback to a surface, without inventing an action. Use
`PrismButton` for touch, keyboard, and accessibility activation.

App-wide, `PrismThemeData(blur: 6, refraction: 30)` sets the frost and
the rim refraction of every surface that uses its material's optics, one field
each, keeping the rest of each native recipe. A surface's own `optics` or
`blur`, and the held lenses of switches, sliders, segments and tabs, keep
theirs.

Regular and clear glass follow iOS 27's Liquid Glass setting (Settings >
Appearance > Liquid Glass) by default: lower settings show more of the
backdrop, higher ones frost and whiten the glass, and glass updates as soon as
the setting changes. `PrismThemeData(glassTint: .5)` fixes the amount
(0–1) for an app or subtree; null follows the device, then iOS's default 0.5,
the fallback setting. It changes the material's own
frost and white face fill only: an explicit `blur` or `optics` keeps a plain
frost, and held control lenses keep their optics. Other platforms and earlier
iOS versions report no setting, so glass renders at 0.5.

Shapes: `PrismShape.capsule`, `PrismShape.circle`,
`PrismShape.rect(cornerRadius: ...)` for continuous corners, and
`PrismShape.roundedRect(cornerRadius: ...)` for circular corners. A circle is
inscribed in the available rectangle without changing layout dimensions.

## Defaults and precedence

`PrismThemeData` accepts `brightness`, `glass`, `tint`, `foregroundColor`,
`optics`, `blur`, `refraction`, `glassTint`, `shape`, `motion`, and component
styles: `button`, `switchStyle`,
`slider`, `segmentedControl`, `tabBar`, `toolbar`, `search`, shared `lens` and
`controlMotion`.

1. Local `style` fields merge over the component theme; omitted fields inherit.
2. Nested themes merge non-null fields, including nested styles and lenses.
3. Native defaults apply to fields still unspecified.

Keep visual, geometry, optical, motion and haptic overrides in the component
style. Semantic and behavioral inputs remain on widgets. The retained button
`variant`/`size` and toolbar `size` shortcuts take precedence over their style
fields; surfaces retain their direct material and optical configuration.

`PrismTheme(inherit: false, ...)` starts from package defaults. Style
`copyWith` retains a field when an argument is null; to remove an existing override,
construct a new style. Styles' `merge` combines nullable fields individually;
`TextStyle` and nested lenses merge too. Optical packets replace as a whole.
Theme `copyWith` replaces a supplied component style; theme `merge` combines it.

Explicit false and zero count as overrides. For example, local
`PrismSwitchStyle(haptics: true)` beats a component theme that disables haptics,
and `PrismSearchStyle(restingInset: 0)` beats an inherited inset.

For optics, an explicit widget `blur` wins, then its explicit `optics.frost`,
then inherited blur and optical defaults. Shape precedence is explicit `shape`,
explicit `optics.cornerRadius`, inherited `shape`, inherited optical corner radius,
then capsule. Zero blur and `PrismGlass.identity` are explicit choices.

Let child icons and text inherit the ambient style for consistent semantic colors.

## Reusable component styles

```dart
const softLens = PrismLensStyle(shadowOpacity: .06, ringOpacity: .03);
const appDefaults = PrismThemeData(
  lens: softLens,
  slider: PrismSliderStyle(trackHeight: 8, heldScale: 1.6),
  toolbar: PrismToolbarStyle(spacing: 2),
  search: PrismSearchStyle(showCancelButton: false),
);

PrismSlider(
  value: level,
  onChanged: changeLevel,
  style: const PrismSliderStyle(
    width: 240,
    lens: PrismLensStyle(minifyUnderlay: false),
  ),
)
```

`level` and `changeLevel` above belong to your app. Wrap controls in
`PrismTheme(data: appDefaults, child: ...)` to apply shared defaults.
The [style reference](style_reference.md) lists every field with its default.
Use [the runnable example](../example/lib/api_main.dart) for complete state/layout.

| Component | Local configuration | Theme field |
| --- | --- | --- |
| Button | `style: PrismButtonStyle(...)` | `button` |
| Switch | `style: PrismSwitchStyle(...)` | `switchStyle` |
| Slider | `style: PrismSliderStyle(...)` | `slider` |
| Segmented control | `style: PrismSegmentedStyle(...)` | `segmentedControl` |
| Tab bar | `style: PrismTabBarStyle(...)` | `tabBar` |
| Toolbar | `style: PrismToolbarStyle(...)` | `toolbar` |
| Search | `style: PrismSearchStyle(...)` | `search` |
| All lifted lenses | component style's `lens` | `lens` |
| Small-control motion | component style's `motion: PrismControlMotion(...)` | `controlMotion` |

Search typography belongs in `PrismSearchStyle.textStyle`. Style objects configure geometry, colors, contours,
material and optics. Geometry is in logical pixels; `scale` multiplies the
switch/slider/segment dimensions. Text sizing and lens minification are separate.
Parent constraints can limit preferred widths; lifted lenses paint beyond the
resting footprint. Keep room around them and avoid clipping ancestors.

Use `PrismColors.of(context)` for appearance-aware palette values. Callback,
focus/controller ownership, disabled state and input-formatting choices remain
on the widgets. The [component guide](components.md) lists these independently.

## Foreground and tint

| Setting | Effect |
| --- | --- |
| `PrismGlass.tint(color)` | Surface material tint, including alpha |
| Theme `tint` | Semantic accent; also tints prominent buttons |
| Theme `foregroundColor` | Literal ordinary-button and selected-tab accent |
| Button style `foregroundColor` | Per-button literal foreground override |
| Tab style `selectedColor` | Selected icon and label color |
| Tab style `unselectedColor` | Unselected icon and label color |
| Tab style `labelStyle.color` | Independent label color |
| Tab style `selectionColor` | Selection pill fill |

Ordinary buttons use the semantic tint directly, matching native SwiftUI glass
buttons. Selected tabs use `#0697FF` in dark mode and `#0081F5` in light mode for
the default blue tint, measured over the grouped page background. A held dark
tab uses `#27B8FF`; a held light tab uses the semantic tint. Native tab
vibrancy adapts to the backdrop; this fixed palette approximates other backgrounds.
Custom opaque tab tints use an approximate brightness adjustment; translucent
tints and explicit foreground overrides retain their literal values.
Prominent buttons default to white; disabled controls use a muted semantic color.
Explicitly colored icons, styled text, and custom artwork retain their colors.

## Chromatic selection rims

`PrismLensStyle.chromaticAberration` sets the red–blue split at full lift in
points. Segmented selections and tab pills default to 3.5; switch thumbs and
slider knobs default to 0 for this effect. `chromaticBand` sets its inward depth
(default 4.8 points). Neither length scales with lens height. Nullable fields
inherit; explicit 0 disables the fringe, leaving generic optical dispersion
independent. The effect follows lift and the release spring, affects the
backdrop and refracted labels/icons, and is absent at rest.

```dart
const noFringe = PrismLensStyle(chromaticAberration: 0);
const segmentStyle = PrismSegmentedStyle(lens: noFringe);
const tabStyle = PrismTabBarStyle(
  lens: PrismLensStyle(chromaticAberration: 2, chromaticBand: 4.8),
);
```

Shared theme lenses, component themes and local lenses merge field by field.
`refractContent: false` disables both displacement and fringe in the foreground;
`contentRefraction: 0` disables displacement while retaining the fringe.
The tab's `rimRefraction` additionally scales the fringe and glint; disabling
only `chromaticAberration` preserves that glint.

## Navigation

`PrismTabBar` requires at least two tabs, a valid `selectedIndex`, bounded
horizontal space, and an `onSelected` callback. Set the callback to null to disable
activation. The parent can reject a proposed selection by retaining its index.
External selection updates interrupt the current drag. Tapping the selected tab
still invokes the callback.

`PrismTabBarStyle` exposes height, padding, icon size, label style/behavior, selected
and unselected colors, selection color and blur, bar and pill shapes, and haptics.
All fields can be supplied through the app theme and overridden per bar.
`selectionBlur` accepts 0–12 logical pixels and is independent of the enclosing
material's blur. It also applies with a custom selection color. `rimRefraction`
(0–2, default 1) scales the held pill's along-rim fringe in the backdrop and
foreground, plus its bright glint; set it to 0 to turn all three off,
for example in a theme:

```dart
PrismTheme(
  data: const PrismThemeData(
    tabBar: PrismTabBarStyle(rimRefraction: 0),
  ),
  child: app,
)
```

Custom icons are ordinary widgets, including images and SVG widgets supplied by
your app. `selectedIcon` is optional; it is also shown for any tab seen through
the moving pill. Unchanged icon state is retained during tab, style, and
appearance updates.

RTL reverses visual positions. Arrow keys move focus and selection; Space/Enter
activates the focused tab. Hidden visual labels remain available to accessibility.

## Scroll edges and toolbars

`PrismScrollEdgeStyle` (theme field `scrollEdge`, or `style` on
`PrismScrollEdge`, `PrismScrollEdge.fade` and the scaffold's
`scrollEdgeStyle`) sets `sigma`, `falloff`, `extension`, `fadeColor`,
`fadeOpacity`, `revealExtent` and the `spring` scroll fades animate with. A
direct `color` on the widget wins over the style's `fadeColor`. Fields merge
individually; zero is respected (a zero `sigma` fades without blurring).

`PrismToolbarStyle.itemTransition` and `itemTransitionStyle` govern how items
and whole groups arrive and leave; `groupSpacing` is the gap between a
`PrismToolbar`'s capsules; `spacing` sets the gap between items within a capsule.

## Motion

```dart
const motion = PrismMotion(
  response: Duration(milliseconds: 400),
  bounce: 0.15,
  pressResponse: Duration(milliseconds: 290),
  pressBounce: 0.35,
  releaseResponse: Duration(milliseconds: 390),
  releaseBounce: 0.48,
  pressScale: 1.1126,
  dragProjection: 0.12,
);
```

Set `PrismMotion` in button, toolbar and tab-bar styles, or the theme's `motion`.
It controls button press/release and tab travel. Small-control styles instead accept
`PrismControlMotion` so travel, tracking, lift, release, flex and minimum lift
can be overridden independently. See [motion and lenses](motion_and_lenses.md)
for the scope of each field and physical spring support.

The tab pill uses the native large-lens lift and release settings: a 250 ms
response with damping ratio 1, plus the extracted 220 ms hang-time parameter. The lens
grows by 8 pt on each side. The housing expands by approximately 14.14 pt in
width, with the foreground inheriting that transform. The previous inverse
housing scale was incorrect. Travel uses a 400 ms response and 0.85 damping ratio from native selection
animation calls; the exact behavior-to-property mapping remains unresolved.

Tracking, deformation, housing spring timing and glow still use fitted
approximations. Like native, the bar keeps an unselected row and a selected copy
(selected icon, semibold label, selected color) that shows through the pill, and
refracts only that copy. While held in light appearance that copy takes the
plain accent, as native does (0, 136, 255 for system blue), rather than the
darker resting calibration the committed tab uses at rest; in dark it keeps the
lighter resting calibration (native measured 48, 192, 248). It is also
magnified 1.16× about each item, native's held selected item source transform;
both follow the lift. See
[native tab bar spec](../research/specs/native_tab_bar_spec.md) for exact extracted values,
fixture geometry, optical passes and remaining differences.

The housing lens captures the backdrop and bar before the foreground is painted.
A broad outward sampling warp, using the captured
9 pt underlay displacement and 36 pt SDF height, makes the housing visible
through the lifted lens smaller. This is separate from its narrow rim;
the displacement profile still uses this renderer's approximation. A separate
transparent foreground filter uses the native ContentLensingView's −14 pt
displacement and 11.2 pt SDF depth to bend icons and labels near the pill's rim.
Only the selected region is filtered; the flat center retains normal content
size, and the foreground outside the pill remains unchanged. Source bounds,
density, continuous contour and movement are accounted for independently from
the housing's minification. Unsupported shader backends retain the crisp tint
window fallback.
Its rim uses the native lens highlight matrix
without the housing's face grading. The selected copy is painted
wherever the pill is, so the selected icon, weight and tint travel with the
lens. Keep custom icons free of repaint boundaries; the refracted copy has not
been verified with them.

Reduce Motion removes spring travel, overshoot, lift and scale while preserving
direct finger tracking and nonspatial feedback. There is no continuous
animation after interaction settles. Null action callbacks disable activation;
cancellation, removal, and scrolling takeover release feedback.

## Advanced shader optics

```dart
PrismSurface(
  optics: const PrismOptics(
    frost: 3,
    refraction: 18,
    dispersion: 0.12,
    edgeWidth: 12,
    reflection: 0.25,
  ),
  child: content,
)
```

Use `PrismButtonStyle.optics` and `PrismTabBarStyle.optics` for controls,
or `PrismThemeData.optics` for shared defaults.
`PrismOptics` also exposes brightness, face tint, saturation, light,
reflection reach, splay, and corner radius, with `copyWith` and clear/frosted/smoked
presets. Constructor assertions document the accepted ranges. Explicit optical
settings replace the default material recipe.

`PrismSelection` provides just the selected fill/blur treatment for custom
controls. `PrismPressable` provides the lower-level semantic interaction
wrapper; its feedback-only constructor does not create an accessibility action.

## Shared feedback and navigation chrome

Theme `haptics` accepts a `PrismHaptics` callback with typed `PrismHapticEvent`
component/kind. A nested non-null hook replaces the outer hook; component false
silences it. No hook retains native feedback and platform gates. A custom hook
receives switch/slider feedback on all platforms.

Theme `navigationBar` and local `navigationBarStyle` merge field by field in
scaffold and sliver app bars. Explicit text styles on title widgets take
precedence. The SwiftUI toolbar settings map to these Dart APIs.

| SwiftUI | Liquid Prism |
| --- | --- |
| `toolbarTitleDisplayMode` | `PrismNavigationBarStyle.titleDisplayMode` |
| `toolbarTitleAlignment` | `PrismNavigationBarStyle.titleAlignment` |
| `toolbarMinimizationBehavior` | `PrismNavigationBarStyle.minimizationBehavior` |
| `toolbarMinimizationRestoration` | `PrismNavigationBarStyle.minimizationRestoration` |
| `toolbarMinimizationSafeAreaAdjustment` | `PrismNavigationBarStyle.minimizationSafeArea` |
| `toolbarVerticalBehavior` | `PrismSystemChrome.setVerticalBarBehavior` |

For an inline Duo title that comes back only near the top, use:

```dart
const PrismNavigationBarStyle(
  titleDisplayMode: PrismTitleDisplayMode.inline,
  minimizationBehavior: PrismMinimizationBehavior.onScrollDown,
  minimizationRestoration: PrismMinimizationRestoration.atScrollEdge,
)
```

A separate expanded row scrolls with the content. When the scroll passes
`revealExtent`, the large title fades over 200 ms and the compact title rises
with its own spring. Zero swaps on the first positive offset. The Duo rail's
automatic minimization keeps the same title in the control row and restores
it on reversal.

Tab/toolbar `badgeColor` and `badgeTextStyle` resolve local style > component
theme > the measured system red and white. Text-style fields merge individually.
Segmented `sizing: PrismSegmentedSizing.fitLabels` and `labelPadding` inherit
in the same order; explicit width/trackHeight/thumbHeight override fitting.
`resizeToAvoidBottomInset` is a scaffold input, default true, consuming only the
body's bottom viewInset when keyboard height is folded into padding.

[Feature evidence and contracts](../research/specs/package_features_spec.md) lists the measured
values and what remains fitted.

## Composition and placement

Use `PrismButton(label: 'Save', onPressed: save)` for a generated text label.
An optional icon combines with the label using `PrismButtonStyle.labelPlacement`
and `spacing`; `child` replaces generated content. `PrismControlSize` chooses a
native size preset, and `PrismButtonSizing.fill` fills a bounded width.
`alignment`, `minimumSize` and `maximumSize` control the content and visual bounds.
The input area remains at least 44 points when its parent allows it. The button
borrows `focusNode` and accepts `autofocus`, `onFocusChange` and `mouseCursor`.

Set scaffold `toolbar` to a list of typed `PrismToolbarContent`: actions, groups, custom
widgets and spacers. Placement belongs to the content; native menu actions keep
their iOS bridge. Navigation and scaffold styles control title alignment, row
geometry, dock alignment, margins and maximum widths. See the
[1.0 migration guide](migration-1.0.md) and run `example/lib/api_main.dart`
for an interactive example.
