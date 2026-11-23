import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Material recipes supported by [PrismGlass].
enum PrismGlassVariant { regular, clear, identity }

/// Composable glass material configuration.
@immutable
final class PrismGlass {
  const PrismGlass._(this.variant, this.tintColor, this.isInteractive);

  /// Standard adaptive frosted glass.
  static const PrismGlass regular = PrismGlass._(
    PrismGlassVariant.regular,
    null,
    false,
  );

  /// Clear optical glass with minimal frost.
  static const PrismGlass clear = PrismGlass._(
    PrismGlassVariant.clear,
    null,
    false,
  );

  /// Pass-through material that draws only its child.
  static const PrismGlass identity = PrismGlass._(
    PrismGlassVariant.identity,
    null,
    false,
  );

  /// Underlying material recipe.
  final PrismGlassVariant variant;

  /// Optional tint color blended with the material.
  final Color? tintColor;

  /// Whether press feedback is enabled for this surface.
  final bool isInteractive;

  /// Returns a copy with [color] applied as the tint; pass null to clear.
  PrismGlass tint(Color? color) => PrismGlass._(variant, color, isInteractive);

  /// Returns a copy with interactive press feedback set to [enabled].
  PrismGlass interactive([bool enabled = true]) =>
      PrismGlass._(variant, tintColor, enabled);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismGlass &&
          other.variant == variant &&
          other.tintColor == tintColor &&
          other.isInteractive == isInteractive;

  @override
  int get hashCode => Object.hash(variant, tintColor, isInteractive);
}

/// Contour geometry used for glass optics, clipping, and shadows.
@immutable
final class PrismShape {
  /// Continuous superellipse rounded rectangle.
  const PrismShape.rect({double cornerRadius = 24})
    : radius = cornerRadius,
      isCircle = false,
      isSmooth = true,
      assert(cornerRadius >= 0 && cornerRadius <= 10000);

  const PrismShape._(this.radius, this.isCircle) : isSmooth = false;

  /// Circular-arc rounded rectangle.
  const PrismShape.roundedRect({double cornerRadius = 24})
    : radius = cornerRadius,
      isCircle = false,
      isSmooth = false,
      assert(cornerRadius >= 0 && cornerRadius <= 10000);

  /// Continuous capsule with radius clamped to half the shortest side.
  static const PrismShape capsule = PrismShape.rect(cornerRadius: 10000);

  /// Circle inscribed in the available layout bounds.
  static const PrismShape circle = PrismShape._(10000, true);

  /// Nominal corner radius in logical pixels.
  final double radius;

  /// Whether this shape is an inscribed circle.
  final bool isCircle;

  /// Whether this shape uses continuous superellipse corners.
  final bool isSmooth;

  @internal
  double effectiveRadius(Size size) =>
      radius.clamp(0, size.shortestSide / 2).toDouble();

  /// Bounds rectangle for this shape within [size].
  Rect rect(Size size) => isCircle
      ? Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.shortestSide,
          height: size.shortestSide,
        )
      : Offset.zero & size;

  /// Rounded rectangle approximation of this shape within [size].
  RRect outline(Size size) =>
      RRect.fromRectAndRadius(rect(size), Radius.circular(radius)).scaleRadii();

  /// Exact clip and stroke path for this shape within [size].
  Path path(Size size) => isSmooth
      ? RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(effectiveRadius(size)),
        ).getOuterPath(rect(size))
      : (Path()..addRRect(outline(size)));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismShape &&
          other.radius == radius &&
          other.isCircle == isCircle &&
          other.isSmooth == isSmooth;

  @override
  int get hashCode => Object.hash(radius, isCircle, isSmooth);
}

@internal
class PrismShapeClipper extends CustomClipper<Path> {
  const PrismShapeClipper(this.shape);

  final PrismShape shape;

  @override
  Path getClip(Size size) => shape.path(size);

  @override
  bool shouldReclip(PrismShapeClipper oldClipper) => shape != oldClipper.shape;
}
