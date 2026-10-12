# Style reference

All style fields are optional. Omission inherits; values below are the resolved
native defaults when neither a local style nor a theme supplies an override.
Lengths are logical pixels. See [customization](customization.md) for precedence
and [components](components.md) for usage.

## Shared lens: `GlassLensStyle`

| Fields | Default / meaning |
| --- | --- |
| `glass` | Clear, with surface interaction disabled (the control owns input) |
| `optics` | Computed native recipe; an override replaces the complete packet |
| `blur` | Zero, or explicit optics' frost; 0–12 |
| `shape` | Capsule; a tab's explicit `selectionShape` takes precedence |
| `minifyUnderlay` | True for switch/segment/tab, false for slider |
| `shadow` / `scaleShadows` | True / true |
| `shadowOpacity` / `shadowBlur` / `shadowOffset` | Lifted ambient shadow: .1 / 5 / (0, 6) |
| `ringOpacity` / `ringBlur` / `ringWidth` / `ringOffset` | Lifted shadow ring: .055 / 4 / 2 / (0, 4) |

Shadow blur/offset/width are reference metrics for a 37.2-point-high lens. They
scale with actual height unless opted out; opacity does not. `shadow: false`
also removes the resting slider shadow. Ambient/ring fields customize lifted
shadows; the resting slider shadow retains its native recipe.

## Buttons: `GlassButtonAppearance`

| Fields | Default / meaning |
| --- | --- |
| `buttonStyle` | `GlassButtonStyle.glass`; prominent is the tinted preset |
| `glass`, `optics`, `blur`, `motion`, `shape` | Component overrides of surface/theme settings |
| `padding` | Standard/menu: horizontal 20, vertical 15; icon: 12 all sides |
| `minimumSize` | Standard/menu: no added minimum; icon: 48×48 |
| `textStyle` | 17-point semibold, merged with surrounding text style |
| `iconSize` | Ambient icon size |
| `foregroundColor` | Calibrated resting accent; prominent defaults white |

An icon button defaults to `GlassShape.circle`. Explicitly colored child content
keeps its own colors. Disabled controls use the semantic disabled label.

## Switches: `GlassSwitchStyle`

| Fields | Default / meaning |
| --- | --- |
| `scale` | 1; multiplies geometry |
| `width`, `trackHeight`, `hitHeight`, `inset` | 63 / 28 / 44 / 2, before scale |
| `thumbSize`, `liftedThumbSize` | 37×24 / 58×38⅓, before scale |
| `activeColor` | Theme tint if supplied, otherwise semantic green |
| `inactiveColor`, `thumbColor` | Tertiary label / white |
| `haptics` | True on iOS user changes |
| `trackShape`, `lens` | Capsule / partial shared-lens override |

Hit width/height remain at least 44. Width must exceed the resting thumb width
plus both insets. Parent layout constraints still apply; leave room for the lens.

## Sliders: `GlassSliderStyle`

| Fields | Default / meaning |
| --- | --- |
| `width`, `scale`, `hitHeight`, `trackHeight` | 300 / 1 / 44 / 6, before scale |
| `thumbSize`, `heldScale` | 37×24 / 1.55; hold scale multiplies both thumb axes |
| `activeColor`, `inactiveColor`, `thumbColor` | Theme accent / semantic slider track / white |
| `trackShape`, `lens` | Capsule / partial shared-lens override |

Preferred width is constrained by the parent; the resting thumb fits narrow widths
proportionally. Hit height stays at least 44. Track fill uses the resting thumb
width for its continuous endpoint blend, even when the held knob grows or flexes.

## Segments: `GlassSegmentedStyle`

| Fields | Default / meaning |
| --- | --- |
| `width`, `scale`, `hitHeight` | 300 / 1 / 44, before scale |
| `trackHeight`, `thumbHeight`, `selectionInset` | 32 / 28 / 2, before scale |
| `liftInset` | (12, 8) extra space on each side, before scale |
| `labelStyle` | 13-point; medium selected, regular unselected |
| `backgroundColor`, `thumbColor` | Tertiary system fill / white |
| `foregroundColor`, `selectedForegroundColor` | Semantic label / black above the resting white pill |
| `trackShape`, `lens` | Capsule / partial shared-lens override |

