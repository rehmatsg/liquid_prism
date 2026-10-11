# Liquid Prism

Liquid glass surfaces, buttons, and draggable tab bars for Flutter on iOS and Android.

- Flutter-rendered glass with colors calibrated against SwiftUI Liquid Glass.
- A customizable Impeller shader for refraction, blur, lighting, and tint.
- Interruptible springs, drag selection, and Reduce Motion support.
- Shared app defaults for materials, tint, foreground colors, shapes, and navigation.
- Continuous rounded corners, custom tab artwork, and optional labels.

Requires **Flutter 3.47+ with Dart 3.13.3+**. Web and desktop are not supported.

## Install

Add the Git dependency to your app's `pubspec.yaml`:

```yaml
dependencies:
  liquid_prism:
    git:
      url: https://github.com/rehmatsg/liquid_prism.git
      ref: main
```

Run `flutter pub get`. Pin `ref` to a reviewed commit in production applications.
This repository is the installation source; the package has not been published to pub.dev.

## Start here

Initialize before `runApp`, then place glass over visible content:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_prism/liquid_prism.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  runApp(const MaterialApp(home: GlassPage()));
}

class GlassPage extends StatelessWidget {
  const GlassPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF146B8F), Color(0xFFB686C8)],
            ),
          ),
        ),
        Center(
          child: LiquidPrism(
            shape: const GlassShape.rect(cornerRadius: 28),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Hello, glass'),
            ),
          ),
        ),
      ],
    ),
  );
}
```

`preload()` loads shader assets before the first glass surface appears.

## Buttons

```dart
LiquidPrismButton(
  label: 'Save', // Accessibility label.
  onPressed: save,
  child: const Text('Save'),
)

