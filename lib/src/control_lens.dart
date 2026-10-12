import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'material.dart';
import 'recipe.dart';
import 'style.dart';

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
  });
  final double lift;
  final GlassRole role;
  final GlassShape shape;
  final Color restingColor;
  final bool restingShadow;

  @override
  Widget build(BuildContext context) {
    final progress = lift.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The accepted tab lens is the 70-point reference. Scale the optics
        // and shadow with the actual lens rather than reusing fixed kernels.
        final scale = constraints.maxHeight / 70;
        return CustomPaint(
          // Keep the shadow out of the lens's backdrop capture. Otherwise its
          // clipped mask can refract into a second capsule inside the lens.
          foregroundPainter: _LensShadow(progress, shape, restingShadow),
          child: LiquidPrism(
            glass: Glass.clear,
            role: role,
            shape: shape,
            blur: 0,
            optics: LiquidPrismStyle(
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
  const _LensShadow(this.progress, this.shape, this.restingShadow);
  final double progress;
  final GlassShape shape;
  final bool restingShadow;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = shape.path(size);
    final scale = size.height / 37.2;
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(40 * scale))
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
        outline.shift(Offset(0, 6 * scale)),
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: .1 * progress)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * scale),
      );
      canvas.drawPath(
        outline.shift(Offset(0, 4 * scale)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * scale
          ..color = const Color(0xFF000000).withValues(alpha: .055 * progress)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * scale),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LensShadow old) =>
      old.progress != progress ||
      old.shape != shape ||
      old.restingShadow != restingShadow;
}
