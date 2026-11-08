import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'glass_transition.dart';
import 'material.dart';
import 'recipe.dart';
import 'style.dart';
import 'appearance.dart';
import 'theme.dart';

/// Shared optical treatment for every lifted selection/handle. The controls
/// retain their captured bounds and travel; material and elevation are common.
class ControlLens extends StatelessWidget {
  const ControlLens({
    super.key,
    required this.lift,
    required this.role,
    this.shape = GlassShape.capsule,
    this.restingColor = const Color(0x00000000),
    this.restingShadow = false,
    this.style,
    this.rim = 0,
  }) : assert(rim >= 0);
  final double lift;
  final GlassRole role;
  final GlassShape shape;
  final Color restingColor;
  final bool restingShadow;
  final GlassLensStyle? style;

  /// Fringe/glint multiplier at full lift; only the tab bar's pill sets it.
  /// It fades with [lift] like the lens's other optics.
  final double rim;

  @override
  Widget build(BuildContext context) {
    final progress = lift.clamp(0.0, 1.0);
    final appearance =
        (LiquidPrismTheme.of(context).lens ?? const GlassLensStyle()).merge(
          style,
        );
    final contour = appearance.shape ?? shape;
    final slider = role == GlassRole.sliderLens;
    final minify = appearance.minifyUnderlay ?? !slider;
    final materialRole = switch ((slider, minify)) {
      (true, true) => GlassRole.controlThumb,
      (true, false) => GlassRole.sliderLens,
      (false, true) => role,
      (false, false) => GlassRole.controlLensUnminified,
    };
    final shadow = switch ((slider, LiquidPrismTheme.brightnessOf(context))) {
      (false, _) => _sharedShadow,
      (true, Brightness.light) => _sliderShadowLight,
      (true, Brightness.dark) => _sliderShadow,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabScale = constraints.maxHeight / 70;
        // Custom rim inputs are expressed for the 37.2-point held small lens.
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
        final fill = ColoredBox(
          color: restingColor.withValues(
            alpha: restingColor.a * (1 - progress),
          ),
        );
        // At rest every optic is zero, so only the fill contributes.
        // Custom optics or frost, a presence fade or the tab glint keep it.
        final resting =
            progress == 0 &&
            rim == 0 &&
            appearance.optics == null &&
            (appearance.blur ?? 0) == 0 &&
            LiquidPrismPresence.maybeData(context) == null;
        return CustomPaint(
          // Keep the shadow out of the lens's backdrop capture. Otherwise its
          // clipped mask can refract into a second capsule inside the lens.
          foregroundPainter: _LensShadow(
            progress,
            contour,
            restingShadow,
            shadow.merge(appearance),
          ),
          child: LiquidPrism(
            glass: (appearance.glass ?? Glass.clear).interactive(false),
            resting: resting,
            role: materialRole,
            lensRim: rim * progress,
            chromaticSplit:
                (appearance.chromaticAberration ??
                    (role == GlassRole.segmentLens || role == GlassRole.tabLens
                        ? 3.5
                        : 0)) *
                progress *
                (role == GlassRole.tabLens ? rim : 1),
            chromaticBand: appearance.chromaticBand ?? 4.8,
            underlay: underlay,
            shape: contour,
            blur: appearance.blur ?? appearance.optics?.frost ?? 0,
            optics:
                appearance.optics ??
                LiquidPrismStyle(
                  edgeWidth: rimWidth.clamp(.01, 64),
                  refraction: (rimRefraction * progress).clamp(0, 64),
                  frost: 0,
                  dispersion: .3 * progress,
                  reflection: .04 * progress,
                  reflectionReach: (20 * tabScale).clamp(0, 80),
                  splay: .1,
                  light: light * progress,
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

/// Rim inputs in points at their reference lens height. The segment profile
/// is fitted to ContentLensing; see doc/native_controls_spec.md.
({double amount, double width, double height}) _nativeRim(GlassRole role) =>
    switch (role) {
      GlassRole.tabLens => (amount: 10.5, width: 7, height: 70),
      GlassRole.segmentLens => (amount: 8.8, width: 7.04, height: 44),
      GlassRole.sliderLens => (amount: 11.1, width: 6.66, height: 37.2),
      _ => (amount: 11.5, width: 6.9, height: 115 / 3),
    };

// Shadow opacities are renderer fits; geometry is in points at height 37.2.
const _sharedShadow = GlassLensStyle(
  heldContactShadow: false,
  shadowOpacity: .1,
  shadowBlur: 5,
  shadowOffset: Offset(0, 6),
  ringOpacity: .055,
  ringBlur: 4,
  ringWidth: 2,
  ringOffset: Offset(0, 4),
);

const _sliderShadow = GlassLensStyle(
  heldContactShadow: true,
  shadowOpacity: .12,
  shadowBlur: 5,
  shadowOffset: Offset(0, 6),
  ringOpacity: .2,
  ringBlur: 3,
  ringWidth: 4,
  ringOffset: Offset(0, 8),
);

const _sliderShadowLight = GlassLensStyle(
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
  const _LensShadow(this.progress, this.shape, this.restingShadow, this.style);
  final double progress;
  final GlassShape shape;
  final bool restingShadow;

  /// Fully resolved: component fallback merged with theme and local styles.
  final GlassLensStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (style.shadow == false) return;
    final outline = shape.path(size);
    final scale = style.scaleShadows == false ? 1.0 : size.height / 37.2;
    final ambientReach = style.shadowOffset!.distance + 3 * style.shadowBlur!;
    final ringReach =
        style.ringOffset!.distance + 3 * style.ringBlur! + style.ringWidth!;
    final extent = math.max(40.0, math.max(ambientReach, ringReach)) * scale;
    canvas.save();
    canvas.clipPath(
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
      canvas.drawPath(
        outline.shift(style.shadowOffset! * scale),
        Paint()
          ..color = const Color(0xFF000000)
              .withValues(alpha: style.shadowOpacity! * progress)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            style.shadowBlur! * scale,
          ),
      );
      canvas.drawPath(
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
