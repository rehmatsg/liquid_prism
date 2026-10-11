import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The material recipes supported by [Glass].
enum GlassVariant { regular, clear, identity }

/// A composable glass material value. Modifiers return new values.
///
/// Tint alpha controls the blend with the untinted material; `tint(null)` removes
/// it. Identity draws only its child and ignores tint and interaction.
@immutable
final class Glass {
  const Glass._(this.variant, this.tintColor, this.isInteractive);
  static const regular = Glass._(GlassVariant.regular, null, false);
  static const clear = Glass._(GlassVariant.clear, null, false);
  static const identity = Glass._(GlassVariant.identity, null, false);
  final GlassVariant variant;
  final Color? tintColor;
  final bool isInteractive;
  Glass tint(Color? color) => Glass._(variant, color, isInteractive);
  Glass interactive([bool enabled = true]) =>
      Glass._(variant, tintColor, enabled);
  @override
  bool operator ==(Object other) =>
      other is Glass &&
      other.variant == variant &&
      other.tintColor == tintColor &&
      other.isInteractive == isInteractive;
  @override
  int get hashCode => Object.hash(variant, tintColor, isInteractive);
}

/// Circle is inscribed in the available rectangle without changing layout.
@immutable
final class GlassShape {
  const GlassShape.rect({double cornerRadius = 24})
    : radius = cornerRadius,
      isCircle = false,
      isSmooth = true,
      assert(cornerRadius >= 0 && cornerRadius <= 10000);
  const GlassShape._(this.radius, this.isCircle) : isSmooth = false;
  const GlassShape.roundedRect({double cornerRadius = 24})
    : radius = cornerRadius,
      isCircle = false,
      isSmooth = false,
      assert(cornerRadius >= 0 && cornerRadius <= 10000);

  /// Continuous corners with the radius clamped to half the shortest side.
  /// Uses the same superellipse contour for optics, clipping and shadows.
  static const capsule = GlassShape.rect(cornerRadius: 10000);
  static const circle = GlassShape._(10000, true);
  final double radius;
  final bool isCircle;
  final bool isSmooth;
  @internal
  double effectiveRadius(Size size) =>
      radius.clamp(0, size.shortestSide / 2).toDouble();
  Rect rect(Size size) => isCircle
      ? Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.shortestSide,
          height: size.shortestSide,
        )
      : Offset.zero & size;
  RRect outline(Size size) =>
      RRect.fromRectAndRadius(rect(size), Radius.circular(radius)).scaleRadii();
  Path path(Size size) => isSmooth
      ? RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(effectiveRadius(size)),
        ).getOuterPath(rect(size))
      : (Path()..addRRect(outline(size)));
  @override
  bool operator ==(Object other) =>
      other is GlassShape &&
      other.radius == radius &&
      other.isCircle == isCircle &&
      other.isSmooth == isSmooth;
  @override
  int get hashCode => Object.hash(radius, isCircle, isSmooth);
}

/// A shared clip for foregrounds, selected materials and fallback surfaces.
@internal
class GlassShapeClipper extends CustomClipper<Path> {
  const GlassShapeClipper(this.shape);
  final GlassShape shape;
  @override
  Path getClip(Size size) => shape.path(size);
  @override
  bool shouldReclip(GlassShapeClipper oldClipper) => shape != oldClipper.shape;
}
