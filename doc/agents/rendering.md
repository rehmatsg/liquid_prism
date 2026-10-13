# Rendering implementation guide

Read [consumer rendering requirements](../rendering.md) and the relevant native
spec before changing paint order or shaders.

## Shader ABI

`GlassRole` IDs in `recipe.dart` are explicit values shared with shader logic.
Deleted components leave holes; never renumber by enum index. The unminified
shared control lens is ID 10; the slider's native unminified lens remains ID 9.

Dart float writes and GLSL uniforms must agree in count, order and coordinate
units. The tab foreground packet appends its effect vector after the existing
65-point continuous contour array. Update both `tab_content_lens.dart` and
`shaders/tab_content.frag` when changing this packet. Inspect all material roles
and batch paths, not only the one fixture under test.

A running app may retain a compiled program with an old uniform count. Full stop
and rebuild is mandatory after packet/asset edits. A hot-reload RangeError can be
a stale shader, but verify the packet before assuming that explanation.

## Tab foreground pass

The housing lens captures backdrop/bar before icons and labels. Its broad sampling
warp minifies the underlay. The glyph pass instead refracts transparent, tinted
foreground with its own SDF displacement and depth.

`_RenderSelectionWindow` paints the ordinary child outside the pill path and a
selected pass inside an `ImageFilterLayer`. Keep this layer owned by the custom
render object. Adding an ImageFiltered widget/repaint boundary can steal the first
paint, causing unselected content to disappear.

The transparent source rect establishes full input bounds. Intersecting those
bounds with the pill path determines the actual filter crop. Correct shader origin
for that crop. Account for DPR and ancestor transforms when converting to raster
coordinates. The lens reads that scale from `compositedTransform` while the
scene is composed (`_ContentLensLayer`), not from `getTransformTo` at paint: an
ancestor transform can animate without repainting the tab bar, and an ancestor
`ImageFilter.matrix` scales the raster only after the filter runs. Out-of-bounds
sampling returns transparent; do not clamp transparent glyph edges into streaks.

Backdrop glass cannot use that remedy: its input is the enclosing pass, whose
origin Impeller chooses. Under an ancestor matrix filter it can only warn (debug
builds, `transformedAfterRaster`). Consumer guidance is in
[rendering](../rendering.md#ancestor-transforms).

Custom tab icons cannot currently include their own repaint boundaries because
this window paints their subtree twice. Preserve state identity during style or
selection changes. Test first render, movement and resize, not only a settled pill.

## Shared captures

Each `BackdropFilterLayer` makes Impeller end the render pass, store the full
screen and redraw it into a new pass; this pass break, not fragment arithmetic,
dominates the cost of many surfaces at once. An unbatched surface normally costs
two breaks: its clipped frost pass and its optical pass. In a group, members in
`_GlassGroupData.shared` are hoisted: the first shared member to add itself to
the scene (`_GlassShadowLayer.addToScene`) paints every shared member's exterior
shadow picture and frost `BackdropFilterLayer` (clipped to that member's contour,
keyed by `frostKey`), and every shared optical pass uses `sharedKey`. Hoisted
frost sigmas are offset by `index * 1e-4` so Impeller does not treat them as one
equal filter and blur the whole capture once. Members' own `_FrostLayer` and
`_GlassShadowLayer` skip themselves while hoisted. Transforms are taken relative
to the host (`inverse(host.getTransformTo(null)) * member.glassTransform()`),
so members under offset or plain transform layers stay aligned.

`GlassGroupHost` and `GlassGroupMembers` split the group's render layer from its
membership scope; the scaffold hosts the layer around its layout and scopes only
the chrome slots. Keep the contract: nothing paints between members that a
member samples. Headless tests exercise the fallback, so verify grouping with
the real-shader drivers under `_research/package_check/` or the showcase.

## Shared lens and shadows

`ControlLens` owns clear optics and underlay minification; controls supply their
bounds and lift. `GlassLensStyle` merges shared defaults and local overrides.
Explicit optics replace the recipe; explicit blur wins over their frost.

Paint lens shadows externally, after capture, with an outside-contour clip. If
painted underneath, their clipped masks may refract as another transparent capsule.
Shadow blur/offset/ring width scale with actual lens height unless opted out.
Custom kernels/offsets require adequate clip extent; avoid hard-coded padding that
clips a deeply customized shadow.

## Fallback and lifecycle

Shader preload is an optimization, not a requirement that removes fallback paths.
Check supported renderer APIs before installing a filter. Dispose owned images,
listeners and animations, and ignore stale async completions after disposal.
Fallback still needs correct geometry, semantics, colors and controlled input.

Run native geometry tests and a fresh Impeller simulator capture after changing
rendering. Headless tests cannot validate sampling, color grading or layer order.
