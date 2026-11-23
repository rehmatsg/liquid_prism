import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/menu/menu.dart';
import 'package:liquid_prism/src/menu/menu_anchor.dart';
import 'package:liquid_prism/src/menu/menu_engine.dart';
import 'package:liquid_prism/src/menu/menu_event.dart';
import 'package:liquid_prism/src/menu/menu_platform_interface.dart';

/// The shared facade for presenting menus.
const PrismMenus prismMenus = PrismMenus.instance;

/// Presents native iOS menus with a Flutter fallback.
final class PrismMenus {
  const new _();

  /// The shared menu instance.
  static const PrismMenus instance = PrismMenus._();

  /// Presents a menu and completes with the first selected value on dismissal.
  Future<T?> show<T>({
    required BuildContext context,
    required PrismMenu menu,
    PrismMenuAnchor? anchor,
  }) async {
    final resolved = anchor ?? _rectOf(context);
    final result = await PrismMenuEngine.instance.show(
      context: context,
      menu: menu,
      anchor: resolved,
    );
    return result as T?;
  }

  /// Presents a menu at a global point.
  Future<T?> showAt<T>(
    Offset position, {
    required BuildContext context,
    required PrismMenu menu,
  }) => show<T>(context: context, menu: menu, anchor: .point(position));

  /// Dismisses the current menu, if any.
  Future<void> dismiss() => PrismMenuEngine.instance.dismiss();

  /// Selects a native action through the bridge for testing.
  @visibleForTesting
  Future<void> debugSelect(String actionId) =>
      PrismMenuPlatform.instance.debugSelect(actionId);

  /// The broadcast stream of native menu events.
  Stream<PrismMenuEvent> get events => PrismMenuEngine.instance.events;

  /// Whether a native menu session is active.
  bool get isPresented => PrismMenuEngine.instance.isPresented;

  /// Whether native menus are supported after a lazy handshake.
  Future<bool> get supportsNativeMenu async {
    await PrismMenuEngine.instance.ensureHandshaken();
    return PrismMenuEngine.instance.nativeSupported;
  }

  static PrismMenuAnchor _rectOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return .rect(
        Rect.fromPoints(
          box.localToGlobal(.zero),
          box.localToGlobal(box.size.bottomRight(.zero)),
        ),
      );
    }
    final size = MediaQuery.maybeSizeOf(context) ?? .zero;
    return .point(size.center(.zero));
  }
}
