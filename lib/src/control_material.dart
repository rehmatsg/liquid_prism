import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'material.dart';
import 'recipe.dart';
import 'style.dart';
import 'theme.dart';

/// Direct layer/timing captures in doc/native_controls_spec.json.
abstract final class NativeControl {
  static const thumbWidth = 37.0, thumbHeight = 24.0;
  static const thumbHeldScale = 1.55;
  static SpringDescription spring(int milliseconds, double ratio) =>
      SpringDescription.withDurationAndBounce(
        duration: Duration(milliseconds: milliseconds),
        bounce: 1 - ratio,
      );
  static final switchTravel = spring(300, 1);
  static final sliderTravel = spring(400, .8);
  static final sliderTracking = spring(400, 1);
  static final smallLift = spring(270, .625);
  static final smallRelease = spring(500, .7);
  static final segmentTravel = spring(400, .85);
  static final segmentTracking = spring(200, .85);
  static final largeLift = spring(250, 1);
}

/// Native white resting fill dissolves into a live lens when held. Opacity is
/// applied to painted fills, never an ancestor saveLayer that isolates backdrop.
class ControlThumb extends StatelessWidget {
  const ControlThumb({
    super.key,
    required this.lift,
    this.small = true,
    this.restingShadow = false,
    this.color,
  });
  final double lift;
  final bool small, restingShadow;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final progress = lift.clamp(0.0, 1.0);
    final fill = color ?? GlassColors.of(context).controlThumb;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return CustomPaint(
          // Paint after the optical pass: a lens must not refract its own
          // exterior shadow mask into a second, sharply bounded capsule.
          foregroundPainter: _ControlShadow(
            progress,
            small: small,
            restingShadow: restingShadow,
          ),
          child: LiquidPrism(
            glass: Glass.clear,
            role: small ? GlassRole.controlThumb : GlassRole.segmentLens,
            shape: GlassShape.capsule,
            blur: 0,
            optics: LiquidPrismStyle(
              edgeWidth: height * (small ? .18 : .1),
              refraction: height * (small ? .3 : .15) * progress,
              frost: 0,
              dispersion: small ? 0 : .3 * progress,
              reflection: 0,
              light: .5 * progress,
              saturation: 1,
              brightness: 0,
              tint: const Color(0x00000000),
            ),
            // Let the lens clip own the fill contour as well as the optics;
            // avoid a second, independently specified border shape.
            child: ColoredBox(
              color: fill.withValues(alpha: fill.a * (1 - progress)),
            ),
          ),
        );
      },
    );
  }
}

/// Uses the same continuous capsule contour as control optics and shadows.
class ControlTrack extends StatelessWidget {
  const ControlTrack({super.key, required this.color, this.child});
  final Color color;
  final Widget? child;
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const GlassShapeClipper(GlassShape.capsule),
    child: ColoredBox(color: color, child: child),
  );
}

/// Captured layer and ring-shadow inputs; radius-to-sigma and the ring mask
/// approximate the native Core Animation kernels.
class _ControlShadow extends CustomPainter {
  const _ControlShadow(
    this.progress, {
    required this.small,
    required this.restingShadow,
  });
  final double progress;
  final bool small, restingShadow;
  @override
  void paint(Canvas canvas, Size size) {
    final outline = GlassShape.capsule.path(size);
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(40))
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
        outline.shift(const Offset(0, 7)),
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: .06 * progress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawPath(
        outline.shift(const Offset(0, 8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFF000000)
              .withValues(alpha: (small ? .18 : .07) * progress)
          // Core Animation's ring filter is not a solid stroked outline.
          // Spread our approximation to avoid a dense lower contour.
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ControlShadow old) =>
      old.progress != progress ||
      old.small != small ||
      old.restingShadow != restingShadow;
}

/// Disabled alpha without hiding the backdrop from the optical filter.
class ControlDisabled extends StatelessWidget {
  const ControlDisabled({
    super.key,
    required this.enabled,
    required this.child,
  });
  final bool enabled;
  final Widget child;
  @override
  Widget build(BuildContext context) => enabled
      ? child
      : ColorFiltered(
          colorFilter: const ui.ColorFilter.matrix([
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            .5,
            0,
          ]),
          child: child,
        );
}
