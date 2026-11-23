import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';

import 'package:liquid_prism/src/core/prism_motion.dart';

/// Drives lens deformation from pointer velocity.
@internal
class ControlLensMotion {
  /// Creates velocity-driven lens deformation.
  new(this.onStretch, {this.settings});

  /// Reads current deformation settings.
  final PrismControlMotion Function()? settings;

  /// Receives deformation targets and velocity impulses.
  final void Function(double target, double impulse) onStretch;
  Duration? _lastTime;
  double _lastX = 0;
  double _target = 0;
  Timer? _idle;
  double _speed = 0;

  /// Native fallback spring for lens deformation.
  static final spring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 444),
    bounce: .44,
  );

  /// Starts velocity sampling for a contact.
  void begin(PointerDownEvent event) {
    stop();
    _lastTime = event.timeStamp;
    _lastX = event.localPosition.dx;
  }

  /// Samples velocity and follows it while active.
  void sample(PointerMoveEvent event, {required bool active}) {
    final previous = _lastTime;
    if (previous != null) {
      final seconds = (event.timeStamp - previous).inMicroseconds / 1000000;
      if (seconds > 0) {
        _speed = (event.localPosition.dx - _lastX).abs() / seconds;
      }
    }
    _lastTime = event.timeStamp;
    _lastX = event.localPosition.dx;
    if (active) follow();
  }

  /// Retargets deformation from the latest finger velocity.
  void follow() {
    final motion = settings?.call() ?? const PrismControlMotion();
    _emit(
      ((motion.flexStrength ?? NativeMotion.stretchPerSpeed) * _speed / 57.35)
          .clamp(0.0, motion.maxStretch ?? .1),
    );
    _idle?.cancel();
    _idle = Timer(
      motion.velocityDecay ?? const Duration(milliseconds: 120),
      () => _emit(0),
    );
  }

  void _emit(double target) {
    final response = settings?.call().flex?.description ?? spring;
    final impulse =
        (target - _target) * response.stiffness / response.mass * .032;
    _target = target;
    onStretch(target, impulse);
  }

  /// Cancels idle decay and clears velocity history.
  void stop() {
    _idle?.cancel();
    _idle = null;
    _lastTime = null;
    _target = 0;
    _speed = 0;
  }
}
