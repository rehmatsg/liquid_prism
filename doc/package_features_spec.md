# Package features: evidence, contracts and adoption

Package features added for the Vance app's workarounds, with the native
measurements behind their defaults. Measurements: iOS 27.0 (24A434), iPhone 17
Pro simulator at 3x, content size L, `tool/native_package_features_probe`;
raw dumps under `_research/package_features/` (local evidence).

## 1. Tab long press

API: `LiquidPrismTabBar.onLongPressed: ValueChanged<int>?`. The existing
`ControlGestureRecognizer` times a hold with Flutter's `kLongPressTimeout`, consumes
it once, and suppresses tap/drag completion afterward. Native hold timing is
**unmeasured**. Crossing touch slop before the timeout, cancellation, multiple
contacts or an external selected-index update suppress the callback. The lifted
pill drops and returns to the parent-selected tab immediately on recognition.
A null `onSelected` disables both selection and long press. Each enabled tab's
semantics exposes a separate long-press action. Sidebar rows use their existing
gesture owner for the same callback.

Hunks: `control_gesture.dart` timer/callback/lifecycle; `tab_bar.dart`
constructor, `_longPress`, gesture wiring and tab semantics; `sidebar.dart`
existing row long-press wiring. Tests: `test/tab_long_press_test.dart`.

Vance: pass `onLongPressed: onLongPress` to the package bar; remove `_glyph`'s
GestureDetector. After item 2 is adopted, remove `_onLongPress`'s separate haptic
so it is not played twice.

## 2. One haptics hook

API: theme `haptics: GlassHaptics((context, event) { ... })`; event has typed
`component` (tabBar, switchControl, slider) and `kind` (selectionChange, toggle,
limitReached, longPress). Nested non-null hooks replace the outer hook.
Per-component false still silences it. A custom hook handles switch/slider events
on every platform; with no hook, their native fallback remains iOS-only. Tab and
sidebar fallback selection clicks retain their existing platform behavior.
Long press uses a provisional light impact fallback. Hook callbacks are
synchronous and own any asynchronous work they initiate.

Hunks: new `haptics.dart`, theme constructor/copyWith/merge; four dispatch sites
in tabs/sidebar/switch/slider; exports. No segmented haptic was added: the native
control spec establishes none. Tests: `test/haptics_hook_test.dart`; existing
control tests continue to cover accepted endpoints and cancellation.

Vance: set one theme hook that maps these events to `VanceHaptics`, checks the app
setting, and plays the desired feedback. Remove tab `haptics: false` and its own
selection feedback; omit the switch's per-build enabled flag. Keep any desired
segmented feedback in the app callback, since it is an app policy.

## 3. Keyboard once

API: `LiquidPrismScaffold.resizeToAvoidBottomInset` (default true). The body still
fills the window; keyboard avoidance follows the scaffold's existing padding
contract. When keyboard height is folded into body padding, the body MediaQuery
consumes **only** `viewInsets.bottom`. Other view insets and `viewPadding` remain.
False omits keyboard coverage and leaves viewInsets to descendants. The floating
bottom tab bar still hides while the keyboard is visible.

Hunks: `chrome_layout.dart` constructor/field, layout keyboard argument and
`_InsetBody` MediaQuery. Test: `test/scaffold_keyboard_test.dart`, nested Material
Scaffold with TextField and SafeArea; verifies the same available height once.
Vance: remove `_KeyboardInsetOnce` entirely and use the default scaffold behavior.

## 4. Segmented label sizing

API: `GlassSegmentedStyle.sizing` fixed/fitLabels and `labelPadding`. Fixed stays
300 × scale. Fit measures Text/RichText labels, sizes every slot from the widest,
and grows the track/hit area for text scale. Arbitrary custom widgets require an
explicit width. Explicit width/trackHeight/thumbHeight win over fitted dimensions;
parent constraints cap the width. Label padding defaults to 10 horizontally (measured:
a fixed-size Picker gives each equal segment its widest label plus about 10
points a side, from two samples) and 8 vertically, which keeps the measured
32-point track. An unframed native Picker fills its width (370 of 402 points
with 16-point margins); fixed sizing keeps the existing 300-point default. `scale` applies to padding and default typography as well as geometry.

Hunks: `appearance.dart` GlassSegmentedSizing/GlassSegmentedStyle;
`segmented_control.dart` measurement/dimensions; export. Test:
`test/segmented_sizing_test.dart` covers equal pitch, text growth, width constraints,
fixed mode and explicit zero padding.
Vance: replace TextPainter and computed dimension styles with
`GlassSegmentedStyle(sizing: GlassSegmentedSizing.fitLabels,
labelPadding: labelPadding, labelStyle: style)`. Keep explicit app colors.

## 5. Badges

API: `GlassBadge.dot()` or `GlassBadge.count(count, overflow: 99)`, optional
semanticLabel. `LiquidPrismTab.badge` and both GlassToolbarItem constructors
accept it. Count zero is visible; full counts are announced even when display is
`99+`. A dot announces “New activity” unless given a localized label. Badge styles
`badgeColor` / `badgeTextStyle` merge local > component theme > fallback, including
individual text-style fields. Tab sidebar rows also display/announce badges.
The overlay adds no gestures or repaint boundary to the tab foreground pass.

