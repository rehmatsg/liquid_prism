# Rendering implementation guide

For the optical code, start at `shadeGlass()` in `shaders/glass_core.glsl`:
it maps coordinates and displacement, then calls `sampleGlass`, `gradeInput`,
`reflectGlass`, `gradeFace`, `lightGlass` and `gradePressed` in paint order.
`glass.frag` declares the scalar packet; `glass_batch.frag` unpacks a member
before entering the same routine. Dart packet assembly is in `_RenderGlass`.

For grouping, `_GlassGroupData.prepare` selects shared and batched members.
`_GlassGroupGeometry.measure` computes each member's bounds and sampling reach;
`_prepareBatches` packs the accepted members. `_hoist` paints only shared
shadows and frost. Edge effects compose independently in `edge_blur.dart`.

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

`ContentLensWindow.selection` stacks two `_RenderSelectionWindow`s: the
interactive, unselected row painted outside the pill path, and a display-only
selected copy (selected icons, semibold labels, selected color; no hit testing,
semantics or focus) painted inside it through an `ImageFilterLayer`. Native keeps
the same two copies, so a tab seen through the moving pill shows its selected
icon. Keep the base row the Stack's first child so opening the window never
rebuilds tab state, and keep the filter layer owned by the custom render object.
Adding an ImageFiltered widget/repaint boundary can steal the first paint,
causing content to disappear.

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

Custom tab icons should still avoid their own repaint boundaries: the refracted
selected copy has not been verified with them on a GPU. Preserve the base row's
state identity during style or selection changes. Test first render, movement and
resize, not only a settled pill.

## Face block and frost passes

`u_face` closes the scalar packet (floats 338–341, `glassUniformCount` 342):
x is regular glass's face-fill alpha, y the inner ring shadow's opacity
(`NativeGlassShadow.ringOpacity` × shadow strength, zero for custom optics and
lenses), z the SDR luma limit and w the fill gray. The last two fields are used
by dark regular grading; clear glass and lenses bypass that grading. The batch
shader carries it as
each lens's seventeenth vec4 (`batchLensStride` 68 floats), so a batch holds
at most `batchMaxLenses` 15 lenses in its 256 vec4. `test/glass_tint_test.dart`
parses both shaders against these constants.

