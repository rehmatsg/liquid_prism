# Working on Liquid Prism

Liquid Prism is a Flutter package and iOS native-menu plugin. Keep public APIs small, typed, and consistent under the `Prism*` prefix.

## Entry points & structure

- `lib/liquid_prism.dart` — main consumer API (widgets, styles, themes, motion, haptics, menus).
- `lib/primitives.dart` — low-level optical, pressable, edge-blur, and system-chrome building blocks.
- `lib/src/` — internal implementation organized by domain (`core/`, `theme/`, `rendering/`, `controls/`, `navigation/`, `menu/`). Never leak `@internal` parameters onto public widget constructors.
- `ios/liquid_prism/Sources/liquid_prism/` — Swift UIKit plugin & menu bridge; tests live in `ios/liquid_prism/Tests/LiquidMenuTests/`.
- `shaders/` — Impeller GLSL fragment shaders.
- `research/` — local measurement probes, specs, and benchmarks (excluded from package archives via `.pubignore`).

## Product constraints

- Keep native iOS popups native via the UIKit menu bridge; do not recreate iOS popup surfaces in Flutter.
- Sheets, wheel pickers, and date pickers were removed; do not reintroduce them unless explicitly requested.
- Keep compact tab sizing as the default; full width is explicit opt-in via `PrismTabBarSizing.fill`.
- Keep shared lifted-lens styling and size-relative shadows. Slider knobs grow on hold without minifying the underlying track by default.
- Preserve motion-driven deformation, switch haptics, the 220 ms minimum switch tap lift, continuous slider fill blending across the first/last 2%, and independent tab foreground refraction.

## Implementation & style rules

- Follow SemVer (`1.x` additive only; deprecate before breaking in `2.0.0`).
- Keep widget constructors focused on semantic/behavioral props; visual, geometry, optical, motion, and haptic overrides belong in immutable `Prism*Style` classes.
- Every immutable style, theme, optics, motion, and data class MUST implement `operator ==` and `hashCode`.
- Resolution order: local `style` > `PrismThemeData` > native fallback. Merge nullable fields individually and respect explicit `false`/`0`.
- Shader role IDs (`PrismRole.shaderId`) are explicit ABI values; never replace them with enum indices.
- Do not add another gesture owner around a button, menu trigger, or control.
- Zero inline `//` comments in Dart, Swift, or GLSL (preserve only required third-party license attribution headers and Swift `// swift-tools-version:` directives). Keep concise one-line `///` dartdocs on public APIs only.
- Use Conventional Commits (`feat:`, `fix:`, `refactor:`, `perf:`, `docs:`, `test:`, `ci:`, `chore:`).

## Verification

Run `./tool/check.sh` after every change. For iOS native/Swift changes, also run `xcodebuild test -scheme liquid_prism-Package` and `pod ipc spec ios/liquid_prism.podspec > /dev/null`. Exercise shader or renderer changes on a real Impeller simulator or device; rebuild after GLSL changes.

Read [doc/agents/README.md](doc/agents/README.md) for detailed rendering, testing, and architecture guides.
