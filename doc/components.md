# Component guide

Import `package:liquid_prism/liquid_prism.dart`, `package:flutter/material.dart`
and `package:flutter/cupertino.dart` for the examples below.
Also import `package:liquid_prism/primitives.dart` for examples using
`PrismOptics`, `PrismLensStyle`, `PrismEdgeBlur`, `PrismEdgeBlurStrip`,
`PrismEdgeFade`, `PrismSystemChrome` or `PrismTabReselection`.
The snippets below use values and callbacks owned by your widget's State. A
runnable customization example is in `example/lib/api_main.dart`.

## Appearance at three levels

Keep semantic and behavioral inputs on widgets. Put visual, optical, geometry,
motion and haptic overrides in immutable `Prism*Style` objects, and use
`PrismThemeData` for shared defaults.

| Widget | Local style | Theme field |
| --- | --- | --- |
| Button | `style: PrismButtonStyle` | `button` |
| Switch | `style: PrismSwitchStyle` | `switchStyle` |
| Slider | `style: PrismSliderStyle` | `slider` |
| Segmented control | `style: PrismSegmentedStyle` | `segmentedControl` |
| Tab bar | `style: PrismTabBarStyle` | `tabBar` |
| Toolbar | `style: PrismToolbarStyle` | `toolbar` |
| Search | `style: PrismSearchStyle` | `search` |
| Every lifted lens | component style's `lens` | `lens` |
| Small-control motion | component style's `motion: PrismControlMotion` | `controlMotion` |

See [all style fields and defaults](style_reference.md),
[customization](customization.md) for precedence and [motion/lenses](motion_and_lenses.md)
for the advanced controls. Search typography belongs in `PrismSearchStyle.textStyle`.

### Typography

Every Prism label and title resolves its text style in the same order: native
iOS metrics, then the app font, then `PrismThemeData.textStyle`, then the
component style's text style, then the local `style`.

- The app font is the family from `ThemeData.textTheme.bodyMedium` under a
  Material theme, or from `CupertinoThemeData.textTheme.textStyle` otherwise.
  The system San Francisco families leave the native faces untouched.
- Labels do not inherit the ambient `DefaultTextStyle`, so they render correctly
  without a `Material` ancestor.
- Sizes and weights stay native unless a theme or style sets them.

```dart
PrismTheme(
  data: const PrismThemeData(
    textStyle: TextStyle(fontFamily: 'Inter'),
    button: PrismButtonStyle(
      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  child: app,
)
```

On a prominent button, a local `PrismButtonStyle.tintColor` wins over
`destructive`, and `destructive` wins over a tint set in the theme.

## Surfaces

```dart
PrismSurface(
  glass: PrismGlass.clear.tint(PrismColors.of(context).purple.withValues(alpha: .2)),
  shape: const PrismShape.rect(cornerRadius: 28),
  blur: 3,
  child: const Padding(padding: EdgeInsets.all(24), child: Text('A new view')),
)
```

`PrismGlass.regular`, `clear`, and `identity` select a material. Fluent `.tint(null)`
removes tint; `.interactive(false)` removes the surface's own press feedback.
`PrismOptics` is the complete expert optical packet, with `copyWith` for
modifying refraction, edge width, dispersion, light, reflection, saturation and
blur. An explicit `blur` overrides its frost. `PrismShape.rect` has continuous
corners; `roundedRect` uses circular arcs. `circle` is inscribed in its bounds.
`PrismGroup` shares backdrop captures among its members; see
[rendering](rendering.md). `PrismScaffold` groups its own chrome.

Set `PrismSurface(shadow: false)` to suppress exterior and inset material
shadows while retaining rim lighting, or set `PrismThemeData(shadow: false)`
for a subtree. Widget values override the theme. Lifted control lens shadows
have their separate `PrismLensStyle.shadow` setting.

### Enter and exit

```dart
PrismVisibility(
  visible: isEditing,
  child: PrismButton(label: 'Done', onPressed: save),
)
```

`PrismVisibility` materializes glass in and out, like SwiftUI's
`glassEffectTransition(.materialize)`. The lens, frost, light and shadows grow
from the live backdrop while content fades in and sharpens. The child stays
mounted through its exit, ignores pointers and leaves semantics while hidden,
and is then removed. `PrismTransition.identity` switches instantly; Reduce Motion
uses a short fade. `PrismTransitionStyle` (widget `style` or theme `transition`)
sets `enterSpring`, `exitSpring` and `contentBlur`.

To drive presence yourself (a scroll, a drag), wrap the glass in
`PrismVisibility.driven(progress: animation, child: ...)`. Nested presences multiply.
Never fade glass with an ancestor `Opacity`: it cuts the lens off its backdrop.

## Buttons

```dart
PrismButton(
  label: 'Save',
  onPressed: save,
  style: const PrismButtonStyle(
    variant: PrismButtonVariant.prominent,
    minimumSize: Size(120, 48),
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  ),
  child: const Text('Save'),
)

PrismButton.icon(
  label: 'Favorite',
  icon: const Icon(CupertinoIcons.heart),
  onPressed: toggleFavorite,
)

PrismButton(
  label: 'Delete',
  style: const PrismButtonStyle(size: PrismControlSize.small),
  icon: const Icon(CupertinoIcons.trash),
  destructive: true,
  autoLoading: true,
  onPressed: deleteDraft,
)
```

