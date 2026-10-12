# Component guide

Import `package:liquid_prism/liquid_prism.dart` and your Flutter widget library.
The snippets below use values and callbacks owned by your widget's State. A
runnable customization example is in `example/lib/api_main.dart`.

## Appearance at three levels

Use direct arguments for small local overrides, component styles for reusable
appearance, and `LiquidPrismThemeData` for shared defaults.

| Widget | Local style | Theme field |
| --- | --- | --- |
| Button | `style: GlassButtonAppearance` | `button` |
| Switch | `style: GlassSwitchStyle` | `switchStyle` |
| Slider | `style: GlassSliderStyle` | `slider` |
| Segmented control | `style: GlassSegmentedStyle` | `segmentedControl` |
| Tab bar | `style: GlassTabBarStyle` | `tabBar` |
| Toolbar | `style: GlassToolbarStyle` | `toolbar` |
| Search | `appearance: GlassSearchStyle` | `search` |
| Every lifted lens | component style's `lens` | `lens` |
| Small-control motion | widget `motion: GlassControlMotion` | `controlMotion` |

See [all style fields and defaults](style_reference.md),
[customization](customization.md) for precedence and [motion/lenses](motion_and_lenses.md)
for the advanced controls. Search's existing `style` argument remains its editor
`TextStyle`; it overrides `appearance.textStyle`.

## Surfaces

```dart
LiquidPrism(
  glass: Glass.clear.tint(GlassColors.of(context).purple.withValues(alpha: .2)),
  shape: const GlassShape.rect(cornerRadius: 28),
  blur: 3,
  child: const Padding(padding: EdgeInsets.all(24), child: Text('A new view')),
)
```

`Glass.regular`, `clear`, and `identity` select a material. Fluent `.tint(null)`
removes tint; `.interactive(false)` removes the surface's own press feedback.
`LiquidPrismStyle` is the complete expert optical packet, with `copyWith` for
modifying refraction, edge width, dispersion, light, reflection, saturation and
blur. An explicit `blur` overrides its frost. `GlassShape.rect` has continuous
corners; `roundedRect` uses circular arcs. `circle` is inscribed in its bounds.
`LiquidPrismGroup` can share compatible captures; see [rendering](rendering.md).

## Buttons

```dart
LiquidPrismButton(
  label: 'Save',
  onPressed: save,
  style: const GlassButtonAppearance(
    buttonStyle: GlassButtonStyle.glassProminent,
    minimumSize: Size(120, 48),
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  ),
  child: const Text('Save'),
)

LiquidPrismButton.icon(
  label: 'Favorite',
  icon: const Icon(CupertinoIcons.heart),
  onPressed: toggleFavorite,
)
```

The icon constructor defaults to a circle and a 48-point minimum extent.
Style overrides include typography, icon size, material, optics, blur, shape,
padding, foreground and motion. A direct `buttonStyle`, `padding` or
`foregroundColor` wins over the style, including explicit defaults. Prominent
buttons default to white text. Null callbacks disable every activation path.
Async callbacks can overlap; set `onPressed: null` while exclusive work runs.

## Switches

```dart
LiquidPrismSwitch(
  label: 'Notifications',
  value: notifications,
  onChanged: (next) => setState(() => notifications = next),
  style: const GlassSwitchStyle(scale: 1.2, haptics: false),
)
```

Scale adjusts visible geometry proportionally; the hit area stays at least
44 points. For independent geometry use `width`, `trackHeight`, `inset`,
`thumbSize` and `liftedThumbSize` (before scale). Width must leave room for the
resting thumb and both insets. Track/lens contours and colors are separate.
`onChangeStart` and `onChangeEnd` optionally report interaction boundaries.

Default iOS haptics fire once on a toggle or each crossed drag boundary. A direct
`haptics` argument wins over the style. Quick taps retain a 220 ms minimum lift.
The default track is 63 × 28; the rest/held thumbs are 37 × 24 and 58 × 38⅓.

## Sliders

```dart
LiquidPrismSlider(
  label: 'Volume',
  value: volume,
  min: 0,
  max: 100,
  divisions: 20,
  semanticFormatterCallback: (value) => '${value.round()} percent volume',
  onChanged: (next) => setState(() => volume = next),
  onChangeEnd: saveVolume,
  style: const GlassSliderStyle(
    trackHeight: 8,
    thumbSize: Size(40, 24),
    heldScale: 1.6,
    lens: GlassLensStyle(shadowOpacity: .07),
  ),
)
```

Parent constraints set the final width; the preferred default is 300. The style
also offers `width`, `scale`, `hitHeight`, colors and a track contour. Narrow
constraints fit the resting thumb proportionally. Values are in your real range;
`divisions` specifies intervals. The formatter receives actual values for current,
increased and decreased semantics. `max == min` disables interaction.

The grabbed thumb follows the finger directly. The fill blends smoothly to the
endpoints across the first/last 2%. Default thumb lift is 1.55×; the track seen
through it keeps its normal thickness. Both are preserved under customization.

