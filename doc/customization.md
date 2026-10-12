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
`optics`, `blur`, `shape`, `motion`, and `tabBar`.

1. Explicit widget arguments override their corresponding theme fields.
2. Nested themes merge each non-null field; omitted values inherit.
3. `LiquidPrismTheme(inherit: false, ...)` starts from package defaults.

For optics, an explicit widget `blur` wins, then its explicit `optics.frost`,
then inherited blur and optical defaults. Shape precedence is explicit `shape`,
explicit `optics.cornerRadius`, inherited `shape`, inherited optical corner radius,
then capsule. Zero blur and `Glass.identity` are explicit choices.

Let child icons and text inherit the ambient style for consistent semantic colors.

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
material's blur. It also applies with a custom selection color.

Custom icons are ordinary widgets, including images and SVG widgets supplied by
your app. `selectedIcon` is optional. Unchanged icon state is retained during tab,
style, and appearance updates.

RTL reverses visual positions. Arrow keys move focus and selection; Space/Enter
activates the focused tab. Hidden visual labels remain available to accessibility.

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

Set this on a theme or an individual control. The defaults combine intercepted tab selection spring parameters with fitted
button motion. `response` and `bounce` move
the tab pill between tabs; `pressResponse`/`pressBounce` grow a held control
and `releaseResponse`/`releaseBounce` let it go, with the native overshoot
and undershoot. `pressScale` is the held size of an ordinary glass button; on
the tab bar it controls the lens lift and housing expansion,
and `pressScale: 1` disables that spatial response while retaining the glow.

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
