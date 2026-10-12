import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'control_lens.dart';
import 'material.dart';
import 'recipe.dart';
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
  static const switchHangTime = Duration(milliseconds: 220);
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
    this.minifyUnderlay = true,
    this.color,
  });
  final double lift;
  final bool small, restingShadow, minifyUnderlay;
  final Color? color;
  @override
  Widget build(BuildContext context) => ControlLens(
    lift: lift,
    role: !small
        ? GlassRole.segmentLens
        : minifyUnderlay
        ? GlassRole.controlThumb
        : GlassRole.sliderLens,
    restingColor: color ?? GlassColors.of(context).controlThumb,
    restingShadow: restingShadow,
  );
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