**Measured geometry:** tab badges are 18.33-point capsules (continuous corner
radius 9.17), 12-point medium white text 14.33 points tall, 4 points of padding
each side: 18.33 wide for one digit, 23.33 for two, 29 for three, 40.33 for
`1,000`. Native counts are never shortened, so `overflow` defaults to none.
Fill is system red (255,56,60 light; 255,66,69 dark). The leading edge sits 5
points inside the tab glyph's trailing edge and the top 2 points below the tab
button (24.5 above the glyph's centre), across 3/4/5-tab bars; a badge near the
platter's end is pulled in to end at its edge (not reproduced). An empty (space)
badge is a solid 18.33 circle. Toolbar `UIBarButtonItem.badge` counts share the
widths; the indicator is an 18-point circle; badges sit 2.6–3.0 points above
the 44-point capsule and overhang the item by 2.5–3.8 points (fitted: 2.8 and
3). The toolbar count font is unmeasured (drawn without a UILabel). Count
geometry grows with text scale (fitted).

Hunks: new `badge.dart`; tab/toolbar models + icon overlays + semantics;
GlassToolbarStyle/GlassTabBarStyle badge fields/merge/copyWith; sidebar overlay;
export. Test: `test/badge_test.dart`.
Vance: replace toolbar Stack dots with `GlassBadge.dot(semanticLabel: 'Filter active')`
and MailBadgeIcon with the underlying mail glyph plus
`hasNewMail ? GlassBadge.dot(semanticLabel: 'New mail') : null`. Use the base
action label 'Emails' to avoid announcing the badge twice. Supply localized dot/count semantic labels.

## 6. Icon-only tab pitch

No default changed. Measured icon-only bars: 3 tabs 274-point platter, 94-point
buttons, 86 pitch; 4 tabs 360 / 98 / 84.67; 5 tabs 360 / 77 / 68.75; buttons
54 tall, inset 4 in a 62-point platter. Native keeps the labelled 86-point
pitch for three tabs, so Vance's 72-point `minimumTabWidth` is an app choice.

## 7. Navigation titles

API: scaffold `title`, `largeTitle`, `navigationBarStyle`; theme `navigationBar`:
`GlassNavigationBarStyle(titleStyle, largeTitleStyle, gutter, controlGap,
revealExtent, revealCurve)`. Scaffold fields reuse its owned outermost vertical
scroll offset, chrome layout, accessory, implied leading and shared captures.
A second navigation/sliver component would duplicate those owners. Body padding,
accessory position and soft/hard scroll-edge extent contract with the large row.
Inline title has symmetric room around screen center after excluding actual
leading/actions bounds. Large title aligns to the reading direction. Text scaling
grows both rows. Only one visible header contributes semantics; Reduce Motion has
no autonomous transition to disable because collapse is scroll-scrubbed.

**Measured:** inline title 17-point semibold, centred on the 44-point control
row; large title 34-point bold, 16 points from the edge, its 40.67-point line
3.67 points below the top of a 52-point row (6.67 with a subtitle, in a
71.33-point row). The row starts at the bar frame, 10 points below the
controls (116 on a 402 × 874 phone), and content starts at its end (168). The large title moves up one for
one with the scroll. When the scroll reaches the row's height (52) the titles
swap on a timer, not with the scroll: the large title fades out in about
0.18 s and the inline title fades in over about 0.53 s while rising 15 points,
decelerating; scrolling back reverses it (large in 0.18 s, inline out over
about 0.8 s). Fitted: the easeOutCubic curve and its flip. Not reproduced:
native snaps a half-scrolled title on release (released at 30 of 52 points it
collapsed; at 22 it expanded). The minimum gap between the inline title and
the capsules was not measured (12 is a fitted default).

Hunks: new `navigation_bar_style.dart`; theme navigationBar wiring; scaffold
fields, header builder and layout delegate title/collapse hunks; export. Tests:
`test/navigation_title_test.dart` (RTL, soft/hard edges, accessory, header semantics,
large text, collapse without edge effect). Existing leading tests cover implied
back-button routing. `example/lib/showcase/package_features_demo.dart` exercises
titles, badges, fit labels and long press in the scroll-edge component page.

Vance: replace ordinary standard/large SliverAppBar arrangements with scaffold
`title: Text(title), largeTitle: Text(title)`, leading/actions/accessory and
navigationBarStyle. Do not delete the entire wrapper yet: custom scrolled-title
spring/deadband/blur reveal, specialized route behavior and arbitrary sliver
composition are **not implemented** by this scroll-scrubbed contract.

## Native validation

`tool/native_package_features_probe` builds and runs on the iPhone 17 Pro
(iOS27) simulator: `tool/native_package_features_probe/run.sh <out>` (cases
Light, Dark, ToolbarLight, ToolbarDark, Tabs4, Tabs5, Scrub). JSON dumps record
view/layer frames, fonts and colours every 100 ms and title opacity/frames per
frame.

## Verification

`tool/check.sh` passes. On the iPhone 17 simulator (Impeller) the showcase's
Scroll Edges page exercises a held tab (fires without selecting), the large
title's scroll and swap, tab and toolbar badges and fitted segments. Physical
haptics were not felt on a device.
