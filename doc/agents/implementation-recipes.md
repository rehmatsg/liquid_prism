# Implementation recipes

## Add a component appearance option

1. Identify the native default and decide whether it is appearance, input behavior
   or motion. Put appearance in the relevant `Prism*Style`; keep callbacks and
   editor behavior on the widget.
2. Add a nullable field, constructor validation and Dartdoc with units/defaults.
   Update `copyWith`, `merge`, `operator ==` and `hashCode`. Nested styles merge
   field by field, respecting explicit false and zero.
3. Resolve local style > component theme > native fallback. Keep visual, optical,
   geometry, motion and haptic fields in the style; callbacks and semantic inputs
   stay on widgets. Preserve existing semantic shortcuts without adding visual
   duplicates to constructors.
4. Wire the field to layout, paint or interaction. Follow the shader ABI guide if
   GPU data changes. Handle narrow parents and semantic state.
5. Test an override that produces an observable difference, plus an explicit
   zero/false and inheritance where relevant. Run existing native geometry tests.
6. Update components/customization docs and the runnable API example when useful.

For a new style type, also add its theme field, theme `copyWith`/`merge`, and public
barrel export. Keep routine use possible without constructing a style.

## Compose an app

Import `package:liquid_prism/liquid_prism.dart`; add `primitives.dart` only for
low-level APIs such as `PrismLensStyle` or `PrismOptics`. Initialize Flutter
bindings and await `Prism.initialize()`. Put a
`PrismTheme` under your app's MediaQuery/Directionality. Use `PrismColors`
for semantic accents instead of duplicating light/dark values. Place visible
artwork or content below glass in paint order; glass needs something to sample.

Keep state in the app. Switches/sliders/segments propose changes; rebuild with the
accepted value. A tab bar reports selection but does not route pages. Search
reports editor input but does not own filtering/network requests.

For custom motion, put `PrismControlMotion` in small-control styles and
`PrismMotion` in button/toolbar/tab styles. Keep slider knob growth separate from lens
`minifyUnderlay`. Read [motion and lenses](../motion_and_lenses.md).

## Add an action with a popup

Use `PrismButton.menu` or `PrismToolbarItem.menu`. For an existing custom
trigger, use `PrismMenuRegion` or `prismMenus.show<T>` with its context. Do not
wrap a menu button in another competing press recognizer. Model menus using
sections, symbols, submenus and item state; UIKit owns the iOS presentation.

Do not add Flutter copies of iOS popups. Test both bridge wire models and the
Material fallback; native menus require a simulator/device test as well.

## Add another interactive control

Confirm it is in scope: sheets and pickers were removed. Reuse the shared lens and
interaction mechanics when behavior matches. Do not force tab motion into the
small-control velocity model; native large-lens deformation has a separate fit.
Specify parent ownership, commit timing, cancel/recontact, external update,
keyboard, semantics, RTL and disabled behavior before implementing animation.

Keep all reference instrumentation in `research/probes/`. Ship only public platform behavior
in `ios/liquid_prism/Sources/liquid_prism/`. Update architecture, specs and tests alongside a new component.
