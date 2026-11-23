import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/prism_glass.dart';
import '../core/prism_optics.dart';
import '../theme/native_colors.dart';

/// Stable role identifiers consumed by the optical shaders.
@internal
enum PrismRole {
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

  const PrismRole(this.shaderId);

  /// Explicit role value in the shader ABI.
  final double shaderId;
}

@internal
abstract final class GlassTint {
  static const double standard = 0.5;

  static const List<double> amounts = <double>[0, .25, .5, .75, 1];

  static const List<double> regularLighten = <double>[
    0.6749999523162842,
    0.7874999642372131,
    0.8999999761581421,
    0.8999999761581421,
    0.8999999761581421,
  ];

  static const List<double> regularNormal = <double>[0, .25, .5, .75, 1];

  static const List<double> regularFaceFill = <double>[0, .1, .2, .35, .5];

  static const List<double> clearBlurRadius = <double>[0, .375, .75, .75, .75];

  static const List<double> clearFillNormal = <double>[0, 0, 0, .5, 1];

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

  static double resolve(double? theme, double? device) =>
      (theme ?? device ?? standard).clamp(0.0, 1.0);
}

@immutable
@internal
final class FrostPass {
  const FrostPass(
    this.sigma, [
    this.opacity = 1,
    this.blendMode = BlendMode.srcOver,
    this.depthFade = false,
  ]) : fill = false;

  const FrostPass.fill(
    this.sigma, [
    this.opacity = 1,
    this.blendMode = BlendMode.srcOver,
  ]) : depthFade = false,
       fill = true;
  final double sigma;
  final double opacity;
  final BlendMode blendMode;

  final bool depthFade;
  final bool fill;

  bool get covers =>
      opacity >= 1 && blendMode == BlendMode.srcOver && !depthFade;

  FrostPass scaled(double factor) => fill
      ? FrostPass.fill(sigma, opacity * factor, blendMode)
      : FrostPass(sigma * factor, opacity, blendMode, depthFade);

  @override
  bool operator ==(Object other) =>
      other is FrostPass &&
      other.sigma == sigma &&
      other.opacity == opacity &&
      other.blendMode == blendMode &&
      other.depthFade == depthFade &&
      other.fill == fill;

  @override
  int get hashCode => Object.hash(sigma, opacity, blendMode, depthFade, fill);

  @override
  String toString() =>
      'FrostPass${fill ? '.fill' : ''}($sigma, $opacity, ${blendMode.name}'
      '${depthFade ? ', depth' : ''})';

  static const double engineSigmaScale = 1.16;

  static const double regularBaseSigma = 10 * engineSigmaScale;
  static const double regularFillSigma = 16 * engineSigmaScale;

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
      if (frost <= .05) return const [];
      final fill = frost * regularFillSigma / regularBaseSigma;
      final normal = GlassTint.sample(GlassTint.regularNormal, tint);
      if (normal >= 1) return [FrostPass.fill(fill)];
      return [
        FrostPass(frost, 1, BlendMode.srcOver, true),
        FrostPass.fill(
          fill,
          GlassTint.sample(GlassTint.regularLighten, tint),
          dark ? BlendMode.darken : BlendMode.lighten,
        ),
        if (normal > 0) FrostPass.fill(fill, normal),
      ];
    }
    final radius = GlassTint.sample(GlassTint.clearBlurRadius, tint);
    final base =
        frost *
        radius /
        GlassTint.sample(GlassTint.clearBlurRadius, GlassTint.standard);
    final fill = GlassTint.sample(GlassTint.clearFillNormal, tint);
    if (fill >= 1 && fillFrost > 0.05) return [FrostPass.fill(fillFrost)];
    return [
      if (base > 0.05) FrostPass(base),
      if (fill > 0 && fillFrost > 0.05) FrostPass.fill(fillFrost, fill),
    ];
  }

  static double effectiveSigma(List<FrostPass> passes) {
    var sigma = 0.0;
    for (final pass in passes) {
      if (pass.covers) {
        sigma = pass.sigma;
      } else if (pass.blendMode == BlendMode.srcOver && !pass.depthFade) {
        sigma = math.min(sigma, pass.sigma);
      }
    }
    return passes.any((p) => p.covers) ? sigma : 0;
  }
}

