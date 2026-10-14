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
`LiquidPrismGroup` shares backdrop captures among its members; see
[rendering](rendering.md). `LiquidPrismScaffold` groups its own chrome.

### Enter and exit

```dart
LiquidPrismVisibility(
  visible: isEditing,
  child: LiquidPrismButton(onPressed: save, child: const Text('Done')),
)
```

`LiquidPrismVisibility` materializes glass in and out, like SwiftUI's
`glassEffectTransition(.materialize)`. The lens, frost, light and shadows grow
from the live backdrop while content fades in and sharpens. The child stays
mounted through its exit, ignores pointers and leaves semantics while hidden,
and is then removed. `GlassTransition.identity` switches instantly; Reduce Motion
uses a short fade. `GlassTransitionStyle` (widget `style` or theme `transition`)
sets `enterSpring`, `exitSpring` and `contentBlur`.

To drive presence yourself (a scroll, a drag), wrap the glass in
`LiquidPrismPresence(progress: animation, child: ...)`. Nested presences multiply.
Never fade glass with an ancestor `Opacity`: it cuts the lens off its backdrop.

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
The whole switch is its thumb: a touch claims the pointer, so a drag at any
angle toggles it, even inside a scroll view.
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

The held knob uses the slider's measured lens inputs: a 6.66-point rim with
11.1 points of refraction, a face black point of .1 that lifts dark backdrops
seen through it, and the contact shadow kept under the lifted knob. Tune them
with `GlassLensStyle.rimWidth`, `rimRefraction`, `rimLight`, `faceBlack` and
`heldContactShadow` in the slider's `lens`; switches and segmented controls
keep their own defaults.

On iOS a light impact plays when a drag, tap, key or accessibility step reaches
the minimum or maximum and the parent accepts that value. It plays once per
arrival: holding against the end is silent until the value leaves it. External
value updates, cancellation and rejected values are silent. Turn it off with
`haptics: false` on the slider (which wins) or `GlassSliderStyle(haptics: false)`.

Touches within the held thumb's half width (28.7 points by default, at least 22)
grab it: the slider claims the pointer, lifts the thumb and follows a drag at
any angle by its horizontal component, so a scroll view around it never takes
that drag and a quick flick needs no hold. The rest of the track is inactive,
as on iOS: holding it lifts and moves nothing, and a mostly vertical drag from
it scrolls an enclosing list. A tap on the track still jumps the value there,
and a horizontal drag from it takes the thumb to the finger and follows.

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

A touch on the selected segment grabs the selection: it claims the pointer,
lifts, and follows a drag at any angle. A touch on another segment behaves as on
iOS: the selection neither lifts nor moves, the touched label dims to .4, a
horizontal drag moves that highlight, and release commits the segment under the
finger while the selection travels there, lifted. A mostly vertical drag from an
unselected segment scrolls an enclosing list and commits nothing.

While the selection is held, labels under its rim bend inward, as on iOS 27;
a label centred in the selection stays still. `GlassSegmentedStyle`'s
`refractContent: false` or `contentRefraction: 0` turns this off, and
`contentDepth` sets the width of the bending band.

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

A touch anywhere on the bar claims the pointer and moves the pill to that tab.
A drag at any angle, or a quick flick without a hold, then moves the pill along
the bar and commits the projected tab on release; an enclosing scroll view does
not take it. A cancelled pointer commits nothing.

Housing material/motion, layout, typography, colors, contours, haptics and independent resting selection
blur are customizable. `lens` customizes the lifted face; `refractContent: false`
or `contentRefraction: 0` disables glyph refraction. `contentDepth` adjusts its
rim region (native defaults 14 displacement / 11.2 depth). `rimRefraction`
(0–2, default 1) sets the held pill's chromatic rim: it splits the pill's view of
the housing per color channel and adds a glint inside its contour, so the pill
stays visible on a dark housing; 0 turns it off. Widget `motion` is
`GlassMotion` for travel, press scale and projection; native lift/flex defaults
remain calibrated separately. Safe-area positioning belongs to the parent.

