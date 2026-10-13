# Public API contracts

## Defaults and overrides

Prefer a short constructor for ordinary use, an immutable style for repeated
component choices, and a scoped theme for app defaults. Do not expose internal
role IDs or rendering states as routine consumer inputs.

Resolution is direct widget argument > local component style > component theme >
native fallback. Shared lens defaults merge below a component's `lens`. Generic
surface theme defaults sit below component-specific material settings. Do not
apply generic glass/blur to lifted lenses accidentally: lenses have their own
clear native recipe.

Nullable style fields mean "inherit". Respect explicit `false`, `0`, zero insets,
transparent colors and `Glass.identity`. Text styles merge their fields;
`LiquidPrismStyle` and `GlassMotion` are complete packets. Partial
`GlassControlMotion` merges its individual fields. Never use truthiness or compare
a supplied value to its default to decide whether it was explicit.

For legacy constructors with non-null defaulted public fields, a nullable input
plus a private supplied flag preserves the public field and recognizes explicit
overrides. Existing examples include button padding, switch haptics and search
cancel visibility. Do not replace a public field with nullable storage casually.

`copyWith` keeps a field when its argument is null. `merge` combines partial
styles, including nested lenses and text fields. To remove a previously set field,
construct a replacement style; `copyWith(null)` is not a reset. To discard outer
theme inheritance, use `LiquidPrismTheme(inherit: false, ...)`. Material tint has
its own explicit reset: `Glass.tint(null)`.

## Input and callback semantics

- Null action/value callbacks disable all activation paths, including semantics.
- Parents own values; a proposal may be rejected. External updates and key
  reordering must cancel obsolete gestures and settle to the current value.
- `onChangeStart`/`onChangeEnd` are input-phase callbacks, not animation completion.
  Switch callbacks receive booleans, segment callbacks receive keys, slider
  callbacks receive actual range values. Preserve existing cancellation behavior.
- Slider formatting receives actual `min`–`max` values, including accessibility
  increase/decrease previews. Divisions quantize values, not physical pixel travel.
- Switch haptics occur on iOS at user toggle boundaries. External updates and
  cancellation must not generate haptics.
- Slider haptics occur on iOS when accepted user input first reaches the minimum
  or maximum. `ControlInteraction` announces an end only when the parent rebuilds
  with exactly the end a user input proposed in that frame; external updates,
  cancellation and rejected or altered values only move the latch.
- Async button callbacks may overlap. Loading/exclusive state belongs to the app.
- Custom tab icons must currently avoid nested repaint boundaries; document this
  renderer limitation rather than silently replacing their stateful subtree.

## Geometry and accessibility

Use logical pixels. Small-control `scale` multiplies geometry; text/track controls
remain separately configurable. Keep minimum 44-point hit height and switch hit
width. A lifted lens may paint outside resting layout. Do not clip it at the
control boundary. Sliders/segments constrain preferred width to available space;
compact tabs measure labels rather than always stretching.

Validate ranges in constructors when const expressions allow it; validate compound
Size/geometry relationships during layout. Ensure constraints can still become
narrow/zero without division by zero. RTL changes physical mapping, not logical
order. Preserve labels, keyboard activation, focus and Reduce Motion.

## Adding an option

Wire the option through public export, style constructor/fields, typed `copyWith`,
`merge`, theme resolution, actual layout/paint, and docs. Test observable behavior
and precedence. A field that is accepted but ignored is a broken API.

Keep names consistent with Flutter conventions. Search already has `style` for
`TextStyle`, so its component configuration is named `appearance`; changing that
would break source compatibility. Button's treatment enum remains `buttonStyle`,
while `style` accepts `GlassButtonAppearance`.

Avoid new dependencies for a configuration object. Keep styles const-friendly,
immutable and typed. Preserve direct-import enum reexports when moving declarations.
