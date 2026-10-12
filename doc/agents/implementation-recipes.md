# Implementation recipes

## Add a component appearance option

1. Identify the native default and decide whether it is appearance, input behavior
   or motion. Put appearance in the relevant `Glass*Style`; keep callbacks and
   editor behavior on the widget.
2. Add a nullable field, constructor validation and Dartdoc with units/defaults.
   Update both `copyWith` and `merge`. Nested styles merge field by field.
3. Resolve the style once from theme plus local override. Apply direct widget
   arguments last. Retain native fallback at the consumption point.
4. Wire the field to layout, paint or interaction. Follow the shader ABI guide if
   GPU data changes. Handle narrow parents and semantic state.
5. Test an override that produces an observable difference, plus an explicit
   zero/false and inheritance where relevant. Run existing native geometry tests.
6. Update components/customization docs and the runnable API example when useful.

For a new style type, also add its theme field, theme `copyWith`/`merge`, and public
barrel export. Keep routine use possible without constructing a style.

## Compose an app

Initialize Flutter bindings and await `LiquidPrism.preload()`. Put a
`LiquidPrismTheme` under your app's MediaQuery/Directionality. Use `GlassColors`
for semantic accents instead of duplicating light/dark values. Place visible
artwork or content below glass in paint order; glass needs something to sample.

Keep state in the app. Switches/sliders/segments propose changes; rebuild with the
accepted value. A tab bar reports selection but does not route pages. Search
reports editor input but does not own filtering/network requests.

For custom motion, use `GlassControlMotion` for small controls and `GlassMotion`
for buttons/toolbar/tab travel. Keep slider knob growth separate from lens
`minifyUnderlay`. Read [motion and lenses](../motion_and_lenses.md).

## Add an action with a popup

Use `LiquidPrismButton.menu` or `GlassToolbarItem.menu`. For an existing custom
trigger, use `LiquidMenuRegion` or `liquidMenus.show<T>` with its context. Do not
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

Keep all reference instrumentation in `tool/`. Ship only public platform behavior
in `ios/Classes/`. Update architecture, specs and tests alongside a new component.
