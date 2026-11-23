# Migrating to Liquid Prism 1.0

Liquid Prism `1.0.0` unifies naming under the `Prism*` prefix, separates core widgets from low-level primitives, moves visual overrides cleanly into `Prism*Style` classes, and implements full value equality (`==` / `hashCode`) across all style and theme objects.

## Entry points

- Core consumer API: `import 'package:liquid_prism/liquid_prism.dart';`
- Low-level primitives (`PrismOptics`, `PrismLensStyle`, `PrismPressable`, `PrismSelection`, `PrismEdgeBlur`, `PrismEdgeFade`, `PrismPresence`, `PrismSystemChrome`, `PrismSystemChromeData`, `PrismReservedRegion`, `PrismSizeClass`, `PrismVerticalBarBehavior`, `PrismEdgeBlurStrip`, `PrismFadeCurve`, `PrismTabReselection`): `import 'package:liquid_prism/primitives.dart';`. Code that sets `optics:` or `lens:` on a style or theme needs this import in addition to `liquid_prism.dart`.
- `package:liquid_prism/liquid_menu.dart` has been folded into `package:liquid_prism/liquid_prism.dart`.
- `package:liquid_prism/liquid_menu_platform_interface.dart` and `package:liquid_prism/liquid_menu_method_channel.dart` are no longer public libraries. `LiquidMenuPlatform` and `MethodChannelLiquidMenu` are now the internal `PrismMenuPlatform` and `MethodChannelPrismMenu` under `lib/src/menu/`.

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

The remaining `Glass*` types are renamed one for one: `GlassMotion`, `GlassSpring`, `GlassControlMotion`, `GlassHaptics`, `GlassHapticEvent`, `GlassBadge`, `GlassToolbarItem`, `GlassToolbarGroup`, `GlassToolbarSpacer`, `GlassToolbarContent`, `GlassSearchFieldBuilder`, `GlassSearchSuffixBuilder`, `GlassReservedRegion`, `GlassEdgeFade` -> the same names with a `Prism` prefix. `LiquidPrismToolbarGroup` (the widget) is now `PrismToolbar.group`.

## Strict widget vs. style split

Visual, optical, geometry, motion, padding, and haptic overrides that were previously duplicated on widget constructors now live exclusively in each widget's `style`:

- **`PrismButton`**: move `glass`, `optics`, `blur`, `motion`, `shape`, `padding`, `foregroundColor`, `tintColor`, `loadingIndicator` into `style: PrismButtonStyle(...)`.
- **`PrismSwitch`**: move `activeColor`, `inactiveColor`, `thumbColor`, `haptics`, `motion` into `style: PrismSwitchStyle(...)`.
- **`PrismSlider`**: move `activeColor`, `inactiveColor`, `thumbColor`, `haptics`, `motion` into `style: PrismSliderStyle(...)`.
- **`PrismSegmentedControl`**: move `backgroundColor`, `thumbColor`, `foregroundColor`, `motion` into `style: PrismSegmentedStyle(...)`.
- **`PrismSearchField`**: move `showCancelButton`, `cancelVisibility`, `restingInset`, `textStyle`, `glass`, `optics`, `blur` into `style: PrismSearchStyle(...)`.
- **`PrismTabBar`**: move `glass`, `optics`, `blur`, `motion` into `style: PrismTabBarStyle(...)`.
- **`PrismToolbar`**: move `glass`, `optics`, `blur`, `motion`, `foregroundColor` into `style: PrismToolbarStyle(...)`, and `spacing` into `style: PrismToolbarStyle(groupSpacing: ...)`. `PrismToolbarStyle.spacing` is the gap between items inside a capsule, not between capsules. A `PrismToolbarGroup.style` now overrides the toolbar's `style` for these fields; in 0.x the toolbar-level arguments won over a group's style.
- **`PrismBackButton`**: move `iconShift` and `iconMirrors` into `style: PrismToolbarStyle(backIconShift: ..., backIconMirrors: ...)`, and `foregroundColor` into `style: PrismToolbarStyle(foregroundColor: ...)`.

## Native menus

All `LiquidMenu*` types and unprefixed menu enums are now `Prism*`:
- `liquidMenus` / `LiquidMenus` -> `prismMenus` / `PrismMenus`
- `LiquidMenu`, `LiquidMenuAction`, `LiquidMenuSection`, `LiquidSubmenu`, `LiquidMenuDivider`, `LiquidMenuDeferred`, `LiquidMenuRegion`, `LiquidMenuAnchor`, `LiquidMenuIcon`, `LiquidMenuEvent` -> `PrismMenu`, `PrismMenuAction`, `PrismMenuSection`, `PrismSubmenu`, `PrismMenuDivider`, `PrismMenuDeferred`, `PrismMenuRegion`, `PrismMenuAnchor`, `PrismMenuIcon`, `PrismMenuEvent`
- `MenuElementState`, `MenuElementSize`, `SymbolWeight`, `SymbolScale`, `SymbolRenderingMode` -> `PrismMenuElementState`, `PrismMenuElementSize`, `PrismSymbolWeight`, `PrismSymbolScale`, `PrismSymbolRenderingMode`
- `LiquidMenuElement`, `LiquidMenuPointAnchor`, `LiquidMenuRectAnchor`, `LiquidMenuSfSymbol`, `LiquidMenuImage`, `LiquidMenuPresented`, `LiquidMenuDismissed`, `LiquidMenuActionEvent`, `LiquidMenuTrigger`, `LiquidMenuAnchorMode` -> the same names with `LiquidMenu` replaced by `PrismMenu`

## Typography

- Button, segmented control and tab labels no longer inherit the ambient `DefaultTextStyle`. To style them, set `PrismThemeData.textStyle`, the component style's text style, or the local `style`.
- All labels and titles now adopt a custom app font from the Material or Cupertino theme. Set `PrismThemeData.textStyle` to pin a different one.
- A `PrismButtonStyle.tintColor` set in the theme no longer recolors destructive buttons.

## Equality and merging

- Menu elements, icons, anchors and events, and `PrismToolbarItem`, `PrismToolbarGroup` and `PrismToolbarSpacer`, now compare by value as well. All `PrismMenuDivider` instances are equal, and comparing a `PrismMenuImage` compares its bytes.
- `PrismTheme` notifies dependents only when its merged data changes by value. In 0.x it notified on every rebuild of the theme widget.
- `merge` keeps a nested style `null` when neither side sets it. In 0.x `LiquidPrismTheme.of(context).button`, `.tabBar`, `.lens` and the other component styles were always non-null after a merge; read them with `?.` or `??` now.
