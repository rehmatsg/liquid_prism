import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Spatial motion shared by glass buttons and navigation controls.
///
/// Defaults are the springs measured on iOS 27 system controls, expressed as
/// SwiftUI-style duration and bounce. [response] and [bounce] move the tab
/// pill between tabs; [pressResponse] and [pressBounce] grow a held control;
/// [releaseResponse] and [releaseBounce] let it go.
@immutable
class GlassMotion {
  const GlassMotion({
    this.response = const Duration(milliseconds: 380),
    this.bounce = 0.15,
    this.pressResponse = const Duration(milliseconds: 290),
    this.pressBounce = 0.35,
    this.releaseResponse = const Duration(milliseconds: 390),
    this.releaseBounce = 0.48,
    this.pressScale = 1.1126,
    this.dragProjection = 0.12,
  }) : assert(bounce >= 0 && bounce < 1),
       assert(pressBounce >= 0 && pressBounce < 1),
       assert(releaseBounce >= 0 && releaseBounce < 1),
       assert(pressScale >= 1 && pressScale <= 1.2),
       assert(dragProjection >= 0 && dragProjection <= 0.3);
  final Duration response, pressResponse, releaseResponse;
  final double bounce, pressBounce, releaseBounce, pressScale, dragProjection;

  /// Travel between tabs, and the settle after a tab selection.
  SpringDescription get spring => SpringDescription.withDurationAndBounce(
    duration: response,
    bounce: bounce,
  );

  /// Growth of a held control.
  SpringDescription get pressSpring => SpringDescription.withDurationAndBounce(
    duration: pressResponse,
    bounce: pressBounce,
  );

  /// Return of a released control.
  SpringDescription get releaseSpring =>
      SpringDescription.withDurationAndBounce(
        duration: releaseResponse,
        bounce: releaseBounce,
      );
}

/// Measured iOS 27 tab bar and button motion that is not user configurable.
///
/// Sources: `_research/motion_extraction/REPORT.md`. Springs are
/// (duration in seconds, bounce) in the SwiftUI sense.
@internal
abstract final class NativeMotion {
  /// Lens inset outside the resting pill while held, in logical pixels.
  static const lensInset = 8.0;

  /// Lens size growth on touch, and its drop on release.
  static final liftIn = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 250),
    bounce: 0.2,
  );
  static final liftOut = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 255),
    bounce: 0.03,
  );

  /// The whole bar content scales about its centre while held.
  static const barScale = 1.0516;
  static final barScaleIn = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 320),
    bounce: 0.38,
  );
  static final barScaleOut = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 350),
    bounce: 0.39,
  );

  /// Every tab's icon and label scale while held.
  static const itemScale = 1.16;
  static final itemScaleIn = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 255),
    bounce: 0.01,
  );
  static final itemScaleOut = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 250),
    bounce: 0,
  );

  /// Bar-wide glow: 0.845 opacity reached in ~0.13 s, decays with τ ≈ 0.13 s.
  static const glowOpacity = 0.845;
  static final glowIn = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 150),
    bounce: 0,
  );
  static final glowOut = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 300),
    bounce: 0,
  );

  /// A radial halo centred on the lens; on release it fades while growing.
  static const haloDiameter = 93.0;
  static const haloOpacity = 0.284;
  static const haloReleaseScale = 4.0;
  static const haloRelease = Duration(milliseconds: 500);

  /// The lens chases the finger through this spring during a drag.
  static final tracking = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 450),
    bounce: 0.4,
  );

  /// Stretch along the travel axis per logical pixel per second of lens speed,
  /// taken off the cross axis, filtered by a short bouncy spring so that a
  /// sudden stop bulges the pill the other way.
  static const stretchPerSpeed = 0.018;
  static const stretchLimit = 24.0;
  static final stretchFilter = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 120),
    bounce: 0.5,
  );

  /// Button glow: 0.945 within 0.1 s, decays over ~0.4 s after release.
  static const buttonGlowOpacity = 0.945;
  static final buttonGlowIn = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 120),
    bounce: 0,
  );
  static final buttonGlowOut = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 320),
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