## Segmented controls

```dart
LiquidPrismSegmentedControl<String>(
  label: 'Appearance',
  selectedValue: appearance,
  onValueChanged: (next) => setState(() => appearance = next),
  children: const {'light': Text('Light'), 'dark': Text('Dark')},
  style: const GlassSegmentedStyle(
    labelStyle: TextStyle(fontSize: 14),
    selectionInset: 3,
    liftInset: Size(10, 6),
  ),
)
```

Map insertion order determines order. Use two or more unique values and a
selected value in that map. Reordering cancels an obsolete gesture. Each child
can be any widget. Configure preferred width, geometry scale, hit/track/thumb
heights, selection inset, lift inset per side, colors and typography.
Direct color arguments override styles. `onChangeStart`/`onChangeEnd` use your
value type. Touch commits on release; keys and semantics commit immediately.

## Tab bars

```dart
LiquidPrismTabBar(
  selectedIndex: selectedTab,
  onSelected: (next) => setState(() => selectedTab = next),
  tabs: const [
    LiquidPrismTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
    LiquidPrismTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
  ],
  style: const GlassTabBarStyle(labelBehavior: GlassTabLabelBehavior.selected),
)
```

The default compact housing uses the widest measured label, with an 86-point
minimum tab spacing and 32 points of label breathing room. Tune those with
`minimumTabWidth` and `labelPadding`; use `expanded: true` to fill a bounded parent.
Hidden labels still have accessibility names. `selectedIcon` accepts custom
selected artwork. Keep custom icon widgets free of repaint boundaries: the
selection window paints their foreground into two complementary regions.

Housing material/motion, layout, typography, colors, contours, haptics and independent resting selection
blur are customizable. `lens` customizes the lifted face; `refractContent: false`
or `contentRefraction: 0` disables glyph refraction. `contentDepth` adjusts its
rim region (native defaults 14 displacement / 11.2 depth). Widget `motion` is
`GlassMotion` for travel, press scale and projection; native lift/flex defaults
remain calibrated separately. Safe-area positioning belongs to the parent.

## Toolbar groups

```dart
LiquidPrismToolbarGroup(
  size: GlassToolbarSize.navigation,
  style: const GlassToolbarStyle(spacing: 10, iconSize: 24),
  items: [
    GlassToolbarItem(label: 'Previous', icon: const Icon(CupertinoIcons.chevron_left), onPressed: previous),
    GlassToolbarItem(label: 'Next', icon: const Icon(CupertinoIcons.chevron_right), onPressed: next),
  ],
)
```

Navigation/bottom presets are 44/48 points high. Style can override height,
inset, spacing, shapes, colors, material and motion. Each item has its own width,
key, selected flag and optional literal foreground. Narrow groups scroll rather
than shrink icons. Direct `size` wins over the theme, even when explicitly bottom.
Null callbacks disable individual actions; menu items use `enabled: false`.

## Search

```dart
LiquidPrismSearchField(
  controller: searchController,
  focusNode: searchFocus,
  placeholder: 'Search ideas',
  onChanged: filterIdeas,
  onSubmitted: submitSearch,
  onCancel: closeSearch,
  textInputAction: TextInputAction.search,
  appearance: const GlassSearchStyle(height: 52, showClearButton: true),
)
```

Controller/focus nodes are optional; dispose only the ones your app creates.
The widget owns its omitted resources. It supports input formatters, keyboard
type/action, capitalization, suggestions/autocorrect, read-only input, alignment,
editing/tap callbacks and custom prefix/suffix widgets. A supplied suffix replaces
its clear action. `onCleared` fires after a nonempty field is cleared, alongside
`onChanged('')`. Cancel clears when necessary, unfocuses, then calls `onCancel`.

Style can change text/placeholder colors, icon/cursor/clear colors, geometry,
material, contour, focus spring and clear/cancel action sizing. Direct
`showCancelButton` and `restingInset` override inherited values. Cancel is hidden
when it cannot fit. Give search a bounded width and handle keyboard avoidance in
the parent. Native bottom search uses a parent inset of 8 and resting inset of 20.

## Native menus

```dart
LiquidPrismButton.menu(
  label: 'More',
  menu: const LiquidMenu(children: [
    LiquidMenuAction<String>(title: 'Share', value: 'share', icon: LiquidMenuSfSymbol('square.and.arrow.up')),
    LiquidMenuAction<String>(title: 'Delete', value: 'delete', destructive: true),
  ]),
  onSelected: handleMenuValue,
  child: const Text('More'),
)
```

Use `GlassToolbarItem.menu` inside a toolbar or `LiquidMenuRegion` for custom
triggers. UIKit owns the iOS popup; customize its model (symbols, sections,
submenus, selected/disabled/destructive items and deferred actions), not its
renderer. For typed imperative results use `liquidMenus.show<T>`. See the
[menu guide](native_menus.md) for setup and callback/dismissal semantics.