Segments divide final width equally. `foregroundColor` overrides both label states;
`selectedForegroundColor` applies only to the resting selected label. Child text
and artwork can override ambient styling themselves.

## Tabs: `GlassTabBarStyle`

| Fields | Default / meaning |
| --- | --- |
| `glass`, `optics`, `blur`, `motion` | Housing/travel overrides; lifted optics use `lens` separately |
| `height`, `padding`, `iconSize`, `labelStyle` | 54-point minimum, horizontal 8 / vertical 4 padding, 25-point symbols, 10-point labels with 1.2 line height; text can require greater height |
| `expanded` | False: compact, centered within available width |
| `minimumTabWidth`, `labelPadding` | 86 / 32; spacing uses the widest measured label |
| `labelBehavior` | Always; selected/never hide visual labels, not semantic names |
| `selectedColor`, `unselectedColor` | Calibrated accent / semantic label |
| `selectionColor`, `selectionBlur` | Native resting pill recipe / 2 extra blur, 0–12 |
| `shape`, `selectionShape`, `lens` | Capsule housing / capsule pill / shared-lens override |
| `haptics` | True for user selection feedback |
| `refractContent`, `contentRefraction`, `contentDepth` | True / 14 / 11.2; lifted glyph displacement and rim depth |

Height/content defaults depend on text scale and available width. Set
`selectionShape` to override shared lens shape for this bar. Housing minification
and glyph refraction are separate effects. Tab motion is the widget/theme's
`GlassMotion`; see [motion scope](motion_and_lenses.md).

## Toolbars: `GlassToolbarStyle`

| Fields | Navigation / bottom defaults |
| --- | --- |
| `size` | Bottom unless explicitly navigation |
| `height`, `inset`, `spacing` | 44 / 4 / 16; bottom: 48 / 5 / 14 |
| `iconSize` | 25.5 |
| `foregroundColor`, `pressedColor` | Calibrated accent / 12% semantic label |
| `shape`, `itemShape` | Capsule / capsule |
| `glass`, `optics`, `blur`, `motion` | Component overrides of material/theme settings |

Each `GlassToolbarItem` owns its width (38 default, at least 36), selected state,
label, callback/menu, key and optional foreground. Group spacing is independent.

## Search: `GlassSearchStyle`

| Fields | Default / meaning |
| --- | --- |
| `height`, `restingInset` | 48 minimum, expands for text / 0, dissolves on focus |
| `showCancelButton`, `showClearButton` | True / true; clear requires nonempty enabled input |
| `textStyle`, `placeholderStyle` | 17-point label / secondary label |
| `iconColor`, `cursorColor`, `clearColor` | Label / theme accent / secondary label |
| `iconSize`, `clearWidth` | 20⅓ / 36 |
| `cancelWidth`, `cancelSpacing` | 48 / 12; cancellation hides if it cannot fit |
| `shape`, `glass`, `optics`, `blur` | Capsule and component material overrides |
| `focusSpring` | 380 ms with zero bounce; field focus, shortening and cancel exit |
| `cancelSpring` | 520 ms with 0.22 bounce; cancel slides in, scales up and fades in |

Apply this through search `appearance` or theme `search`. Search `style` remains
its direct editor `TextStyle`. Input configuration, custom prefix/suffix and
controller/focus ownership stay on the widget. A custom suffix replaces clearing.

## Transitions: `GlassTransitionStyle`

| Fields | Default / meaning |
| --- | --- |
| `enterSpring` / `exitSpring` | 450 ms / 300 ms, zero bounce |
| `contentBlur` | 8; content blur at zero presence, 0 fades only |

Defaults are fitted by eye; native materialize timing has not been captured.
Apply through `LiquidPrismVisibility.style` or theme `transition`.

## Motion

`GlassControlMotion` exposes partial travel/tracking/lift/release/flex springs,
minimum lift, flex strength, maximum stretch and velocity decay. `GlassSpring`
accepts duration/bounce or Flutter physics. `GlassMotion` controls button/toolbar
press and tab travel. See [motion and lenses](motion_and_lenses.md) for their
separate scopes, native timings and input guarantees.
