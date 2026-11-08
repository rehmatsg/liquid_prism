import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';

import 'motion.dart';

/// Finger-driven flex for small controls, independent of their
/// position spring. In particular, direct slider tracking has no spring velocity.
class ControlLensMotion {
  ControlLensMotion(this.onStretch, {this.settings});
  final GlassControlMotion Function()? settings;
  final void Function(double target, double impulse) onStretch;
  Duration? _lastTime;
  double _lastX = 0, _target = 0;
  Timer? _idle;
  double _speed = 0;

  static final spring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 444),
    bounce: .44,
  );

  void begin(PointerDownEvent event) {
    stop();
    _lastTime = event.timeStamp;
    _lastX = event.localPosition.dx;
  }

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

  void follow() {
    final motion = settings?.call() ?? const GlassControlMotion();
    _emit(
      ((motion.flexStrength ?? NativeMotion.stretchPerSpeed) * _speed / 57.35)
          .clamp(0.0, motion.maxStretch ?? .1),
    );
    _idle?.cancel();
    // No new samples means a stationary finger, even while the control remains
    // held. Preserve shape momentum as it settles back to its lifted bounds.
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

  void stop() {
    _idle?.cancel();
    _idle = null;
    _lastTime = null;
    _target = 0;
    _speed = 0;
  }
}
