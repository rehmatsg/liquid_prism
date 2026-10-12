# Research and acknowledgments

Thank you to **[AhmeedGamil/liquid_glass_easy](https://github.com/AhmeedGamil/liquid_glass_easy)**
and **[luciascarlet/gpui-glass-demo](https://github.com/luciascarlet/gpui-glass-demo)**.
These two projects made this work possible:

- **Liquid Glass Easy** was the starting point for the Flutter investigation. Its
  [composition-time uniform updates](https://github.com/AhmeedGamil/liquid_glass_easy/tree/9bc72e3795cb7b972ef2fe381a2224237162cf5b/lib)
  informed how the shader stays aligned with a moving backdrop. Liquid Prism has
  no dependency on the package.
- **GPUI Glass Demo** supplied the optical profile, spectral dispersion,
  directional highlight and vibrancy equations, and Radiance reflection blend.
  Its [macOS reverse-engineering notes](https://github.com/luciascarlet/gpui-glass-demo/blob/78858810d3dcb0b0ad1f6cec97db206c5efc84fe/RESEARCH.md)
  were the main technical reference. Radiance is that project's approximation,
  not a recovered Apple formula.

### What we measured and changed

We compared matching Flutter and SwiftUI galleries on iPhone 17 simulators running
**iOS 26.5 and 27**, using the same backgrounds and geometry. LLDB inspection of
our own native reference app helped separate material, edge, foreground, and
selection effects. These are observations of those runtimes, not Apple API
contracts. Rendering probes are confined to the reference apps. The shipped iOS plugin presents native popup menus.

| Area | Finding and implementation |
| --- | --- |
| Borders | Clear glass follows the inspected iOS 27 vertical key/fill highlights: a sharp 1-point rim, an 8-point diffuse lobe, and a thin dark exterior edge between bright regions. The dark edge uses a fitted opacity; native spread varies with size. Regular and custom materials retain the earlier diagonal lighting. Highlights grade backdrop color rather than drawing a uniform white stroke. |
| Sampling | Display-resolution geometry, bilinear sampling, and integration over compressed pixel footprints reduce jagged refraction at the rim. Gaussian blur runs before refraction; ordinary surface foreground stays sharp. Lifted tab foreground uses its own transparent refraction pass. |
| Materials | Regular and clear glass have different face and highlight treatments. Regular surfaces and buttons use a luminance response measured against iOS 27; tab bars retain their separate role calibration. |
| Tint | All 12 named accents use full extracted regular-glass RGB matrices in light/dark appearances. Clear glass has separate matrices for blue, green, orange, and pink; unmeasured inputs retain the custom-color approximation. |
| Foregrounds | Semantic source colors differ from displayed pixels. Ordinary buttons and selected tabs share the measured iOS 27 resting palette. The lifted tab pill refracts selected icons and labels in a separate GPU pass; content outside it stays sharp. |
| Selection | The selected pill has its own color adjustment and an additional 2-point blur, including when bar blur is zero. The measured iOS 27 dark pill is darker than the iOS 26 treatment. |
| Touch | A held native button expanded to about 1.10× its resting size. Springs were tuned by comparison; their timing was not extracted from Apple. |
| Rendering cost | Simulator profiling motivated sharing compatible optical passes. Nearby, overlapping, clipped, scaled, or fractionally positioned surfaces retain separate passes to preserve their appearance. |

The default semantic blue is `#0088FF` in light mode and `#0091FF` in dark mode.
The resting iOS 27 foreground measured on our reference wallpaper is `#005DC7`
and `#3BCCFF`, respectively. Those foreground values are useful defaults, not
universal native colors: Apple's output changes with the backdrop and settings.
The implementation lives in [material recipes](../lib/src/recipe.dart),
[foreground colors](../lib/src/foreground.dart), [selection](../lib/src/selection.dart),
and the [shared shader](../shaders/glass_core.glsl).

The shader does not reproduce Apple's complete adaptive renderer. Shadows,
overlapping materials, custom tint, and color management remain approximations.
Simulator comparisons do not establish physical-device battery use or temperature.
Raw probes, screenshots, and comparison apps stay in the ignored local research
archive; they are not shipped with the package.

### Further sources

- Apple: [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/),
  [applying glass to custom SwiftUI views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views),
  [UIGlassEffect](https://developer.apple.com/documentation/uikit/uiglasseffect),
  and the [WWDC26 system appearance update](https://developer.apple.com/videos/play/wwdc2026/102/).
  These inform the visual reference; the shader does not read a numeric system blur setting.
- Flutter: [fragment shaders and backdrop filters](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
  and [performance profiling](https://docs.flutter.dev/perf/ui-performance).
- Flutter's [rounded-superellipse parameters](https://github.com/flutter/flutter/blob/3.47.4/engine/src/flutter/impeller/geometry/round_superellipse_param.cc)
  and [distance functions](https://github.com/flutter/flutter/blob/3.47.4/engine/src/flutter/impeller/entity/shaders/uber_sdf.frag)
  informed the continuous-corner geometry. The closest-point search derives from
  [Inigo Quilez's distance-function work](https://iquilezles.org/articles/ellipsedist/),
  also credited in Flutter's [SDF helpers](https://github.com/flutter/flutter/blob/3.47.4/engine/src/flutter/impeller/entity/shaders/sdf_functions.glsl).
- [SniperGER/iOS-Wallpapers](https://github.com/SniperGER/iOS-Wallpapers) supplied
  reference backgrounds for the local comparisons. No Apple wallpapers are included
  in this package or its example.

Pinned revisions and redistribution terms are in
[third-party notices](../THIRD_PARTY_NOTICES.md) and [LICENSES](../LICENSES/).
