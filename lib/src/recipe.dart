import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'material.dart';
import 'native_colors.dart';
import 'style.dart';

enum GlassRole {
  surface(0),
  button(1),
  tabBar(2),
  tabLens(3),
  controlThumb(4),
  segmentLens(5),
  toolbar(7),
  searchField(8),
  sliderLens(9),
  controlLensUnminified(10);

  // Preserve shader IDs when a component is removed from the enum.
  const GlassRole(this.shaderId);
  final double shaderId;
}

/// Measured tint inputs, interpolated between device setting values.
/// See doc/native_adaptive_layout.md for captures and fitted behavior.
@internal
abstract final class GlassTint {
  /// iOS's default, where the package's recipes were calibrated.
  static const standard = 0.5;

  /// Tint amounts the tables below were measured at.
  static const amounts = <double>[0, .25, .5, 1];

  /// Regular: blur fill lighten opacity (float32 inputs as captured).
  static const regularLighten = <double>[
    0.6749999523162842,
    0.7874999642372131,
    0.8999999761581421,
    0.8999999761581421,
  ];

  /// Regular: blur fill normal opacity.
  static const regularNormal = <double>[0, .25, .5, 1];

  /// Regular, light: alpha of the white face fill colour.
  static const regularFaceFill = <double>[0, .1, .2, .5];

  /// Clear: blur radius (the face's own, light blur).
  static const clearBlurRadius = <double>[0, .375, .75, .75];

  /// Clear: blur fill normal opacity (its radius is 8 only at tint 1).
  static const clearFillNormal = <double>[0, 0, 0, 1];

  /// [values] at tint amount [t], linear between the measured amounts.
  static double sample(List<double> values, double t) {
    final x = t.clamp(0.0, 1.0);
    for (var i = 1; i < amounts.length; i++) {
      if (x <= amounts[i]) {
        final f = (x - amounts[i - 1]) / (amounts[i] - amounts[i - 1]);
        return values[i - 1] + (values[i] - values[i - 1]) * f;
      }
    }
    return values.last;
  }

  /// Resolution order: an explicit theme value, then the device's setting,
  /// then iOS's default.
  static double resolve(double? theme, double? device) =>
      (theme ?? device ?? standard).clamp(0.0, 1.0);
}

/// One blur of a surface's frost: a Gaussian copy of the backdrop under the
/// glass, composited over it at [opacity] with [blendMode]. Every pass of a
/// surface reads the same capture of the backdrop.
@immutable
@internal
final class FrostPass {
  const FrostPass(
    this.sigma, [
    this.opacity = 1,
    this.blendMode = BlendMode.srcOver,
  ]);
  final double sigma;
  final double opacity;
  final BlendMode blendMode;

  /// Replaces the backdrop under the glass outright, as a plain frost does.
  bool get covers => opacity >= 1 && blendMode == BlendMode.srcOver;

  FrostPass scaled(double factor) =>
      FrostPass(sigma * factor, opacity, blendMode);

  @override
  bool operator ==(Object other) =>
      other is FrostPass &&
      other.sigma == sigma &&
      other.opacity == opacity &&
      other.blendMode == blendMode;

  @override
  int get hashCode => Object.hash(sigma, opacity, blendMode);

  @override
  String toString() => 'FrostPass($sigma, $opacity, ${blendMode.name})';

