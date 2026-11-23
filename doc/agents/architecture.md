# Architecture

## Public boundary

- `package:liquid_prism/liquid_prism.dart` exports consumer widgets, styles, themes, motion, haptics, badges, and native menus.
- `package:liquid_prism/primitives.dart` exports low-level optical, pressable, edge-blur, and system-chrome building blocks (`PrismOptics`, `PrismLensStyle`, `PrismPressable`, `PrismSelection`, `PrismEdgeBlur`, `PrismEdgeFade`, `PrismPresence`, `PrismSystemChrome`, `PrismTabReselection`).
- `lib/src/` is private implementation detail organized by domain:

| Directory | Responsibility |
| --- | --- |
| `lib/src/core/` | `PrismGlass`, `PrismShape`, `PrismOptics`, `PrismColors`, `PrismMotion`, `PrismSpring`, `PrismHaptics`, `PrismBadge`, `PrismLensStyle` |
| `lib/src/theme/` | `PrismTheme`, `PrismThemeData`, native tint matrices, accent vibrancy |
| `lib/src/rendering/` | `Prism.initialize()`, `PrismSurface`, internal `RawPrismSurface`, render objects/layers, `PrismGroup`, `PrismEdgeBlur`, `PrismEdgeFade`, `PrismVisibility`, `PrismRecipe` (`PrismRole` ABI), `ContentLensWindow`, `PrismDisplay`, superellipse uniforms |
| `lib/src/controls/` | `ControlGestureRecognizer`, `ControlInteraction`, `ControlLens`, `PrismPressable`, `PrismSelection`, `PrismButton`, `PrismSwitch`, `PrismSlider`, `PrismSegmentedControl`, `PrismSearchField`, and their `Prism*Style` classes |
| `lib/src/navigation/` | `PrismScaffold` (split under `scaffold/`), `PrismSliverAppBar`, `PrismNavigationBarStyle`, `PrismTitle`, `PrismTabBar`, `PrismToolbar`, `PrismBackButton`, `PrismScrollEdge`, `PrismRefreshController`, `PrismSystemChrome`, `PrismSidebar`, `PrismTabReselection` |
| `lib/src/menu/` | `PrismMenu` models, platform interface, method channel, engine, `PrismMenuRegion`, `prismMenus` facade, and Material fallback |
| `ios/liquid_prism/Sources/liquid_prism/` | Swift UIKit plugin, `UIMenu` presenter, system chrome, sensor housing, and EDR headroom observers |
| `shaders/` | Impeller GLSL fragment shaders (`glass.frag`, `glass_batch.frag`, `frost_fill.frag`, `edge_blur.frag`, `refresh.frag`, `tab_content.frag`) |

## Ownership & invariants

- Values are parent-owned; controls propose updates and settle to the authoritative parent value if rejected.
- Every immutable style, theme, optics, motion, badge, tab, toolbar, and menu data class implements `==` and `hashCode` so `PrismTheme` (`InheritedWidget`) never triggers spurious rebuilds.
- Internal shader plumbing (`role`, `lensRim`, `chromaticSplit`, `chromaticBand`, `underlay`, `resting`, `materialOptics`, `disabledProminent`) stays on `@internal RawPrismSurface`, never on public `PrismSurface`.
- External shadows paint after lifted lens capture so clipped shadow masks never refract inside the glass.
- Research probes, measurement specs, and benchmarks live under `research/` and are excluded from published archives via `.pubignore`.