## Adaptive layout

`LiquidPrismScaffold` places a `tabBar`, top-trailing `actions` and a
`leading` control over a full-window `body`. Each action is a
`GlassToolbarItem` or a list of them: `[share, more]` is one capsule,
`[[filter], [share, more]]` two, and loose items next to each other share a
capsule; an empty list draws nothing and materializes in when it gains an item, and
in the iPhone Duo rail the groups stack or fold into one "More" menu. With no `leading`, a route that
can pop gets a `LiquidPrismBackButton`: a glass back chevron, or a close mark
on a fullscreen dialog, popping through `Navigator.maybePop`. Pass
`automaticallyImplyLeading: false` to suppress it, or your own
`LiquidPrismBackButton(icon: ...)` for a custom glyph.

To use an icon pack's glyphs everywhere, including the implied button, set
them in the theme:

```dart
LiquidPrismThemeData(
  toolbar: GlassToolbarStyle(
    backIcon: Icon(MyIcons.chevronLeft),
    closeIcon: Icon(MyIcons.close),
    // This chevron draws "<" in both text directions.
    backIconMirrors: false,
  ),
)
```

The back glyph is shifted `backIconShift` (.5) points toward its tip so its
mass reads centred; the close mark is not shifted.

| Window | Placement |
| --- | --- |
| iPhone, portrait or landscape | Actions in a 44 pt top bar, tab bar floating 21 pt above the bottom edge |
| iPhone Duo beside its sensor bar, folded or unfolded | Actions and an icon-only tab bar stacked in a 48 pt rail inside that side's safe area |

On iOS 27.1 and later the plugin reports where UIKit itself would put its
bars: `UITraitCollection.verticalBarEdge` picks the rail and its edge
(including the left edge for an app on the left of Split View, and horizontal
bars on the inner display in portrait), and the status bar's reserved region
sets where the rail's actions begin. Elsewhere, `GlassChromePlacement.resolve`
picks the rail when one side's safe area is at least 48 pt deeper than the
other. Pass `placement` to force one. The [adaptive layout
measurements](native_adaptive_layout.md) record the native frames this follows.

The body receives `MediaQuery.padding` that includes the space the chrome
covers plus 14 points below the top bar's capsules, so scroll views keep
content clear while it still shows through the glass. When the device is partly folded, the fold reaches the body as a
`MediaQuery.displayFeatures` entry; `DisplayFeatureSubScreen` keeps content out
of it. Read `LiquidPrismScaffold.placementOf(context)` to adapt your own layout.

When the rail is too short for both the actions and the tab bar, the actions
collapse into one "More" item whose native menu lists them, as native bars do
before compressing the tab bar.

Inside the scaffold, `LiquidPrismTabBar` and the actions group adopt the
placement's axis. Set `axis` on either widget to choose it yourself. A vertical
tab bar is icon-only; labels remain the accessible names. Arrow up and down move
between its tabs, and it reads top to bottom in both text directions.

The scaffold hides a bottom tab bar while the keyboard is up and adds the
keyboard height to the body's bottom padding. Native popup menus close when the
window resizes, as UIKit menus do.

Set `tabBarPlacement: GlassTabBarPlacement.sidebar` to list a
`LiquidPrismTabBar`'s tabs in a leading sidebar while the window has regular
width, such as the unfolded iPhone Duo. Apple suggests it for
information-dense apps. The sidebar is a frosted glass panel over full-width
content. Its toggle slides it away while the content reflows into the space,
with the native spring; a toggle that materializes at the top leading corner
brings it back. As natively, the tabs stay out of the tab bar and rail while the
sidebar is hidden. Reduce Motion skips the slide. Regular width comes from
UIKit's size class on iOS 27.1, or a 700 pt window elsewhere.

### Your own sheets, dialogs and bars

