import 'dart:async';

import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/menu/menu_platform_interface.dart';

final class FakePrismMenuPlatform extends PrismMenuPlatform {
  bool nativeMenu = true;

  bool acceptShow = true;

  bool wasPresented = false;

  String? session;
  int handshakeCalls = 0;
  int dismissCalls = 0;
  final List<
    ({String menuId, Map<String, Object?> menu, Map<String, Object?> anchor})
  >
  shows = [];

  @override
  Future<List<Object?>?> Function(String menuId, String deferredId)?
  deferredResolver;

  final _events = StreamController<PrismMenuEvent>.broadcast();

  void emit(PrismMenuEvent event) => _events.add(event);

  @override
  Future<Map<String, Object?>> handshake(String session) async {
    this.session = session;
    handshakeCalls++;
    return {
      'capabilities': {'nativeMenu': nativeMenu},
    };
  }

  @override
  Future<bool> show(
    String menuId,
    Map<String, Object?> menu,
    Map<String, Object?> anchor,
  ) async {
    shows.add((menuId: menuId, menu: menu, anchor: anchor));
    wasPresented = acceptShow;
    return acceptShow;
  }

  final List<String> debugSelects = [];

  @override
  Future<void> debugSelect(String actionId) async {
    debugSelects.add(actionId);
  }

  @override
  Future<bool> dismiss() async {
    dismissCalls++;
    final was = wasPresented;
    wasPresented = false;
    return was;
  }

  @override
  Stream<PrismMenuEvent> get events => _events.stream;
}
