# Liquid Prism

Liquid glass surfaces, buttons, and draggable tab bars for Flutter on iOS and Android.

- Native Liquid Glass on iOS 26+, following system appearance preferences.
- A customizable Impeller shader for explicit optical settings and Android.
- Spring-driven touch feedback, interruption, and Reduce Motion support.
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

`preload()` initializes native support and shader assets. Rebuild your app after
adding the dependency: hot reload cannot register a new native plugin.

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

A null `onPressed` disables the button. Callbacks accept synchronous or asynchronous
work. Async callbacks may overlap; disable the button while an exclusive action runs.
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

The parent owns selection. Taps spring the pill to its destination; holding and
sliding previews a selection and commits once on release. Supply any widget as an
icon and optionally provide `selectedIcon`. Labels can be always visible, selected
only, or hidden; accessibility labels remain available. Give the bar a bounded width
and position it inside your app's safe area.

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

## Rendering and customization

| Configuration | Rendering |
| --- | --- |
| Default on iOS 26+ | Native system glass |
| Explicit `blur`, `optics`, or `GlassRendering.shader` | Custom shader when supported |
| Android / earlier iOS | Custom shader when supported |
| Renderer without shader filters | Frosted fallback |

Explicit `blur: 0` selects the custom renderer; it is not the system's lowest glass
setting. `GlassTabBarStyle.selectionBlur` is additional pill blur, independent of
bar blur, and defaults to 2 logical pixels. Set it to zero to disable it.

Native materials follow system preferences. Custom shader optics do not read a
numeric system blur setting. Flutter-drawn selected colors approximate native
backdrop adaptation; they are not guaranteed to match every wallpaper or contrast
setting exactly.

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
See [contributing](CONTRIBUTING.md) for native build checks.

## License

BSD-3-Clause. See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md).
