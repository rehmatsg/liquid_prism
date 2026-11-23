import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/painting.dart' show Color;

/// An SF Symbol or encoded bitmap used by a menu.
sealed class PrismMenuIcon {
  /// Creates a PrismMenuIcon.
  const PrismMenuIcon();

  /// Serializes native wire fields.
  Map<String, Object?> toMap();
}

/// An SF Symbol with optional configuration and palette colors.
final class PrismMenuSfSymbol extends PrismMenuIcon {
  /// Creates a PrismMenuSfSymbol.
  const PrismMenuSfSymbol(
    this.name, {
    this.weight,
    this.scale,
    this.renderingMode = .automatic,
    this.palette = const [],
  });

  /// The SF Symbol name.
  final String name;

  /// The optional SF Symbol weight.
  final PrismSymbolWeight? weight;

  /// The optional SF Symbol scale.
  final PrismSymbolScale? scale;

  /// The SF Symbol rendering mode.
  final PrismSymbolRenderingMode renderingMode;

  /// The SF Symbol palette colors in rendering order.
  final List<Color> palette;

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuSfSymbol &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          weight == other.weight &&
          scale == other.scale &&
          renderingMode == other.renderingMode &&
          listEquals(palette, other.palette));

  /// The hash of this value and its fields.
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    weight,
    scale,
    renderingMode,
    Object.hashAll(palette),
  );

  /// Serializes native wire fields.
  @override
  Map<String, Object?> toMap() => {
    'kind': 'sfSymbol',
    'name': name,
    if (weight != null) 'weight': weight!.name,
    if (scale != null) 'scale': scale!.name,
    if (renderingMode != .automatic) 'renderingMode': renderingMode.name,
    if (palette.isNotEmpty) 'palette': [for (final c in palette) c.toARGB32()],
  };
}

/// Encoded bitmap bytes with optional template tinting.
final class PrismMenuImage extends PrismMenuIcon {
  /// Creates a bitmap menu icon.
  const PrismMenuImage(this.bytes, {this.templated = false});

  /// The encoded image bytes.
  final Uint8List bytes;

  /// Whether the bitmap uses the menu tint.
  final bool templated;

  /// Whether another value has the same type and fields.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrismMenuImage &&
          runtimeType == other.runtimeType &&
          listEquals(bytes, other.bytes) &&
          templated == other.templated);

  /// The hash of this value and its fields.
  @override
  int get hashCode =>
      Object.hash(runtimeType, Object.hashAll(bytes), templated);

  /// Serializes native wire fields.
  @override
  Map<String, Object?> toMap() => {
    'kind': 'image',
    'bytes': bytes,
    'templated': templated,
  };
}

/// The native SF Symbol weight.
enum PrismSymbolWeight {
  /// Uses the ultralight weight.
  ultraLight,

  /// Uses the thin weight.
  thin,

  /// Uses the light weight.
  light,

  /// Uses the regular weight.
  regular,

  /// Uses the medium weight.
  medium,

  /// Uses the semibold weight.
  semibold,

  /// Uses the bold weight.
  bold,

  /// Uses the heavy weight.
  heavy,

  /// Uses the black weight.
  black,
}

/// The native SF Symbol scale.
enum PrismSymbolScale {
  /// The small setting.
  small,

  /// The medium setting.
  medium,

  /// The large setting.
  large,
}

/// The native SF Symbol rendering mode.
enum PrismSymbolRenderingMode {
  /// Uses the system rendering mode.
  automatic,

  /// Uses a single tint color.
  monochrome,

  /// Uses hierarchical tint levels.
  hierarchical,

  /// Uses the configured palette colors.
  palette,

  /// Uses the symbol’s built-in colors.
  multicolor,
}
