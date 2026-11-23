![Liquid Prism glass wordmark](assets/liquid-prism-4k.png)

# Liquid Prism

[![CI](https://github.com/rehmatsg/liquid_prism/actions/workflows/ci.yml/badge.svg)](https://github.com/rehmatsg/liquid_prism/actions/workflows/ci.yml)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: BSD-3-Clause & MIT](https://img.shields.io/badge/license-BSD--3--Clause%20%26%20MIT-blue.svg)](LICENSE)
[![Flutter 3.50+](https://img.shields.io/badge/flutter-3.50%2B-02569B.svg)](https://flutter.dev)

Liquid glass for Flutter: live Impeller shaders, velocity-driven spring controls, adaptive iOS chrome, and real UIKit popup menus.

Defaults follow measured native iOS Liquid Glass behavior. Keep widget call sites short with semantic props, customize visuals through immutable `Prism*Style` objects, or theme an entire app with `PrismTheme`.

---

## Install

Requires **Flutter 3.50+ / Dart 3.14+**. Supported targets are **iOS** and **Android**. Native popup menus require iOS 17.4+ (other platforms use a Material fallback). Glass renders with Impeller fragment shaders when supported and a frosted fallback otherwise.

```yaml
dependencies:
  liquid_prism:
    git:
      url: https://github.com/rehmatsg/liquid_prism.git
      ref: v1.0.0 # x-release-please-version
```

Upgrading from `0.x`? See the [1.0 migration guide](doc/migration-1.0.md) and [CHANGELOG.md](CHANGELOG.md).

---

## Your first glass surface

https://github.com/user-attachments/assets/669b0c2c-dfd9-484a-8d25-1bf75be2b271

```dart
import 'package:liquid_prism/liquid_prism.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prism.initialize();
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
          child: PrismSurface(
            shape: const PrismShape.rect(cornerRadius: 28),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Hello, glass.'),
            ),
          ),
        ),
      ],
    ),
  );
}
```

Choose a material with `PrismGlass.regular`, `PrismGlass.clear`, or `PrismGlass.identity`. Chain `.tint(color)` for tinted glass and `.interactive()` for spring press feedback. Continuous superellipse corners are the default.

### Clear glass

https://github.com/user-attachments/assets/b8a14a8a-5ca1-4a54-93b6-22e2a8cba75a

```dart
PrismSurface(
  glass: PrismGlass.clear,
  shape: const PrismShape.rect(cornerRadius: 30),
  child: const SizedBox(width: 220, height: 126),
)
```

### Glass shapes

https://github.com/user-attachments/assets/afc6683d-6ee2-4ab5-b33d-46606fe35170

```dart
Wrap(
  spacing: 16,
  runSpacing: 16,
  children: [
    PrismSurface(
      glass: PrismGlass.clear.interactive(),
      shape: const PrismShape.rect(cornerRadius: 26),
      child: const SizedBox(width: 112, height: 112, child: Icon(CupertinoIcons.sparkles)),
    ),
    PrismSurface(
      glass: PrismGlass.clear.interactive(),
      shape: PrismShape.circle,
      child: const SizedBox.square(dimension: 78, child: Icon(CupertinoIcons.add)),
    ),
    PrismSurface(
      glass: PrismGlass.clear.interactive(),
      shape: PrismShape.capsule,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Text('Capsule'),
      ),
    ),
  ],
)
```

---

## Components

| Need | Widget |
| --- | --- |
| Glass surface & batched group | `PrismSurface`, `PrismGroup` |
| Action button or circular icon | `PrismButton`, `PrismButton.icon`, `PrismButton.menu` |
| On/off toggle | `PrismSwitch` |
| Continuous or stepped slider | `PrismSlider` |
| Segmented picker | `PrismSegmentedControl<T>` |
| Floating navigation tabs | `PrismTabBar`, `PrismTab` |
| Adaptive app layout & pull-to-refresh | `PrismScaffold`, `PrismSliverAppBar`, `PrismRefreshController` |
| Grouped glass actions & back button | `PrismToolbar`, `PrismToolbar.group`, `PrismBackButton` |
| Glass search bar | `PrismSearchField` |
| Scroll edge blur & fade | `PrismScrollEdge`, `PrismScrollEdge.fade` |
| Live materialize transition | `PrismVisibility`, `PrismVisibility.driven` |
| Native iOS `UIMenu` popup | `PrismMenu`, `PrismMenuRegion`, `prismMenus` |

All controls are parent-owned: a null callback disables every input path, and controls support keyboard navigation, semantics, RTL, and Reduce Motion. All demos above were recorded directly from Flutter running on iOS Impeller.

### Switch

https://github.com/user-attachments/assets/b8bb5865-b513-462b-8e28-8b6784ad7d3c

```dart
PrismSwitch(
  label: 'Notifications',
  value: notifications,
  onChanged: (next) => setState(() => notifications = next),
  style: const PrismSwitchStyle(scale: 2),
)
```

### Slider

https://github.com/user-attachments/assets/71ccc482-a99e-4562-a2e5-d6ed8d503106

```dart
PrismSlider(
  label: 'Volume',
  value: volume,
  min: 0,
  max: 100,
  onChanged: (next) => setState(() => volume = next),
  onChangeEnd: saveVolume,
)
```

### Tab bar

Compact by default; pass `PrismTabBarStyle(sizing: PrismTabBarSizing.fill)` for full-width navigation.

https://github.com/user-attachments/assets/1448b864-000b-4883-a7b1-d5bff2de8142

```dart
PrismTabBar(
  selectedIndex: selectedTab,
  onSelected: (next) => setState(() => selectedTab = next),
  tabs: const [
    PrismTab(label: 'Explore', icon: Icon(CupertinoIcons.sparkles)),
    PrismTab(label: 'Studio', icon: Icon(CupertinoIcons.slider_horizontal_3)),
    PrismTab(label: 'Library', icon: Icon(CupertinoIcons.square_grid_2x2_fill)),
  ],
)
```

### Adaptive scaffold & pull to refresh

`PrismScaffold` floats your navigation title, toolbar actions, and tab bar over scrolling content and adapts automatically between standard iPhone layout, iPhone Duo side rails, and regular-width sidebars. Add `onRefresh` for a Dynamic Island / top-edge liquid drop refresh indicator.

```dart
PrismScaffold(
  title: const Text('Inbox'),
  largeTitle: const Text('Inbox'),
  onRefresh: reload,
  toolbar: [
    PrismToolbarItem(
      icon: const Icon(CupertinoIcons.share),
      label: 'Share',
      onPressed: share,
    ),
  ],
  tabBar: PrismTabBar(
    selectedIndex: selectedTab,
    onSelected: (next) => setState(() => selectedTab = next),
    tabs: tabs,
  ),
  slivers: [
    SliverList.builder(itemCount: items.length, itemBuilder: buildRow),
  ],
)
```

### Native iOS popup menus

Popup menus use real `UIMenu` presentation on iOS 17.4+ with a Material `showMenu` fallback elsewhere.

```dart
PrismButton.menu(
  label: 'More options',
  menu: PrismMenu(
    children: [
      PrismMenuAction<String>(
        title: 'Favorite',
        value: 'favorite',
        icon: const PrismMenuSfSymbol('heart'),
        onSelected: saveFavorite,
      ),
      const PrismMenuDivider(),
      const PrismMenuAction<String>(
        title: 'Delete',
        value: 'delete',
        destructive: true,
        icon: PrismMenuSfSymbol('trash'),
      ),
    ],
  ),
  onSelected: handleResult,
  child: const Text('More'),
)
```

---

## Styling & theming

Widgets take semantic and behavioral inputs directly. Visual, geometry, motion, optical, and haptic overrides live in immutable `Prism*Style` objects that merge cleanly over `PrismTheme`:

```dart
PrismTheme(
  data: const PrismThemeData(
    tint: Color(0xFF6155F5),
    button: PrismButtonStyle(minimumSize: Size(88, 48)),
    slider: PrismSliderStyle(trackHeight: 8),
    lens: PrismLensStyle(shadowOpacity: .08),
    toolbar: PrismToolbarStyle(spacing: 10),
  ),
  child: myApp,
)
```

- Resolution order: **local widget `style` > `PrismThemeData` > native default**.
- Use `PrismColors.of(context)` for the adaptive light/dark semantic palette.
- Low-level building blocks (`PrismOptics`, `PrismLensStyle`, `PrismPressable`, `PrismSelection`, `PrismEdgeBlur`, `PrismEdgeFade`, `PrismPresence`, `PrismSystemChrome`, `PrismTabReselection`) live in `package:liquid_prism/primitives.dart`.

---

## Documentation

- [Component guide](doc/components.md)
- [Theming & styles](doc/customization.md)
- [Motion & lenses](doc/motion_and_lenses.md)
- [Native iOS menus](doc/native_menus.md)
- [Rendering & performance](doc/rendering.md)
- [1.0 migration guide](doc/migration-1.0.md)

## Try the showcase

```sh
cd example
flutter pub get
../tool/run_example.sh <device-id>
```

For contributors, see [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), and [SECURITY.md](SECURITY.md).

## Credits & license

BSD-3-Clause, with the merged Liquid Menu UIKit bridge under MIT. Built with research from [Liquid Glass Easy](https://github.com/AhmeedGamil/liquid_glass_easy) and [GPUI Glass Demo](https://github.com/luciascarlet/gpui-glass-demo). See [LICENSE](LICENSE), [LICENSE-liquid-menu](LICENSE-liquid-menu), and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