`LiquidPrismSystemChrome` exposes what UIKit reports, so screens that don't use
the scaffold can follow it too. Put it in your app's builder:

```dart
CupertinoApp(
  builder: (context, child) => LiquidPrismSystemChrome(child: child!),
  home: const Home(),
)
```

- Dialogs, popup menus and modal sheets then avoid an active fold: it is added
  to `MediaQuery.displayFeatures`, which Flutter's routes and
  `DisplayFeatureSubScreen` already respect.
- `LiquidPrismSystemChrome.of(context)` returns a `GlassSystemChrome`:
  `verticalBarEdge` (left, right or null), `hasVerticalBar`, and the
  `occlusions` (status bar, camera) and `divisions` (fold) as
  `GlassReservedRegion`s with a frame, interactive margins and an `active`
  flag. Use them to place custom bars or sheet controls on the same edge as the
  system's vertical bar and below the status bar.
- `LiquidPrismSystemChrome.listenable` gives the same report outside widgets.
- A `LiquidPrismScaffold` inside a sheet lays out its own rail too.
- To keep interactive content off a bent fold, read
  `MediaQuery.displayFeaturesOf(context)` for a feature in
  `DisplayFeatureState.postureHalfOpened` and lay out on either side of its
  bounds. The showcase's `LargeTitlePage` splits its sections into two columns
  this way. Scrolling content may cross the fold.

The report is null on other platforms, before iOS 27.1 and without the plugin.

To keep horizontal bars for a screen better served by them, such as a
full-screen video player, use `LiquidPrismViewController` as your Flutter view
controller (in `Main.storyboard`, set the custom class) and call
`LiquidPrismSystemChrome.setVerticalBarBehavior(GlassVerticalBarBehavior.disabled)`.
It returns false where it can't apply. Apple asks that this be a stable choice,
not one that changes as people navigate.

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
key, selected flag and optional literal foreground. A group with one item and
no explicit width is a circle as tall as the bar (44 or 48 points), like a lone
native bar button; give the item a width to keep a wider capsule. Narrow groups scroll rather
than shrink icons. Direct `size` wins over the theme, even when explicitly bottom.
Null callbacks disable individual actions; menu items use `enabled: false`.

Items may come and go: an item added to `items` materializes in while the
capsule widens, and a removed one leaves the same way. Items are matched by
`key`, else by `label`. An empty list materializes the whole capsule away and
draws nothing, so a list whose items all depend on state is fine.
`GlassToolbarStyle.itemTransition: GlassTransition.identity` swaps at once, as
Reduce Motion does; `itemTransitionStyle` sets the springs.

Several capsules in one bar are one `LiquidPrismToolbar`, a list of groups
laid out `spacing` (default 8) apart. Declare every group the bar can show and
let emptiness animate, so groups keep their positions:

```dart
LiquidPrismToolbar(
  size: GlassToolbarSize.navigation,
  groups: [
    [if (hasSuggestions) suggestionsItem],
    [sortItem, moreItem],
  ],
)
```

## Scroll edge effects

iOS softens content scrolled under a bar with a progressive blur and a partial
fade, strongest at the edge and dissolving a little below the bar. The bar's
glass controls refract the content beneath, not the blur.

`LiquidPrismScaffold` draws this effect under its top bar while the body's
outermost scroll view is scrolled, fading toward its `backgroundColor`
(without one, it blurs only). `scrollEdge: false` turns it off and
`scrollEdgeStyle`, or the theme's `scrollEdge`, tunes it. The defaults are
measured from iOS 27's own effect ([spec](native_scroll_edge_spec.md)): a
1.5-point variable blur and a half-opacity fade held over the top third of the
strip and falling along a smoothstep over its last 98 points, a 16-point haze
blended in at half opacity, 50 points of reach below the bar, and a 16-point
scroll over which it arrives (the reveal is this package's; native shows it as
soon as content is beneath).

