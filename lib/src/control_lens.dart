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
    final materialRole = minify
        ? (role == GlassRole.sliderLens ? GlassRole.controlThumb : role)
        : (role == GlassRole.sliderLens
              ? role
              : GlassRole.controlLensUnminified);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The accepted tab lens is the 70-point reference. Scale the optics
        // and shadow with the actual lens rather than reusing fixed kernels.
        final scale = constraints.maxHeight / 70;
        // Rim inputs are expressed for the 37.2-point held small lens.
        final small = constraints.maxHeight / 37.2;
        // The slider's held glassBackground: inner refraction height 6.66 and
        // amount 11.1, face black .1 (doc/native_controls_spec.json). Other
        // lenses keep their accepted, fitted rim until measured separately.
        final rimWidth = appearance.rimWidth == null
            ? (slider ? 6.66 * small : 12 * scale)
            : appearance.rimWidth! * small;
        final rimRefraction = appearance.rimRefraction == null
            ? (slider ? 11.1 * small : 9 * scale)
            : appearance.rimRefraction! * small;
        final light = appearance.rimLight ?? (slider ? _sliderRimLight : .6);
        final faceBlack = appearance.faceBlack ?? (slider ? .1 : 0.0);
        final fill = ColoredBox(
          color: restingColor.withValues(
            alpha: restingColor.a * (1 - progress),
          ),
        );
        // At rest every optic is scaled to zero and the fill covers the lens,
        // so the glass would only cost a full-screen backdrop pass per thumb.
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
            (slider ? _sliderShadow : _sharedShadow).merge(appearance),
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
                  reflectionReach: (20 * scale).clamp(0, 80),
                  splay: .1,
                  light: light * progress,
                  saturation: 1,
                  brightness: 0,
                  // Mixing toward white by b equals a face color matrix with
                  // black b and white 1: b + (1 - b) * color.
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

/// Fitted key/fill strength of the held slider rim; see doc/motion_and_lenses.md.
const _sliderRimLight = 1.0;

/// Shared lifted-shadow fallbacks: renderer calibrations of the native layer
/// and ring shadows, not recovered kernels.
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

/// The held slider keeps its measured contact shadow (.14, radius 5, offset
/// 1) and uses the measured ring geometry (width 4, radius 3, offset 8). The
/// ring and ambient opacities are fitted to the native dark capture.
const _sliderShadow = GlassLensStyle(
  heldContactShadow: true,
  shadowOpacity: _sliderAmbient,
  shadowBlur: 5,
  shadowOffset: Offset(0, 6),
  ringOpacity: _sliderRing,
  ringBlur: 3,
  ringWidth: 4,
  ringOffset: Offset(0, 8),
);
const _sliderAmbient = .12, _sliderRing = .2;

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
