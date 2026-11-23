import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Complete optical parameter packet for custom glass rendering.
@immutable
class PrismOptics {
  /// Creates an optical configuration in logical pixels.
  const PrismOptics({
    this.edgeWidth = 16,
    this.refraction = 60,
    this.frost = 1.8,
    this.dispersion = 0.2,
    this.brightness = 0.06,
    this.tint = const Color(0x0FFFFFFF),
    this.saturation = 1.12,
    this.light = 1,
    this.reflection = 0.3,
    this.reflectionReach = 30,
    this.splay = 0.12,
    this.cornerRadius = 32,
  }) : assert(edgeWidth > 0 && edgeWidth <= 64),
       assert(refraction >= 0 && refraction <= 64),
       assert(frost >= 0 && frost <= 12),
       assert(dispersion >= 0 && dispersion <= 2),
       assert(brightness >= -0.5 && brightness <= 0.5),
       assert(saturation >= 0 && saturation <= 2),
       assert(light >= 0 && light <= 2),
       assert(reflection >= 0 && reflection <= 2),
       assert(reflectionReach >= 0 && reflectionReach <= 80),
       assert(splay >= 0 && splay <= 1),
       assert(cornerRadius >= 0 && cornerRadius <= 10000);

  /// Clear optical preset.
  static const PrismOptics clear = PrismOptics();

  /// Frosted optical preset.
  static const PrismOptics frosted = PrismOptics(
    frost: 7,
    tint: Color(0x24FFFFFF),
    refraction: 14,
    dispersion: 0.15,
  );

  /// Smoked dark optical preset.
  static const PrismOptics smoked = PrismOptics(
    frost: 3,
    tint: Color(0x66101C2D),
    light: 1.1,
    reflection: 0.45,
  );

  /// Refracting rim width in logical pixels.
  final double edgeWidth;

  /// Rim displacement magnitude in logical pixels.
  final double refraction;

  /// Backdrop frost blur sigma in logical pixels.
  final double frost;

  /// Chromatic dispersion strength along the rim.
  final double dispersion;

  /// Face brightness offset.
  final double brightness;

  /// Face saturation multiplier.
  final double saturation;

  /// Specular rim lighting intensity.
  final double light;

  /// Strength of surroundings mirrored into the rim band.
  final double reflection;

  /// Reach outside the contour sampled for rim reflection.
  final double reflectionReach;

  /// Corner lighting splay factor.
  final double splay;

  /// Default corner radius when no shape override is provided.
  final double cornerRadius;

  /// Surface tint overlay color.
  final Color tint;

  /// Returns a copy with specified fields replaced.
  PrismOptics copyWith({
    double? edgeWidth,
    double? refraction,
    double? frost,
    double? dispersion,
    double? brightness,
    Color? tint,
    double? saturation,
    double? light,
    double? reflection,
    double? reflectionReach,
    double? splay,
    double? cornerRadius,
  }) => PrismOptics(
    edgeWidth: edgeWidth ?? this.edgeWidth,
    refraction: refraction ?? this.refraction,
    frost: frost ?? this.frost,
    dispersion: dispersion ?? this.dispersion,
    brightness: brightness ?? this.brightness,
    tint: tint ?? this.tint,
    saturation: saturation ?? this.saturation,
    light: light ?? this.light,
    reflection: reflection ?? this.reflection,
    reflectionReach: reflectionReach ?? this.reflectionReach,
    splay: splay ?? this.splay,
    cornerRadius: cornerRadius ?? this.cornerRadius,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismOptics &&
          other.edgeWidth == edgeWidth &&
          other.refraction == refraction &&
          other.frost == frost &&
          other.dispersion == dispersion &&
          other.brightness == brightness &&
          other.tint == tint &&
          other.saturation == saturation &&
          other.light == light &&
          other.reflection == reflection &&
          other.reflectionReach == reflectionReach &&
          other.splay == splay &&
          other.cornerRadius == cornerRadius;

  @override
  int get hashCode => Object.hash(
    edgeWidth,
    refraction,
    frost,
    dispersion,
    brightness,
    tint,
    saturation,
    light,
    reflection,
    reflectionReach,
    splay,
    cornerRadius,
  );
}
