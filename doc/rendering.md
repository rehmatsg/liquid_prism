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

The optional batch shader targets Impeller. Builds and headless tests may print
an SkSL compatibility warning for that shader; the Skia backend uses the frosted
fallback instead of loading it.

Profile a release/profile build on your target phones with realistic moving
content. Simulator frame timings do not establish battery consumption or heat.
The example and regression tests are not a physical-device energy certification.

## Color and appearance

Light/dark material tint ramps come from the native reference. Regular surface
and button luminance is calibrated over neutral backgrounds; separate light/dark
chroma gains retain the backdrop color. Tab bars use their own material recipe. Ordinary buttons
and selected tabs share a calibrated resting accent. Explicit foreground overrides
remain literal; prominent buttons default to white. The shader does not reproduce
Apple's complete backdrop-dependent adaptation or read its system blur setting.
Use theme or widget `blur`, `optics`, and color overrides for app-owned appearance.