The icon constructor defaults to a circle and a 48-point minimum extent.
Style overrides include typography, icon size, material, optics, blur, shape,
padding, foreground and motion belong in `PrismButtonStyle`. The retained
`variant` and `size` widget shortcuts override their style fields. Prominent
buttons default to white text and use a neutral material tint while disabled.
Null callbacks and `enabled: false` disable every activation path.
`isLoading`, or `autoLoading` while the future `onPressed` returns is pending,
swaps the content for an activity indicator in the same space and ignores
activation while keeping its colors, focus and enabled semantics;
`PrismButtonStyle.loadingIndicator` replaces the built-in indicator. Without either, async callbacks can
overlap. `destructive` draws the system red as a regular button's foreground
and a prominent button's tint, over a component theme's foreground (the
local style's `foregroundColor` still wins); style `tintColor` tints the glass directly. `icon`
sits beside the label at the style's `labelPlacement` and `trailingIcon`
follows both. `onLongPress` plays the theme's long-press haptic
(`PrismHapticComponent.button`) and wins over the tap once recognized.
`semanticLabel` replaces the accessible name. Every button keeps a 44-point
hit area, so `PrismControlSize.small` (28 points) suits text actions in a
bar's `trailing` slot.

## Switches

```dart
PrismSwitch(
  label: 'Notifications',
  value: notifications,
  onChanged: (next) => setState(() => notifications = next),
  style: const PrismSwitchStyle(scale: 1.2, haptics: false),
)
```

Scale adjusts visible geometry proportionally; the hit area stays at least
44 points. For independent geometry use `width`, `trackHeight`, `inset`,
`thumbSize` and `liftedThumbSize` (before scale). Width must leave room for the
resting thumb and both insets. Track/lens contours and colors are separate.
`onChangeStart` and `onChangeEnd` optionally report interaction boundaries.

Default iOS haptics fire once on a toggle or each crossed drag boundary.
Set `PrismSwitchStyle(haptics: false)` to disable them locally. Quick taps retain
a 220 ms minimum lift.
The whole switch is its thumb: a touch claims the pointer, so a drag at any
angle toggles it, even inside a scroll view.
The default track is 63 × 28; the rest/held thumbs are 37 × 24 and 58 × 38⅓.

## Sliders

```dart
PrismSlider(
  label: 'Volume',
  value: volume,
  min: 0,
  max: 100,
  divisions: 20,
  semanticFormatterCallback: (value) => '${value.round()} percent volume',
  onChanged: (next) => setState(() => volume = next),
  onChangeEnd: saveVolume,
  style: const PrismSliderStyle(
    trackHeight: 8,
    thumbSize: Size(40, 24),
    heldScale: 1.6,
    lens: PrismLensStyle(shadowOpacity: .07),
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
with `PrismLensStyle.rimWidth`, `rimRefraction`, `rimLight`, `faceBlack` and
`heldContactShadow` in the slider's `lens`. Switches, segmented controls and the
tab pill default to their own native rims (11.5 / 6.9, 8.8 / 7.04 and
10.5 / 7 points of refraction / band).

On iOS a light impact plays when a drag, tap, key or accessibility step reaches
the minimum or maximum and the parent accepts that value. It plays once per
arrival: holding against the end is silent until the value leaves it. External
value updates, cancellation and rejected values are silent. Turn it off with
`PrismSliderStyle(haptics: false)` in the slider's `style`.

Touches within the held thumb's half width (28.7 points by default, at least 22)
grab it: the slider claims the pointer, lifts the thumb and follows a drag at
any angle by its horizontal component, so a scroll view around it never takes
that drag and a quick flick needs no hold. The rest of the track is inactive,
as on iOS: holding it lifts and moves nothing, and a mostly vertical drag from
it scrolls an enclosing list. A tap on the track still jumps the value there,
and a horizontal drag from it takes the thumb to the finger and follows.

## Segmented controls

```dart
PrismSegmentedControl<String>(
  label: 'Appearance',
  selectedValue: appearance,
  onValueChanged: (next) => setState(() => appearance = next),
  children: const {'light': Text('Light'), 'dark': Text('Dark')},
  style: const PrismSegmentedStyle(
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
Set colors in `PrismSegmentedStyle`; local fields override the component theme. `onChangeStart`/`onChangeEnd` use your
value type. Touch commits on release; keys and semantics commit immediately.

A touch on the selected segment grabs the selection: it claims the pointer,
lifts, and follows a drag at any angle. A touch on another segment behaves as on
iOS: the selection neither lifts nor moves, the touched label dims to .4, a
horizontal drag moves that highlight, and release commits the segment under the
finger while the selection travels there, lifted. A mostly vertical drag from an
unselected segment scrolls an enclosing list and commits nothing.

While the selection is held, labels under its rim bend inward, as on iOS 27;
a label centred in the selection stays still. `PrismSegmentedStyle`'s
`refractContent: false` or `contentRefraction: 0` turns this off, and
`contentDepth` sets the width of the bending band.

## Tab bars

```dart
PrismTabBar(
  selectedIndex: selectedTab,
  onSelected: (next) => setState(() => selectedTab = next),
  tabs: const [
    PrismTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
    PrismTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
  ],
  style: const PrismTabBarStyle(labelBehavior: PrismTabLabelBehavior.selected),
)
```

The default compact housing uses the widest measured label, with an 86-point
minimum tab spacing and 32 points of label breathing room. Tune those with
`minimumTabWidth` and `labelPadding`; use `sizing: PrismTabBarSizing.fill` to fill a bounded parent.
Hidden labels still have accessibility names. `selectedIcon` accepts custom
selected artwork, shown for the selected tab and for any tab seen through the
moving pill. While the pill is held or moving, the bar builds a display-only
selected copy of every tab for the inside of the pill, so a stateful icon can
briefly have two instances. Keep custom icon widgets free of repaint boundaries.

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
stays visible on a dark housing; 0 turns it off. Style `motion` is
`PrismMotion` for travel, press scale and projection; native lift/flex defaults
remain calibrated separately. Safe-area positioning belongs to the parent.

## Scrolling pages

Pass `slivers:` instead of `body:` and the scaffold builds the scroll view:

```dart
PrismScaffold(
  title: const Text('Applications'),
  largeTitle: const Text('Applications'),
  toolbar: [PrismToolbarGroup(items: [filter]), PrismToolbarGroup(items: [sort, search])],
  onRefresh: reload,
  bottomBar: PrismButton(label: 'Save', onPressed: save),
  slivers: [
    SliverList.builder(
      itemCount: 30,
      itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
    ),
  ],
)
```

It pads the content below the bar, large title and accessory and above the tab
bar, `bottomBar` and keyboard; follows the scroll for the edge effects and the
large title; and dismisses the keyboard on drag. `scrollController` hands the
page its controller. Pinned `SliverPersistentHeader`s pin below the bar, and
`SliverFillRemaining` fills the space between the insets, for empty and error
states. `bottomBar` pins a bar above the home indicator, tab bar or keyboard;
content under it takes a bottom scroll edge effect in the same glass group as
the top one. That edge follows the bar's laid-out height, so a bar that
collapses to nothing (a presence animation kept mounted) fades its edge out
over its last `revealExtent` points (16 by default) and draws none at zero height. Like a Material `bottomNavigationBar`, it is offered the screen's
height and must size to its content: an `Align` or a presence animation that
fills its constraints would cover the page, so wrap one in
`Column(mainAxisSize: MainAxisSize.min)`. A `body` still works for content that builds its own scrollable:
the insets arrive as `MediaQuery.padding`. When that body's lists sit one level
down, as in a tab view, pass `scrollDepth: 1`.

### Pull to refresh

`onRefresh` is the whole API, for `slivers` and for a `body`:

```dart
PrismScaffold(
  title: const Text('Inbox'),
  onRefresh: () => inbox.reload(),
  slivers: [
    SliverList.builder(
      itemCount: 30,
      itemBuilder: (context, index) => ListTile(title: Text('Message $index')),
    ),
  ],
)
```

With a compact title or accessory-only header, pulling scales and fades a circle
into the gap below the entire header (including search, filters and tabs). The
body holds that gap while refreshing and returns when the indicator disappears.
The presentation is selected at the start of the pull; a collapsed large title
does not change the page's presentation.

With a large title, scrolling custom header, or no top chrome, pulling the content
down draws a black drop out of the Dynamic Island, or out
of the notch on iPhones that have one. Where the window has neither (iPhone
Duo, a sheet, landscape, other platforms) it comes out of the top edge.
In dark appearance, a thin translucent white outline separates the emerging
drop and detached circle from dark content. It does not outline the sensor
housing itself.

1. The drop holds a ring that fills clockwise from the top as the pull grows.
2. Once the ring is whole the drop pinches off into a circle that swells and
   breathes while it is held: a release will now refresh. Pulling back merges
   it into its anchor again.
3. Released, the circle rests level with the bar's controls and spins until
   the future completes.
4. The ring closes into a white disc with a check, then the circle merges back.

The drop floats over the chrome and never moves the content, and it ignores a
pull while a refresh is already running.

**Start it from code.** Give the scaffold a `PrismRefreshController` to
refresh without a pull, such as when a tab is tapped again. The drop leaves its
anchor, pinches off and spins exactly as after a released pull:

```dart
final refresh = PrismRefreshController();

PrismScaffold(
  onRefresh: feed.reload,
  refreshController: refresh,
  slivers: const [SliverToBoxAdapter(child: Text('Feed'))],
)

await refresh.refresh();
final isRefreshing = refresh.isRefreshing;
```

`refresh()` joins a refresh already running. The controller notifies listeners
when `isRefreshing` changes; dispose it when its owner is disposed.

**Report a failure.** A callback whose future completes with `false`, such as
`() => feed.reload()` for a `Future<bool> reload()`, or one that throws, ends
without the check and without the success haptic: the spinner just returns.
Any other value, or none, is a success.

**Turn it on and off freely.** `onRefresh: canRefresh ? reload : null` keeps
the page's scroll position, focus and bar when it changes; the scaffold builds
the same tree either way.

**Haptics** mark four moments on iOS and Android: the drop starting to leave
its anchor, the pinch-off, releasing an armed pull, and a successful completion.
They go through the theme's `PrismHaptics` hook when you set one, as
`PrismHapticComponent.refresh` events of kind `refreshPulled`, `refreshArmed`,
`refreshReleased`, `refreshSucceeded` and `refreshFailed` (silent by default),
so an app can route them through its own
haptics setting or drop them.

`refreshReleased` plays a light impact by default. It fires once when an armed
pull is released, not for a programmatic refresh or a pull released below the
arming threshold. Consumers with exhaustive switches over `PrismHapticKind`
must handle this event when updating.

```dart
PrismThemeData(
  haptics: PrismHaptics((context, event) => appHaptics.play(event)),
)
```

It follows the scroll view that drives the bar (`scrollDepth`). `slivers` can
always be pulled; a `body` scroll view shorter than the window needs
`AlwaysScrollableScrollPhysics`. The indicator owns its animation resources; an
app-created refresh controller remains app-owned. The indicator is always black,
and its position follows the device and header layout.
`PrismSystemChrome.dynamicIsland` reports the island's frame, or null,
for your own island-anchored effects.

`header:` puts your own heading at the top of the slivers, such as a detail
page's icon and title; it scrolls away under the bar and the inline `title`
fades in once it has, as after a large title. The large title fades over 200 ms
with ease-in-out timing. The inline title fades and rises 15 points with separate
native-fitted reveal/hide springs (`revealSpring` and `hideSpring`).

Automatic inline titles center when they fit between the controls, then align
to the leading edge when crowded to use the available space before truncating.
They lead by default when the bar has more than one action (toolbar items and a
`trailing` widget, in the bar or on the rail), and on the folded iPhone Duo
outside sheets; sheets there, the unfolded Duo and other iPhones center.
`PrismTitle` glass capsules retain their centered default. Set `titleAlignment`
to `leading`, `center` or `trailing`; directional alignment mirrors in RTL.
`largeTitleAlignment` independently controls the expanded title, leading by default.
Title widgets keep their own pointer and keyboard input. Only the active title
participates in focus and accessibility.

Use `PrismNavigationBarStyle.titleDisplayMode` with either scaffold or sliver
bars. The four values correspond to SwiftUI's toolbar title modes.

| Mode | iPhone Duo with a vertical bar | Horizontal bar |
| --- | --- | --- |
| `automatic` | Large type in the control row | Uses the supplied title widgets. The Duo's horizontal layout also expands a single text title. |
| `inline` | Compact type in the control row | Compact type in the control row |
| `inlineLarge` | Large type in the control row | Large type in the control row |
| `large` | Large type in the control row | Large type in a separate row beneath the controls |

On the Duo rail, large titles use 28-point bold type, or 22 points with an
11-point subtitle. Compact titles use 17-point semibold type, or 15 points with
a 12-point subtitle. The measured title row is 58 points. Text styles, row
height, padding, spacing and alignment still accept overrides. An explicit
`largeTitleExtent` with a supplied `largeTitle` keeps a separate expanded row in
automatic mode. Use `PrismSystemChrome.setVerticalBarBehavior` to select
the system's automatic or disabled vertical-bar behavior.

Automatic minimization hides a titled rail bar as content advances and brings
the same title back on reversal, including in sheets. Horizontal bars and
scaffolds with a custom `header` stay pinned automatically. A custom header's
compact title appears when the header crosses the bar. `never` pins the bar and lets an in-row large title
switch to compact type as content advances. Use `onScrollDown` to specify the
hide direction yourself. Pair it with `atScrollEdge` to return with the content
top. Automatic rail minimization follows the system's reversal behavior.
`onScrollUp` hides the bar when scrolling back toward the top and restores it
at the top or when content advances again.

Rail safe-area adjustment follows the bar by default. The folded Duo fixture
goes from 82 points of pinned clearance to 24 when minimized. The leading
scroll extent stays fixed, so the rows travel with the gesture while the
pinned clearance adjusts. A caller-owned `body` receives stable top padding
for the same reason. Horizontal bars keep fixed clearance by default. Use
`enabled` or `disabled` to choose the pinned clearance behavior explicitly.

A bar that hides on scroll down moves off-screen at full presence. The
scaffold's top edge shrinks to the status-bar edge where present and grows back
with the bar on reveal. On the outer Duo display the bar-owned edge disappears
with the bar. Rail controls in a scaffold remain fixed and accessories stay
interactive at the top. The Duo keeps 16 points between a top accessory and the
body by default, which `contentSpacing` can override. A top-docked tab bar follows the
navigation bar. Other docks remain independent. Minimization is scroll-driven
and also works with `scrollEdge: false`. Use `header` for custom page content
that scrolls away below the navigation bar. See [the measurements](../research/specs/navigation_bar_spec.json).

`trailing:` places a widget of your own before the action capsules, such as a
credits pill or a counter, centred on the control row 8 points from the first
capsule (or at the trailing edge without actions). An interactive heading, such
as a feed switcher with a menu, can use `title` or `leading`. The leading slot
takes any widget, bounded by the
actions and `trailing`, 12 points before them, so a long label ellipsizes
rather than running under them. An inline title taller than the bar's row,
such as a logo beside two lines at a large text size, scales down to fit the
row instead of overflowing it.

A text button in glass, such as Invite, also goes in `trailing:`; it stays in
the top bar on iPhone Duo, where only the icon actions move to the rail, and
there ends at the content's edge, the rail's 12 points from its column.

Toolbar items split the same way on a vertical rail, as SwiftUI's do: an item
with an icon moves into the rail, and a text-only item or custom widget stays
in a horizontal bar. A text `topLeading` item, such as Select All, keeps the
top bar's leading edge and a text `topTrailing` item, such as Done, its
trailing edge, each in the bar's own glass capsule. Bottom items that move
sit at the rail's bottom, a gap above any tab bar there, keeping their groups,
while the rest keep the bottom bar, as Photos keeps a "Show Selected" label
below its grid while Share and Delete move into the rail. A group moves only
when all of its items can, so related items share an axis. Override the
inference with `PrismToolbarItem(axisBehavior:)`, as SwiftUI's
`axisBehavior(_:)`: `horizontalOnly` for an item whose label alternates
between a symbol and text, `verticalPreferred` for a custom widget with a good
vertical form. Flexible spacers collapse on the rail; fixed spacers keep their
extent.

`hiddenScrollEdges` drops the scroll edge effect on the edges it names, as
SwiftUI's `scrollEdgeEffectHidden(_:for:)`: `{PrismEdge.bottom}` for a
floating selection bar whose glass needs no fade beneath it. `scrollEdge:
false` still turns both edges off.

### Glass titles and avatars

Changing `avatar` or `leading` animates between the above-avatar, inline-avatar,
and title-only layouts with the shared spring. When moving between the above
and inline positions, one avatar stays mounted and animates its position and
size with one visible overshoot (300 ms spring response, 0.22 bounce).
The capsule and scaffold use the same timing. The avatar child is laid out
at its declared destination slot size, so its own corner geometry remains
proportional; its painted size follows the transition while its state stays
mounted. It fades only when entering or leaving the title-only layout. The scaffold animates its title
height with the composition, including accessory and body placement. Keep the
same title widget identity to preserve the transition; rapid changes retarget the
spring, and Reduce Motion snaps to the new layout. The Conversation showcase
cycles through all three by tapping its title.

`PrismTitle` puts the title in a glass capsule, as SwiftUI chat and
contact screens do. `child` is the title (usually `Text`, or any widget),
`leading` sits inside the capsule before it (a small avatar), and `avatar` sits
above it, with the capsule tucked 6 points under (a conversation header). Each
is optional except the title; `onPressed` makes the whole capsule one button.

```dart
PrismScaffold(
  title: PrismTitle(
    avatar: ClipOval(child: Image.asset('friday.png')),
    onPressed: openContact,
    child: const Text('Friday'),
  ),
  toolbar: [PrismToolbarItem(icon: const Icon(CupertinoIcons.phone), label: 'Call', onPressed: call)],
  body: conversation,
)

PrismScaffold(
  title: PrismTitle(
    leading: ClipOval(child: Image.asset('spacy.png')),
    child: const Text('Spacy'),
  ),
  trailing: PrismButton(label: 'Invite', onPressed: invite, child: const Text('Invite')),
  body: conversation,
)
```

The avatar and leading are laid out in squares (64 and 22 points by default)
so the bar knows its height: with an avatar it grows below the control row,
which the leading control, actions and `trailing` keep, and the content starts
below the capsule. For an inline company avatar, use `leading` with
`PrismTitleStyle(leadingSize: 32)`. The leading is centred in the capsule's
height and treated as a circle, as far from the capsule's start as from its top
and bottom at every height. A rounded-square logo passes its
`leadingCornerRadius`, which moves it in until its corners clear the capsule's
rounded end by as much; `leadingPadding` sets exact insets instead and overrides
the radius. A scaffold or sliver bar's `subtitle` belongs
inside the glass capsule beneath the title text. Inline capsules match the
bar's icon-button height by default (44 points on top bars, 48 on rails), using
adaptive vertical insets around logos and subtitle lines. Custom toolbar heights
are respected. Explicit title padding/minimum heights and larger accessibility
text can require a taller capsule. Sizes, padding and
glass come from `PrismTitleStyle`, on the title or app-wide in
`PrismNavigationBarStyle.titleCapsule`.

A static glass title uses toolbar optics, retaining refraction at compact heights.
A glass title reveals through its optical material presence, with its logo and
text following the same progress. It never passes through a whole-title opacity
or image-filter layer, so the backdrop stays live throughout the reveal.
Text and glass titles, and any page with an `accessory` (including one with no
top bar, such as a search header), take the full top scroll edge, down to the
bottom of the bar, so a glass title's capsule sits inside it. The fade past the
bar keeps bare text legible, so it runs below a text title, a large title or an
accessory; a glass title with nothing bare on the edge has its fade end at the
bottom of the glass instead (`topEdgeInset`). Actions-only bars
and bars minimized on scroll down without a reveal take a compact edge
over the status bar instead: it ends as far below the Dynamic Island as the
island sits below the screen's top edge (the status bar's bottom without an
island), so no page with top chrome is left without a top edge. Sheets have no
status bar beneath them and keep only the full edge. The bottom scroll edge is independent. On vertical-rail
layouts, ordinary automatic titles lead when the page has trailing actions and
center when it has none; glass titles remain centered and explicit alignment
wins.

Toolbar groups materialize as complete, unclipped capsules while their reserved
layout extent changes. The parent toolbar owns this transition for its groups;
standalone groups own their own. Activity badges without a count use the full native
badge height, placed consistently in horizontal and vertical bars. Counted toolbar badges grow inward from their trailing edge; tab/sidebar badge centers stay fixed as text grows.

A `slivers` page scrolls back to the top when its tab is tapped again and, on
iOS, when the status bar is tapped. `PrismTabReselection.maybeOf(context)`
reports reselections for anything else, such as focusing a search field. The
scaffold supplies the background, keyboard avoidance and these behaviours, so a
page needs no Material `Scaffold`; keep one (or a `Material` ancestor) only for
Material widgets that need it, such as ink effects or snack bars.

## Sliver app bar

`PrismSliverAppBar` is the scaffold's top bar as a pinned sliver, for
pages built on a `CustomScrollView`. Make it the first sliver:

```dart
CustomScrollView(
  slivers: [
    PrismSliverAppBar(
      title: const Text('Library'),
      largeTitle: const Text('Library'),
      toolbar: [PrismToolbarGroup(items: [activity]), PrismToolbarGroup(items: [share, more])],
      accessory: PreferredSize(preferredSize: const Size.fromHeight(48), child: tabs),
    ),
    SliverList.builder(
      itemCount: 30,
      itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
    ),
  ],
)
```

It takes `leading` (or implies a back or close button), `title`,
`largeTitle`, `subtitle`, `toolbar`, `trailing`, `accessory`, `sheet`, `backgroundColor` (the fade colour),
`scrollEdge`, `scrollEdgeStyle` and `navigationBarStyle`, with the scaffold's
measured geometry: 16-point edges, the 44-point control row under the status
bar, a 52-point large title row that rides the scroll before the titles swap
on a timer, and 16 points of clearance before the content. The bar's glass and
its edge effect share one glass group; the controls refract the blurred, faded
content painted by that effect.

## Adaptive layout

`PrismScaffold` places a `tabBar`, typed `toolbar` content and a
`leading` control over a full-window `body`. Consecutive `PrismToolbarItem`s
share a capsule; explicit `PrismToolbarGroup(items: [...])` entries create
separate capsules. An empty group draws nothing and materializes in when it gains
an item. In the iPhone Duo rail, groups stack or fold into one "More" menu. With no `leading`, a route that
can pop gets a `PrismBackButton`: a glass back chevron, or a close mark
on a fullscreen dialog, popping through `Navigator.maybePop`. Pass
`automaticallyImplyLeading: false` to suppress it, or your own
`PrismBackButton(icon: ...)` for a custom glyph.

To use an icon pack's glyphs everywhere, including the implied button, set
them in the theme:

```dart
PrismThemeData(
  toolbar: PrismToolbarStyle(
    backIcon: Icon(MyIcons.chevronLeft),
    closeIcon: Icon(MyIcons.close),
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
sets where the rail's actions begin. Elsewhere, `PrismChromePlacement.resolve`
picks the rail when one side's safe area is at least 48 pt deeper than the
other. Pass `placement` to force one. The [adaptive layout
measurements](../research/specs/native_adaptive_layout.md) record the native frames this follows.

The body receives `MediaQuery.padding` that includes the space the chrome
covers plus 16 points below the top bar's capsules, so scroll views keep
content clear while it still shows through the glass. When the device is partly folded, the fold reaches the body as a
`MediaQuery.displayFeatures` entry; `DisplayFeatureSubScreen` keeps content out
of it. Read `PrismScaffold.placementOf(context)` to adapt your own layout.
For overlays outside the body, such as a sheet's drag handle, use
`PrismScaffold.contentInsetsOf(context)` to align with its content area.
This includes physical safe insets and the rail's minimum width, but not measured
top/bottom bar coverage. The body's `MediaQuery.padding` already includes both;
do not add these insets again there. An explicit `placement` argument overrides
the nearest scaffold or system placement.

When the rail is too short for both the actions and the tab bar, the actions
collapse into one "More" item whose native menu lists them, as native bars do
before compressing the tab bar.

Inside the scaffold, `PrismTabBar` and the actions group adopt the
placement's axis. Set `axis` on either widget to choose it yourself. A vertical
tab bar is icon-only; labels remain the accessible names. Arrow up and down move
between its tabs, and it reads top to bottom in both text directions.

The scaffold hides a bottom tab bar while the keyboard is up and adds the
keyboard height to the body's bottom padding. Native popup menus close when the
window resizes, as UIKit menus do.

Set `tabBarPlacement: PrismTabBarPlacement.sidebar` to list a
`PrismTabBar`'s tabs in a leading sidebar while the window has regular
width, such as the unfolded iPhone Duo. Apple suggests it for
information-dense apps. The sidebar is a frosted glass panel over full-width
content. Its toggle slides it away while the content reflows into the space,
with the native spring; a toggle that materializes at the top leading corner
brings it back. As natively, the tabs stay out of the tab bar and rail while the
sidebar is hidden. Reduce Motion skips the slide. Regular width comes from
UIKit's size class on iOS 27.1, or a 700 pt window elsewhere.

### Your own sheets, dialogs and bars

`PrismSystemChrome` exposes what UIKit reports, so screens that don't use
the scaffold can follow it too. Put it in your app's builder:

```dart
CupertinoApp(
  builder: (context, child) => PrismSystemChrome(child: child!),
  home: const Home(),
)
```

- Dialogs, popup menus and modal sheets then avoid an active fold: it is added
  to `MediaQuery.displayFeatures`, which Flutter's routes and
  `DisplayFeatureSubScreen` already respect.
- `PrismSystemChrome.of(context)` returns a `PrismSystemChromeData`:
  `verticalBarEdge` (left, right or null), `hasVerticalBar`, and the
  `occlusions` (status bar, camera) and `divisions` (fold) as
  `PrismReservedRegion`s with a frame, interactive margins and an `active`
  flag. Use them to place custom bars or sheet controls on the same edge as the
  system's vertical bar and below the status bar.
- `PrismSystemChrome.listenable` gives the same report outside widgets.
- `PrismSystemChrome.deviceGlassTintAmount` is the device's Liquid Glass
  setting (0–1, null where iOS has none). Glass follows it already; read it to
  match your own surfaces, or override it with `PrismThemeData.glassTint`.
- A `PrismScaffold` inside a sheet lays out its own rail too.
- To keep interactive content off a bent fold, read
  `MediaQuery.displayFeaturesOf(context)` for a feature in
  `DisplayFeatureState.postureHalfOpened` and lay out on either side of its
  bounds. The showcase's `LargeTitlePage` splits its sections into two columns
  this way. Scrolling content may cross the fold.

The report is null on other platforms, before iOS 27.1 and without the plugin.

To keep horizontal bars for a screen better served by them, such as a
full-screen video player, use the package's native Flutter view-controller subclass and call
`PrismSystemChrome.setVerticalBarBehavior(PrismVerticalBarBehavior.disabled)`.
It returns false where it can't apply. Apple asks that this be a stable choice,
not one that changes as people navigate.

## Toolbar composition

`PrismToolbarItem` renders its label when `icon` is omitted. Native menus use
`.menu`; `.custom(child: ...)` hosts app-owned input without a second gesture or
semantics owner. Custom content has no additional glass unless placed inside an
explicit `PrismToolbarGroup`. `width` sets its main-axis extent inside a group;
ungrouped custom content may size intrinsically.

`PrismScaffold.toolbar` and `PrismSliverAppBar.toolbar` accept
`List<PrismToolbarContent>`. Items default to the top trailing region. Set
`placement` to `topLeading`, `principal`, `bottomLeading`, `bottom` or
`bottomTrailing`. Principal content replaces the inline title while the large
title remains independent. Bottom regions form a window footer in a scaffold;
in a sliver app bar they form a pinned row below the accessory. In a
scaffold's footer, `bottom` content sits on the window's center whatever the
leading and trailing groups beside it take, and those groups keep the
floating tab bar's 24-point side margin, clear of the display's rounded
corners. The margin follows the tab bar's measured margin; the bottom
toolbar's own has not been measured separately.

Consecutive loose actions share one capsule. `PrismToolbarGroup(items: [...])`
starts a separate capsule, with an optional local `style`. Fixed and flexible
`PrismToolbarSpacer`s separate capsules; flexible space uses a bounded main axis
and collapses under unbounded constraints. A standalone toolbar respects list
order and ignores placements. Long intrinsic toolbars scroll along their axis.
Give stateful custom entries a stable `key` when reordering them.

See the [1.0 migration guide](migration-1.0.md) for API changes.

### Shared capsule

```dart
PrismToolbar.group(
  style: const PrismToolbarStyle(
    size: PrismToolbarSize.navigation,
    spacing: 10,
    iconSize: 24,
  ),
  items: [
    PrismToolbarItem(label: 'Previous', icon: const Icon(CupertinoIcons.chevron_left), onPressed: previous),
    PrismToolbarItem(label: 'Next', icon: const Icon(CupertinoIcons.chevron_right), onPressed: next),
  ],
)
```

Navigation/bottom presets are 44/48 points high. Style can override height,
inset, spacing, shapes, colors, material and motion. Each item has its own width,
key, selected flag and optional literal foreground. A group with one item and
an icon and no explicit width is a circle as tall as the bar (44 or 48 points), like a lone
native bar button; give the item a width to keep a wider capsule. Narrow groups scroll rather
than shrink icons. Direct `size` wins over the theme, even when explicitly bottom.
Null callbacks disable individual actions; menu items use `enabled: false`.

Items may come and go: an item added to `items` materializes in while the
capsule widens, and a removed one leaves the same way. Items are matched by
`key`, else by `label`. An empty list materializes the whole capsule away and
draws nothing, so a list whose items all depend on state is fine. In an action-only
toolbar, regrouping the same ordered actions between capsules keeps them fully
present and interactive;
it does not replay item entry/exit transitions. Use keys or distinct labels to
identify actions. Toolbars containing custom content or spacers retain their
normal transition behavior.
`PrismToolbarStyle.itemTransition: PrismTransition.identity` swaps at once, as
Reduce Motion does; `itemTransitionStyle` sets the springs.

Several capsules in one bar are one `PrismToolbar`, with typed content
laid out with style `groupSpacing` (default 8) between them. Declare every group the bar can show and
let emptiness animate, so groups keep their positions:

```dart
PrismToolbar(
  size: PrismToolbarSize.navigation,
  content: [
    PrismToolbarGroup(items: [if (hasSuggestions) suggestionsItem]),
    PrismToolbarGroup(items: [sortItem, moreItem]),
  ],
)
```

## Scroll edge effects

iOS softens content scrolled under a bar with a progressive blur and a partial
fade, strongest at the edge and dissolving a little below the bar. The bar's
glass controls refract the blurred, faded content painted beneath them.

`PrismScaffold` draws this effect under its top bar while the body's
outermost scroll view is scrolled, fading toward its `backgroundColor`
(without one, it blurs only). `scrollEdge: false` turns it off and
`scrollEdgeStyle`, or the theme's `scrollEdge`, tunes it. A scaffold bottom bar
always uses the soft variant, including when its top edge is hard;
`scrollEdge: false` disables both edges. The defaults are
measured from iOS 27's own effect ([spec](../research/specs/native_scroll_edge_spec.md)): a
3-point variable blur and a half-opacity fade held over the top third of the
strip and falling along a smoothstep over its last 98 points, a 32-point haze
blended in at half opacity, 50 points of reach below the bar, and a 16-point
scroll over which it arrives (the reveal is this package's; native shows it as
soon as content is beneath).

`PrismScrollEdgeVariant.hard` is the effect under a bar with a background, as
SwiftUI's `.hard` style: it stops at the bar's edge with a one-pixel hairline
(10% black in light, 10% white in dark), blurs 2 points keeping a quarter of
that to the edge, and holds its fade and haze flat. Give the scaffold an `accessory` (a `PreferredSizeWidget` such as
segmented tabs) to extend the bar below its capsules; the effect and the body's
padding cover it. Together they make a bar like a native navigation bar with a
palette of tabs:

```dart
PrismScaffold(
  backgroundColor: background,
  scrollEdgeStyle: const PrismScrollEdgeStyle(variant: PrismScrollEdgeVariant.hard),
  accessory: PreferredSize(
    preferredSize: const Size.fromHeight(44),
    child: PrismSegmentedControl<int>(
      selectedValue: selectedFilter,
      onValueChanged: changeFilter,
      children: const {0: Text('All'), 1: Text('Saved')},
    ),
  ),
  body: list,
)
```

For a bar of your own, lay `PrismScrollEdge` in the bar's background,
filling the bar's box with the title and controls painted above it, and drive
`progress` from the scroll offset:

```dart
SliverLayoutBuilder(
  builder: (context, constraints) => SliverAppBar(
    pinned: true,
    backgroundColor: Colors.transparent,
    flexibleSpace: PrismScrollEdge(
      progress: PrismScrollEdge.progressFor(constraints.scrollOffset),
      color: Theme.of(context).scaffoldBackgroundColor,
    ),
    leading: PrismToolbar.group(size: PrismToolbarSize.navigation, items: [back]),
    actions: [PrismToolbar(size: PrismToolbarSize.navigation, content: content)],
  ),
)
```

Wrap the page (the `CustomScrollView`, or the body around it) in a
`PrismGroup` so compatible capsules share captures. Paint the edge effect
first; it keeps its own passes, and the capsules refract its output. See
[rendering](rendering.md#shared-captures-and-edge-effects).

`PrismScrollEdge.fade` wraps a scroll view and springs the same blur and fade
in at each edge while content extends past it, with `extent`, `sigma`,
`fadeOpacity` and `plateau` to tune. Both build on the primitive `PrismEdgeBlur`, which
blurs and fades up to two opposite edges of any child per pixel along
`PrismEdgeFade.curve`, a smoothstep fade:

```dart
PrismEdgeBlur(
  edges: [
    PrismEdgeBlurStrip(edge: PrismEdge.top, extent: 96, sigma: 3, plateau: .35, fadeColor: background),
  ],
  child: pinnedHeaderContent,
)
```

Each strip can also hold a `floor` of strength at its inner end, a `fadeFloor`
for a fade that stays flat, and a `haze`: a heavy blur blended in at
`hazeOpacity`, masked linearly past `hazePlateau`, the way native bars lay a
32-point blur at half opacity under their light variable blur so fine detail
softens without vanishing. Both blurs stay inside their strip: like native
blurs, they drop samples past its edges and reweight the rest, so content at
the screen edge or below the strip does not bleed in. Animate by scaling `sigma`, `fadeOpacity` and
`hazeOpacity`; an ancestor `Opacity` does not attenuate a backdrop blur. With
nothing active the widget paints straight through without a layer, so child
state survives. `PrismEdgeFade.gradient` builds the same fade as a plain
`LinearGradient` for decorations.

## Search

```dart
PrismSearchField(
  controller: searchController,
  focusNode: searchFocus,
  placeholder: 'Search ideas',
  onChanged: filterIdeas,
  onSubmitted: submitSearch,
  onCancel: closeSearch,
  textInputAction: TextInputAction.search,
  style: const PrismSearchStyle(height: 52, showClearButton: true),
)
```

Controller/focus nodes are optional; dispose only the ones your app creates.
The widget owns its omitted resources. It supports input formatters, keyboard
type/action, capitalization, suggestions/autocorrect, read-only input, alignment,
editing/tap callbacks and custom prefix/suffix widgets. A supplied suffix replaces
its clear action; `suffixBuilder` can keep or replace it instead. `onCleared` fires after a nonempty field is cleared, alongside
`onChanged('')`. Cancel clears when necessary, unfocuses, then calls `onCancel`.

Style can change text/placeholder colors, icon/cursor/clear colors, geometry,
material, contour, focus spring and clear/cancel action sizing. Set
`showCancelButton` and `restingInset` in `PrismSearchStyle` to override inherited values. Cancel is hidden
when it cannot fit. Cancel shows while the field is focused; on a search screen
of its own, `PrismSearchStyle(cancelVisibility: PrismSearchCancelVisibility.always)` keeps it
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

PrismSearchField(
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
PrismButton.menu(
  label: 'More',
  menu: const PrismMenu(children: [
    PrismMenuAction<String>(title: 'Share', value: 'share', icon: PrismMenuSfSymbol('square.and.arrow.up')),
    PrismMenuAction<String>(title: 'Delete', value: 'delete', destructive: true),
  ]),
  onSelected: handleMenuValue,
  child: const Text('More'),
)
```

Use `PrismToolbarItem.menu` inside a toolbar or `PrismMenuRegion` for custom
triggers. UIKit owns the iOS popup; customize its model (symbols, sections,
submenus, selected/disabled/destructive items and deferred actions), not its
renderer. For typed imperative results use `prismMenus.show<T>`. See the
[menu guide](native_menus.md) for setup and callback/dismissal semantics.

## Tab actions, feedback, badges and navigation titles

Tabs accept `onLongPressed`; a hold uses Flutter's `kLongPressTimeout`, returns
the pill to the selected tab and never selects on release. Use the package
callback instead of an icon GestureDetector. A null `onSelected` disables it.

Set theme `haptics: PrismHaptics((context, event) { ... })` for a shared app
feedback policy. Component `haptics: false` still silences feedback. Null retains
existing native calls. Segmented controls do not generate package haptics.

Text/RichText segments can opt into
`PrismSegmentedStyle(sizing: PrismSegmentedSizing.fitLabels)`; equal widths fit
the widest label and text scaling. Custom widget labels need explicit width.

Add `badge: PrismBadge.count(7)`, `PrismBadge.text('New')` or an empty
`PrismBadge.dot()` to a tab or toolbar item. As on iOS 27, counts are never
shortened (1000 draws `1,000`); pass `overflow: 99` to draw `99+`. The full value
is announced; supply a localized `semanticLabel` (and `PrismBadge.text` for a
locale's digit grouping). Styles expose `badgeColor` and `badgeTextStyle`.

`PrismScaffold(title: Text('Inbox'), largeTitle: Text('Inbox'), body: list)`
adds a header that follows the outermost vertical scroll view, even with
`scrollEdge: false`. On a horizontal bar the large title scrolls away and
the inline title rises in. On the iPhone Duo rail the large title shares the
control row and returns on scroll reversal. Use `PrismTitleDisplayMode.inline`
with a single title to request compact type. The accessory sits
below the title rows. Keyboard height enters body padding once; the body's
bottom viewInset is consumed. Set `resizeToAvoidBottomInset: false` to delegate
keyboard avoidance to descendants.

See [feature contracts and adoption](../research/specs/package_features_spec.md) for per-item
changes, native measurements and remaining gaps.

## Chrome layout overrides

`PrismNavigationBarStyle.titleAlignment` supports automatic, leading, center and
trailing alignment. `controlRowHeight` sets the minimum row height (44 by default),
`contentPadding` adds directional insets inside the safe area, and
`largeTitleExtent` replaces the typography-measured expanded row height. These
fields apply to both scaffold and sliver app bars.

Centered scaffold titles use the content area's center, shifting only as far as
needed to fit between the visible controls. A window's corner status-bar region
still bounds top-row controls, but does not move a sheet title below that region.

`PrismScaffoldStyle`, through scaffold `style` or theme `scaffold`, controls
`tabBarMargin`, `tabBarAlignment`, `tabBarMaxWidth`, `bottomBarMargin`,
`bottomBarAlignment` and `bottomBarMaxWidth`. Margins replace the corresponding
package gaps; explicit zero is respected. Bottom content stays above the keyboard
or bottom tab dock. Cross-axis alignment determines where a compact bar sits.

`PrismTabBarPlacement.top`, `.bottom`, `.leading` and `.trailing` explicitly dock
tabs. Leading/trailing follow RTL and use vertical bars. `.automatic` preserves
system rail behavior; `.sidebar` keeps the existing adaptive sidebar. Body and
scroll-edge insets follow the dock. Bottom tabs hide while the keyboard is open;
top and side docks remain visible. Compact sizing remains the default.
`PrismTabBarSizing.fill` fills a bounded main axis; under unbounded constraints it
uses compact sizing. Vertical labels default to hidden but honor explicit
`labelBehavior`.

### Scaffold lab

The showcase's Scaffold Lab keeps its common heading, scroll behavior, accessory,
edge and action controls at the top. Expand the advanced sections to override:

- All `PrismNavigationBarStyle` fields: alignment, minimization and restoration,
  safe-area adjustment, geometry, four title/subtitle typography styles, reveal
  and hide springs, fade timing/curve, and title-capsule styling.
- All `PrismScaffoldStyle` fields: tab and bottom-bar alignment, margins and width.
- All `PrismScrollEdgeStyle` fields, including material fade and edge motion.
- Title compositions, custom/implicit leading, trailing content, toolbar regions,
  tabs and dock placement, background, keyboard avoidance, RTL, body/sliver mode,
  nested scroll notification depth, and standalone `PrismSliverAppBar`.

Numeric overrides are disabled initially, preserving inherited/native values.
Switch an override off to clear it, or use **Reset to native defaults**. The
sheet button exercises the same page inside a sheet. Body mode owns its scroll
view and safe-area padding; refresh and custom scrolling headers use sliver mode.
The global showcase settings continue to control appearance and glass quality.

Large navigation titles scroll with the content and fade out over 200 ms with
ease-in-out when replaced. They do not receive the compact title’s blur or
15-point translation. The compact title uses its separate reveal/hide motion.
A custom `header` is ordinary scrolling content and has no added exit animation;
its disappearance triggers the compact title. See `research/specs/navigation_bar_spec.json`
for native capture details.
