import 'package:flutter/widgets.dart';

import 'material.dart';
import 'style.dart';

// Default tint ramps map material luminance to output sRGB.
enum GlassRole { surface, button, tabBar, selection }

final class GlassRecipe {
  const GlassRecipe(
    this.kind,
    this.dark,
    this.role,
    this.tintSlope,
    this.tintBias,
    this.tintAlpha,
  );
  final double kind;
  final bool dark;
  final GlassRole role;
  final List<double> tintSlope, tintBias;
  final double tintAlpha;
  static GlassRecipe resolve(
    Glass glass,
    Brightness brightness,
    GlassRole role, {
    required bool customOptics,
  }) {
    final dark = brightness == Brightness.dark;
    final tint = glass.tintColor;
    final rgb = tint == null ? 0 : tint.toARGB32() & 0xFFFFFF;
    final ramp = (dark ? _darkRamps : _lightRamps)[rgb];
    // Custom colors retain a small luminance response around the tint.
    final slope =
        ramp?.$1 ??
        [
          0.12 * (1 - (tint?.r ?? 0)),
          0.12 * (1 - (tint?.g ?? 0)),
          0.12 * (1 - (tint?.b ?? 0)),
        ];
    final bias =
        ramp?.$2 ??
        [(tint?.r ?? 0) * 0.94, (tint?.g ?? 0) * 0.94, (tint?.b ?? 0) * 0.94];
    return GlassRecipe(
      customOptics ? 0 : (glass.variant == GlassVariant.clear ? 2 : 1),
      dark,
      role,
      slope,
      bias,
      tint?.a ?? 0,
    );
  }

  LiquidPrismStyle optics(double radius) => kind == 2
      ? LiquidPrismStyle.clear.copyWith(cornerRadius: radius)
      : LiquidPrismStyle(
          edgeWidth: 16,
          refraction: 48,
          frost: 3.3,
          brightness: 0,
          tint: const Color(0x00000000),
          saturation: 1,
          reflection: 0.08,
          cornerRadius: radius,
        );
  List<double> get uniforms => [
    kind,
    dark ? 1 : 0,
    role.index.toDouble(),
    tintAlpha,
    ...tintSlope,
    0,
    ...tintBias,
    0,
  ];
}

const _darkRamps = <int, (List<double>, List<double>)>{
  0x0091FF: (
    [0.2041667, 0.0667487, -0.0375001],
    [-0.0306248, 0.5586151, 1.005625],
  ),
  0x30D158: (
    [0.1610681, 0.0069058, 0.1227668],
    [0.1640756, 0.818572, 0.326683],
  ),
  0xFF9230: (
    [-0.0288723, 0.1058156, 0.2269116],
    [1.0043306, 0.5566769, 0.1541982],
  ),
  0xFF375F: (
    [-0.0276142, 0.2302288, 0.1786605],
    [1.0041419, 0.1811522, 0.34575],
  ),
};

const _lightRamps = <int, (List<double>, List<double>)>{
  0x0088FF: ([2.5e-06, 0.2462743, 0.3999984], [-4e-07, 0.2870589, 0.6000015]),
  0x34C759: (
    [0.1366555, 0.3265512, 0.1844524],
    [0.067267, 0.4538407, 0.1645673],
  ),
  0xFF8D28: (
    [0.2782007, 0.2718404, 0.1845447],
    [0.7217991, 0.2811008, -0.0276817],
  ),
  0xFF2D55: (
    [0.2629757, 0.2076127, 0.2853849],
    [0.7370241, -0.0311419, 0.0479484],
  ),
};
