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
280 pt, full-height `UIGlassEffect` panel along the leading edge, over content
that stays full width (the body's leading safe area is 280). A 48 pt glass
toggle sits at x 212, y 24. Rows are 240 × 44 at x 20 from y 81, with
accent-colored icons centred at x 50 and labels at x 74 in 17 pt SF, medium when
selected and regular otherwise, in the label color. The selected row is a
vibrant capsule. The rail keeps the trailing group under the status bar and
moves the bottom-bar items to its bottom (y 537 and 597); no tab bar remains in
it, shown or hidden.

Material, fitted on 2026-10-12 from screenshots against the same wallpaper with
the sidebar hidden (RMS 2.6/255 light, 0.9/255 dark): a Gaussian blur (σ 13 pt
light, 12 dark), then per channel `luma·L + chroma·(C − L) + offset`, with
Rec. 709 luminance L. Light: luma .403, chroma .911, offset (131.4, 136.2,
139.4)/255, so white reads #EAEFF2. Dark: luma .374, chroma .558, offset (25,
29.4, 32.5)/255, so black reads #181D20. The light fit has a small highlight
curve that a matrix cannot follow; it is pinned to the white point. The edge is
sharp, with no refraction rim. The selected capsule darkens what is beneath by
8.6% in light (#D6DBDE on white) and adds 21 per channel in dark (#2C3134 on
black).

Motion, from presentation frames sampled every display frame through four
hide/show cycles in each appearance (tapping the toggle in an XCUITest):

| Element | Motion | Fit |
| --- | --- | --- |
| Panel | slides its full width, no fade | response .35 s, damping 1.0 |
| Body content | leading inset 296 ↔ 16, width reflows | response .34 s, damping 1.0 |
| Inline navigation title | x 300 ↔ 80 | response .42 s, damping .75 (2.8% overshoot) |
| Hidden-state toggle (x 20, y 24) | materializes beneath the panel from 1.2× | settles in ~.4 s |

On show, the hidden-state toggle goes at once and the panel slides back over
it. The navigation bar row keeps its place in both states, so content never
moves vertically.

### Poses

Reported by the plugin while the showcase ran on the iPhone Duo simulator
(iOS 27.1), with the poses changed in DeviceHub. Regions are active only.

| Pose | Window | Edge | Right inset | Status bar (occlusion) | Fold (division) |
| --- | --- | --- | --- | --- | --- |
| Closed, portrait | 466 × 678 | right | 84 | 382, 0, 84 × 170 | none |
| Closed, landscape | 678 × 466 | left | 0 (left 84) | 0, 0, 82 × 84 | none |
| Open, landscape | 951 × 669 | right | 84 | 867, 0, 84 × 120 | inactive at x 455.5 |
| Open, portrait | 669 × 951 | none | 0 | 535, 0, 134 × 82 | inactive at y 455.5 |
| Open, partly folded | 951 × 669 | right | 84 | 867, 0, 84 × 120 | 455.5, 0, 40 × 669, margins 20 |
| Split View, right half | 469 × 669 | right | 84 | 385, 0, 84 × 120 | 0, 0, 13.5 × 669 |
| Split View, left half | 455.5 × 669 | left | 0 | none | 455.5, 0, 13.5 × 669 |

Native `TabView` frames in the same poses (the probe, kept open while the
poses changed):

| Pose | Trailing group | Tab bar |
| --- | --- | --- |
| Closed, landscape, bar on the right | x 606, y 24, 48 × 100 | x 606, y 172, 48 × 212: ends at y 384, the top of the status bar and camera region (594, 384, 84 × 82) at the rail's bottom |
| Closed, landscape, bar on the left | x 24, y 82, 48 × 100: below the status bar region (0, 0, 84 × 82) | x 24, y 230, 48 × 212: ends 24 pt above the edge |
| Open, portrait | x 431, y 24, 104 × 48: in the top row, ending at x 535 where the corner status bar region begins | Floating at the bottom, as on iPhone |
| Split View, left half | x 24, y 24, 48 × 100 | x 24, y 433, 48 × 212 |
| Split View, right half | x 397, y 120, 48 × 100 | x 397, y 433, 48 × 212 |