The ring is evaluated in `ringShadow()` under the key/fill highlight. Its band
mask (`facing`, `gain`) is a fit documented in [native shadows](../native_shadows.md#the-rim-over-white-on-ios-272).

A surface's frost is a list of `FrostPass`es (`lib/src/recipe.dart`), resolved
from the tint amount for the material's own frost and plain otherwise. Each
pass is a `BackdropFilterLayer` under the `_FrostLayer` (blur, faded by a
colour-matrix alpha, composited with the pass's blend mode). An unshared
surface's passes share the layer's own `BackdropKey`, so the backdrop is
captured once and each pass blurs the same pixels; hoisted members' passes use
`frostKey`. Each pass gets a distinct sigma offset (1e-4) so Impeller never
treats two as equal filters on one key. `style.frost` handed to the optical
pass is `FrostPass.effectiveSigma`: zero while sharp detail shows through. A
batch composes one plain frost, so only members whose frost is a single
covering pass batch; the rest share captures. Regular and Clear share the device frost curve, including the two-pass blur
fill at intermediate high settings. The
calibration and limits are in [native defaults](../native_defaults.md).

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
the showcase drivers in `example/test_driver/`.

`_clipsToGroup` walks a member's layers up to the group layer. Offset, transform, plain container and annotated-region layers pass;
plain clip layers are collected (in root logical coordinates, via
`compositedTransform` divided by the DPR) and applied again to that member's
hoisted shadow and frost passes; anything else (a saveLayer clip,
opacity, filter, mask) keeps the member out of `shared`. Batching still
requires no intermediate layer at all.

## Edge effects

Edge effects paint their own passes in place. Glass painted after an effect
captures and refracts its blurred, faded content. Edge effects do not register
with the glass group or share its captures.

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
frame. The haze is skipped in the texture frame. Under
an isolating ancestor the effect filters its child's raster through a
composed `ImageFilter` on its content layer instead, and adds no backdrop
pass.

## Tab pill rim

The tab pill uses an along-rim chromatic fringe.
Recipe slot `u_state.w` (uniform 45, `GlassRecipe.lensRim`) retains the bright
glint, scaled by lift and `GlassTabBarStyle.rimRefraction`. That style multiplier
also scales the fringe in backdrop and foreground; 0 disables all three.
The 1.5-point glint (blue reaching .3 deeper) and .16 strength
scale with lens height over 70; this is a fitted treatment, not a native operator.

`u_derived[1].w` (float 329) carries effective red–blue split in device pixels:
style split × lift × presence × DPR, before the sampling transform. Reserved `u_shapeD.z`
(float 60) carries band depth in local points. The contour generator still writes
zero there; packet assembly replaces it only for lens kind 3. Non-lens recipes
write both slots as zero; batching accepts only kind 1 and keeps its constant
`u_shapeD` zero. The smooth-contour bypass and flat-center exit include the band.
Reserved `u_shapeD.w` (float 61) carries the lifted lens's underlay
displacement in points, limited like the rim to 0.55 of the lens's thinner side;
it is separate from the rim refraction in `u_derived[0].y`, as native gives the
underlay and the lens's glassBackground rim separate passes. Zero skips the
36-point field.

`chromatic_fringe.glsl` shares the direction `-(n.y,n.x)` across both passes.
In the backdrop, only inside the lens and band, red reads `p-s`, green `p`,
blue `p+s`, with `s = .5 * w * split * direction` transformed into the backdrop
raster basis. The existing generic dispersion path remains outside the band.
The glyph pass has its own measured fit (`glyphFringeWeight`): channels shift
`.77 × split × size × w`, half blended with the unshifted glyph, flat to
`1.15 band` then e-folding every `.44 band`, with `size` the pill height over
73.6. See [measurements and fit errors](../native_controls_spec.md#chromatic-rim-fringe)
and [glyph fringe](../native_controls_spec.md#glyph-fringe).

In the foreground packet, `u_effect` is vec4 at floats 286–289:
displacement/depth in scaled points,
effective split in raster pixels (split × clamped lift × flex scale × composited
DPR), and band in scaled points. Out-of-bounds reads remain transparent. R/G/B
come from the corresponding shifted premultiplied samples; output alpha is their
maximum, bounding every channel even at antialiased glyph edges. Zero displacement
can still fringe; `refractContent: false` disables both foreground effects.
Float 290, `u_tone`, is the grey level of the bar under the foreground (1 in
light appearance, .16 in dark): a channel whose shifted sample misses the glyph
takes it for the coverage it lacks, as native disperses glyphs already over the
bar. Without it, those pixels paint the remaining channels at full alpha, which
reads as black smears on light bars. Float 291, `u_wrapper`, carries the outer
content-wrapper displacement. The shader evaluates the inner lens at the
depth displaced by that wrapper.

The touch glow paints between the housing and lens. Clip it to the housing
including its flex expansion, so its inner edge cannot refract as a second rim.

## Shared lens and shadows

`ControlLens` owns clear optics and underlay minification; controls supply their
bounds and lift. It resolves each role's captured rim and the separate underlay
amount (9 points over 36 for every minifying lens, scaled by lift). The shader
reads that field at the refracted sample's depth, as native composes the two. `GlassLensStyle` merges shared defaults and local overrides.
Explicit optics replace the recipe; explicit blur wins over their frost.

Paint lens shadows externally, after capture, with an outside-contour clip. If
painted underneath, their clipped masks may refract as another transparent capsule.
Shadow blur/offset/ring width scale with actual lens height unless opted out.
Custom kernels/offsets require adequate clip extent; avoid hard-coded padding that
clips a deeply customized shadow.

## Frame budget

The cheapest frame is one that is never drawn. Nothing in the package ticks
while idle; keep it that way (no repeating controllers, no listeners that
rebuild on unchanged values).

- Springs stop when their remaining motion is invisible. Pass `precision` to
  `springGlass` (from `GlassSettle.precision`: a quarter physical pixel of
  movement, half an 8-bit step of colour) and the spring ends once its energy
  bound says it can never stray further. Flutter's default tolerance waited for
  0.001 units/s and kept a unit-range spring ticking for 0.3 to 0.4 s more. Leave
  it null where a value's visible rate is unknown or very large (the slider
  position: its fill blends over 2 % of the value).
- Scrolling must not repaint the chrome. The scaffold's layout reads the scroll
  offset only while the large title can move (`_layoutOffset` is clamped past
  it), and `ScrollEdgeProgressBuilder` rebuilds an edge effect only when its
  strength changes. A relayout of the scaffold's `CustomMultiChildLayout`
  repaints its whole route boundary, re-recording every bar surface and shadow.
- A `LiquidPrismSliverAppBar` sits under a `RepaintBoundary`: the viewport
  repaints all slivers each scroll frame, and the pinned bar would otherwise be
  re-recorded with them. Glass uniforms are read at composition, so a reused
  bar layer still follows the scroll.
- A resting control thumb has no glass. `ControlLens` at lift 0 paints only
  its fill, clipped to the contour: every optic is scaled by lift and the
  opaque fill covers the lens, so the backdrop pass (a full-screen store and
  reload per thumb, every frame) bought nothing. Custom `optics`, frost, a
  `LiquidPrismPresence` ancestor or a tab glint (`rim`) keep the glass, since
  those are not neutral at rest. `test/resting_thumb_test.dart` covers it.

`test/frame_budget_test.dart` covers these contracts.

## Refresh contour

Compact and accessory-only scaffold headers use an independent circle below
chrome instead of the attached-drop shader. Layout publishes the full header
boundary, including accessories and docks, for the painter. The boundary also
records the lowest occupied header edge, so the resting circle has 24-point
clearance above and below without counting the normal body inset twice. The presentation is
latched when a pull starts (also for controller refreshes). Only the extra gap
not already supplied by scroll overscroll is translated into the body; this
holds space during refreshing and supports clamping physics without double
movement. Large/custom scrolling headings and headerless pages keep the drop.

The refresh shader handles the attached drop's smooth unions. Its 14-float
packet ends with the inward outline width and alpha; the outline fades away at
the original sensor-housing contour. Dark appearance uses a one-point white
outline at 22% opacity. Once the neck and anchor no longer affect the circle,
Canvas draws it with native antialiasing instead of sampling the shader's SDF.

Paint bounds include both smooth unions' possible expansion (`k / 6` each),
the anchor and the antialiasing margin. The tip can still be above the top edge
while the union protrudes below it; using the tip's bounds alone clips that
early bulge on devices without an island. Verify early pulls as well as attached,
detached and refreshing states. With `test_driver/showcase.dart` running, use
`DART_VM_SERVICE_URL=... dart test_driver/capture_refresh.dart <output-directory>`
from `example/` to capture both appearances and the reported device tint. Captures
are local evidence, not package assets.

## Fallback and lifecycle

Shader preload is an optimization, not a requirement that removes fallback paths.
Check supported renderer APIs before installing a filter. Dispose owned images,
listeners and animations, and ignore stale async completions after disposal.
Fallback still needs correct geometry, semantics, colors and controlled input.

Run native geometry tests and a fresh Impeller simulator capture after changing
rendering. Headless tests cannot validate sampling, color grading or layer order.
