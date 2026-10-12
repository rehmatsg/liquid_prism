import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'glass.dart';
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
  });
  final double lift;
  final GlassRole role;
  final GlassShape shape;
  final Color restingColor;
  final bool restingShadow;
  final GlassLensStyle? style;

  @override
  Widget build(BuildContext context) {
    final progress = lift.clamp(0.0, 1.0);
    final appearance =
        (LiquidPrismTheme.of(context).lens ?? const GlassLensStyle()).merge(
          style,
        );
    final contour = appearance.shape ?? shape;
    final minify = appearance.minifyUnderlay ?? role != GlassRole.sliderLens;
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
        return CustomPaint(
          // Keep the shadow out of the lens's backdrop capture. Otherwise its
          // clipped mask can refract into a second capsule inside the lens.
          foregroundPainter: _LensShadow(
            progress,
            contour,
            restingShadow,
            appearance,
          ),
          child: LiquidPrism(
            glass: (appearance.glass ?? Glass.clear).interactive(false),
            role: materialRole,
            shape: contour,
            blur: appearance.blur ?? appearance.optics?.frost ?? 0,
            optics:
                appearance.optics ??
                LiquidPrismStyle(
                  edgeWidth: (12 * scale).clamp(.01, 64),
                  refraction: (9 * scale * progress).clamp(0, 64),
                  frost: 0,
                  dispersion: .3 * progress,
                  reflection: .04 * progress,
                  reflectionReach: (20 * scale).clamp(0, 80),
                  splay: .1,
                  light: .6 * progress,
                  saturation: 1,
                  brightness: 0,
                  tint: const Color(0x00000000),
                ),
            child: ColoredBox(
              color: restingColor.withValues(
                alpha: restingColor.a * (1 - progress),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LensShadow extends CustomPainter {
  const _LensShadow(this.progress, this.shape, this.restingShadow, this.style);
  final double progress;
  final GlassShape shape;
  final bool restingShadow;
  final GlassLensStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (style.shadow == false) return;
    final outline = shape.path(size);
    final scale = style.scaleShadows == false ? 1.0 : size.height / 37.2;
    final ambientReach =
        (style.shadowOffset ?? const Offset(0, 6)).distance +
        3 * (style.shadowBlur ?? 5);
    final ringReach =
        (style.ringOffset ?? const Offset(0, 4)).distance +
        3 * (style.ringBlur ?? 4) +
        (style.ringWidth ?? 2);
    final extent = math.max(40.0, math.max(ambientReach, ringReach)) * scale;
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(extent))
        ..addPath(outline, Offset.zero),
    );
    if (restingShadow && progress < 1) {
      canvas.drawPath(
        outline.shift(const Offset(0, 1)),
        Paint()
          ..color = const Color(0xFF000000)
              .withValues(alpha: .14 * (1 - progress))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10 / 3),
      );
    }
    if (progress > 0) {
      canvas.drawPath(
        outline.shift((style.shadowOffset ?? const Offset(0, 6)) * scale),
        Paint()
          ..color = const Color(0xFF000000)
              .withValues(alpha: (style.shadowOpacity ?? .1) * progress)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (style.shadowBlur ?? 5) * scale,
          ),
      );
      canvas.drawPath(
        outline.shift((style.ringOffset ?? const Offset(0, 4)) * scale),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (style.ringWidth ?? 2) * scale
          ..color = const Color(0xFF000000)
              .withValues(alpha: (style.ringOpacity ?? .055) * progress)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (style.ringBlur ?? 4) * scale,
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
