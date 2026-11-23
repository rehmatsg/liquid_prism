import 'package:flutter/foundation.dart' show immutable;

/// A native menu lifecycle or selection event.
sealed class PrismMenuEvent {
  /// Creates a PrismMenuEvent.
  const new({required this.menuId});

  /// The identifier of the menu associated with this event.
  final String menuId;

  /// Decodes a native event, ignoring unknown event types.
  static PrismMenuEvent? fromMap(Map<Object?, Object?> map) {
    final menuId = map['menuId'] as String?;
    if (menuId == null) return null;
    return switch (map['event']) {
      'presented' => PrismMenuPresented(menuId: menuId),
      'dismissed' => PrismMenuDismissed(menuId: menuId),
      'action' => PrismMenuActionEvent(
        menuId: menuId,
        actionId: map['actionId'] as String? ?? '',
      ),
      _ => null,
    };
  }
}

/// Reports that the system began presenting a menu.
@immutable
final class PrismMenuPresented extends PrismMenuEvent {
  /// Creates a PrismMenuPresented.
  const new({required super.menuId});

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuPresented &&
          runtimeType == other.runtimeType &&
          menuId == other.menuId);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(runtimeType, menuId);
}

/// Reports that a menu finished dismissing.
@immutable
final class PrismMenuDismissed extends PrismMenuEvent {
  /// Creates a PrismMenuDismissed.
  const new({required super.menuId});

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuDismissed &&
          runtimeType == other.runtimeType &&
          menuId == other.menuId);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(runtimeType, menuId);
}

/// Reports a row selection, including repeated selections.
@immutable
final class PrismMenuActionEvent extends PrismMenuEvent {
  /// Creates a PrismMenuActionEvent.
  const new({required super.menuId, required this.actionId});

  /// The selected action wire identifier.
  final String actionId;

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuActionEvent &&
          runtimeType == other.runtimeType &&
          menuId == other.menuId &&
          actionId == other.actionId);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(runtimeType, menuId, actionId);
}
