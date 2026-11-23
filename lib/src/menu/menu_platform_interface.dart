import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'menu_event.dart';
import 'menu_method_channel.dart';

/// Defines the native menu bridge and deferred resolution contract.
abstract class PrismMenuPlatform extends PlatformInterface {
  /// Creates a PrismMenuPlatform.
  PrismMenuPlatform() : super(token: _token);

  static final Object _token = Object();

  static PrismMenuPlatform _instance = MethodChannelPrismMenu();

  /// The active native menu bridge.
  static PrismMenuPlatform get instance => _instance;

  /// Sets the verified native menu bridge.
  static set instance(PrismMenuPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Starts a Dart session and returns native capabilities.
  Future<Map<String, Object?>> handshake(String session) {
    throw UnimplementedError('handshake() has not been implemented.');
  }

  /// Requests native presentation and reports whether it was accepted.
  Future<bool> show(
    String menuId,
    Map<String, Object?> menu,
    Map<String, Object?> anchor,
  ) {
    throw UnimplementedError('show() has not been implemented.');
  }

  /// Dismisses the current menu, if any.
  Future<bool> dismiss() {
    throw UnimplementedError('dismiss() has not been implemented.');
  }

  /// Selects a native action through the bridge for testing.
  Future<void> debugSelect(String actionId) {
    throw UnimplementedError('debugSelect() has not been implemented.');
  }

  /// The broadcast stream of native menu events.
  Stream<PrismMenuEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  /// Resolves deferred children into wire elements at display time.
  Future<List<Object?>?> Function(String menuId, String deferredId)?
  get deferredResolver;

  /// Sets the display-time deferred element resolver.
  set deferredResolver(
    Future<List<Object?>?> Function(String menuId, String deferredId)? resolver,
  );
}
