# Changelog

## Unreleased

- Add scroll edge effects and progressive edge blurs. `LiquidPrismEdgeBlur`
  blurs and fades up to two opposite edges of its child per pixel along the
  smootherstep `GlassEdgeFade.curve`, as backdrop passes of a new
  `edge_blur.frag` that pairs its Gaussian taps into bilinear reads and derives
  the weights incrementally, so a 4-point strip costs 37 texture reads per pass
  instead of 73. `LiquidPrismScrollEdge` is a bar's effect driven by scroll
  progress; `LiquidPrismScrollFade` springs a scrollable's edges in and out;
  `GlassScrollEdgeStyle` themes them. `LiquidPrismScaffold` draws the effect
  under its top bar while the body is scrolled (`scrollEdge: false` opts out).
- Let edge effects join a glass group's shared captures. Inside a
  `LiquidPrismGroup` or the scaffold, the effect's passes are hoisted with the
  members' frost, cut out of their contours, and the members' optical passes
  read a capture taken before the fade and finished blur: glass over a scroll
  edge refracts the unblurred content beneath it, as native bar buttons do,
  and a bar's effect and capsules cost two captures together instead of two
  each. Plain clips (a viewport, an app bar's toolbar clip) between a member
  and its group no longer keep it out of the shared capture; the hoisted shadow
  and frost are clipped the same way.
- Measure iOS 27's scroll edge effect and build the defaults from it
  (`doc/native_scroll_edge_spec.md`, probe under `tool/native_scroll_edge_probe`).
  The native effect is a 16-point blur at half opacity under a light 1.5-point
  variable blur and a half fade, masked by a smoothstep; `GlassFadeCurve` is
  now smoothstep, `GlassEdgeBlur` gains `haze`, `hazeOpacity`, `hazePlateau`,
  `floor` and `fadeFloor`, and the defaults become sigma 1.5, falloff 98,
  reach 50 and a 16-point haze at half opacity. The old 4-point blur and
  smootherstep were fitted by eye and read harder than native.
- Add `GlassScrollEdgeVariant.hard`, the effect under a bar with a background:
  no reach past the bar, a 2-point blur keeping a quarter of its strength to
  the edge, the fade and haze held flat, and a one-pixel 10% black hairline.
  `LiquidPrismScaffold.accessory` adds a row of tabs or controls below the top
  bar inside the effect and the body's padding.
- Imply a leading control in `LiquidPrismScaffold`: when its route can pop
  and `leading` is null, a `LiquidPrismBackButton` draws a back chevron, or a
  close mark on a fullscreen dialog, and pops the route.
  `automaticallyImplyLeading: false` opts out. The button is public for custom
  glyphs; its default chevron is shifted half a point toward its tip so it
  reads centred in the circle. The body now keeps 14 points clear below the
  top bar's capsules (`LiquidPrismScaffold.topBarClearance`), as the measured
  iPhone Duo content safe area does.
- Animate toolbar items. `LiquidPrismToolbarGroup` materializes items in and
  out as `items` changes, resizing the capsule, and takes an empty list, which
  materializes the capsule away. New `LiquidPrismToolbar` lays several groups
  out with a gap and collapses empty ones, so every group a bar can show is
  declared once. `GlassToolbarStyle` gains `itemTransition`,
  `itemTransitionStyle` and `groupSpacing`.
- Cut backdrop pass breaks for grouped glass: shared members' shadows and frost
  passes are painted ahead of the first shared optical pass, so a group of
  frosted surfaces costs two backdrop captures instead of two per surface.
  `LiquidPrismScaffold` now groups its leading control, actions and tab bar.
- Skip the tab bar's separate 2-point selection blur pass when the housing is
  frosted at 3 points or more; `GlassTabBarStyle.selectionBlur` still forces it.
- Trim the optical shader: an interior fast path past every inward band, a
  two-tap rim reflection and two-tap broad lobe, major-axis-only footprint
  integration, and reflection reads ending where they can no longer move a
  channel by two 8-bit steps. Measured on the isolated Metal optical pass: 7–9%
  less GPU time for capsule bars and 15–17% for panels, with buttons inside the
  harness's scheduling noise.

## 0.2.1

- Lay out a `LiquidPrismToolbarGroup` with a single item as a circle, as iOS
  draws a lone bar button: 44 × 44 in a navigation bar and 48 × 48 in a bottom
  toolbar or rail, following custom heights and insets. A navigation group was
  a 46 × 44 capsule. An explicit `GlassToolbarItem.width` is still honored, so
  a wider item stays a capsule; groups of several items are unchanged.

- Let apps host their own autocomplete on `LiquidPrismSearchField`:
  `fieldBuilder` wraps the glass capsule as an overlay anchor, `groupId` and
  `onTapOutside` share the editor's tap region, `onFocusChange` reports focus
  transitions, and `suffixBuilder` keeps or replaces the clear action. The
  cancel action now belongs to the editor's tap region group.
- Add `GlassSearchStyle.padding` and `prefixPadding` for the editor and the
  default search icon.
- Measure the tab foreground lens's raster scale when the scene is composed,
  from the layers that composite it. An ancestor transform that animates
  beneath a repaint boundary, such as a page scaled behind a modal sheet, no
  longer leaves the held tab's glyph lens on a stale scale, and a
  `Transform(filterQuality: ...)` ancestor no longer distorts it.
- In debug builds, report once when glass sits under an ancestor that moves it
  after it is rasterized, such as `Transform(filterQuality: ...)`. Glass cannot
  align its refraction and rim there; remove the `filterQuality` (see
  [rendering](doc/rendering.md#ancestor-transforms)).
- Add `example/lib/transform_main.dart`, a fixture placing glass, a toolbar
  group and a tab bar on a page scaled as a sheet's covered page.

## 0.2.0

- Add `LiquidPrismScaffold` and `GlassChromePlacement`: floating glass chrome
  that moves into the iPhone Duo sensor-bar rail and follows window resizes.
  On iOS 27.1 it follows UIKit's `verticalBarEdge` and reserved regions,
  collapses rail actions into an overflow menu when space runs out, and
  exposes a partial fold as a display feature.
- Add `LiquidPrismSystemChrome`, `GlassSystemChrome` and
  `GlassReservedRegion`: UIKit's vertical bar edge and reserved regions for
  your own sheets, dialogs and bars, with the fold added to
  `MediaQuery.displayFeatures` app-wide. `LiquidPrismViewController` and
  `setVerticalBarBehavior` let an app opt out of the vertical bar.
- Add `GlassTabBarPlacement.sidebar` to `LiquidPrismScaffold`: the measured
  native sidebar at regular width, with a hide and show toggle. Report UIKit's
  size classes as `GlassSystemChrome.horizontalSizeClass` and
  `verticalSizeClass`.
- Match the native sidebar's glass material and its show and hide motion: the
  panel slides on a measured spring while content reflows beneath it, and the
  show toggle materializes in place. Hiding the sidebar no longer moves the tabs
  into the tab bar or rail, matching iOS.
- Add `LiquidPrismVisibility`, `LiquidPrismPresence`, `GlassTransition` and
  `GlassTransitionStyle`: glass materializes in and out from the live backdrop
  while its content fades and sharpens, with a theme-level `transition`.
- Animate the search field's cancel action: the field shortens while the
  button slides in from the trailing edge and fades, with `cancelSpring`.
- Keep tab labels steady under the pill while it is dragged or lifted.
- Reserve the rail strip when UIKit reports a vertical bar edge without an
  inset, as for an app on the left of Split View. The showcase reflows its
  sections into two columns around a bent fold.
- End the rail's tab bar above system UI at the rail's bottom (the closed
  iPhone Duo in landscape), and put top actions beside a status bar in a top
  corner (the unfolded iPhone Duo in portrait), as native bars do.
- Add `axis` to `LiquidPrismTabBar` and `LiquidPrismToolbarGroup` for the
  measured vertical rail layout.
- Present native menus in the Flutter view's own window and close them when
  it resizes.
- Rebuild the showcase with native large titles, grouped lists and content
  that scrolls under its glass chrome.

- Add reusable component appearance styles and shared lens defaults through
  `LiquidPrismThemeData`, with partial inheritance and typed `copyWith`/`merge`.
- Expose small-control springs, minimum lift, velocity deformation and decay
  through `GlassControlMotion` and `GlassSpring`.
- Add circular icon buttons, search editor options, typed input-phase callbacks,
  slider accessibility formatting and configurable tab foreground refraction.
- Preserve native geometry, motion, palette and controlled-value defaults.
- Add a runnable API example, component/style guides and agent implementation docs.

- Match the measured iOS 27 interaction motion: tab pills lift into a glass
  lens with bar and icon scaling, glide on touch, chase the finger through a
  spring and stretch with speed; buttons use the native press and release
  springs and glow timing. `GlassMotion` gains press and release bounce fields.
- Remove the former native glass-rendering plugin, platform views, and rendering-mode API. Popup menus use the separate UIKit bridge.
- Calibrate regular material colors against SwiftUI and share foreground/selection defaults across platforms.

- Fix the fallback circle border in non-square layouts.
- Simplify renderer dispatch and batch grouping without changing the public API.
- Document research, source projects and rendering limitations in dedicated guides; keep the README focused on usage.

## 0.1.0

- Introduce LiquidPrism surfaces, glass buttons, and controlled spring tab bars.
- Support Flutter-rendered Liquid Glass with customizable Impeller optics.
- Add app-wide appearance, tint, foreground, motion, and shape configuration.
- Support custom tab icons, optional labels, finger tracking, and independent pill blur.
- Include mobile example, regression tests, and CI build checks.