/// Resolved material inputs and shader state for one surface.
@immutable
@internal
final class PrismRecipe {
  const PrismRecipe(
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
    this.faceGray = 1,
    this.tintAmount = GlassTint.standard,
    this.shadow = true,
  ]);
  final double kind;
  final bool dark;
  final PrismRole role;

  final List<double> tintMatrix;
  final double tintAlpha;

  final double presence;

  final double lensRim;

  final double chromaticSplit;

  final double chromaticBand;

  final double underlay;

  final double faceFill;
  final double faceGray;
  final double tintAmount;
  final bool shadow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismRecipe &&
          other.kind == kind &&
          other.dark == dark &&
          other.role == role &&
          other.tintAlpha == tintAlpha &&
          other.presence == presence &&
          other.lensRim == lensRim &&
          other.chromaticSplit == chromaticSplit &&
          other.chromaticBand == chromaticBand &&
          other.underlay == underlay &&
          other.faceFill == faceFill &&
          other.faceGray == faceGray &&
          other.tintAmount == tintAmount &&
          other.shadow == shadow &&
          listEquals(other.tintMatrix, tintMatrix);

  @override
  int get hashCode => Object.hash(
    kind,
    dark,
    role,
    tintAlpha,
    presence,
    lensRim,
    chromaticSplit,
    chromaticBand,
    underlay,
    faceFill,
    faceGray,
    tintAmount,
    shadow,
    Object.hashAll(tintMatrix),
  );

  PrismRecipe _copyWith({
    double? presence,
    double? lensRim,
    double? chromaticSplit,
    double? chromaticBand,
    double? underlay,
    double? faceFill,
    double? faceGray,
    double? tintAmount,
    bool? shadow,
  }) => PrismRecipe(
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
    faceGray ?? this.faceGray,
    tintAmount ?? this.tintAmount,
    shadow ?? this.shadow,
  );

  PrismRecipe withTint(double tint) => _copyWith(
    faceFill: dark
        ? math.max(tint - .5, 0)
        : GlassTint.sample(GlassTint.regularFaceFill, tint),
    faceGray: dark ? (tint - .5).abs() * .25 : 1,
    tintAmount: tint,
  );

  PrismRecipe withChromaticFringe(double split, double band) =>
      _copyWith(chromaticSplit: split, chromaticBand: band);

  PrismRecipe withUnderlay(double value) =>
      value == underlay ? this : _copyWith(underlay: value);

  PrismRecipe withPresence(double value) =>
      value == presence ? this : _copyWith(presence: value);

  PrismRecipe withLensRim(double value) =>
      value == lensRim ? this : _copyWith(lensRim: value);
  PrismRecipe withShadow(bool value) =>
      value == shadow ? this : _copyWith(shadow: value);

  bool get usesNativeControlShadow => kind != 0 && role != PrismRole.surface;
  double get shadowStrength =>
      presence *
      (shadow && kind != 3 && !(kind == 2 && role == PrismRole.surface)
          ? 1
          : 0);
  static PrismRecipe resolve(
    PrismGlass glass,
    Brightness brightness,
    PrismRole role, {
    required bool customOptics,
    bool disabledProminent = false,
  }) {
    final dark = brightness == Brightness.dark;
    final tint = glass.tintColor;
    final rgb = tint == null ? 0 : tint.toARGB32() & 0xFFFFFF;
    final disabledScale = dark ? .3086487948894501 : .30867475271224976;
    final disabledBias = dark ? .31474554538726807 : .285163551568985;
    final matrix = disabledProminent
        ? <double>[
            disabledScale,
            0,
            0,
            disabledBias,
            0,
            disabledScale,
            0,
            disabledBias,
            0,
            0,
            disabledScale,
            disabledBias,
          ]
        : nativeTintMatrices[(
            glass.variant == PrismGlassVariant.clear,
            dark,
            rgb,
          )];
    final fallback = <double>[
      for (final component in [tint?.r ?? 0, tint?.g ?? 0, tint?.b ?? 0]) ...[
        0.12 * (1 - component) * 0.2126,
        0.12 * (1 - component) * 0.7152,
        0.12 * (1 - component) * 0.0722,
        component * 0.94,
      ],
    ];
    final materialKind = glass.variant == PrismGlassVariant.clear ? 2.0 : 1.0;
    final kind = switch (role) {
      PrismRole.toolbar || PrismRole.searchField => materialKind,
      PrismRole.controlThumb ||
      PrismRole.segmentLens ||
      PrismRole.tabLens ||
      PrismRole.sliderLens ||
      PrismRole.controlLensUnminified => 3.0,
      _ => customOptics ? 0.0 : materialKind,
    };
    return PrismRecipe(
      kind,
      dark,
      role,
      matrix ?? fallback,
      disabledProminent
          ? (dark ? .3499999940395355 : .44999998807907104)
          : tint?.a ?? 0,
    );
  }

  static const double regularFrost = FrostPass.regularBaseSigma;
  static const double blurFillFrost = 12.0;

  PrismOptics optics(double radius) => kind == 2
      ? PrismOptics.clear.copyWith(
          cornerRadius: radius,
          tint: const Color(0x00000000),
          brightness: 0,
          saturation: 1,

          reflection: 0,
        )
      : PrismOptics(
          refraction: 48,
          frost: regularFrost,
          brightness: 0,
          tint: const Color(0x00000000),
          saturation: 1,

          reflection: 0,
          cornerRadius: radius,
        );
  List<double> get uniforms => [
    kind,
    dark ? 1 : 0,
    role.shaderId,
    tintAlpha,
    ...tintMatrix,

    0,
    0,
    1 - presence,
    lensRim,
  ];

  List<double> get faceUniforms => faceUniformsFor(64);

  List<double> faceUniformsFor(double extent) {
    final size = ((extent - 64) / 40).clamp(0.0, 1.0);
    final limit = dark
        ? .6 - .25 * size + .2 * size * math.max(.5 - tintAmount, 0)
        : 1 + NativeGlassDepth.lightGain * NativeGlassDepth.amount(extent);
    return [
      faceFill,
      kind == 0 ? 0 : NativeGlassShadow.ringOpacity * shadowStrength,
      limit,
      faceGray,
    ];
  }
}

