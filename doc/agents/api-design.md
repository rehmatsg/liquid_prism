# Public API contracts

## Naming & barrel boundaries

- Every public type uses the `Prism*` prefix (and `prismMenus` for the menu facade). Zero unprefixed public enums or classes.
- Core consumer types export from `lib/liquid_prism.dart`; low-level building blocks export from `lib/primitives.dart`.

## Widget vs. style split

- Widget constructors accept semantic and behavioral parameters (`value`, `onChanged`, `label`, `icon`, `variant`, `size`, `enabled`, `isLoading`, `autoLoading`, `destructive`, `selected`, `focusNode`, `style`, etc.).
- Visual, geometry, optical, motion, padding, and haptic overrides live in immutable `Prism*Style` classes and inherit from `PrismThemeData`.
- Resolution order: local widget `style` > `PrismThemeData` > native fallback.
- Nullable style fields mean inherit; respect explicit `false`, `0`, zero insets, transparent colors, and `PrismGlass.identity`.
- Every style, theme, optics, motion, and data class MUST implement `==`, `hashCode`, `copyWith`, and `merge` (for partial styles).

## Input & callback semantics

- Null action/value callbacks disable all activation paths including semantics.
- Parents own values; external updates and key reordering cancel obsolete gestures and settle to the current value.
- `onChangeStart` / `onChangeEnd` are input-phase callbacks, not animation completion.
- Switch haptics fire on iOS at user toggle boundaries; slider haptics fire when accepted user input reaches `min` or `max`.
- Each tab bar, switch, slider, and segmented control has a single gesture owner (`ControlGestureRecognizer`). Disabled controls remain recognizer-free so scrolls pass through.
- `PrismButton` with `isLoading` or `autoLoading` ignores activation while remaining enabled, focusable, and announced as a button.

## SemVer & compatibility

- Follow SemVer starting at `1.0.0`. Additive changes are minor; bug/visual fixes are patch; breaking removals require a deprecation cycle (`@Deprecated`) and a major release (`2.0.0`).
- Shader role IDs (`PrismRole.shaderId`) are explicit ABI values; never replace them with enum indices.