`GlassScrollEdgeVariant.hard` is the effect under a bar with a background, as
SwiftUI's `.hard` style: it stops at the bar's edge with a one-pixel hairline,
blurs 2 points keeping a quarter of that to the edge, and holds its fade and
haze flat. Give the scaffold an `accessory` (a `PreferredSizeWidget` such as
segmented tabs) to extend the bar below its capsules; the effect and the body's
padding cover it. Together they make a bar like a native navigation bar with a
palette of tabs:

```dart
LiquidPrismScaffold(
  backgroundColor: background,
  scrollEdgeStyle: const GlassScrollEdgeStyle(variant: GlassScrollEdgeVariant.hard),
  accessory: PreferredSize(
    preferredSize: const Size.fromHeight(44),
    child: LiquidPrismSegmentedControl<int>(...),
  ),
  body: ...,
)
```

For a bar of your own, lay `LiquidPrismScrollEdge` in the bar's background,
filling the bar's box with the title and controls painted above it, and drive
`progress` from the scroll offset:

```dart
SliverLayoutBuilder(
  builder: (context, constraints) => SliverAppBar(
    pinned: true,
    backgroundColor: Colors.transparent,
    flexibleSpace: LiquidPrismScrollEdge(
      progress: LiquidPrismScrollEdge.progressFor(constraints.scrollOffset),
      color: Theme.of(context).scaffoldBackgroundColor,
    ),
    leading: LiquidPrismToolbarGroup(size: GlassToolbarSize.navigation, items: [back]),
    actions: [LiquidPrismToolbar(size: GlassToolbarSize.navigation, groups: groups)],
  ),
)
```