@internal
abstract final class NativeGlassDepth {
  static double amount(double extent) =>
      ((math.min(extent, 150) - 64) / 120).clamp(0.0, 1.0);

  static double bleedSigma(double extent) =>
      .35 *
      math.min(extent, 150) *
      bleedSigmaPerRadius *
      FrostPass.engineSigmaScale;
  static const double bleedSigmaPerRadius = .9;

  static double bleedRadius(double extent, double fillSigma) {
    final sigma = bleedSigma(extent);
    return math.sqrt(2 * math.max(sigma * sigma - fillSigma * fillSigma, 0));
  }

  static const double bleedBlend = .716;

  static double lens(double extent) => ((extent - 10) / 6).clamp(0.0, 1.0);

  static const double lightGain = .087;
}

@immutable
@internal
final class NativeGlassShadow {
  const NativeGlassShadow(this.radius, this.opacity);
  final double radius;
  final double opacity;
  static const NativeGlassShadow control = NativeGlassShadow(
    4,
    0.03999999910593033,
  );
  static const double colorAlpha = 0.30000001192092896;
  static const double offset = 8.0;
  static const double ringWidth = 4.0;
  static const double ringRadius = 5.0;
  static const double ringOpacity = 0.05999999865889549;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeGlassShadow &&
          other.radius == radius &&
          other.opacity == opacity;

  @override
  int get hashCode => Object.hash(radius, opacity);

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
