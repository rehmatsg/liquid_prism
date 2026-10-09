import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Optical controls in logical pixels, independent of device density.
@immutable
class LiquidPrismStyle {
  const LiquidPrismStyle({
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

  static const clear = LiquidPrismStyle();
  static const frosted = LiquidPrismStyle(
    frost: 7,
    tint: Color(0x24FFFFFF),
    refraction: 14,
    dispersion: 0.15,
  );
  static const smoked = LiquidPrismStyle(
    frost: 3,
    tint: Color(0x66101C2D),
    light: 1.1,
    reflection: 0.45,
  );

  final double edgeWidth,
      refraction,
      frost,
      dispersion,
      brightness,
      saturation,
      light,
      reflection,
      reflectionReach,
      splay,
      cornerRadius;
  final Color tint;

  LiquidPrismStyle copyWith({
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
  }) => LiquidPrismStyle(
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
}
