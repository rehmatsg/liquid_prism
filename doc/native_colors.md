# Native color provenance

The shipped reference is iOS 27.0, build 24A5370g, normal contrast/transparency,
iPhone Simulator. A SwiftUI probe inspected its own live Core Animation model
layers. Color matrix `NSValue`s were decoded as 20 native float32 coefficients;
semantic UIColor inputs were resolved against explicit light/dark traits.
Screenshot pixels were not used to generate these constants.

The portable record in `test/fixtures/native_colors.json` contains source paths,
SHA-256 hashes, the original tint/pill matrices, face parameters and semantic
RGBA values. `lib/src/native_colors.dart` preserves the RGB matrix coefficients
and bias at their extracted precision. Tint alpha is composed separately; the
recorded alpha-0.5 blue/green/orange/pink fixtures had identical RGB rows to their
alpha-1 counterparts. Other opacity values remain application-controlled rather
than separately certified native states.

| Face input | Regular light | Regular dark | Clear |
| --- | --- | --- | --- |
| Black level | 0.4000000059604645 | 0.125 | 0.125 |
| White level | 1.0299999713897705 | 1.100000023841858 | 1.0800000429153442 |
| Saturation | 1.2000000476837158 | 1.399999976158142 | 1.059999942779541 |
| White fill alpha | 0.20000000298023224 | 0 | 0 |

Surface, button and tab-bar gray-background regular face inputs matched in the
probe, so these components share the extracted recipe. The separate pill matrix
retains every float32 coefficient; only its additive offsets are multiplied by
255 for `ColorFilter.matrix`. Its independent blur remains 2 logical pixels.

`GlassColors` exposes the 12 extracted accent source colors, four label levels
and four fill levels. Fill opacities use `Color.from` rather than quantizing to an
8-bit alpha (for example, dark system fill is exactly 0.36 in the source record).
The extended-sRGB white label is represented by display white in Flutter.

The original local research is `_research/tint_extraction/REPORT.md` and
`extracted.json`, with 161 resting fixtures, 624 interaction frames and native
XCTest evidence. That ignored research directory is not required to build or
use the package. The shipped fixture keeps the relevant values reviewable.

## Limits

These are exact extracted inputs, not a claim of identical Apple pixels. The
Flutter renderer implements its own optical pipeline and uses these face inputs
in its existing luminance/chroma grading model; Apple's full glassBackground
compositing, luminance clamps, blur-fill passes and adaptive thresholds were not
reconstructed. Blur/geometry and resting foreground calibration retain their
existing implementation.

All 12 regular tint matrices were captured in matching light/dark source and
material appearances. Only four clear tints were captured. Unmeasured clear
colors, custom RGB inputs and source colors used with the opposite material
appearance use the documented custom-color fallback. No matrix is presented as
an extracted value for those cases. The explicit `materialBrightness` override
is especially useful for untinted tab bars and their selected pills.

Different platforms, OS versions, accessibility settings and physical-device
color management can differ. The default recipes are fixed to this measured
reference across supported Flutter platforms.

## Verification

Tests compare the shipped palette, full tint matrix rows and converted pill
matrices against the portable extraction record, and exercise live appearance
changes and the example tint picker. The example was built and hot restarted
on iOS Simulator with Metal Impeller and no runtime errors.

A full checkerboard GPU comparison between individual and grouped surfaces
exposed differences at their optical rims in the current rendering pipeline
(maximum channel difference 37 with default blur, 104 with zero blur). This
comparison does not establish identical pixels between those paths. Tint
coefficient provenance is independent of these optical/cache differences.

Six focused scalar/batch comparisons (light/dark, tinted material, controls,
held and released) passed for material interiors, excluding 20 logical pixels
from each edge. Maximum interior channel difference was 2/255, within the
3/255 bound allowing intermediate pass quantization. These compare the two
Flutter paths, not Apple's rendered pixels. Full-rim parity remains unresolved.
Local logs and per-region evidence are retained in the ignored research
`_research/tint_extraction/flutter-verification/` directory.
