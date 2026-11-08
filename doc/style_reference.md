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
| `ringOpacity` / `ringBlur` / `ringWidth` / `ringOffset` | Lifted shadow ring: .055 / 4 / 2 / (0, 4); slider .2 / 3 / 4 / (0, 8) |
| `chromaticAberration` | Full-lift red–blue split along the rim, in points: segment/tab 3.5, switch/slider 0; explicit 0 off |
| `chromaticBand` | Band depth in points, 4.8; explicit 0 off |
| `rimWidth` / `rimRefraction` | Rim band and its displacement for a 37.2-point lens; defaults are each lens's native rim at its own height: slider 6.66 / 11.1, switch 6.9 / 11.5, segment 7.04 / 8.8, tab pill 7 / 10.5 |
| `rimLight` | Rim key/fill highlight strength at full lift: slider 1, others .6 |
| `faceBlack` | Lens face black point, 0–1: slider .1, others 0 |
| `heldContactShadow` | Keep the resting contact shadow while lifted: slider true, others false |

Shadow blur/offset/width are reference metrics for a 37.2-point-high lens. They
scale with actual height unless opted out; opacity does not. `shadow: false`
also removes the resting slider shadow. Ambient/ring fields customize lifted
shadows; the resting slider shadow retains its native recipe. Rim fields scale
with lens height like shadow metrics and are ignored when `optics` is supplied.
Chromatic split/band do not scale with lens height and remain independent of
`optics`; split scales with lift and surface presence. They affect backdrop and
refracted foreground. Generic optical dispersion is a separate setting.

## Buttons: `GlassButtonStyle`

| Fields | Default / meaning |
| --- | --- |
| `variant` | `GlassButtonVariant.regular`; prominent is the tinted preset |
| `glass`, `optics`, `blur`, `motion`, `shape` | Component overrides of surface/theme settings |
| `padding` | Standard/menu: horizontal 20, vertical 15, matching the native large button's 50.3-point height with a 17-point label; icon: 12 all sides |
| `minimumSize` | Standard/menu: no added minimum; icon: 48×48 |
| `textStyle` | 17-point regular, merged with surrounding text style |
| `iconSize` | Ambient icon size |
| `foregroundColor` | Semantic tint; prominent defaults white |

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
| `refractContent`, `contentRefraction`, `contentDepth` | True / 14 / 11.2; labels bend near the held selection's rim |

Hit width/height remain at least 44. Width must exceed the resting thumb width
plus both insets. Parent layout constraints still apply; leave room for the lens.

## Sliders: `GlassSliderStyle`

| Fields | Default / meaning |
| --- | --- |
| `width`, `scale`, `hitHeight`, `trackHeight` | 300 / 1 / 44 / 6, before scale |
| `thumbSize`, `heldScale` | 37×24 / 1.55; hold scale multiplies both thumb axes |
| `activeColor`, `inactiveColor`, `thumbColor` | Theme accent / semantic slider track / white |
| `trackShape`, `lens` | Capsule / partial shared-lens override |
| `haptics` | True: iOS light impact when user input reaches the minimum or maximum |

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
| `backgroundColor`, `thumbColor` | Tertiary system fill / white in light, translucent gray in dark |
| `foregroundColor`, `selectedForegroundColor` | Semantic label / black in light, white in dark |
| `trackShape`, `lens` | Capsule / partial shared-lens override |

Segments divide final width equally. `foregroundColor` overrides both label states;
`selectedForegroundColor` applies only to the resting selected label. Child text
and artwork can override ambient styling themselves.

## Tabs: `GlassTabBarStyle`

| Fields | Default / meaning |
| --- | --- |
| `glass`, `optics`, `blur`, `motion` | Housing/travel overrides; lifted optics use `lens` separately |
| `height`, `padding`, `iconSize`, `labelStyle` | 54-point minimum, horizontal 8 / vertical 4 padding, 25-point symbols, 10-point labels with 1.2 line height; text can require greater height |
| `sizing` | `GlassTabBarSizing.compact`; `.fill` fills a bounded main axis |
| `minimumTabWidth`, `labelPadding` | 86 / 32; spacing uses the widest measured label |
| `labelBehavior` | Always; selected/never hide visual labels, not semantic names |
| `selectedColor`, `unselectedColor` | Calibrated accent / semantic label |
| `selectionColor`, `selectionBlur` | Native resting pill recipe / 2 extra blur, 0–12 |
| `shape`, `selectionShape`, `lens` | Capsule housing / capsule pill / shared-lens override |
| `haptics` | True for user selection feedback |
| `refractContent`, `contentRefraction`, `contentDepth` | True / 14 / 11.2; lifted glyph displacement and rim depth |
| `rimRefraction` | 1, 0–2; multiplier for along-rim fringe (backdrop and foreground) and bright glint, 0 off |

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
| `backIcon`, `closeIcon` | Back chevron / close mark of `LiquidPrismBackButton` |
| `backIconShift`, `backIconMirrors` | .5 toward the tip / true, the shift mirrors in RTL |

Each `GlassToolbarItem` owns its width (38 default, at least 36), selected state,
label, callback/menu, key and optional foreground. Group spacing is independent.

## Search: `GlassSearchStyle`