A navigation back button moves into the rail too. In Apple Music on the
closed iPhone Duo (iOS 27, device screenshot, about ±1 pt) it is a 48 pt
circle at the column's top, y 174 under the status bar, where a trailing group
would otherwise start, with the share/more capsule about 12 pt below it; the
top bar row is empty. `LiquidPrismScaffold` places `leading` the same way (at
the actions' top, the 12 pt rail gap above them).

Text buttons stay in the top bar. In a SwiftUI chat app on the closed Duo
(device screenshot, 3×), an Invite capsule 76 × 48.3 pt sits at x 306–382, ending
at the content's edge, the rail's 12 pt from its column, level with a glass
title capsule, while back and more icons sit in the rail. `trailing` drops its
16 pt edge on the rail's side to match. The same screenshots give the
`LiquidPrismTitle` defaults: a 64 pt avatar from y 24 on the content's centre,
and the capsule (38 pt for a 17 pt title, 14 pt horizontal padding; 44.3 pt with
a 22 pt inline avatar inset 12 pt from its start and 11 pt above and below, 10
pt before the text). The text button and the capsule share the top margin's
48 pt row, the Invite's top at y 24 tucked about 6 pt under it.

The rail therefore runs from below any system region in its top half to above
any in its bottom half. With horizontal bars, a status bar in a top corner
shares the top bar's row.

The open portrait pose keeps horizontal bars, as Apple describes. In Split View
on the left, iOS puts the bar on the left edge but gives the window no left
inset and no status bar: the inset comes from native bars, so
`LiquidPrismScaffold` reserves the 84 pt strip itself and starts the actions at
the 24 pt top margin.

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

## Device Liquid Glass setting

iOS 27 has a Liquid Glass slider (Settings > Appearance > Liquid Glass) that
replaced iOS 26.1's Clear/Tinted switch. It has no public API; iOS applies it
only to glass it draws. UIKitCore keeps it as the glass tint amount:
`UIViewGlassGetTintAmount` (getter, no arguments, cached; it returns an
`NSNumber`, which read 0, 0.5 and 1 at the slider's lowest, middle and highest
positions on an iOS 27 device),
`UIViewGlassSetTintAmount` (used by Settings) and
`UIViewGlassTintAmountDidChangeNotification`, found in the iOS 27.1 simulator
runtime's shared cache; Setup Assistant carries the user's value as
`glassTintAmount` beside `appearanceMode`. The plugin reads the getter and
observes the notification through `dlsym`, with the names assembled from
reversed fragments (after NotchMyProblem), and reports its value; where the
symbols are missing (earlier iOS, possibly 26.x) it reports null. It also
re-reads when the app becomes active.

What the setting changes, read directly from the glass layers' filter inputs
(`tool/native_dispersion_probe --scene tint`, iOS 27.2 iPhone Duo, light, white
backdrop, the slider moved in Settings; `UIViewGlassSetTintAmount` does not
change the value in-process). Only `glassBackground` inputs move; refraction,
highlights and shapes do not.

| Tint amount | 0 | 0.25 | 0.5 | 1 |
| --- | --- | --- | --- | --- |
| Regular: blur fill lighten opacity | 0.675 | 0.7875 | 0.9 | 0.9 |
| Regular: blur fill normal opacity | 0 | 0.25 | 0.5 | 1 |
| Regular: face fill colour (white) alpha | 0 | 0.1 | 0.2 | 0.5 |
| Clear: blur radius | 0 | 0.375 | 0.75 | 0.75 |
| Clear: blur opacities 0–3 | 0 | 1, .5, .5, 1 | 1, .5, .5, 1 | 1, .5, .5, 1 |
| Clear: blur fill radius / normal opacity | 0 / 0 | 0 / 0 | 0 / 0 | 8 / 1 |

The prominent button's vibrant colour matrix is zero at 0 and set above it.
The package's earlier simulator captures (blur fill lighten 0.9, normal 0.5,
radius 8) match 0.5, so iOS's default is the middle position and the package's
recipes are calibrated there. Reduce
Transparency (`UIAccessibility.isReduceTransparencyEnabled` and its change
notification) is reported beside it on every version.

