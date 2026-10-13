# Changelog

## Unreleased

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
