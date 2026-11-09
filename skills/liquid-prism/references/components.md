# Components and defaults

## Styles and material

Resolve customization in this order: direct widget argument, local component
style, component theme, native fallback. Null style fields inherit; zero, false
and transparent colors are explicit choices. Nullable nested fields merge;
optical packets replace as a whole. `copyWith(null)` retains an override rather
than clearing it; construct a replacement style to remove that override.

Use `GlassColors.of(context)` and inherited icon/text styling for appearance-aware
colors. Set theme brightness only when the app intentionally differs from the
system. Preserve clear/regular native material defaults before tuning optics.
`glassTint: null` follows the device setting where supported; an explicit value
fixes it for the subtree. An explicit blur or optical packet can override the
material's adaptive frost, so inspect app themes before diagnosing the renderer.

Paint meaningful content behind glass. Stacked glass surfaces, opaque ancestors
and clipping can change the result without a shader defect. Keep room for lifted
lenses to paint outside their resting footprint.

## Actions and state

Use `LiquidPrismButton` or typed `GlassToolbarItem` actions for built-in styling,
focus, semantics and activation. Ordinary toolbar items receive glass treatment;
raw `leading`/`trailing` widgets retain their own styling. Custom toolbar content
does not automatically become an individual glass button; grouping can supply a
shared capsule. Check the installed constructor and group behavior before adding
another glass wrapper.

Use `LiquidPrismButton.menu` or `GlassToolbarItem.menu` for native iOS popups.
Do not recreate the native popup in Flutter or add another gesture detector
around a menu trigger, button, tab bar or control.

Values remain parent-owned. Handle proposals in callbacks and rebuild with the
accepted value; external updates and rejected changes are valid. Null callbacks
disable actions. Async loading/exclusivity belongs to the app. Preserve borrowed
controllers/focus nodes and dispose only those the app owns.

Tab bars are compact by default; full-width sizing is an explicit choice.
Standalone tab bars do not add safe-area margins. Scaffold-owned tab bars receive
adaptive placement. Avoid nested repaint boundaries in custom tab icons because
foreground refraction currently has that renderer limitation.

## Titles and motion

`LiquidPrismTitle` supports plain, inline-leading and above-avatar composition.
On versions with composition transitions, retain the same title/ avatar identity
while changing properties so position and scale can animate together. Do not
cross-fade separately keyed copies or add another size animation around the
package's coordinated transition. Confirm support in the resolved version.

Use package motion styles when customization is needed; preserve interruption,
Reduce Motion and input ownership. Do not transplant a button's press spring
into navigation title visibility or infer native timings from a screenshot.