Other inputs in the same dumps that do not move with the setting: every glass
layer's `inputBlurFillBlurRadius` (8 for regular glass at every amount),
refraction, the negative key/fill rim, the ring shadow, and the held tab lens
(`_UITabSelectionView` blur and colour matrix, the lens warp). The regular
glass highlight layers (capsule, button, toolbar item, tab bar, prominent
button) all carry the vibrant matrix whose first row is
`(1.1202, -0.1894, -0.0190)`, the lens matrix in
[native tab bar spec](native_tab_bar_spec.md); clear glass carries
`(1.3192, -0.0478, -0.0047)`. Their `CASDFKeyFillHighlightEffect` inputs are
identical for regular and clear glass. The dumps cover light appearance only.

### How Liquid Prism follows it

`LiquidPrismThemeData.glassTint` sets the amount; null follows
`LiquidPrismSystemChrome.deviceGlassTintAmount` (live), then 0.5. The tables
above are interpolated linearly between the measured amounts
(`GlassTint` in `lib/src/recipe.dart`). Measured and fitted parts:

| Part | Measured | Fitted (this package) |
| --- | --- | --- |
| Light regular face fill | White alpha 0 / .1 / .2 / .35 / .5 at amounts 0 / .25 / .5 / .75 / 1 | Used as captured. |
| Regular face tone | Light black .4, white 1.03, saturation 1.2, SDR limit .94. Dark black .125, white 1.125, saturation 1.3; size-dependent SDR limit. | Light and dark quadratic rolloff; dark size interpolation. |
| Regular blur fill | Lighten (darken in dark) plus normal opacity, radius 8 | Opaque Gaussian equivalents fitted separately by appearance and amount. |
| Clear blur | Radius 0 / .375 / .75 / .75 / .75 | Fitted frost 1.8 scales with radius ÷ .75. |
| Clear blur fill | Normal opacity 0 / 0 / 0 / .5 / 1, radius 8 when active | Fitted sigma 12. |
| Reduce Transparency | Reported, not measured | Not applied: no capture shows what it changes in glass. |

See [native defaults](native_defaults.md) for the current fit tables, dark face
fill and measured inputs. Explicit blur or optics retain literal Gaussian frost.

Native glass over flat sRGB greys (`tool/native_dispersion_probe --scene
levels --light`, iOS 27.0 simulator, default tint), the face at each band's
middle in 8-bit sRGB. The band at 0 is left out because it reads light from
the white strip above it.

| Backdrop | 32 | 64 | 96 | 128 | 160 | 192 | 208 | 224 | 232 | 238 | 242 | 246 | 250 | 253 | 255 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Regular face | 151 | 168 | 184 | 200 | 215 | 229 | 236 | 242 | 245 | 248 | 249 | 251 | 252 | 253 | 253.5 |
| Clear face | 62 | 93 | 124 | 154 | 185 | 215 | 231 | 246 | 253.5 | 255 | 255 | 255 | 255 | 255 | 255 |

Over (242, 242, 247) regular glass draws (250, 249, 254). The package fits the
regular face before the white fill as `0.4 + v (0.7239 − 0.129 v)` for luma
`v`, which gives these values within half a level at the default fill of 0.2.
The current fit also applies the small bright-end correction documented in
[native shadows](native_shadows.md#the-rim-over-white-on-ios-272) before the fill.
Clear glass's `mix(0.125, 1.08, v)` matches its row exactly. On an iPhone Duo
with iOS 27.2, native toolbar glass measured about 2 levels lower: 247 over
(242, 241, 246) and 252–253 over white.

Regular material uses one covering Gaussian backdrop pass. Native's asymmetric
lighten/darken composition is approximated because those blend modes are not
supported as Impeller backdrop pipeline blends. Clear material can fade a second
Gaussian over its light base blur. Held control lenses keep their captured optics.

The current comparison includes textured native/Flutter pairs at all five
settings in both appearances, plus genuine native held/released control states.
See [the defaults calibration](native_defaults.md) for reproduction and limits.
