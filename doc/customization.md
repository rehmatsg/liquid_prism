# Customization

Import `package:liquid_prism/liquid_prism.dart`. The entry point exposes the public
widgets and configuration values; files under `lib/src/` are implementation details.

## Materials and surfaces

```dart
LiquidPrism(
  glass: Glass.clear.interactive(),
  shape: const GlassShape.rect(cornerRadius: 24),
  child: content,
)
```

`Glass.regular` is the standard material; `Glass.clear` is more transparent.
`Glass.identity` draws only the child. `.tint(color)` changes material color;
`.tint(null)` explicitly removes inherited material tint. `.interactive()` adds
spring touch feedback to a surface, without inventing an action. Use
`LiquidPrismButton` for touch, keyboard, and accessibility activation.

Shapes: `GlassShape.capsule`, `GlassShape.circle`,
`GlassShape.rect(cornerRadius: ...)` for continuous corners, and
`GlassShape.roundedRect(cornerRadius: ...)` for circular corners. A circle is
inscribed in the available rectangle without changing layout dimensions.

## Defaults and precedence

`LiquidPrismThemeData` accepts `brightness`, `glass`, `tint`, `foregroundColor`,
`optics`, `blur`, `shape`, `motion`, and component styles: `button`, `switchStyle`,
`slider`, `segmentedControl`, `tabBar`, `toolbar`, `search`, shared `lens` and
`controlMotion`.

1. Explicit widget arguments override the corresponding local style fields.
2. Local styles merge over the component theme; omitted fields inherit.
3. Nested themes merge non-null fields, including nested styles and lenses.
4. Native defaults apply to fields still unspecified.

`LiquidPrismTheme(inherit: false, ...)` starts from package defaults. Style
`copyWith` retains a field when an argument is null; to remove an existing override,
construct a new style. Styles' `merge` combines nullable fields individually;
`TextStyle` and nested lenses merge too. Optical packets replace as a whole.
Theme `copyWith` replaces a supplied component style; theme `merge` combines it.

Explicit false and zero count as overrides. For example, `haptics: true` on a
switch beats a theme that disables haptics, and search `restingInset: 0` beats an
inherited inset. When an older constructor has a default argument, omission still
allows its component style to supply the value.

For optics, an explicit widget `blur` wins, then its explicit `optics.frost`,
then inherited blur and optical defaults. Shape precedence is explicit `shape`,
explicit `optics.cornerRadius`, inherited `shape`, inherited optical corner radius,
then capsule. Zero blur and `Glass.identity` are explicit choices.

Let child icons and text inherit the ambient style for consistent semantic colors.

## Reusable component styles

```dart
const softLens = GlassLensStyle(shadowOpacity: .06, ringOpacity: .03);
const appDefaults = LiquidPrismThemeData(
  lens: softLens,
  slider: GlassSliderStyle(trackHeight: 8, heldScale: 1.6),
  toolbar: GlassToolbarStyle(spacing: 2),
  search: GlassSearchStyle(showCancelButton: false),
);

// A local lens override keeps the shared shadow settings.
LiquidPrismSlider(
  value: level,
  onChanged: changeLevel,
  style: const GlassSliderStyle(
    width: 240,
    lens: GlassLensStyle(minifyUnderlay: false),
  ),
)
```

`level` and `changeLevel` above belong to your app. Wrap controls in
`LiquidPrismTheme(data: appDefaults, child: ...)` to apply shared defaults.
The [style reference](style_reference.md) lists every field with its default.
Use [the runnable example](../example/lib/api_main.dart) for complete state/layout.

| Component | Local configuration | Theme field |
| --- | --- | --- |
| Button | `style: GlassButtonAppearance(...)` | `button` |
| Switch | `style: GlassSwitchStyle(...)` | `switchStyle` |
| Slider | `style: GlassSliderStyle(...)` | `slider` |
| Segmented control | `style: GlassSegmentedStyle(...)` | `segmentedControl` |
| Tab bar | `style: GlassTabBarStyle(...)` | `tabBar` |
| Toolbar | `style: GlassToolbarStyle(...)` | `toolbar` |
| Search | `appearance: GlassSearchStyle(...)` | `search` |
| All lifted lenses | component style's `lens` | `lens` |
| Small-control motion | widget's `motion: GlassControlMotion(...)` | `controlMotion` |

Search's existing `style` argument remains a `TextStyle`; it overrides
`appearance.textStyle`. Style objects configure geometry, colors, contours,
material and optics. Geometry is in logical pixels; `scale` multiplies the
switch/slider/segment dimensions. Text sizing and lens minification are separate.
Parent constraints can limit preferred widths; lifted lenses paint beyond the
resting footprint. Keep room around them and avoid clipping ancestors.

Use `GlassColors.of(context)` for appearance-aware palette values. Callback,
focus/controller ownership, disabled state and input-formatting choices remain
on the widgets. The [component guide](components.md) lists these independently.

## Foreground and tint

| Setting | Effect |
| --- | --- |
| `Glass.tint(color)` | Surface material tint, including alpha |
| Theme `tint` | Semantic accent; also tints prominent buttons |
| Theme `foregroundColor` | Literal ordinary-button and selected-tab accent |
| Button `foregroundColor` | Per-button literal foreground override |
| Tab style `selectedColor` | Selected icon and label color |
| Tab style `unselectedColor` | Unselected icon and label color |
| Tab style `labelStyle.color` | Independent label color |
| Tab style `selectionColor` | Selection pill fill |

Ordinary buttons and selected tabs share the measured resting accent:
`#3BCCFF` in dark mode and `#005DC7` in light mode for the default blue tint.
These displayed colors are distinct from `GlassColors.blue`, the semantic source
used for material tint. Custom opaque tints use an approximate brightness adjustment;
translucent tints and explicit foreground overrides retain their literal values.
Prominent buttons default to white; disabled controls use a muted semantic color.
Explicitly colored icons, styled text, and custom artwork retain their colors.

