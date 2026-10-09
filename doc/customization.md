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
`rendering`, `optics`, `blur`, `shape`, `motion`, and `tabBar`.

1. Explicit widget arguments override their corresponding theme fields.
2. Nested themes merge each non-null field; omitted values inherit.
3. `LiquidPrismTheme(inherit: false, ...)` starts from package defaults.

For optics, an explicit widget `blur` wins, then its explicit `optics.frost`,
then inherited blur and optical defaults. Shape precedence is explicit `shape`,
explicit `optics.cornerRadius`, inherited `shape`, inherited optical corner radius,
then capsule. Zero blur and `Glass.identity` are explicit choices.

A theme does not override an explicitly styled child's text or artwork. For
consistent semantic colors, let child icons and text inherit the ambient style.

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

Ordinary buttons and selected tabs share the default resting accent on native glass
and iOS 27. Custom shader rendering on earlier platforms uses backdrop-dependent
foreground treatment. Explicit foreground overrides bypass that treatment.
Prominent buttons default to white; disabled controls use a muted semantic color.
Multicolor images and explicitly colored child widgets retain their own pixels.

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
style, and appearance updates within one renderer. Switching between native and
shader composition can remount foreground state.

RTL reverses visual positions. Arrow keys move focus and selection; Space/Enter
activates the focused tab. Hidden visual labels remain available to accessibility.

## Motion

```dart
const motion = GlassMotion(
  response: Duration(milliseconds: 280),
  bounce: 0.18,
  pressResponse: Duration(milliseconds: 140),
  pressScale: 1.08,
  dragProjection: 0.12,
);
```

Set this on a theme or an individual control. Defaults expand ordinary glass
buttons by 10% and the tab pill horizontally by 8%. `pressScale: 1` disables that
horizontal/ordinary-button scale response while retaining nonspatial touch feedback;
the tab pill has a separate subtle vertical contact response.

Reduce Motion removes spring travel, overshoot, and scale while preserving direct
finger tracking and nonspatial feedback. There is no continuous animation after
interaction settles. Null action callbacks disable activation; cancellation,
removal, and scrolling takeover release feedback.

## Advanced shader optics

```dart
LiquidPrism(
  rendering: GlassRendering.shader,
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
settings opt out of native system material adaptation.

`LiquidPrismSelection` provides just the selected fill/blur treatment for custom
controls. `LiquidPrismPressable` provides the lower-level semantic interaction
wrapper; its feedback-only constructor does not create an accessibility action.