  /// Composites the measured blur fills at [tint]. Regular frost is calibrated
  /// at tint 0.5; normal opacity is normalized to that value and capped at 1.
  static List<FrostPass> resolve({
    required double kind,
    required bool dark,
    required double frost,
    required double fillFrost,
    required double? tint,
  }) {
    if (tint == null || (kind != 1 && kind != 2)) {
      return frost > 0.05 ? [FrostPass(frost)] : const [];
    }
    if (kind == 1) {
      final normal = math.min(
        1.0,
        GlassTint.sample(GlassTint.regularNormal, tint) /
            GlassTint.sample(GlassTint.regularNormal, GlassTint.standard),
      );
      if (frost <= 0.05) return const [];
      if (normal >= 1) return [FrostPass(frost)];
      final blend = GlassTint.sample(GlassTint.regularLighten, tint);
      return [
        if (normal > 0) FrostPass(frost, normal),
        if (blend > 0)
          FrostPass(frost, blend, dark ? BlendMode.darken : BlendMode.lighten),
      ];
    }
    final radius = GlassTint.sample(GlassTint.clearBlurRadius, tint);
    final base =
        frost *
        radius /
        GlassTint.sample(GlassTint.clearBlurRadius, GlassTint.standard);
    final fill = GlassTint.sample(GlassTint.clearFillNormal, tint);
    if (fill >= 1 && fillFrost > 0.05) return [FrostPass(fillFrost)];
    return [
      if (base > 0.05) FrostPass(base),
      if (fill > 0 && fillFrost > 0.05) FrostPass(fillFrost, fill),
    ];
  }

  /// The blur the optical pass may assume of the face it reads: the last pass
  /// that replaces the backdrop outright, or none while sharp detail shows
  /// through.
  static double effectiveSigma(List<FrostPass> passes) {
    var sigma = 0.0;
    for (final pass in passes) {
      if (pass.covers) {
        sigma = pass.sigma;
      } else if (pass.blendMode == BlendMode.srcOver) {
        sigma = math.min(sigma, pass.sigma);
      }
    }
    return passes.any((p) => p.covers) ? sigma : 0;
  }
}

final class GlassRecipe {
  const GlassRecipe(
    this.kind,
    this.dark,
    this.role,
    this.tintMatrix,
    this.tintAlpha, [
    this.presence = 1,
    this.lensRim = 0,
    this.chromaticSplit = 0,
    this.chromaticBand = 0,
    this.underlay = 0,
    this.faceFill = .2,
  ]);
  final double kind;
  final bool dark;
  final GlassRole role;

  /// Three RGB rows with normalized offsets (12 values).
  final List<double> tintMatrix;
  final double tintAlpha;

  /// How materialized the surface is, 0–1. Fades the optical output and
  /// shadows; the caller scales lens and frost inputs.
  final double presence;

  /// Strength of the selected tab pill's bright glint, shader slot
  /// `u_state.w`. Zero, the default, for every other surface; the shader also
  /// ignores it outside the lifted lens recipe.
  final double lensRim;

  /// Effective red–blue split in points, already scaled by lift.
  final double chromaticSplit;

  /// Chromatic band depth in points (independent of lens height).
  final double chromaticBand;

  /// Broad outward displacement of the backdrop seen through a lifted lens,
  /// in points over a 36-point field, already scaled by lift. Separate from
  /// the optics' rim refraction: native gives each its own pass.
  final double underlay;

  /// Alpha of the white face fill of light regular glass, which follows the
  /// device's Liquid Glass setting ([GlassTint.regularFaceFill]); 0.2 at iOS's
  /// default. The shader ignores it for clear glass and dark appearance, whose
  /// measured fill is clear.
  final double faceFill;

  GlassRecipe _copyWith({
    double? presence,
    double? lensRim,
    double? chromaticSplit,
    double? chromaticBand,
    double? underlay,
    double? faceFill,
  }) => GlassRecipe(
    kind,
    dark,
    role,
    tintMatrix,
    tintAlpha,
    presence ?? this.presence,
    lensRim ?? this.lensRim,
    chromaticSplit ?? this.chromaticSplit,
    chromaticBand ?? this.chromaticBand,
    underlay ?? this.underlay,
    faceFill ?? this.faceFill,
  );

  GlassRecipe withTint(double tint) {
    final fill = GlassTint.sample(GlassTint.regularFaceFill, tint);
    return fill == faceFill ? this : _copyWith(faceFill: fill);
  }

  GlassRecipe withChromaticFringe(double split, double band) =>
      _copyWith(chromaticSplit: split, chromaticBand: band);

  GlassRecipe withUnderlay(double value) =>
      value == underlay ? this : _copyWith(underlay: value);

