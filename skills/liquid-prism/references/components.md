# Components and defaults

## Styles and material

Resolve customization in this order: local component style, component theme,
native fallback. Keep visuals, geometry, optics, motion and haptics in styles.
The retained button `variant`/`size` and toolbar `size` shortcuts override their
style fields; `PrismSurface` accepts direct material/optical configuration. Null style fields inherit; zero, false
and transparent colors are explicit choices. Nullable nested fields merge;
optical packets replace as a whole. `copyWith(null)` retains an override rather
than clearing it; construct a replacement style to remove that override.

Use `PrismColors.of(context)` and inherited icon/text styling for appearance-aware
colors. Set theme brightness only when the app intentionally differs from the
system. Preserve clear/regular native material defaults before tuning optics.
`glassTint: null` follows the device setting where supported; an explicit value
fixes it for the subtree. An explicit blur or optical packet can override the
material's adaptive frost, so inspect app themes before diagnosing the renderer.

Paint meaningful content behind glass. Stacked glass surfaces, opaque ancestors
and clipping can change the result without a shader defect. Keep room for lifted
lenses to paint outside their resting footprint.

## Actions and state

Use `PrismButton(label: ..., onPressed: ...)` or typed `PrismToolbarItem` actions for built-in styling,
focus, semantics and activation. Ordinary toolbar items receive glass treatment;
raw `leading`/`trailing` widgets retain their own styling. Custom toolbar content
does not automatically become an individual glass button; grouping can supply a
shared capsule. Use `PrismToolbar.group(items: ...)` for a standalone capsule
and `PrismToolbarGroup(items: ...)` as typed toolbar content. Each button requires
`label`, including icon, menu and custom-child buttons.

Use `PrismButton.menu` or `PrismToolbarItem.menu` for native iOS popups.
Do not recreate the native popup in Flutter or add another gesture detector
around a menu trigger, button, tab bar or control.

Values remain parent-owned. Handle proposals in callbacks and rebuild with the
accepted value; external updates and rejected changes are valid. Null callbacks
disable actions. Buttons support `isLoading` and `autoLoading`; app-wide async
exclusivity remains app-owned. Preserve borrowed
controllers/focus nodes and dispose only those the app owns.

Tab bars are compact by default; opt into a bounded full width with
`PrismTabBarStyle(sizing: PrismTabBarSizing.fill)`.
Standalone tab bars do not add safe-area margins. Scaffold-owned tab bars receive
adaptive placement. Avoid nested repaint boundaries in custom tab icons because
foreground refraction currently has that renderer limitation.

## Titles and motion

`PrismTitle` supports plain, inline-leading and above-avatar composition.
Retain the same title/avatar identity
while changing properties so position and scale can animate together. Do not
cross-fade separately keyed copies or add another size animation around the
package's coordinated transition.

Set `PrismMotion` in button, toolbar and tab styles, and `PrismControlMotion` in
switch, slider and segmented styles. Use `PrismLensStyle` from `primitives.dart`
for lifted lens appearance. Keep slider growth independent from underlay
minification, switch tap lift at its 220 ms default, continuous slider endpoint
fill, velocity deformation and independent tab foreground refraction.

Use `PrismVisibility` or `PrismVisibility.driven` for glass presence. Preserve interruption,
Reduce Motion and input ownership. Do not transplant a button's press spring
into navigation title visibility or infer native timings from a screenshot.
