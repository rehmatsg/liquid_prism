import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_lens_style.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';
import 'package:liquid_prism/src/rendering/prism_transition.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Shared resting and lifted optical treatment for control handles.
@internal
class ControlLens extends StatelessWidget {
  /// Creates the shared control lens material.
  const new({
    super.key,
    required this.lift,
    required this.role,
    this.shape = PrismShape.capsule,
    this.restingColor = const Color(0x00000000),
    this.restingShadow = false,
    this.style,
    this.rim = 0,
  }) : assert(rim >= 0, 'Rim must be non-negative.');

  /// Normalized lift progress.
  final double lift;

  /// Explicit renderer role for the lens.
  final PrismRole role;

  /// Fallback lens contour.
  final PrismShape shape;

  /// Fill that dissolves as the lens lifts.
  final Color restingColor;

  /// Whether to retain a contact shadow at rest.
  final bool restingShadow;

  /// Lens overrides merged over the shared theme.
  final PrismLensStyle? style;

  /// Full-lift glint multiplier used by tab selection lenses.
  final double rim;

  @override
  Widget build(BuildContext context) {
    final progress = lift.clamp(0.0, 1.0);
    final appearance = (PrismTheme.of(context).lens ?? const PrismLensStyle())
        .merge(style);
    final contour = appearance.shape ?? shape;
    final slider = role == PrismRole.sliderLens;
    final minify = appearance.minifyUnderlay ?? !slider;
    final materialRole = switch ((slider, minify)) {
      (true, true) => PrismRole.controlThumb,
      (true, false) => PrismRole.sliderLens,
      (false, true) => role,
      (false, false) => PrismRole.controlLensUnminified,
    };
    final shadow = switch ((slider, PrismTheme.brightnessOf(context))) {
      (false, _) => _sharedShadow,
      (true, Brightness.light) => _sliderShadowLight,
      (true, Brightness.dark) => _sliderShadow,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabScale = constraints.maxHeight / 70;
        final smallLensScale = constraints.maxHeight / 37.2;
        final captured = _nativeRim(role);
        final nativeScale = constraints.maxHeight / captured.height;
        final rimWidth = appearance.rimWidth == null
            ? captured.width * nativeScale
            : appearance.rimWidth! * smallLensScale;
        final rimRefraction = appearance.rimRefraction == null
            ? captured.amount * nativeScale
            : appearance.rimRefraction! * smallLensScale;
        final underlay = minify
            ? (appearance.optics?.refraction ?? 9 * progress)
            : 0.0;
        final light = appearance.rimLight ?? (slider ? 1.0 : .6);
        final faceBlack = appearance.faceBlack ?? (slider ? .1 : 0.0);
        final rimLift = (progress / 0.55).clamp(0.0, 1.0);
        final fillFade = ((progress - 0.15) / 0.45).clamp(0.0, 1.0);
        final fill = ColoredBox(
          color: restingColor.withValues(
            alpha:
                restingColor.a * (1 - fillFade * fillFade * (3 - 2 * fillFade)),
          ),
        );
        final resting =
            progress == 0 &&
            rim == 0 &&
            appearance.optics == null &&
            (appearance.blur ?? 0) == 0 &&
            PrismPresence.maybeData(context) == null;
        return CustomPaint(
          foregroundPainter: _LensShadow(
            progress,
            contour,
            restingShadow,
            shadow.merge(appearance),
          ),
          child: RawPrismSurface(
            glass: (appearance.glass ?? PrismGlass.clear).interactive(false),
            resting: resting,
            role: materialRole,
            lensRim: rim * progress,
            chromaticSplit:
                (appearance.chromaticAberration ??
                    (role == PrismRole.segmentLens || role == PrismRole.tabLens
                        ? 3.5
                        : 0)) *
                progress *
                (role == PrismRole.tabLens ? rim : 1),
            chromaticBand: appearance.chromaticBand ?? 4.8,
            underlay: underlay,
            shape: contour,
            blur: appearance.blur ?? appearance.optics?.frost ?? 0,
            optics:
                appearance.optics ??
                PrismOptics(
                  edgeWidth: rimWidth.clamp(.01, 64),
                  refraction: (rimRefraction * rimLift).clamp(0, 64),
                  frost: 0,
                  dispersion: .3 * progress,
                  reflection: .04 * progress,
                  reflectionReach: (20 * tabScale).clamp(0, 80),
                  splay: .1,
                  light: light * rimLift,
                  saturation: 1,
                  brightness: 0,
                  tint: const Color(0xFFFFFFFF)
                      .withValues(alpha: (faceBlack * progress).clamp(0, 1)),
                ),
            child: fill,
          ),
        );
      },
    );
  }
}