Wrap the page (the `CustomScrollView`, or the body around it) in a
`LiquidPrismGroup` so the effect and the bar's capsules share two backdrop
captures and the capsules see through the effect; see
[rendering](rendering.md#shared-captures-and-edge-effects).

`LiquidPrismScrollFade` wraps a scroll view and springs the same blur and fade
in at each edge while content extends past it, with `extent`, `sigma`,
`fadeOpacity` and `plateau` to tune. Both build on `LiquidPrismEdgeBlur`, which
blurs and fades up to two opposite edges of any child per pixel along
`GlassEdgeFade.curve`, a smootherstep whose onset the eye cannot find:

```dart
LiquidPrismEdgeBlur(
  edges: [
    GlassEdgeBlur(edge: GlassEdge.top, extent: 96, sigma: 3, plateau: .35, fadeColor: background),
  ],
  child: pinnedHeaderContent,
)
```

Each strip can also hold a `floor` of strength at its inner end, a `fadeFloor`
for a fade that stays flat, and a `haze`: a heavy blur blended in at
`hazeOpacity`, masked linearly past `hazePlateau`, the way native bars lay a
16-point blur at half opacity under their light variable blur so fine detail
softens without vanishing. Animate by scaling `sigma`, `fadeOpacity` and
`hazeOpacity`; an ancestor `Opacity` does not attenuate a backdrop blur. With
nothing active the widget paints straight through without a layer, so child
state survives. `GlassEdgeFade.gradient` builds the same fade as a plain
`LinearGradient` for decorations.

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
its clear action; `suffixBuilder` can keep or replace it instead. `onCleared` fires after a nonempty field is cleared, alongside
`onChanged('')`. Cancel clears when necessary, unfocuses, then calls `onCancel`.

Style can change text/placeholder colors, icon/cursor/clear colors, geometry,
material, contour, focus spring and clear/cancel action sizing. Direct
`showCancelButton` and `restingInset` override inherited values. Cancel is hidden
when it cannot fit. Cancel shows while the field is focused; on a search screen
of its own, `cancelVisibility: GlassSearchCancelVisibility.always` keeps it
visible and tappable while unfocused, so `onCancel` can close the screen
(tapping it also clears the field). Give search a bounded width and handle keyboard avoidance in
the parent. Native bottom search uses a parent inset of 8 and resting inset of 20.

### Hosting autocomplete

The field owns its glass housing, focus spring, clear and cancel actions. Host
your own suggestions around it with these hooks:

- `fieldBuilder` wraps the glass capsule, excluding the resting inset and the
  cancel action. Its rect is the anchor for a dropdown: wrap the capsule in a
  `CompositedTransformTarget`, `OverlayPortal`, `TapRegion` or `Focus`. It runs
  on rebuilds, not per animation frame. Keep its structure stable; replacing
  ancestors of the field remounts the editor.
- `groupId` is the editor's tap region group. Give the dropdown's `TapRegion` the
  same group so a tap on a suggestion is not outside the field. The cancel
  action always belongs to the group. `onTapOutside` replaces the platform
  default for every other tap.
- `onFocusChange` reports focus transitions, not rebuilds or node swaps.
- `suffixBuilder` receives the field's own clear action, or null while clearing
  is unavailable. Return it, replace it (for example with a progress indicator)
  or return null. A direct `suffix` wins.
- For keys, supply a `focusNode` and set its `onKeyEvent`, or wrap the capsule in
  `Focus(onKeyEvent: ...)` through `fieldBuilder`.

```dart
final link = LayerLink();
final portal = OverlayPortalController();
final group = Object();

LiquidPrismSearchField(
  controller: query,
  focusNode: focus,
  groupId: group,
  onTapOutside: (_) => focus.unfocus(),
  onFocusChange: (focused) => focused ? portal.show() : portal.hide(),
  suffixBuilder: (context, clear) =>
      loading ? const CupertinoActivityIndicator() : clear,
  fieldBuilder: (context, field) => OverlayPortal(
    controller: portal,
    overlayChildBuilder: (context) => CompositedTransformFollower(
      link: link,
      targetAnchor: Alignment.bottomLeft,
      showWhenUnlinked: false,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: TapRegion(groupId: group, child: suggestions),
      ),
    ),
    child: CompositedTransformTarget(link: link, child: field),
  ),
)
```

This snippet omits app state: `query`, `focus`, `loading` and `suggestions`
belong to your widget. Read `link.leaderSize` for the anchor's size, or measure
the capsule with a key placed through `fieldBuilder`.

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

## Tab actions, feedback, badges and navigation titles

Tabs accept `onLongPressed`; a hold uses Flutter's `kLongPressTimeout`, returns
the pill to the selected tab and never selects on release. Use the package
callback instead of an icon GestureDetector. A null `onSelected` disables it.

Set theme `haptics: GlassHaptics((context, event) { ... })` for a shared app
feedback policy. Component `haptics: false` still silences feedback. Null retains
existing native calls. Segmented controls do not generate package haptics.

Text/RichText segments can opt into
`GlassSegmentedStyle(sizing: GlassSegmentedSizing.fitLabels)`; equal widths fit
the widest label and text scaling. Custom widget labels need explicit width.

Add `badge: GlassBadge.count(7)`, `GlassBadge.text('New')` or an empty
`GlassBadge.dot()` to a tab or toolbar item. As on iOS 27, counts are never
shortened (1000 draws `1,000`); pass `overflow: 99` to draw `99+`. The full value
is announced; supply a localized `semanticLabel` (and `GlassBadge.text` for a
locale's digit grouping). Styles expose `badgeColor` and `badgeTextStyle`.

`LiquidPrismScaffold(title: Text('Inbox'), largeTitle: Text('Inbox'), body: list)`
adds a header that follows the outermost vertical scroll view, even with
`scrollEdge: false`: the large title scrolls up with the content and, once its
row has gone, fades out as the inline title rises in, as on iOS 27. Supply only `title` for an inline header. The accessory sits
below the title rows. Keyboard height enters body padding once; the body's
bottom viewInset is consumed. Set `resizeToAvoidBottomInset: false` to delegate
keyboard avoidance to descendants.

See [feature contracts and adoption](package_features_spec.md) for per-item
changes, native measurements and remaining gaps.
