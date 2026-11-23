import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/menu/fallback_menu.dart';
import 'package:liquid_prism/src/menu/ids.dart';
import 'package:liquid_prism/src/menu/menu.dart';
import 'package:liquid_prism/src/menu/menu_anchor.dart';
import 'package:liquid_prism/src/menu/menu_elements.dart';
import 'package:liquid_prism/src/menu/menu_event.dart';
import 'package:liquid_prism/src/menu/menu_platform_interface.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';
import 'package:material_ui/material_ui.dart' show Theme;

/// Owns menu sessions, native events, and fallback presentation.
final class PrismMenuEngine {
  new _();

  /// The shared menu instance.
  static final PrismMenuEngine instance = PrismMenuEngine._();

  /// Whether the last handshake reported native menu support.
  bool get nativeSupported => _nativeSupported;
  bool _nativeSupported = false;

  Future<void>? _handshake;
  _MenuSession? _current;
  StreamSubscription<PrismMenuEvent>? _eventSub;
  final StreamController<PrismMenuEvent> _publicEvents =
      StreamController<PrismMenuEvent>.broadcast();

  /// The broadcast stream of native menu events.
  Stream<PrismMenuEvent> get events => _publicEvents.stream;

  /// Whether a native menu session is active.
  bool get isPresented => _current != null;

  /// Clears handshake and session state for the next test.
  @visibleForTesting
  void resetForTests() {
    _handshake = null;
    _nativeSupported = false;
    _current = null;
    unawaited(_eventSub?.cancel());
    _eventSub = null;
  }

  /// Overrides platform detection in tests.
  @visibleForTesting
  static TargetPlatform? debugTargetPlatformOverride;

  /// Initializes native capabilities and event routing once.
  Future<void> ensureHandshaken() {
    return _handshake ??= () async {
      final platform = PrismMenuPlatform.instance
        ..deferredResolver = _resolveDeferred;
      try {
        final caps = await platform.handshake(MenuIds.session);
        final capsMap = caps['capabilities'];
        _nativeSupported =
            capsMap is Map<Object?, Object?> && capsMap['nativeMenu'] == true;
      } on Object catch (_) {
        _nativeSupported = false;
      }
      if (_nativeSupported) {
        _eventSub ??= platform.events.listen(_onEvent);
      }
    }();
  }

  /// Presents a menu and completes with the first selected value on dismissal.
  Future<Object?> show({
    required BuildContext context,
    required PrismMenu menu,
    required PrismMenuAnchor anchor,
  }) async {
    final appearance =
        (PrismTheme.of(context).brightness ?? Theme.of(context).brightness)
            .name;
    await ensureHandshaken();
    if (!context.mounted) return null;
    _finishCurrent(null);

    final platformIsIOS =
        (debugTargetPlatformOverride ?? defaultTargetPlatform) == .iOS;
    if (_nativeSupported && platformIsIOS) {
      final session = _prepare(menu);
      session.wireMenu['appearance'] = appearance;
      _current = session;
      var accepted = false;
      try {
        accepted = await PrismMenuPlatform.instance.show(
          session.menuId,
          session.wireMenu,
          anchor.toMap(),
        );
      } on Object catch (_) {
        accepted = false;
      }
      if (accepted) {
        return await session.result.future;
      }
      _finishCurrent(null);
    }
    if (!context.mounted) return null;
    return await FallbackMenu.show(context, menu, anchor);
  }

  /// Dismisses the current menu, if any.
  Future<void> dismiss() async {
    _finishCurrent(null);
    try {
      await PrismMenuPlatform.instance.dismiss();
    } on Object catch (_) {}
  }

  void _finishCurrent(Object? value) {
    final session = _current;
    if (session == null) return;
    _current = null;
    if (!session.result.isCompleted) session.result.complete(value);
  }

  void _onEvent(PrismMenuEvent event) {
    _publicEvents.add(event);
    final session = _current;
    if (session == null || event.menuId != session.menuId) return;
    switch (event) {
      case PrismMenuActionEvent(:final actionId):
        final action = session.actions[actionId];
        if (action == null) return;
        action.onSelected?.call();
        if (!session.gotSelection) {
          session
            ..gotSelection = true
            ..selectedValue = action.value;
        }
      case PrismMenuDismissed():
        _finishCurrent(session.selectedValue);
      case PrismMenuPresented():
        break;
    }
  }

  _MenuSession _prepare(PrismMenu menu) {
    final session = _MenuSession(menuId: MenuIds.mint());
    final wireMenu = menu.toMap((e) => _serialize(e, session));
    session.wireMenu = wireMenu;
    return session;
  }

  Map<String, Object?> _serialize(
    PrismMenuElement element,
    _MenuSession session,
  ) {
    switch (element) {
      case final PrismMenuAction<Object?> action:
        final wireId = action.id ?? MenuIds.mint();
        session.actions[wireId] = action;
        return {...action.toMap(), 'id': wireId};
      case PrismMenuSection() || PrismSubmenu():
        final map = element.toMap();
        final menu = map['menu']! as Map<String, Object?>;
        final children = switch (element) {
          PrismMenuSection s => s.children,
          PrismSubmenu s => s.children,
          _ => const <PrismMenuElement>[],
        };
        menu['items'] = [for (final e in children) _serialize(e, session)];
        return map;
      case PrismMenuDivider():
        return element.toMap();
      case final PrismMenuDeferred deferred:
        final wireId = deferred.id ?? MenuIds.mint();
        session.deferred[wireId] = deferred.loader;
        return {'type': 'deferred', 'id': wireId};
    }
  }

  Future<List<Object?>?> _resolveDeferred(
    String menuId,
    String deferredId,
  ) async {
    final session = _current;
    if (session == null || session.menuId != menuId) return const [];
    final loader = session.deferred[deferredId];
    if (loader == null) return const [];
    try {
      final children = await loader();
      return [for (final e in children) _serialize(e, session)];
    } on Object catch (_) {
      return const [];
    }
  }
}

final class _MenuSession {
  new({required this.menuId});

  final String menuId;
  final Completer<Object?> result = Completer<Object?>();
  final Map<String, PrismMenuAction<Object?>> actions = {};
  final Map<String, FutureOr<List<PrismMenuElement>> Function()> deferred = {};
  late Map<String, Object?> wireMenu;

  Object? selectedValue;
  bool gotSelection = false;
}
