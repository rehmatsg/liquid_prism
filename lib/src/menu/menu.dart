import 'package:flutter/foundation.dart' show immutable, listEquals;

import 'package:liquid_prism/src/menu/menu_elements.dart';
import 'package:liquid_prism/src/menu/menu_icon.dart';

/// A native popup menu with ordered child elements.
@immutable
final class PrismMenu {
  /// Creates a PrismMenu.
  const new({
    this.title = '',
    this.image,
    this.identifier,
    this.children = const [],
    this.preferredElementSize = .automatic,
  });

  /// The row or menu header text.
  final String title;

  /// The menu header image.
  final PrismMenuIcon? image;

  /// The optional native menu identifier.
  final String? identifier;

  /// The ordered child elements.
  final List<PrismMenuElement> children;

  /// The preferred native row density.
  final PrismMenuElementSize preferredElementSize;

  /// Serializes native wire fields.
  Map<String, Object?> toMap(
    Map<String, Object?> Function(PrismMenuElement) serializeChild,
  ) => {
    'title': title,
    if (image != null) 'image': image!.toMap(),
    if (identifier != null) 'identifier': identifier,
    'elementSize': preferredElementSize.name,
    'options': const <String, Object?>{},
    'items': [for (final e in children) serializeChild(e)],
  };

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenu &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          image == other.image &&
          identifier == other.identifier &&
          listEquals(children, other.children) &&
          preferredElementSize == other.preferredElementSize);

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(
    runtimeType,
    title,
    image,
    identifier,
    Object.hashAll(children),
    preferredElementSize,
  );
}