({double amount, double width, double height}) _nativeRim(PrismRole role) =>
    switch (role) {
      PrismRole.tabLens => (amount: 10.5, width: 7, height: 70),
      PrismRole.segmentLens => (amount: 8.8, width: 7.04, height: 44),
      PrismRole.sliderLens => (amount: 11.1, width: 6.66, height: 37.2),
      _ => (amount: 11.5, width: 6.9, height: 115 / 3),
    };

const _sharedShadow = PrismLensStyle(
  heldContactShadow: false,
  shadowOpacity: .1,
  shadowBlur: 5,
  shadowOffset: Offset(0, 6),
  ringOpacity: .055,
  ringBlur: 4,
  ringWidth: 2,
  ringOffset: Offset(0, 4),
);

const _sliderShadow = PrismLensStyle(
  heldContactShadow: true,
  shadowOpacity: .12,
  shadowBlur: 5,
  shadowOffset: Offset(0, 6),
  ringOpacity: .2,
  ringBlur: 3,
  ringWidth: 4,
  ringOffset: Offset(0, 8),
);

const _sliderShadowLight = PrismLensStyle(
  heldContactShadow: false,
  shadowOpacity: .045,
  shadowBlur: 3,
  shadowOffset: Offset(0, 7),
  ringOpacity: .09,
  ringBlur: 3,
  ringWidth: 4,
  ringOffset: Offset(0, 8),
);

class _LensShadow extends CustomPainter {
  const new(this.progress, this.shape, this.restingShadow, this.style);
  final double progress;
  final PrismShape shape;
  final bool restingShadow;

  final PrismLensStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (style.shadow == false) return;
    final outline = shape.path(size);
    final scale = style.scaleShadows == false ? 1.0 : size.height / 37.2;
    final ambientReach = style.shadowOffset!.distance + 3 * style.shadowBlur!;
    final ringReach =
        style.ringOffset!.distance + 3 * style.ringBlur! + style.ringWidth!;
    final extent = math.max(40, math.max(ambientReach, ringReach)) * scale;
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect((Offset.zero & size).inflate(extent))
          ..addPath(outline, Offset.zero),
      );
    final contact =
        (restingShadow ? 1 - progress : 0.0) +
        (style.heldContactShadow! ? progress : 0.0);
    if (contact > 0) {
      canvas.drawPath(
        outline.shift(const Offset(0, 1)),
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: .14 * contact)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10 / 3),
      );
    }
    if (progress > 0) {
      canvas
        ..drawPath(
          outline.shift(style.shadowOffset! * scale),
          Paint()
            ..color = const Color(0xFF000000)
                .withValues(alpha: style.shadowOpacity! * progress)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              style.shadowBlur! * scale,
            ),
        )
        ..drawPath(
          outline.shift(style.ringOffset! * scale),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.ringWidth! * scale
            ..color = const Color(0xFF000000)
                .withValues(alpha: style.ringOpacity! * progress)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              style.ringBlur! * scale,
            ),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LensShadow old) =>
      old.progress != progress ||
      old.shape != shape ||
      old.restingShadow != restingShadow ||
      old.style != style;
}
