import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Spatial motion shared by glass buttons and navigation controls.
@immutable
class GlassMotion {
  const GlassMotion({
    this.response = const Duration(milliseconds: 280),
    this.bounce = 0.18,
    this.pressResponse = const Duration(milliseconds: 140),
    this.pressScale = 1.10,
    this.dragProjection = 0.12,
  }) : assert(bounce >= 0 && bounce < 1),
       assert(pressScale >= 1 && pressScale <= 1.2),
       assert(dragProjection >= 0 && dragProjection <= 0.3);
  final Duration response, pressResponse;
  final double bounce, pressScale, dragProjection;

  SpringDescription get spring => SpringDescription.withDurationAndBounce(
    duration: response,
    bounce: bounce,
  );
  SpringDescription get pressSpring => SpringDescription.withDurationAndBounce(
    duration: pressResponse,
    bounce: 0,
  );
}

/// Retargets from the displayed position with uninterrupted velocity.
@internal
void springGlass(
  AnimationController controller,
  double target,
  SpringDescription spring, {
  double? velocity,
  bool immediate = false,
}) {
  if (immediate) {
    controller.value = target;
  } else {
    unawaited(
      controller.animateWith(
        SpringSimulation(
          spring,
          controller.value,
          target,
          velocity ?? controller.velocity,
          snapToEnd: true,
        ),
      ),
    );
  }
}
