# Liquid Prism showcase

A complete interactive gallery built with the public Liquid Prism API.

- **Explore**: original artwork, live glass, interactive controls and collection highlights.
- **Studio**: light/dark appearance, regular/clear glass, all 12 native accent colors, tab labels, three artwork palettes, adjustable frost and refraction, and a draggable lens.
- **Library**: searchable examples for surfaces, buttons, switches, sliders, segmented controls, tab bars, grouped toolbar actions, search fields and native popup menus. Each example includes gesture guidance and, where relevant, disabled states.

Appearance, material, accent and sample values follow you between pages. Layouts adapt to narrow phones, larger text and wider windows. Artwork is drawn in Dart; no external assets or network services are required. Pickers are intentionally excluded.

```sh
flutter pub get
../tool/run_example.sh <device-id>
```

Use `flutter devices` to find a simulator or device. Dart changes support hot reload; shader asset changes require a rebuild.

The separate `controls_main.dart` and `chrome_main.dart` entry points retain the focused native-comparison fixtures.

To record the showcase, launch `flutter run -t test_driver/showcase.dart -d <device-id>`, then run `test_driver/showcase_video.dart` with `DART_VM_SERVICE_URL`, `PRISM_SIMULATOR_ID` and `PRISM_SHOWCASE_OUT` set. Videos and screenshots are local artifacts.

## Customization example

Run `flutter run -t lib/api_main.dart -d <device-id>` for a smaller, fully runnable
example of shared themes, local styles, lens overrides, icon buttons and editor
options. Its state stays in the app; controls only propose updates. See
[components](../doc/components.md) and [customization](../doc/customization.md).
