# Native popup menus

Liquid Prism includes the existing Liquid Menu implementation, merged from
`liquid_menu` commit `3f41d89`. Its MIT license is retained in
[LICENSE-liquid-menu](../LICENSE-liquid-menu). Consumers install one package;
there is no dependency on a sibling checkout.

On iOS 17.4 and newer, UIKit builds and presents the real `UIMenu` through an
invisible `UIButton` and `performPrimaryAction()`. Menu surfaces, typography,
SF Symbols, separators, checkmarks, submenus, and presentation animations belong
to the operating system. No Flutter menu surface or platform view is drawn on
this path. The trigger still uses Liquid Prism's existing glass and feedback.

```dart
import 'package:liquid_prism/liquid_prism.dart';

final menu = LiquidMenu(children: [
  LiquidMenuAction<String>(
    title: 'Favorite',
    value: 'favorite',
    icon: const LiquidMenuSfSymbol('heart'),
    onSelected: () => saveFavorite(),
  ),
  const LiquidMenuDivider(),
  const LiquidMenuAction<String>(
    title: 'Delete',
    value: 'delete',
    destructive: true,
    icon: LiquidMenuSfSymbol('trash'),
  ),
]);

LiquidPrismButton.menu(
  label: 'More options',
  menu: menu,
  onSelected: (value) => handleResult(value),
  child: const Text('More'),
)

LiquidPrismToolbarGroup(items: [
  GlassToolbarItem.menu(
    label: 'More options',
    menu: menu,
    icon: const Icon(CupertinoIcons.ellipsis),
  ),
])
```

Each trigger keeps one gesture owner and one accessibility action. `enabled:
false` disables a menu trigger. The popup anchors to the triggering button or
individual toolbar item, accounting for scale transforms. Native appearance
follows the enclosing Liquid Prism theme; plain Material/Cupertino applications
use their app theme.

For a custom trigger, use `LiquidMenuRegion.builder` with
`anchor: LiquidMenuAnchorMode.triggerRect`, and call its `show` callback from
that trigger's own handler. A visual-only `LiquidMenuRegion` supports tap and
long-press gestures, including `anchor: LiquidMenuAnchorMode.tapPoint`.
Imperative presentation is available through `liquidMenus.show(context: ...,
menu: ...)` and `liquidMenus.showAt(position, context: ..., menu: ...)`.

The merged API retains `LiquidMenuSection`, `LiquidSubmenu`,
`LiquidMenuDeferred`, SF Symbol/bitmap icons, selected/mixed states, disabled and
hidden actions, destructive actions, and `keepsMenuPresented`. Per-action
callbacks run on selection; the trigger's `onSelected` receives the first
selected value when the menu closes, or null on dismissal without selection.

Swift Package Manager and CocoaPods are supported. The iOS deployment minimum
remains 15.0. On iOS below 17.4 and on other platforms, the existing Liquid Menu
fallback uses Flutter's standard Material `showMenu`. A `CupertinoApp` using
that fallback must include `DefaultMaterialLocalizations.delegate`; the
showcase already does. `liquidMenus.supportsNativeMenu` reports the native
capability after the channel handshake.

Open **Library → Popup menus** in the showcase to exercise the native button,
toolbar trigger, long-press context menu, submenu, and deferred items. Toolbar
**More** also opens a native menu.

Run `tool/check.sh` for Dart/Flutter checks. The root `Package.swift` is a test
harness for the Flutter-free UIKit core:

```sh
xcodebuild test -scheme liquid_prism-Package \
  -destination 'platform=iOS Simulator,id=<simulator-id>'
```

Core presentation tests require a scene-hosting test process and skip in a
headless Swift package runner. The separate `tool/native_menu_ui_probe` drives
the installed showcase and real UIKit rows via XCTest. Build/install the
showcase, generate that probe with XcodeGen, then test its `NativeMenuUI` scheme
on the same simulator. It verifies actual row selection and return values,
submenus, dark appearance, and long-press menus.
