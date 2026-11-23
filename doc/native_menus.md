# Native popup menus

Liquid Prism includes a merged UIKit menu bridge (MIT-licensed; see [LICENSE-liquid-menu](../LICENSE-liquid-menu)). On iOS 17.4+, UIKit builds and presents a real `UIMenu` through an invisible `UIButton` and `performPrimaryAction()`. On older iOS versions and other platforms, the same model renders with Flutter's Material `showMenu`.

```dart
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

final menu = PrismMenu(
  children: [
    PrismMenuAction<String>(
      title: 'Favorite',
      value: 'favorite',
      icon: const PrismMenuSfSymbol('heart'),
      onSelected: () => saveFavorite(),
    ),
    const PrismMenuDivider(),
    const PrismMenuAction<String>(
      title: 'Delete',
      value: 'delete',
      destructive: true,
      icon: PrismMenuSfSymbol('trash'),
    ),
  ],
);

PrismButton.menu(
  label: 'More options',
  menu: menu,
  onSelected: (value) => handleResult(value),
  child: const Text('More'),
)

PrismToolbar.group(
  items: [
    PrismToolbarItem.menu(
      label: 'More options',
      menu: menu,
      icon: const Icon(CupertinoIcons.ellipsis),
    ),
  ],
)
```

## Triggers & imperative presentation

- `PrismButton.menu` and `PrismToolbarItem.menu` own activation and anchor the popup to the button or toolbar item bounds.
- `PrismMenuRegion` wraps any custom visual for tap or long-press menus (`PrismMenuTrigger.tap` / `PrismMenuTrigger.longPress`, anchored to `PrismMenuAnchorMode.triggerRect` or `PrismMenuAnchorMode.tapPoint`).
- `PrismMenuRegion.builder` provides a `show` callback for triggers that already own their gesture recognizer.
- `prismMenus.show(context: ..., menu: ...)` and `prismMenus.showAt(position, context: ..., menu: ...)` present imperatively and complete with the selected action's value (or null on dismissal).

## Menu elements & icons

Supported elements: `PrismMenuAction`, `PrismMenuDivider`, `PrismMenuSection`, `PrismSubmenu`, and `PrismMenuDeferred` (async display-time items).

Supported icons: `PrismMenuSfSymbol` (with `PrismSymbolWeight`, `PrismSymbolScale`, `PrismSymbolRenderingMode`, and palette colors) and `PrismMenuImage` (encoded bitmap bytes).

Check `prismMenus.supportsNativeMenu` for iOS 17.4+ native capability after the lazy handshake.

## Native tests

The root `Package.swift` hosts unit tests for the Flutter-free UIKit core:

```sh
xcodebuild test -scheme liquid_prism-Package \
  -destination 'platform=iOS Simulator,id=<simulator-id>'
```
