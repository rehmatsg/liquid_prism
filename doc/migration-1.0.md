# Migrating to Liquid Prism 1.0

Liquid Prism `1.0.0` unifies naming under the `Prism*` prefix, separates core widgets from low-level primitives, moves visual overrides cleanly into `Prism*Style` classes, and implements full value equality (`==` / `hashCode`) across all style and theme objects.

## Entry points

- Core consumer API: `import 'package:liquid_prism/liquid_prism.dart';`
- Low-level primitives (`PrismOptics`, `PrismLensStyle`, `PrismPressable`, `PrismSelection`, `PrismEdgeBlur`, `PrismEdgeFade`, `PrismPresence`, `PrismSystemChrome`, `PrismTabReselection`): `import 'package:liquid_prism/primitives.dart';`
- `package:liquid_prism/liquid_menu.dart` has been folded into `package:liquid_prism/liquid_prism.dart`.

## Startup & surface

| 0.x | 1.0 |
| --- | --- |
| `LiquidPrism.preload(enableHDR: ...)` | `Prism.initialize(enableHDR: ...)` |
| `LiquidPrism.isShaderSupported` | `Prism.isShaderSupported` |
| `LiquidPrism(...)` | `PrismSurface(...)` |
| `LiquidPrismGroup` | `PrismGroup` |
| `LiquidPrismStyle` | `PrismOptics` (`primitives.dart`) |
| `Glass`, `GlassVariant`, `GlassShape` | `PrismGlass`, `PrismGlassVariant`, `PrismShape` |
| `LiquidPrismTheme`, `LiquidPrismThemeData`, `GlassColors` | `PrismTheme`, `PrismThemeData`, `PrismColors` |

## Widgets & controls

| 0.x | 1.0 |
| --- | --- |
| `LiquidPrismButton` | `PrismButton` |
| `LiquidPrismSwitch` | `PrismSwitch` |
| `LiquidPrismSlider` | `PrismSlider` |
| `LiquidPrismSegmentedControl` | `PrismSegmentedControl` |
| `LiquidPrismSearchField` | `PrismSearchField` |
| `LiquidPrismTabBar`, `LiquidPrismTab` | `PrismTabBar`, `PrismTab` |
| `LiquidPrismToolbar` | `PrismToolbar` |
| `LiquidPrismToolbarGroup` | `PrismToolbar.group` |
| `LiquidPrismBackButton` | `PrismBackButton` |
| `LiquidPrismTitle` | `PrismTitle` |
| `LiquidPrismScaffold` | `PrismScaffold` |
| `LiquidPrismSliverAppBar` | `PrismSliverAppBar` |
| `LiquidPrismRefreshController` | `PrismRefreshController` |
| `LiquidPrismScrollEdge` | `PrismScrollEdge` |
| `LiquidPrismScrollFade` | `PrismScrollEdge.fade` |
| `LiquidPrismVisibility` | `PrismVisibility` |
| `LiquidPrismPresence` | `PrismVisibility.driven` (or `PrismPresence` in `primitives.dart`) |
| `LiquidPrismEdgeBlur`, `GlassEdgeBlur` | `PrismEdgeBlur`, `PrismEdgeBlurStrip` (`primitives.dart`) |
| `LiquidPrismPressable`, `LiquidPrismSelection` | `PrismPressable`, `PrismSelection` (`primitives.dart`) |
| `LiquidPrismSystemChrome`, `GlassSystemChrome` | `PrismSystemChrome`, `PrismSystemChromeData` (`primitives.dart`) |

## Styles & enums

All `Glass*Style` classes and enums are now `Prism*`:
- `GlassToolbarTitleDisplayMode` -> `PrismTitleDisplayMode`
- `GlassToolbarMinimizationBehavior` -> `PrismMinimizationBehavior`
- `GlassToolbarMinimizationRestoration` -> `PrismMinimizationRestoration`
- `GlassToolbarMinimizationSafeAreaAdjustment` -> `PrismMinimizationSafeArea`
- `GlassNavigationBarStyle.minimizationSafeAreaAdjustment` -> `PrismNavigationBarStyle.minimizationSafeArea`

## Strict widget vs. style split

Visual, optical, geometry, motion, padding, and haptic overrides that were previously duplicated on widget constructors now live exclusively in each widget's `style`:

- **`PrismButton`**: move `glass`, `optics`, `blur`, `motion`, `shape`, `padding`, `foregroundColor`, `tintColor`, `loadingIndicator` into `style: PrismButtonStyle(...)`.
- **`PrismSwitch`**: move `activeColor`, `inactiveColor`, `thumbColor`, `haptics`, `motion` into `style: PrismSwitchStyle(...)`.
- **`PrismSlider`**: move `activeColor`, `inactiveColor`, `thumbColor`, `haptics`, `motion` into `style: PrismSliderStyle(...)`.
- **`PrismSegmentedControl`**: move `backgroundColor`, `thumbColor`, `foregroundColor`, `motion` into `style: PrismSegmentedStyle(...)`.
- **`PrismSearchField`**: move `showCancelButton`, `cancelVisibility`, `restingInset`, `textStyle`, `glass`, `optics`, `blur` into `style: PrismSearchStyle(...)`.
- **`PrismTabBar`**: move `glass`, `optics`, `blur`, `motion` into `style: PrismTabBarStyle(...)`.
- **`PrismToolbar`**: move `glass`, `optics`, `blur`, `motion`, `foregroundColor`, `spacing` into `style: PrismToolbarStyle(...)`.
- **`PrismBackButton`**: move `iconShift`, `iconMirrors`, `foregroundColor` into `style: PrismToolbarStyle(...)`.

## Native menus

All `LiquidMenu*` types and unprefixed menu enums are now `Prism*`:
- `liquidMenus` / `LiquidMenus` -> `prismMenus` / `PrismMenus`
- `LiquidMenu`, `LiquidMenuAction`, `LiquidMenuSection`, `LiquidSubmenu`, `LiquidMenuDivider`, `LiquidMenuDeferred`, `LiquidMenuRegion`, `LiquidMenuAnchor`, `LiquidMenuIcon`, `LiquidMenuEvent` -> `PrismMenu`, `PrismMenuAction`, `PrismMenuSection`, `PrismSubmenu`, `PrismMenuDivider`, `PrismMenuDeferred`, `PrismMenuRegion`, `PrismMenuAnchor`, `PrismMenuIcon`, `PrismMenuEvent`
- `MenuElementState`, `MenuElementSize`, `SymbolWeight`, `SymbolScale`, `SymbolRenderingMode` -> `PrismMenuElementState`, `PrismMenuElementSize`, `PrismSymbolWeight`, `PrismSymbolScale`, `PrismSymbolRenderingMode`
