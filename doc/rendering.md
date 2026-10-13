# Rendering and performance

Liquid Prism draws glass entirely in Flutter. Impeller's shader filters provide
live backdrop refraction; `LiquidPrism.isShaderSupported` reports that capability.
Unsupported renderers use a frosted fallback retaining content and interaction.
Glass does not use platform views or an OS-native glass renderer. The separate
iOS plugin presents popup menus using UIKit. Web and desktop support is outside this package's contract.

## Composition

Put glass over content already painted in the same scene. A flat background cannot
show much refraction. Ordinary surface content stays sharp. The lifted tab pill separately refracts
its selected icon/label near the rim. Avoid wrapping glass
in an ancestor `Opacity` or `ImageFiltered` save layer: that can isolate its backdrop.
Fade glass with `LiquidPrismPresence` instead. Presence travels in the recipe:
shader slot `u_state.z` carries absence (1 − presence, so the zero default stays
fully present) and premultiplies the output, shadows scale with it, and frost
(a separate backdrop pass) grows with presence. Materializing also grows the
lens and dispersion; a plain fade (`materialize: false`) keeps the full lens. Content fades and unblurs in
the glass's own child wrappers. Glass nested inside the content of a fading
surface sits under that content fade while it runs.

Smooth rectangles and capsules use Flutter's continuous-corner clipping and
scalar shader passes. Circles retain their circular contour. Selected pills apply
an independent blur and color adjustment beneath foreground content; held tabs additionally use the glyph refraction pass.
That pass clips to the pill inside its filter and applies the housing's flex
scale beneath it. Impeller places a filter layer on whole device pixels, so a
clip that follows the pill or an animating ancestor scale makes the filtered
glyphs pop between pixels against the unfiltered ones.

Default regular glass also draws a separate inner ring and a negative edge
highlight. Shadow inputs were extracted from the iOS Simulator; the compositor
mapping and its measured limits are described in [native shadows](native_shadows.md).

## Cost

Blur cost depends on the affected pixel area, device, overlap, and moving backdrop.
Prefer small control surfaces, bounded blur radii, and static materials during
interaction. The built-in springs update transforms and lifted bounds; they do not animate
frost blur. An idle component has no repeating ticker.

The optical shader skips reflection samples where their weight falls below half
an 8-bit step, and skips the highlight and press color matrices at zero weight.
Footprint integration scales with the frost blur: a compressed footprint under
0.3σ reads one sample, under 0.7σ a ±¼ pair, and only wider footprints the
four-point rule. Where the dispersion split is under 0.45σ, three taps with
moment-matched per-channel weights replace the five spectral bands. Each gate
keeps the change below half an 8-bit step over the blurred backdrop; at zero
frost the full paths run. The flat center skips the lens direction arithmetic,
and highlights and reflections are evaluated only within their reach of the
edge. The regular inner ring adds a blurred contour stroke. Exterior shadows are drawn as rounded-rect or
rounded-superellipse primitives, so Impeller uses its analytic blur instead of
tessellating a blurred path every frame. Press, tint and material changes update
uniforms at composition without repainting the glass content.
Smooth-corner distance bisects over the 64-chord arc whose vertices are computed
once per geometry in Dart and passed as uniforms, so the search evaluates no
`pow` or trigonometry per pixel. A terminal-segment test skips the search when
its answer is already known, and pixels whose round-corner depth proves they
lie beyond every consumer of the field (the reflections, the lens band and the
coverage ramp) skip it entirely; the round-corner depth never exceeds the
smooth-corner depth by more than 0.0181 of the radius, so the bound is exact
and the projected contour is unchanged. The circular corner sector compares
against a precomputed cosine. Terms that depend only on the surface (lens band,
displacement, dispersion split and thresholds, frost thresholds, reflection
ends, the smooth bypass depth) are computed once per surface in Dart and passed
as uniforms rather than evaluated per fragment. Geometry and edge sampling stay
at display resolution.

Frost runs as its own backdrop pass clipped to the glass contour, followed by a
shader-only optical pass. Impeller renders the input of a composed shader filter
without a coverage limit, so a blur composed under the optical shader would
filter the whole captured backdrop for every surface on every frame; on an
iPhone 16 Pro that doubled whole-device power and reached the serious thermal
state. Reflection taps outside the contour read the unfrosted backdrop, and the
rim reflection averages four taps one sigma apart in its place. Press scaling is
applied by the glass to its contour, clip, shadow and content rather than as an
ancestor transform, since a non-identity basis above a shader filter makes
Impeller re-rasterize its backdrop. Avoid wrapping glass in your own scale or
rotation transforms for the same reason. Batched group members still compose
frost into their one batch filter.

Filter descriptions are reused while their shader, uniforms and blur stay equal.
The backdrop itself remains live: movement, scrolling, material changes and
presses update the filter inputs during scene composition. Reusing a description
does not eliminate the GPU work needed to filter a changing background.

`LiquidPrismGroup` can share a shader pass among compatible regular circular-corner shapes and
circles:

```dart
LiquidPrismGroup(child: myControls)
```

Grouping preserves semantics but is an optimization, not a merging/morphing effect.
Members must share a background painted outside the group; keep intervening
content outside the group as well.
Incompatible, overlapping, transformed, or smooth-rectangle surfaces can use
individual passes.
Members that are not batched, and whose sampling never reaches another member's
paint, share one backdrop capture while keeping their own filter. This removes
render-pass breaks without resampling their output.

The optional batch shader targets Impeller. Builds and headless tests may print
an SkSL compatibility warning for that shader; the Skia backend uses the frosted
fallback instead of loading it.

Profile a release/profile build on your target phones with realistic moving
content. Simulator frame timings do not establish battery consumption or heat.
The example and regression tests are not a physical-device energy certification.

## Color and appearance

Clear glass uses vertical bright highlights and a thin dark exterior rim,
calibrated against the iOS 27 reference. Both follow the existing contour.
Explicit custom optics retain their diagonal lighting. This adds arithmetic to the
optical pass without adding texture samples or a separate rendering pass.

The built-in regular surface, button and tab-bar face recipes use the extracted
iOS 27 black/white levels, saturation and fill alpha. Clear glass uses its own
extracted face values. Named material tints use full RGB matrices, and the tab
pill uses the decoded native color matrix with normalized offsets converted to
Flutter units. [Native color provenance](native_colors.md) records the source and
scope. Ordinary buttons and selected tabs retain their separately calibrated
resting foreground; explicit foreground overrides remain literal, and prominent
buttons default to white.

The shader does not reproduce Apple's complete compositor, backdrop-dependent
appearance switching, or system blur preference. `materialBrightness` can select
a body/pill appearance independently of the source palette. Custom optics bypass
the built-in face recipe. Use theme or widget `blur`, `optics`, and color overrides
for app-owned appearance.
