import 'dart:ui' show Offset, Rect;

/// A menu attachment point or rectangle in global coordinates.
sealed class PrismMenuAnchor {
  /// Creates a PrismMenuAnchor.
  const PrismMenuAnchor();

  /// Creates an anchor at a global point.
  const factory PrismMenuAnchor.point(Offset position) = PrismMenuPointAnchor;

  /// Creates an anchor at global bounds.
  const factory PrismMenuAnchor.rect(Rect rect) = PrismMenuRectAnchor;

  /// Serializes native wire fields.
  Map<String, Object?> toMap();
}

/// Anchors a menu at a global point.
final class PrismMenuPointAnchor extends PrismMenuAnchor {
  /// Creates a PrismMenuPointAnchor.
  const PrismMenuPointAnchor(this.position);

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
final class PrismMenuRectAnchor extends PrismMenuAnchor {
  /// Creates a PrismMenuRectAnchor.
  const PrismMenuRectAnchor(this.rect);

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