## Chromatic selection rims

`GlassLensStyle.chromaticAberration` sets the red–blue split at full lift in
points. Segmented selections and tab pills default to 3.5; switch thumbs and
slider knobs default to 0 for this effect. `chromaticBand` sets its inward depth
(default 4.8 points). Neither length scales with lens height. Nullable fields
inherit; explicit 0 disables the fringe, leaving generic optical dispersion
independent. The effect follows lift and the release spring, affects the
backdrop and refracted labels/icons, and is absent at rest.

```dart
const noFringe = GlassLensStyle(chromaticAberration: 0);
const segmentStyle = GlassSegmentedStyle(lens: noFringe);
const tabStyle = GlassTabBarStyle(
  lens: GlassLensStyle(chromaticAberration: 2, chromaticBand: 4.8),
);
```

Shared theme lenses, component themes and local lenses merge field by field.
`refractContent: false` disables both displacement and fringe in the foreground;
`contentRefraction: 0` disables displacement while retaining the fringe.
The tab's `rimRefraction` additionally scales the fringe and glint; disabling
only `chromaticAberration` preserves that glint.

## Navigation

`LiquidPrismTabBar` requires at least two tabs, a valid `selectedIndex`, bounded
horizontal space, and an `onSelected` callback. Set the callback to null to disable
activation. The parent can reject a proposed selection by retaining its index.
External selection updates interrupt the current drag. Tapping the selected tab
still invokes the callback.

`GlassTabBarStyle` exposes height, padding, icon size, label style/behavior, selected
and unselected colors, selection color and blur, bar and pill shapes, and haptics.
All fields can be supplied through the app theme and overridden per bar.
`selectionBlur` accepts 0–12 logical pixels and is independent of the enclosing
material's blur. It also applies with a custom selection color. `rimRefraction`
(0–2, default 1) scales the held pill's along-rim fringe in the backdrop and
foreground, plus its bright glint; set it to 0 to turn all three off,
for example in a theme:

```dart
LiquidPrismTheme(
  data: const LiquidPrismThemeData(
    tabBar: GlassTabBarStyle(rimRefraction: 0),
  ),
  child: app,
)
```

Custom icons are ordinary widgets, including images and SVG widgets supplied by
your app. `selectedIcon` is optional. Unchanged icon state is retained during tab,
style, and appearance updates.

RTL reverses visual positions. Arrow keys move focus and selection; Space/Enter
activates the focused tab. Hidden visual labels remain available to accessibility.

## Scroll edges and toolbars

`GlassScrollEdgeStyle` (theme field `scrollEdge`, or `style` on
`LiquidPrismScrollEdge`, `LiquidPrismScrollFade` and the scaffold's
`scrollEdgeStyle`) sets `sigma`, `falloff`, `extension`, `fadeColor`,
`fadeOpacity`, `revealExtent` and the `spring` scroll fades animate with. A
direct `color` on the widget wins over the style's `fadeColor`. Fields merge
individually; zero is respected (a zero `sigma` fades without blurring).

`GlassToolbarStyle.itemTransition` and `itemTransitionStyle` govern how items
and whole groups arrive and leave; `groupSpacing` is the gap between a
`LiquidPrismToolbar`'s capsules, below a direct `spacing`.

## Motion

```dart
const motion = GlassMotion(
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

Set `GlassMotion` on buttons, toolbar groups, tab bars, or the theme's `motion`.
It controls button press/release and tab travel. Small controls instead accept
`GlassControlMotion` so travel, tracking, lift, release, flex and minimum lift
can be overridden independently. See [motion and lenses](motion_and_lenses.md)
for the scope of each field and physical spring support.

The tab pill uses the native large-lens lift and release settings: a 250 ms
response with damping ratio 1, plus the extracted 220 ms hang-time parameter. The lens
grows by 8 pt on each side. The housing expands by approximately 14.14 pt in
width, with the foreground inheriting that transform. The previous inverse
housing scale was incorrect. Travel uses a 400 ms response and 0.85 damping ratio from native selection
animation calls; the exact behavior-to-property mapping remains unresolved.

Tracking, deformation, housing spring timing and glow still use fitted
approximations. The native implementation has separate medium and semibold
foreground copies and magnifies the selected portal while held. Our selection
window now refracts its foreground separately, while the exact native source
weight/scale transition remains approximate. See
[native tab bar spec](native_tab_bar_spec.md) for exact extracted values,
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
without the housing's face grading. The selected tint is painted
wherever the pill is, so it travels with the lens. Icons must not contain
repaint boundaries because that window paints them a second time.

Reduce Motion removes spring travel, overshoot, lift and scale while preserving
direct finger tracking and nonspatial feedback. There is no continuous
animation after interaction settles. Null action callbacks disable activation;
cancellation, removal, and scrolling takeover release feedback.

## Advanced shader optics

```dart
LiquidPrism(
  optics: const LiquidPrismStyle(
    frost: 3,
    refraction: 18,
    dispersion: 0.12,
    edgeWidth: 12,
    reflection: 0.25,
  ),
  child: content,
)
```

The same `optics` argument is available on buttons, tab bars, and themes.
`LiquidPrismStyle` also exposes brightness, face tint, saturation, light,
reflection reach, splay, and corner radius, with `copyWith` and clear/frosted/smoked
presets. Constructor assertions document the accepted ranges. Explicit optical
settings replace the default material recipe.

`LiquidPrismSelection` provides just the selected fill/blur treatment for custom
controls. `LiquidPrismPressable` provides the lower-level semantic interaction
wrapper; its feedback-only constructor does not create an accessibility action.
