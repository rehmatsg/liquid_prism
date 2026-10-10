# Rendering and performance

Liquid Prism draws glass entirely in Flutter. Impeller's shader filters provide
live backdrop refraction; `LiquidPrism.isShaderSupported` reports that capability.
Unsupported renderers use a frosted fallback retaining content and interaction.
There are no platform views, native plugins, or OS-version-dependent renderer
switches. Web and desktop support is outside this package's contract.

## Composition

Put glass over content already painted in the same scene. A flat background cannot
show much refraction. Content inside the glass stays sharp. Avoid wrapping glass
in an ancestor `Opacity` or `ImageFiltered` save layer: that can isolate its backdrop.

Smooth rectangles use Flutter's continuous-corner clipping and scalar shader
passes. Capsule and circle geometry retain their own contours. Selected pills apply
an independent blur and color adjustment beneath sharp foreground content.

## Cost

Blur cost depends on the affected pixel area, device, overlap, and moving backdrop.
Prefer small control surfaces, bounded blur radii, and static materials during
interaction. The built-in springs animate transforms rather than blur or layout
size. An idle component has no repeating ticker.

The optical shader skips reflection samples where their weight falls below half
an 8-bit step, and skips the highlight and press color matrices at zero weight.
Over a frost blur of at least 2px, the compressed-rim footprint reads one sample
per step instead of a ±¼px pair. Exterior shadows are drawn as rounded-rect or
rounded-superellipse primitives, so Impeller uses its analytic blur instead of
tessellating a blurred path every frame. Press, tint and material changes update
uniforms at composition without repainting the glass content.
Smooth-corner distance uses six angular bisections with cached curve endpoints
and unit-vector midpoints. A terminal-segment test skips the search when its
answer is already known; the projected contour is unchanged. The circular corner
sector uses a dot-product test instead of an inverse tangent. Geometry and edge
sampling stay at display resolution.

Filter descriptions are reused while their shader, uniforms and blur stay equal.
The backdrop itself remains live: movement, scrolling, material changes and
presses update the filter inputs during scene composition. Reusing a description
does not eliminate the GPU work needed to filter a changing background.

`LiquidPrismGroup` can share a shader pass among compatible regular capsules and
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

Light/dark material tint ramps come from the native reference. Regular surface
and button luminance is calibrated over neutral backgrounds; separate light/dark
chroma gains retain the backdrop color. Tab bars use their own material recipe. Ordinary buttons
and selected tabs share a calibrated resting accent. Explicit foreground overrides
remain literal; prominent buttons default to white. The shader does not reproduce
Apple's complete backdrop-dependent adaptation or read its system blur setting.
Use theme or widget `blur`, `optics`, and color overrides for app-owned appearance.