| Fields | Default / meaning |
| --- | --- |
| `height`, `restingInset` | 48 minimum, expands for text / 0, dissolves on focus |
| `showCancelButton`, `showClearButton` | True / true; clear requires nonempty enabled input |
| `cancelVisibility` | `focused`; `always` keeps cancel visible and tappable while unfocused |
| `textStyle`, `placeholderStyle` | 17-point label / secondary label |
| `iconColor`, `cursorColor`, `clearColor` | Label / theme accent / secondary label |
| `iconSize`, `clearWidth` | 20⅓ / 36 |
| `padding`, `prefixPadding` | Zero editor padding / 12 start and 8 end around the search icon |
| `cancelWidth`, `cancelSpacing` | 48 / 12; cancellation hides if it cannot fit |
| `shape`, `glass`, `optics`, `blur` | Capsule and component material overrides |
| `focusSpring` | 380 ms with zero bounce; field focus, shortening and cancel exit |
| `cancelSpring` | 520 ms with 0.22 bounce; cancel slides in, scales up and fades in |

Apply this through search `style` or theme `search`. Search `textStyle` overrides
the editor typography directly. Input configuration, custom prefix/suffix and
controller/focus ownership stay on the widget. A custom suffix replaces clearing.
Autocomplete hooks (`fieldBuilder`, `suffixBuilder`, `groupId`, `onTapOutside`,
`onFocusChange`) are widget arguments; see [components](components.md#hosting-autocomplete).

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

## Additional feature styles

| Style / field | Default / meaning |
| --- | --- |
| `GlassSegmentedStyle.sizing` | `fixed`; opt into `fitLabels` for Text/RichText |
| `GlassSegmentedStyle.labelPadding` | Horizontal 10 (measured) / vertical 8, before scale; fit mode only |
| Tab / toolbar `badgeColor` | System red (measured) |
| Tab / toolbar `badgeTextStyle` | 12-point medium, white (measured) |
| `GlassNavigationBarStyle.titleStyle` | 17-point semibold, semantic label |
| `GlassNavigationBarStyle.largeTitleStyle` | 34-point bold, semantic label |
| `titleAlignment` / `largeTitleAlignment` | Centered inline / leading expanded; automatic follows those defaults |
| `gutter` / `controlGap` | 16 / 12 |
| `contentSpacing` | 10 below a standard top bar; 16 in rail/sidebar layouts |
| `minimizationBehavior` | `automatic` (pinned); `never`, `onScrollDown`, `onScrollUp` |
| `minimizationRestoration` | `automatic` restores on reversal; `atScrollEdge` waits for the top with on-scroll-down |
| `minimizationSafeAreaAdjustment` | `automatic` / `disabled` keep content insets stable; `enabled` makes them follow the bar |
| `minimizationThreshold` | Fitted initial travel 13⅓ points, after large-title collapse |
| `titleCapsule` (`GlassTitleStyle`) | `LiquidPrismTitle` geometry: avatar 64, tucked 6 under; capsule at least 38 tall, padding 14 × 9 around the title; leading 22 with `leadingPadding` 12 start, 11 top and bottom, 10 before the title (a 44-point capsule); regular glass (measured from iOS 27 SwiftUI apps' device screenshots) |
| `revealExtent` | The large title's row, 52 at default size (measured); zero swaps on the first pixel |
| `revealSpring` / `hideSpring` | Native-fitted inline fade/rise springs: mass 1, stiffness/damping 225/28.3 entering, 93.3/18.22 leaving |
| `inlineTitleDelay` | Fitted 12 ms onset after the large fade, only when starting at rest; zero disables it |
| `largeTitleFadeDuration` / `largeTitleFadeCurve` | Measured 200 ms / `Curves.easeInOut`; independent of inline springs |

Measured on iOS 27: badges are 18.33-point capsules (18 on toolbar items) with
4 points of padding; a tab badge's leading edge sits 5 points inside the glyph's
trailing edge, its top 24.5 above the glyph's centre; a toolbar badge sits 2.8
points above the capsule and overhangs the item by 3. The icon-only tab pitch is
86, as for labelled tabs.
See [evidence and adoption](package_features_spec.md).

Theme `haptics` replaces native calls with `GlassHaptics`, subject to component
haptics flags. Scaffold titles resolve `navigationBarStyle` above theme
`navigationBar`; scaffold `resizeToAvoidBottomInset` defaults true.

## Composition layout

| Style / fields | Default / meaning |
| --- | --- |
| `GlassButtonStyle.variant`, `size` | Regular glass / large; widget arguments override these |
| `sizing`, `labelPlacement`, `spacing`, `alignment` | Intrinsic / trailing / 8 / center |
| `minimumSize`, `maximumSize` | Native preset minimum / unbounded visual maximum; hit area at least 44 where possible |
| `GlassToolbarStyle.textStyle` | 17-point semibold text actions; labels measure their width |
| `GlassNavigationBarStyle.titleAlignment` | Automatic centers the inline title; explicit leading/trailing remain available |
| `controlRowHeight`, `contentPadding`, `largeTitleExtent` | Native 44 (48 in system rail) / zero / measured typography |
| `GlassScaffoldStyle.tabBarMargin`, `tabBarMaxWidth`, `tabBarAlignment` | Bottom horizontal 24, native bottom gap; explicit top/side 12 all around / 440 / center |
| `bottomBarMargin`, `bottomBarMaxWidth`, `bottomBarAlignment` | Native bottom gap or 8 above tabs / unbounded / center |

Alignment uses the dock's cross axis. Directional insets/alignment follow RTL.
Explicit zero margins replace package gaps. Top/side docks and their body insets
avoid the keyboard; bottom tabs hide while it is open. Custom toolbar content owns
its own gestures and semantics.
