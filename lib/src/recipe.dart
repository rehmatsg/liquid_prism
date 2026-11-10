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
  static const amounts = <double>[0, .25, .5, .75, 1];

  /// Regular: blur fill lighten opacity (float32 inputs as captured).
  static const regularLighten = <double>[
    0.6749999523162842,
    0.7874999642372131,
    0.8999999761581421,
    0.8999999761581421,
    0.8999999761581421,
  ];

  /// Regular: blur fill normal opacity.
  static const regularNormal = <double>[0, .25, .5, .75, 1];

  /// Regular, light: alpha of the white face fill colour.
  static const regularFaceFill = <double>[0, .1, .2, .35, .5];

  /// Clear: blur radius (the face's own, light blur).
  static const clearBlurRadius = <double>[0, .375, .75, .75, .75];

  /// Clear: blur fill normal opacity (its radius is 8 only at tint 1).
  static const clearFillNormal = <double>[0, 0, 0, .5, 1];

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
    this.depthFade = false,
  ]) : fill = false;

  /// A blur fill: blended over the sharp backdrop inside the optical pass,
  /// which reads the blur from the backdrop's alpha
  /// (shaders/frost_fill.frag) rather than from a backdrop layer of its own.
  const FrostPass.fill(
    this.sigma, [
    this.opacity = 1,
    this.blendMode = BlendMode.srcOver,
  ]) : depthFade = false,
       fill = true;
  final double sigma;
  final double opacity;
  final BlendMode blendMode;

  /// Native regular base blur: its radius grows with the surface's size and
  /// halves from the deep face to the rim ([NativeGlassDepth]). [sigma] is the
  /// radius at full depth amount.
  final bool depthFade;
  final bool fill;

  /// Replaces the backdrop under the glass outright, as a plain frost does.
  bool get covers =>
      opacity >= 1 && blendMode == BlendMode.srcOver && !depthFade;

  /// This pass at [factor] of its strength. Every surface shares one fill
  /// blur, so a fill fades in by opacity and other passes by radius.
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

  /// Impeller's blur is a Gaussian cut off at sqrt(3) sigma. Fitted on device,
  /// it matches a true Gaussian of sigma s when given this multiple of s.
  static const engineSigmaScale = 1.16;

  /// Native blur radii are half the Gaussian sigma measured on device: the
  /// regular base (radius 5) and blur fill (radius 8).
  static const regularBaseSigma = 10 * engineSigmaScale;
  static const regularFillSigma = 16 * engineSigmaScale;

  /// Native regular composition and clear curve; explicit optics stay literal.
  ///
  /// Regular keeps the backdrop sharp under a blur fill that is blended twice:
  /// lighten (darken in dark appearance) at the captured directional opacity,
  /// then normally at the captured normal opacity. Large surfaces add the
  /// size-dependent base blur first.
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

  /// The blur the optical pass may assume of the face it reads: the last pass
  /// that replaces the backdrop outright, or none while sharp detail shows
  /// through.
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
    this.faceGray = 1,
    this.tintAmount = GlassTint.standard,
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

  /// Regular-glass face fill alpha, resolved from the device setting.
  final double faceFill;
  final double faceGray;
  final double tintAmount;

  GlassRecipe _copyWith({
    double? presence,
    double? lensRim,
    double? chromaticSplit,
    double? chromaticBand,
    double? underlay,
    double? faceFill,
    double? faceGray,
    double? tintAmount,
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
    faceGray ?? this.faceGray,
    tintAmount ?? this.tintAmount,
  );

  GlassRecipe withTint(double tint) => _copyWith(
    faceFill: dark
        ? math.max(tint - .5, 0)
        : GlassTint.sample(GlassTint.regularFaceFill, tint),
    faceGray: dark ? (tint - .5).abs() * .25 : 1,
    tintAmount: tint,
  );

  GlassRecipe withChromaticFringe(double split, double band) =>
      _copyWith(chromaticSplit: split, chromaticBand: band);

  GlassRecipe withUnderlay(double value) =>
      value == underlay ? this : _copyWith(underlay: value);

  GlassRecipe withPresence(double value) =>
      value == presence ? this : _copyWith(presence: value);

  GlassRecipe withLensRim(double value) =>
      value == lensRim ? this : _copyWith(lensRim: value);

  bool get usesNativeControlShadow => kind != 0 && role != GlassRole.surface;
  double get shadowStrength => presence * (kind == 3 ? 0 : 1);
  static GlassRecipe resolve(
    Glass glass,
    Brightness brightness,
    GlassRole role, {
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
        : nativeTintMatrices[(glass.variant == GlassVariant.clear, dark, rgb)];
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
    return GlassRecipe(
      kind,
      dark,
      role,
      matrix ?? fallback,
      disabledProminent
          ? (dark ? .3499999940395355 : .44999998807907104)
          : tint?.a ?? 0,
    );
  }

  /// Regular base blur as a Gaussian sigma (native radius 5).
  static const regularFrost = FrostPass.regularBaseSigma;
  static const blurFillFrost = 12.0;

  LiquidPrismStyle optics(double radius) => kind == 2
      ? LiquidPrismStyle.clear.copyWith(
          cornerRadius: radius,
          tint: const Color(0x00000000),
          brightness: 0,
          saturation: 1,
        )
      : LiquidPrismStyle(
          refraction: 48,
          dispersion: 0.2,
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

  /// `u_face`: face fill, inner ring opacity, SDR luma limit, fill gray.
  List<double> get faceUniforms => faceUniformsFor(64);

  /// `z` is the SDR luma limit in dark appearance and the size-dependent
  /// face contrast gain in light appearance.
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

/// Size-dependent iOS 27 glassBackground terms. Surfaces up to 64 points on
/// their shortest side have none; they grow linearly to 150 points.
abstract final class NativeGlassDepth {
  /// Native `inputBlurOpacity0` (the base blur's share of its radius) and
  /// dark `inputBleedOpacity`:
  /// 0 / .1333 / .3333 / .55 / .7167 at 64 / 80 / 104 / 130 / 150+ points.
  static double amount(double extent) =>
      ((math.min(extent, 150) - 64) / 120).clamp(0.0, 1.0);

  /// Native `inputBleedBlurRadius` is .35 of the extent; fitted Gaussian
  /// sigma per unit of that radius.
  static double bleedSigma(double extent) =>
      .35 *
      math.min(extent, 150) *
      bleedSigmaPerRadius *
      FrostPass.engineSigmaScale;
  static const bleedSigmaPerRadius = .9;

  /// How far apart the optical pass reads a fill of [fillSigma] to widen it
  /// to the bleed's blur: the radius of a ring with the missing variance.
  static double bleedRadius(double extent, double fillSigma) {
    final sigma = bleedSigma(extent);
    return math.sqrt(2 * math.max(sigma * sigma - fillSigma * fillSigma, 0));
  }

  /// Fitted share of [amount] at which dark glass lightens toward the bleed.
  /// The bleed's gain (1.6) and colours (.125 to .365) are in `bleedGlass`,
  /// shaders/glass_core.glsl.
  static const bleedBlend = .716;

  /// Share of a plain surface's lens (rim refraction and dispersion) at this
  /// shortest side. Measured on device against native: a 48-point surface
  /// does not bend its backdrop, and surfaces from 64 points bend it fully.
  static double lens(double extent) => ((extent - 48) / 16).clamp(0.0, 1.0);

  /// Fitted light-appearance face contrast gain per unit of [amount].
  static const lightGain = .087;
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
