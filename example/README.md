# Liquid Prism 1.0.0 examples

`lib/main.dart` runs the interactive showcase: Explore, Studio, and Library pages
cover glass surfaces, controls, adaptive navigation, scroll effects, and native
iOS popup menus. Studio changes appearance, materials, accents, and optics.
Artwork is drawn in Dart; no external assets or network services are required.

`lib/api_main.dart` runs a smaller customization example with shared
`PrismThemeData`, local `Prism*Style` overrides, lens styling, controlled values,
and app-owned search suggestions.

Run from `example/`:

```sh
flutter pub get
flutter run -t lib/main.dart -d <device-id>
flutter run -t lib/api_main.dart -d <device-id>
```

Use `flutter devices` to find a device or simulator. Dart changes support hot
reload; shader changes require a rebuild. Native popup menus require iOS.

Both entry points call `Prism.initialize()` before `runApp`. Import the consumer
API from `package:liquid_prism/liquid_prism.dart`; import
`package:liquid_prism/primitives.dart` for low-level optics, lenses, pressables,
and system chrome. Keep visual overrides in immutable `Prism*Style` objects.

See the [migration guide](../doc/migration-1.0.md),
[components](../doc/components.md), and [customization](../doc/customization.md).

```sh
dart --suppress-analytics format lib test
dart --suppress-analytics analyze
flutter test
```