  GlassRecipe withPresence(double value) =>
      value == presence ? this : _copyWith(presence: value);

  GlassRecipe withLensRim(double value) =>
      value == lensRim ? this : _copyWith(lensRim: value);

  bool get usesNativeControlShadow => kind != 0 && role != GlassRole.surface;
  double get shadowStrength =>
      presence *
      (kind == 3 ? 0 : (usesNativeControlShadow ? 1 : (kind == 1 ? 0.5 : 1)));
  static GlassRecipe resolve(
    Glass glass,
    Brightness brightness,
    GlassRole role, {
    required bool customOptics,
  }) {
    final dark = brightness == Brightness.dark;
    final tint = glass.tintColor;
    final rgb = tint == null ? 0 : tint.toARGB32() & 0xFFFFFF;
    final matrix =
        nativeTintMatrices[(glass.variant == GlassVariant.clear, dark, rgb)];
    final fallback = <double>[
      for (final component in [tint?.r ?? 0, tint?.g ?? 0, tint?.b ?? 0]) ...[
        0.12 * (1 - component) * 0.2126,
        0.12 * (1 - component) * 0.7152,
        0.12 * (1 - component) * 0.0722,
        component * 0.94,
      ],
    ];
    final materialKind = glass.variant == GlassVariant.clear ? 2.0 : 1.0;
    final kind = switch (role) {
      GlassRole.toolbar || GlassRole.searchField => materialKind,
      GlassRole.controlThumb ||
      GlassRole.segmentLens ||
      GlassRole.tabLens ||
      GlassRole.sliderLens ||
      GlassRole.controlLensUnminified => 3.0,
      _ => customOptics ? 0.0 : materialKind,
    };
    return GlassRecipe(kind, dark, role, matrix ?? fallback, tint?.a ?? 0);
  }

  /// The regular recipe's frost: the blur fill a clear surface fades in
  /// towards tint 1, which native draws with the same captured radius.
  static const regularFrost = 3.3;

  LiquidPrismStyle optics(double radius) => kind == 2
      ? LiquidPrismStyle.clear.copyWith(
          cornerRadius: radius,
          tint: const Color(0x00000000),
          brightness: 0,
          saturation: 1,
        )
      : LiquidPrismStyle(
          refraction: 48,
          frost: regularFrost,
          brightness: 0,
          tint: const Color(0x00000000),
          saturation: 1,
          reflection: 0.08,
          cornerRadius: radius,
        );
  List<double> get uniforms => [
    kind,
    dark ? 1 : 0,
    role.shaderId,
    tintAlpha,
    ...tintMatrix,
    // Press progress, smooth contour flag, absence (1 - presence) and the tab
    // pill's glint. Absence keeps the zero default fully materialized.
    0, 0, 1 - presence, lensRim,
  ];

  /// `u_face`: white fill, inner ring opacity, two reserved zeros.
  List<double> get faceUniforms => [
    faceFill,
    kind == 0 ? 0 : NativeGlassShadow.ringOpacity * shadowStrength,
    0,
    0,
  ];
}

/// Extracted iOS 27 glassBackground shadow inputs. Kernel conversion belongs to
/// the renderer; these retain the native radius and separate color alpha.
final class NativeGlassShadow {
  const NativeGlassShadow(this.radius, this.opacity);
  final double radius;
  final double opacity;
  static const control = NativeGlassShadow(4, 0.03999999910593033);
  static const colorAlpha = 0.30000001192092896;
  static const offset = 8.0;
  static const ringWidth = 4.0;
  static const ringRadius = 5.0;
  static const ringOpacity = 0.05999999865889549;

  factory NativeGlassShadow.resolve(double extent, {required bool dark}) {
    final progress = ((extent - 64) / 96).clamp(0.0, 1.0);
    const smallOpacity = 0.03999999910593033;
    final largeOpacity = dark ? 0.6000000238418579 : 0.4000000059604645;
    return NativeGlassShadow(
      4 + 20 * progress,
      smallOpacity + (largeOpacity - smallOpacity) * progress,
    );
  }
}
