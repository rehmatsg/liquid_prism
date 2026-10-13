# Liquid Prism

Liquid glass for Flutter: surfaces, buttons, switches, sliders, segmented controls,
floating tab bars, toolbars and search. Popup menus use real UIKit menus on iOS.

The defaults follow our SwiftUI reference. Use a few widget arguments for a local
change, reusable styles for a component, or a theme for the whole app.

## Install

Requires **Flutter 3.47+ / Dart 3.13.3+**. The supported app targets are iOS and
Android. Native menus require iOS 17.4+; other platforms use the Material fallback.
Glass uses Impeller shader filters when available and a frosted fallback otherwise.

```yaml
dependencies:
  liquid_prism:
    git:
      url: https://github.com/rehmatsg/liquid_prism.git
      ref: v0.2.0
```

Run `flutter pub get`. Each [release](https://github.com/rehmatsg/liquid_prism/releases)
is a `vX.Y.Z` tag; see the [changelog](CHANGELOG.md). The package is not on
pub.dev.

## Your first glass surface

https://github.com/user-attachments/assets/669b0c2c-dfd9-484a-8d25-1bf75be2b271

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

Put glass above something visible. `Glass.regular`, `Glass.clear` and
`Glass.identity` choose the material; `.tint(color)` adds a tint and `.interactive()`
adds press feedback to a surface. Continuous rounded corners are the default.

### Clear glass

https://github.com/user-attachments/assets/b8a14a8a-5ca1-4a54-93b6-22e2a8cba75a

```dart
LiquidPrism(
  glass: Glass.clear,
  shape: const GlassShape.rect(cornerRadius: 30),
  child: const SizedBox(width: 234, height: 150),
)
```

### Glass shapes

https://github.com/user-attachments/assets/afc6683d-6ee2-4ab5-b33d-46606fe35170

```dart
Wrap(
  spacing: 16,
  runSpacing: 16,
  children: [
    LiquidPrism(
      glass: Glass.clear,
      shape: const GlassShape.rect(cornerRadius: 30),
      child: const SizedBox(width: 174, height: 138),
    ),
    LiquidPrism(
      glass: Glass.clear,
      shape: GlassShape.circle,
      child: const SizedBox.square(dimension: 78, child: Icon(Icons.add)),
    ),
    LiquidPrism(
      glass: Glass.clear,
      shape: GlassShape.capsule,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text('Through a new lens.'),
      ),
    ),
  ],
)
```

## Choose a component

| You need | Use |
| --- | --- |
| A surface | `LiquidPrism` |
| An action or circular icon | `LiquidPrismButton` / `LiquidPrismButton.icon` |
| An on/off setting | `LiquidPrismSwitch` |
| A numeric value | `LiquidPrismSlider` |
| One choice from a small set | `LiquidPrismSegmentedControl<T>` |
| Floating navigation | `LiquidPrismTabBar` |
| Grouped icon actions | `LiquidPrismToolbarGroup` |
| Search with clear/cancel | `LiquidPrismSearchField` |
| A native popup | `LiquidPrismButton.menu` / `GlassToolbarItem.menu` |

You own the values in these examples. A null action callback disables a control.
Sliders update continuously; switch and segmented drags commit on release.
Controls support keyboard input, accessibility, RTL and Reduce Motion.
The videos were recorded from Flutter at 1206 pixels wide and 60 fps.

### Switch

This demo uses `GlassSwitchStyle(scale: 2)`.

https://github.com/user-attachments/assets/b8bb5865-b513-462b-8e28-8b6784ad7d3c

```dart
LiquidPrismSwitch(
  label: 'Notifications',
  value: notifications,
  onChanged: (next) => setState(() => notifications = next),
  style: const GlassSwitchStyle(scale: 2),
)
```

### Slider

https://github.com/user-attachments/assets/71ccc482-a99e-4562-a2e5-d6ed8d503106

```dart
LiquidPrismSlider(
  label: 'Volume',
  value: volume,
  min: 0,
  max: 100,
  onChanged: (next) => setState(() => volume = next),
  onChangeEnd: saveVolume,
)
```

### Tab bar

The tab bar is compact by default and grows for longer labels. Use
`GlassTabBarStyle(expanded: true)` for full-width navigation. Place it where your
layout needs it; the widget does not add safe-area margins. The icons below use
`package:flutter/cupertino.dart`.

https://github.com/user-attachments/assets/1448b864-000b-4883-a7b1-d5bff2de8142

```dart
LiquidPrismTabBar(
  selectedIndex: selectedTab,
  onSelected: (next) => setState(() => selectedTab = next),
  tabs: const [
    LiquidPrismTab(label: 'Explore', icon: Icon(CupertinoIcons.sparkles)),
    LiquidPrismTab(label: 'Studio', icon: Icon(CupertinoIcons.slider_horizontal_3)),
    LiquidPrismTab(label: 'Library', icon: Icon(CupertinoIcons.square_grid_2x2_fill)),
  ],
  style: const GlassTabBarStyle(
    height: 62,
    labelStyle: TextStyle(fontSize: 11),
  ),
)
```

### App layout for every iPhone, including iPhone Duo

`LiquidPrismScaffold` floats your tab bar and actions over scrolling content and
puts them where iOS would. On iPhone, actions sit top-right and the tab bar floats
at the bottom. Beside the iPhone Duo sensor bar, both move into a side rail and
the tabs turn icon-only. The layout follows the window as it folds, rotates or
resizes, and scroll views get padding to clear the glass.

```dart
LiquidPrismScaffold(
  backgroundColor: const Color(0xFFF2F2F7),
  actions: [
    GlassToolbarItem(
      icon: const Icon(CupertinoIcons.share),
      label: 'Share',
      onPressed: share,
    ),
  ],
  tabBar: LiquidPrismTabBar(
    selectedIndex: selectedTab,
    onSelected: (next) => setState(() => selectedTab = next),
    tabs: tabs,
  ),
  body: ListView(children: rows),
)
```

## Make it yours

Set shared defaults around your app's routes:

```dart
LiquidPrismTheme(
  data: const LiquidPrismThemeData(
    tint: Color(0xFF6155F5),
    button: GlassButtonAppearance(minimumSize: Size(88, 48)),
    slider: GlassSliderStyle(trackHeight: 8),
    lens: GlassLensStyle(shadowOpacity: .08),
    toolbar: GlassToolbarStyle(spacing: 10),
  ),
  child: myApp,
)
```

Override one component with `style` (`appearance` on search, whose `style` is its
editor `TextStyle`). Direct widget arguments override styles. Null fields inherit;
zero and false are real overrides. Nested themes merge fields; `inherit: false`
starts from native defaults. Styles and themes support `copyWith` and `merge`.

Use `GlassColors.of(context)` for the native light/dark palette. Set theme
`brightness` when your app's appearance differs from the device. Advanced
customization includes geometry, typography, lens optics/shadows, motion, toolbar
spacing, tab foreground refraction and search input behavior.

- [Component examples and options](doc/components.md)
- [Theming, styles and override precedence](doc/customization.md)
- [Motion and lens customization](doc/motion_and_lenses.md)
- [Native menus](doc/native_menus.md)
- [Rendering and performance](doc/rendering.md)

## Try the showcase

```sh
cd example
flutter pub get
../tool/run_example.sh <device-id>
```

Explore the components, customize them in Studio, or find examples in Library.
See the [showcase guide](example/README.md).

For contributors: [CONTRIBUTING.md](CONTRIBUTING.md). For coding agents:
[AGENTS.md](AGENTS.md) and the [implementation guides](doc/agents/README.md).

## Credits and license

Built with research from [Liquid Glass Easy](https://github.com/AhmeedGamil/liquid_glass_easy)
and [GPUI Glass Demo](https://github.com/luciascarlet/gpui-glass-demo), alongside our
native SwiftUI measurements. Rendering approximates Apple's private glass
operators. See [research and acknowledgments](doc/research.md) for sources and limits.

BSD-3-Clause, with the merged Liquid Menu code under MIT. See [LICENSE](LICENSE),
[LICENSE-liquid-menu](LICENSE-liquid-menu) and [third-party notices](THIRD_PARTY_NOTICES.md).
