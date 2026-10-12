# Changelog

## Unreleased

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
