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

`_clipsToGroup` walks a member's or edge effect's layers up to the group
layer. Offset, transform, plain container and annotated-region layers pass;
plain clip layers are collected (in root logical coordinates, via
`compositedTransform` divided by the DPR) and applied again to that member's
hoisted shadow, frost and edge passes; anything else (a saveLayer clip,
opacity, filter, mask) keeps the member out of `shared`. Batching still
requires no intermediate layer at all.

## Edge effects in a group

`_RenderEdgeBlur` (edge_blur.dart, a part of glass.dart) registers in
`_GlassGroupData.edges`. `prepare()` puts active, non-isolated, hoistable
effects in `hoistEdges` and turns batching off. The hoist host is whichever
reaches the scene first: a shared member's `_GlassShadowLayer` or an effect's
`_EdgeHoistLayer`, which sits between the effect's content layer and its strip
clips so the hoisted shadows are not clipped to the strips. `_hoist` paints
shadows, frost, then each hoisted effect's horizontal pass (`frostKey`),
vertical pass (`sharedKey`) and fade, all clipped to the strips minus the
shared members' contours (`Path.combine` difference, cached by signature). An
effect with a child is hoisted only as host, since its child must already be
painted. Hoisted effects skip their own `_EdgePassLayer` and `_EdgeFadeLayer`;
a lone shared member stays shared while an effect is hoisted.

An effect's clip walk to the group starts at its content layer's parent (the
content layer is its own). While an effect is hoisted, members share unless
their glass bounds overlap: their 44-point reflection envelopes and shadow
skirts reaching a neighbour would otherwise leave both unshared, and an
unshared member captures after the effect and refracts blurred, faded
content (a bar button above a search-field accessory). Without hoisted
effects the stricter sampled/painted test still applies. With an effect
hoisted, the shared shadows paint after it: they belong to the glass above
the effect, so the effect must neither blur nor fade them. Headless tests do
not load the shaders, so verify hoisting on a simulator: compare the glass
over the strip with `scrollEdge: false`.

The pass uniforms are `u_pass`, `u_box`, `u_matrix`, `u_inverse`, `u_start`,
`u_end` (24 floats after the engine's texture size; the strips' fourth
components are their strength floors); keep `_uniforms` and
`shaders/edge_blur.frag` in step. The shader pairs Gaussian taps into one
bilinear read, so the backdrop sampler is bound linear through the same 1 x 1
image trick as the optical shader, and derives weights incrementally. Its ramp
is smoothstep, fitted to the native mask (doc/native_scroll_edge_spec.md).
The pass is ALU bound: taps are formed in uv space (the clamp is a free
saturate) and, from a 1.5-texel sigma up, the kernel ends at 2.88 sigma
(under 0.4% of its mass dropped, at most one 8-bit step); below that one pair
carries too much weight to drop, so 3 sigma stays.

The haze (`GlassEdgeBlur.haze`) is a third backdrop filter after the vertical
pass: a plain `ImageFilter.blur(sigma)` whose backdrop layer has one child, a
`dstIn` linear gradient (`_paintHazeWeights`) that scales the blurred strip
by its per-row weight (opacity over the plateau fraction, then linearly to
zero), so composited over the pass it blends the heavy blur in by that
weight, as native bars composite a 16-point blur at half opacity under a
linear mask. Keep the blur the top-level filter: Impeller passes a coverage
hint (the clip) only to the outermost filter, so a blur composed under a
shader or colour filter is computed over the whole captured screen every
frame. The hoisted haze uses its own backdrop layer whose gradient is
recorded in the host's space. Hoisted, it reads
`sharedKey` like the vertical pass. It is skipped in the texture frame. Under
an isolating ancestor the effect filters its child's raster through a
composed `ImageFilter` on its content layer instead, and adds no backdrop
pass.

## Tab pill rim

The tab pill's old radial channel split is replaced by the along-rim fringe.
Recipe slot `u_state.w` (uniform 45, `GlassRecipe.lensRim`) retains the bright
glint, scaled by lift and `GlassTabBarStyle.rimRefraction`. That style multiplier
also scales the new fringe in backdrop and foreground; 0 disables all three.
The existing 1.5-point glint (blue reaching .3 deeper) and .16 strength still
scale with lens height over 70; this is a fitted treatment, not a native operator.

The scalar packet remains 338 floats. Reserved `u_derived[1].w` (float 329)
now carries effective red–blue split in device pixels: style split × lift ×
presence × DPR, before the existing sampling transform. Reserved `u_shapeD.z`
(float 60) carries band depth in local points. The contour generator still writes
zero there; packet assembly replaces it only for lens kind 3. Non-lens recipes
write both slots as zero; batching accepts only kind 1 and keeps its constant
`u_shapeD` zero. The smooth-contour bypass and flat-center exit include the band.

`chromatic_fringe.glsl` shares the fitted falloff and direction `-(n.y,n.x)`
across both passes. Only inside the lens and band, red reads `p-s`, green `p`,
blue `p+s`, with `s = .5 * w * split * direction` transformed into the backdrop
raster basis. The existing generic dispersion path remains outside the band.
See [measurements and fit errors](../native_controls_spec.md#chromatic-rim-fringe).

The foreground packet grows from 288 to 290 floats: after the contour,
`u_effect` is now vec4 at floats 286–289: displacement/depth in scaled points,
effective split in raster pixels (split × clamped lift × flex scale × composited
DPR), and band in scaled points. Out-of-bounds reads remain transparent. R/G/B
come from the corresponding shifted premultiplied samples; output alpha is their
maximum, bounding every channel even at antialiased glyph edges. Zero displacement
can still fringe; `refractContent: false` disables both foreground effects.

The touch glow is painted between the housing and the lens and must be
clipped to the housing as drawn, including its flex expansion. Clipped to the
resting contour it left a hard inner edge that the lens magnified into a
second rim.

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
