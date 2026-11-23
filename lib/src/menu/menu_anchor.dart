import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart' show immutable;

/// A menu attachment point or rectangle in global coordinates.
sealed class PrismMenuAnchor {
  /// Creates a PrismMenuAnchor.
  const new();

  /// Creates an anchor at a global point.
  const factory point(Offset position) = PrismMenuPointAnchor;

  /// Creates an anchor at global bounds.
  const factory rect(Rect rect) = PrismMenuRectAnchor;

  /// Serializes native wire fields.
  Map<String, Object?> toMap();
}

/// Anchors a menu at a global point.
@immutable
final class PrismMenuPointAnchor extends PrismMenuAnchor {
  /// Creates a PrismMenuPointAnchor.
  const new(this.position);

  /// The attachment point in global coordinates.
  final Offset position;

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuPointAnchor &&
          runtimeType == other.runtimeType &&
          position == other.position);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(runtimeType, position);

  /// Serializes native wire fields.
  @override
  Map<String, Object?> toMap() => {
    'type': 'point',
    'x': position.dx,
    'y': position.dy,
  };
}

/// Anchors a menu to global bounds.
@immutable
final class PrismMenuRectAnchor extends PrismMenuAnchor {
  /// Creates a PrismMenuRectAnchor.
  const new(this.rect);

  /// The attachment bounds in global coordinates.
  final Rect rect;

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuRectAnchor &&
          runtimeType == other.runtimeType &&
          rect == other.rect);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(runtimeType, rect);

  /// Serializes native wire fields.
  @override
  Map<String, Object?> toMap() => {
    'type': 'rect',
    'x': rect.left,
    'y': rect.top,
    'width': rect.width,
    'height': rect.height,
  };
}
