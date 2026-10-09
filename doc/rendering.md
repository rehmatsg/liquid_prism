# Rendering and performance

The default `GlassRendering.system` selects public UIKit Liquid Glass on iOS 26+
when the plugin is initialized and no optical/blur override is supplied. Each
surface uses one platform view; Flutter owns content and gestures. Native materials
follow system appearance and accessibility preferences. This path needs an iOS 26+
SDK to compile and an iOS 26+ device to display native glass.

Android, earlier iOS, and `GlassRendering.shader` use the custom renderer.
`LiquidPrism.isShaderSupported` reports custom shader-filter capability only; it is
not an overall native-glass availability check. Unsupported custom renderers use a
frosted fallback that retains content and interaction but omits optical refraction.
Web and desktop support is outside this package's contract.

## Composition

Put glass over content already painted in the same scene. A flat background cannot
show much refraction. Content inside the glass stays sharp. Avoid wrapping glass
in an ancestor `Opacity` or `ImageFiltered` save layer: that can isolate its backdrop.
Changing native/shader backends can remount child state.

Smooth rectangles use Flutter's continuous-corner clipping and scalar shader
passes. Capsule and circle geometry retain their own contours. Native pill blur
uses rounded clip primitives supported by Flutter's iOS embedder.

## Cost

Blur cost depends on the affected pixel area, device, overlap, and moving backdrop.
Prefer small control surfaces, bounded blur radii, and static materials during
interaction. The built-in springs animate transforms rather than blur or layout
size. An idle component has no repeating ticker.

`LiquidPrismGroup` can share a shader pass among compatible regular capsules and
circles:

```dart
LiquidPrismTheme(
  data: const LiquidPrismThemeData(rendering: GlassRendering.shader),
  child: LiquidPrismGroup(child: myControls),
)
```

Grouping preserves semantics but is an optimization, not a merging/morphing effect.
Members must share a background painted outside the group; keep intervening
content outside the group as well.
Incompatible, overlapping, transformed, or smooth-rectangle surfaces can use
individual passes. Native materials remain native. Grouping does not imply that
native platform views share a material pass.

The optional batch shader targets Impeller. Builds and headless tests may print
an SkSL compatibility warning for that shader; the Skia backend uses the frosted
fallback instead of loading it.

Profile a release/profile build on your target phones with realistic moving
content. Simulator frame timings do not establish battery consumption or heat.
The example and regression tests are not a physical-device energy certification.

## Native integration

The plugin includes Swift Package Manager and CocoaPods metadata. Flutter 3.47 uses
Swift Package Manager by default. The example targets iOS 15+ and compiles with
Xcode 26+; native glass is availability-guarded to iOS 26+. No native Android plugin
is needed for the Flutter shader path.

The package does not expose a numeric system-glass blur setting. Use native defaults
to follow system appearance, or set `blur` / `optics` explicitly for app-owned
shader control. Selected colors are a Flutter approximation of adaptive native
foregrounds, not a pixel-for-pixel guarantee across backgrounds and settings.
