import 'package:flutter/services.dart';

import 'package:liquid_prism/src/menu/menu_event.dart';
import 'package:liquid_prism/src/menu/menu_platform_interface.dart';

/// Implements the native menu method and event channels.
class MethodChannelPrismMenu extends PrismMenuPlatform {
  /// Creates a MethodChannelPrismMenu.
  new() {
    methodChannel.setMethodCallHandler(_handleNativeCall);
  }

  /// The native bridge wire protocol version.
  static const int protocolVersion = 1;

  /// The channel used for native menu commands.
  final MethodChannel methodChannel = const MethodChannel('liquid_prism/menus');
  final EventChannel _eventChannel = const EventChannel(
    'liquid_prism/menus/events',
  );

  /// Resolves deferred children into wire elements at display time.
  @override
  Future<List<Object?>?> Function(String menuId, String deferredId)?
  deferredResolver;

  Stream<PrismMenuEvent>? _events;

  Map<String, Object?> _envelope(Map<String, Object?> body) => {
    'protocolVersion': protocolVersion,
    ...body,
  };

  /// Starts a Dart session and returns native capabilities.
  @override
  Future<Map<String, Object?>> handshake(String session) async {
    final res = await methodChannel.invokeMapMethod<String, Object?>(
      'handshake',
      _envelope({'session': session}),
    );
    return res ?? <String, Object?>{};
  }

  /// Requests native presentation and reports whether it was accepted.
  @override
  Future<bool> show(
    String menuId,
    Map<String, Object?> menu,
    Map<String, Object?> anchor,
  ) async {
    final res = await methodChannel.invokeMapMethod<String, Object?>(
      'show',
      _envelope({'menuId': menuId, 'menu': menu, 'anchor': anchor}),
    );
    return (res?['accepted'] as bool?) ?? false;
  }

  /// Dismisses the current menu, if any.
  @override
  Future<bool> dismiss() async {
    final res = await methodChannel.invokeMapMethod<String, Object?>(
      'dismiss',
      _envelope(const {}),
    );
    return (res?['dismissed'] as bool?) ?? false;
  }

  /// Selects a native action through the bridge for testing.
  @override
  Future<void> debugSelect(String actionId) => methodChannel.invokeMethod<void>(
    'debugSelect',
    _envelope({'actionId': actionId}),
  );

  /// The broadcast stream of native menu events.
  @override
  Stream<PrismMenuEvent> get events => _events ??= _eventChannel
      .receiveBroadcastStream()
      .map(
        (e) => e is Map<Object?, Object?>
            ? PrismMenuEvent.fromMap(e.cast<Object?, Object?>())
            : null,
      )
      .where((e) => e != null)
      .cast<PrismMenuEvent>();

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'resolveDeferred') {
      final args = (call.arguments as Map<Object?, Object?>)
          .cast<String, Object?>();
      final menuId = args['menuId'] as String? ?? '';
      final id = args['id'] as String? ?? '';
      final resolver = deferredResolver;
      if (resolver == null) return const <Object?>[];
      return await resolver(menuId, id);
    }
    return null;
  }
}