LiquidPrismButton(
  label: 'Continue',
  buttonStyle: GlassButtonStyle.glassProminent,
  onPressed: continueFlow,
  child: const Text('Continue'),
)
```

A null `onPressed` disables the button. Async callbacks may overlap; disable the
button while an exclusive action runs.
Use `GlassShape.circle` with an icon for a circular button.

## Tab bar

```dart
LiquidPrismTabBar(
  selectedIndex: selectedTab,
  onSelected: (index) => setState(() => selectedTab = index),
  tabs: const [
    LiquidPrismTab(label: 'Home', icon: Icon(Icons.home_outlined)),
    LiquidPrismTab(label: 'Saved', icon: Icon(Icons.bookmark_outline)),
  ],
  style: const GlassTabBarStyle(
    labelBehavior: GlassTabLabelBehavior.always,
    selectionBlur: 2,
  ),
)
```

The parent owns selection. Touching a tab lifts the pill into a glass lens and
glides it there with the native spring; dragging makes the lens chase the finger,
stretching with its speed, and commits the tab under the finger on release. Icons accept any widget, with an optional
`selectedIcon`. Labels can be always visible, selected only, or hidden. Accessibility
labels remain available. Place the bar inside a safe area with a bounded width.

## App-wide appearance

Wrap the app's routes or a subtree:

```dart
LiquidPrismTheme(
  data: const LiquidPrismThemeData(
    brightness: Brightness.dark,
    foregroundColor: Color(0xFF3BCCFF),
    tabBar: GlassTabBarStyle(
      labelBehavior: GlassTabLabelBehavior.never,
      selectionBlur: 2,
    ),
  ),
  child: MyApp(),
)
```

Widget arguments override inherited defaults. Nested themes merge individual fields;
`inherit: false` resets them. Match `brightness` to your app's selected theme when
it differs from the device setting.

Use `glass: Glass.regular.tint(color)` to tint a surface. `foregroundColor` sets a
literal shared accent for ordinary buttons and selected tabs. Prominent buttons
keep white text unless explicitly overridden. Material tint and foreground color
are independent.

## Native tint palette

`GlassColors.of(context)` resolves the extracted iOS 27 source colors against
`LiquidPrismTheme` brightness, falling back to platform brightness. Rebuild inside
a `Builder` below your theme when the appearance changes:

```dart
final colors = GlassColors.of(context);
LiquidPrism(
  glass: Glass.regular.tint(colors.purple),
  child: myContent,
)
```

The accents are `blue`, `brown`, `cyan`, `green`, `indigo`, `mint`, `orange`,
`pink`, `purple`, `red`, `teal`, and `yellow`. `colors.accents` is an immutable
named map for pickers. `GlassColors.light` and `GlassColors.dark` provide explicit
palettes without a context. Labels include `label`, `secondaryLabel`,
`tertiaryLabel`, and `quaternaryLabel`; fills include `systemFill`,
`secondarySystemFill`, `tertiarySystemFill`, and `quaternarySystemFill`.

Regular glass uses the full extracted RGB tint matrices for all 12 accents in
both appearances. Clear glass has separately extracted matrices for blue, green,
orange, and pink. Other clear accents and arbitrary custom colors retain the
package's custom-color approximation. The palette values are source colors;
material fills and selected-pill matrices determine the composited appearance.

Apple can change the glass body and pill appearance independently of the app.
The exact switching rule was not recovered. For a known backdrop, choose the
body/pill recipe explicitly while keeping source accents on the app appearance:

```dart
LiquidPrismTheme(
  data: const LiquidPrismThemeData(
    brightness: Brightness.dark,
    materialBrightness: Brightness.light,
  ),
  child: myNavigation,
)
```

See [native color provenance](doc/native_colors.md) for the extracted parameters
and the limits of this rendering implementation.

## Rendering and customization

| Renderer | Rendering |
| --- | --- |
| Impeller with shader-filter support | Flutter glass shader |
| Renderer without shader filters | Frosted fallback |

All surfaces, content, and interactions render in Flutter. There are no platform
views or native plugins. `blur` and `optics` customize the shader directly;
`blur: 0` removes the material blur. `GlassTabBarStyle.selectionBlur` adds independent
pill blur and defaults to 2 logical pixels. Set it to zero to disable it.

Colors approximate the native reference, including its brighter dark-mode accent
and darker selected pill. Apple's backdrop adaptation varies with wallpaper and
contrast settings. The package does not read the system Liquid Glass blur setting.

See [customization](doc/customization.md) for precedence, shapes, motion, and
advanced optics, and [rendering](doc/rendering.md) for performance and composition
constraints.

## Example and development

```sh
cd example
flutter pub get
../tool/run_example.sh <device-id>
```

The example demonstrates surfaces, tint, buttons, dark/light appearance, and
interactive tabs over an original procedural background.

Run `./tool/check.sh` from the repository root for formatting, analysis, and tests.
See [contributing](CONTRIBUTING.md) for mobile build checks.

## Research and acknowledgments

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
contracts. Native code is confined to the separate research reference app.

| Area | Finding and implementation |
| --- | --- |
| Borders | Clear glass follows the inspected iOS 27 vertical key/fill highlights: a sharp 1-point rim, an 8-point diffuse lobe, and a thin dark exterior edge between bright regions. The dark edge uses a fitted opacity; native spread varies with size. Regular and custom materials retain the earlier diagonal lighting. Highlights grade backdrop color rather than drawing a uniform white stroke. |
| Sampling | Display-resolution geometry, bilinear sampling, and integration over compressed pixel footprints reduce jagged refraction at the rim. Gaussian blur runs before refraction; foreground content stays sharp. |
| Materials | Regular and clear glass have different face and highlight treatments. Regular surfaces and buttons use a luminance response measured against iOS 27; tab bars retain their separate role calibration. |
| Tint | All 12 named accents use full extracted regular-glass RGB matrices in light/dark appearances. Clear glass has separate matrices for blue, green, orange, and pink; unmeasured inputs retain the custom-color approximation. |
| Foregrounds | Semantic source colors differ from displayed pixels. Ordinary buttons and selected tabs share the measured iOS 27 resting palette on every platform, without foreground readback passes. |
| Selection | The selected pill has its own color adjustment and an additional 2-point blur, including when bar blur is zero. The measured iOS 27 dark pill is darker than the iOS 26 treatment. |
| Touch | A held native button expanded to about 1.10× its resting size. Springs were tuned by comparison; their timing was not extracted from Apple. |
| Rendering cost | Simulator profiling motivated sharing compatible optical passes. Nearby, overlapping, clipped, scaled, or fractionally positioned surfaces retain separate passes to preserve their appearance. |

The default semantic blue is `#0088FF` in light mode and `#0091FF` in dark mode.
The resting iOS 27 foreground measured on our reference wallpaper is `#005DC7`
and `#3BCCFF`, respectively. Those foreground values are useful defaults, not
universal native colors: Apple's output changes with the backdrop and settings.
The implementation lives in [material recipes](lib/src/recipe.dart),
[foreground colors](lib/src/foreground.dart), [selection](lib/src/selection.dart),
and the [shared shader](shaders/glass_core.glsl).

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
[third-party notices](THIRD_PARTY_NOTICES.md) and [LICENSES](LICENSES/).

## License

BSD-3-Clause. See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md).
