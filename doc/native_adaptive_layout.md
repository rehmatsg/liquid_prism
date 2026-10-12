# Native adaptive layout

Measured on 2026-10-12 with a SwiftUI probe: a `TabView` (`.sidebarAdaptable`,
three tabs plus a search tab) whose pages use a `NavigationStack` with a large
title, two `.topBarTrailing` items and two `.bottomBar` items. Frames come from
the UIKit view hierarchy, in points and window coordinates.

## Windows

| Simulator | Runtime | Window | Size classes | Window safe area |
| --- | --- | --- | --- | --- |
| iPhone 18 Pro | iOS 27.0 | 402 × 874 | compact × regular | top 62, bottom 34 |
| iPad Air 11-inch (M4) | iOS 27.0 | 820 × 1180 | regular × regular | top 32, bottom 20 |
| iPhone Duo, folded | iOS 27.1 | 466 × 678 | compact × regular | right 84, bottom 34 |
| iPhone Duo, unfolded | iOS 27.1 | 951 × 669 | regular × regular | right 84, bottom 34 |

The iPhone Duo simulator boots folded, on its 1398 × 2034 px display.
Unfolding (a control on the DeviceHub device frame; `simctl` has none) switches
to the 2007 × 2853 px display, shown in landscape.

## Measurements

iPhone 18 Pro: the navigation bar starts at y 62. The trailing group is 100 × 44
at x 285 (16 pt from the edge). The tab bar floats at the bottom. Content safe
area: top 168, bottom 86.

iPad Air: the tab bar is a text-only floating bar centered in the top bar
(y 32, 44 high). The trailing group is 100 × 44 at x 709. Liquid Prism does not
reproduce this top tab bar; `LiquidPrismScaffold` keeps the bottom placement.

iPhone Duo: the status bar, toolbar items and tab bar move into a vertical rail
in the right safe area. The large title stays at the top left (navigation bar at
y 24, 58 high). Content safe area: top 82, right 84.

| Element | Frame |
| --- | --- |
| Trailing group (two items) | x 394, y 170, 48 × 100; items 48 × 48 at a 52 pt pitch |
| Bottom-bar items | x 394, y 322 and 382, 48 × 48 each |
| Tab bar capsule (four tabs) | x 394, y 442, 48 × 212 |
| Tab buttons | 44 × 58 at a 50 pt pitch, starting 2 pt across and 2 pt down |

Unfolded, the layout keeps the same rail despite regular width: the status
bar, actions and tab bar stay in the right safe area, with the large title at
the top left (navigation bar at y 24, 58 high; content safe area top 82,
right 84). Only the trailing group moves up, following the status bar.

| Element (unfolded) | Frame |
| --- | --- |
| Trailing group (two items) | x 879, y 120, 48 × 100 |
| Bottom-bar items | x 879, y 313 and 373, 48 × 48 each |
| Tab bar capsule (four tabs) | x 879, y 433, 48 × 212 |

## System APIs (iOS 27.1)

UIKit publishes the placement directly; the plugin streams it on
`liquid_prism/system_chrome` for the Flutter view:

- `UITraitCollection.verticalBarEdge`: `leading`, `trailing` or `unspecified`
  (horizontal bars). Changes are observed through
  `systemTraitsAffectingVerticalBarEdge`.
- `UIView.reservedRegions(kind:)`: `.occlusion` regions covered by system UI and
  `.division` regions content should split around, each with a frame
  (including margins for interactive content) and an active flag. UIKit has no
  change notification, so the plugin re-queries on layout, safe-area and trait
  changes.

Unfolded Duo values: edge `trailing`; one active occlusion at x 867, y 0,
84 × 120, the status bar, whose bottom is exactly where the trailing group
starts; an inactive occlusion for the camera at x 677, y 21, 58 × 37; and an
inactive division at the hinge, x 455.5, 40 wide, with 20 pt margins.

Apple's guidance (Design for iPhone Duo, Prepare your app for iPhone Duo): the
inner display keeps horizontal bars only in portrait; an app on the left of
Split View gets its bars on the left edge; top toolbar items sit at the top of
the rail and bottom ones at its bottom, with the tab bar bottom-aligned; when
the rail runs out of room, bar items collapse into an overflow menu before the
tab bar compresses (`UIVerticalBarCompressionBehaviorAutomatic`).

With the vertical bar disabled (`preferredVerticalBarBehavior = .disabled`)
on the unfolded Duo, iOS 27.1 reported no edge, a right safe area of 0, and the
status bar's occlusion region at x 817, y 0, 134 × 82 in the top-right corner.
The header says the trait keeps reporting the preferred edge; the plugin also
reports the app's own preference so either behavior resolves to horizontal bars.

### Sidebar

`TabView` with `.defaultTabBarPlacement(.sidebar)` on the unfolded Duo shows a
280 pt opaque sidebar along the leading edge (light #EAEFF2, dark #181D20). A
48 pt glass toggle sits at x 212, y 24. Rows are 240 × 44 at x 20 from y 81,
with accent-colored icons and labels at x 74; the selected row is a capsule
(light #D6DBDE, dark #2C3134). Content starts at x 280. The rail keeps the
trailing group under the status bar and moves the bottom-bar items to its
bottom (y 537 and 597); no tab bar remains in it.

## Fitted behavior

- Without the system APIs (before iOS 27.1, or without the plugin), a rail is
  used when one side's window safe area is at least 48 pt deeper than the
  other. iPhone landscape insets are symmetric and keep the bottom bar.
- The rail column is 48 pt wide, 12 pt outside the content edge (24 pt from the
  window edge for an 84 pt inset). Actions start below the status bar's occlusion
  region; without it, at the measured y 170 (portrait) or y 120 (landscape). The tab bar ends 24 pt above the window's bottom edge.
- Vertical tabs use a 50 pt pitch and 2 × 6 pt padding, giving 48 × (50n + 12).
  The pill spans the slot plus 8 pt, matching the 58 pt native buttons.
- A vertical toolbar group transposes the measured horizontal group: two items
  give the same 100 pt length.
