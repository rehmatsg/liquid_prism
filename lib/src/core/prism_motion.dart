import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Reusable spring expressed as response duration and bounce.
@immutable
class PrismSpring {
  /// Creates a spring with [response] duration and [bounce] factor.
  const PrismSpring({
    this.response = const Duration(milliseconds: 400),
    this.bounce = .15,
  }) : physics = null,
       assert(bounce >= 0 && bounce < 1);

  /// Creates a spring from explicit physical [physics] parameters.
  const PrismSpring.physical(SpringDescription this.physics)
    : response = const Duration(milliseconds: 400),
      bounce = .15;

  /// Explicit physical spring description, if constructed with [PrismSpring.physical].
  final SpringDescription? physics;

  /// Nominal response duration.
  final Duration response;

  /// Bounce factor in `[0, 1)`.
  final double bounce;

  /// Resolved Flutter [SpringDescription].
  SpringDescription get description =>
      physics ??
      SpringDescription.withDurationAndBounce(
        duration: response,
        bounce: bounce,
      );

  /// Returns a copy with specified fields replaced.
  PrismSpring copyWith({Duration? response, double? bounce}) =>
      response == null && bounce == null
      ? this
      : PrismSpring(
          response: response ?? this.response,
          bounce: bounce ?? this.bounce,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismSpring &&
          other.response == response &&
          other.bounce == bounce &&
          other.physics?.mass == physics?.mass &&
          other.physics?.stiffness == physics?.stiffness &&
          other.physics?.damping == physics?.damping;

  @override
  int get hashCode => Object.hash(
    response,
    bounce,
    physics?.mass,
    physics?.stiffness,
    physics?.damping,
  );
}

/// Partial motion overrides for switches, sliders, and segmented controls.
@immutable
class PrismControlMotion {
  /// Creates a partial control motion configuration.
  const PrismControlMotion({
    this.travel,
    this.tracking,
    this.lift,
    this.release,
    this.flex,
    this.minimumLiftDuration,
    this.flexStrength,
    this.maxStretch,
    this.velocityDecay,
  }) : assert(flexStrength == null || flexStrength >= 0),
       assert(maxStretch == null || (maxStretch >= 0 && maxStretch < 1));

  /// Spring driving committed value travel.
  final PrismSpring? travel;

  /// Spring driving live drag tracking.
  final PrismSpring? tracking;

  /// Spring driving lens lift on contact.
  final PrismSpring? lift;

  /// Spring driving lens settle on release.
  final PrismSpring? release;

  /// Spring filtering velocity-driven deformation.
  final PrismSpring? flex;

  /// Minimum duration a tapped control remains lifted.
  final Duration? minimumLiftDuration;

  /// Decay duration for drag velocity sampling.
  final Duration? velocityDecay;

  /// Velocity-to-stretch factor in logical pixels per second.
  final double? flexStrength;

  /// Maximum fractional axis deformation.
  final double? maxStretch;

  /// Returns a copy with specified fields replaced.
  PrismControlMotion copyWith({
    PrismSpring? travel,
    PrismSpring? tracking,
    PrismSpring? lift,
    PrismSpring? release,
    PrismSpring? flex,
    Duration? minimumLiftDuration,
    double? flexStrength,
    double? maxStretch,
    Duration? velocityDecay,
  }) => PrismControlMotion(
    travel: travel ?? this.travel,
    tracking: tracking ?? this.tracking,
    lift: lift ?? this.lift,
    release: release ?? this.release,
    flex: flex ?? this.flex,
    minimumLiftDuration: minimumLiftDuration ?? this.minimumLiftDuration,
    flexStrength: flexStrength ?? this.flexStrength,
    maxStretch: maxStretch ?? this.maxStretch,
    velocityDecay: velocityDecay ?? this.velocityDecay,
  );

  /// Merges non-null fields from [other] over this motion.
  PrismControlMotion merge(PrismControlMotion? other) => other == null
      ? this
      : copyWith(
          travel: other.travel,
          tracking: other.tracking,
          lift: other.lift,
          release: other.release,
          flex: other.flex,
          minimumLiftDuration: other.minimumLiftDuration,
          flexStrength: other.flexStrength,
          maxStretch: other.maxStretch,
          velocityDecay: other.velocityDecay,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismControlMotion &&
          other.travel == travel &&
          other.tracking == tracking &&
          other.lift == lift &&
          other.release == release &&
          other.flex == flex &&
          other.minimumLiftDuration == minimumLiftDuration &&
          other.flexStrength == flexStrength &&
          other.maxStretch == maxStretch &&
          other.velocityDecay == velocityDecay;

  @override
  int get hashCode => Object.hash(
    travel,
    tracking,
    lift,
    release,
    flex,
    minimumLiftDuration,
    flexStrength,
    maxStretch,
    velocityDecay,
  );
}

/// Spatial spring motion shared by glass buttons and navigation controls.
@immutable
class PrismMotion {
  /// Creates a motion configuration with duration and bounce springs.
  const PrismMotion({
    this.response = const Duration(milliseconds: 400),
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

  /// Selection travel spring response duration.
  final Duration response;

  /// Press expansion spring response duration.
  final Duration pressResponse;

  /// Release settle spring response duration.
  final Duration releaseResponse;

  /// Selection travel spring bounce.
  final double bounce;

  /// Press expansion spring bounce.
  final double pressBounce;

  /// Release settle spring bounce.
  final double releaseBounce;

  /// Scale factor applied while a control is pressed.
  final double pressScale;

  /// Velocity projection horizon in seconds for drag release.
  final double dragProjection;

  /// Returns a copy with specified fields replaced.
  PrismMotion copyWith({
    Duration? response,
    double? bounce,
    Duration? pressResponse,
    double? pressBounce,
    Duration? releaseResponse,
    double? releaseBounce,
    double? pressScale,
    double? dragProjection,
  }) => PrismMotion(
    response: response ?? this.response,
    bounce: bounce ?? this.bounce,
    pressResponse: pressResponse ?? this.pressResponse,
    pressBounce: pressBounce ?? this.pressBounce,
    releaseResponse: releaseResponse ?? this.releaseResponse,
    releaseBounce: releaseBounce ?? this.releaseBounce,
    pressScale: pressScale ?? this.pressScale,
    dragProjection: dragProjection ?? this.dragProjection,
  );

  /// Spring description for selection travel.
  SpringDescription get spring => SpringDescription.withDurationAndBounce(
    duration: response,
    bounce: bounce,
  );

  /// Spring description for press growth.
  SpringDescription get pressSpring => SpringDescription.withDurationAndBounce(
    duration: pressResponse,
    bounce: pressBounce,
  );

  /// Spring description for release return.
  SpringDescription get releaseSpring =>
      SpringDescription.withDurationAndBounce(
        duration: releaseResponse,
        bounce: releaseBounce,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismMotion &&
          other.response == response &&
          other.bounce == bounce &&
          other.pressResponse == pressResponse &&
          other.pressBounce == pressBounce &&
          other.releaseResponse == releaseResponse &&
          other.releaseBounce == releaseBounce &&
          other.pressScale == pressScale &&
          other.dragProjection == dragProjection;

  @override
  int get hashCode => Object.hash(
    response,
    bounce,
    pressResponse,
    pressBounce,
    releaseResponse,
    releaseBounce,
    pressScale,
    dragProjection,
  );
}

@internal
abstract final class NativeMotion {
  static const double lensInset = 8.0;
  static const double heldSelectedScale = 1.16;
  static final SpringDescription liftIn =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 250),
        bounce: 0,
      );
  static final SpringDescription liftOut =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 250),
        bounce: 0,
      );
  static const double barExpansion = 14.1379310344828;
  static final SpringDescription barScaleIn =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 320),
        bounce: 0.38,
      );
  static final SpringDescription barScaleOut =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 350),
        bounce: 0.39,
      );
  static const double glowOpacity = 0.845;
  static final SpringDescription glowIn =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 150),
        bounce: 0,
      );
  static final SpringDescription glowOut =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 520),
        bounce: 0,
      );
  static const double haloDiameter = 93.0;
  static const double haloBlurRadius = 46.5;
  static const double haloOpacity = 0.284;
  static const double haloReleaseScale = 4.0;
  static const Duration haloRelease = Duration(milliseconds: 500);
  static final SpringDescription tracking =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 450),
        bounce: 0.4,
      );
  static const double stretchPerSpeed = 0.018;
  static const double stretchLimit = 24.0;
  static final SpringDescription stretchFilter =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 330),
        bounce: 0.72,
      );
  static const Duration lensDwell = Duration(milliseconds: 220);
  static const double buttonGlowOpacity = 0.945;
  static final SpringDescription buttonGlowIn =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 120),
        bounce: 0,
      );
  static final SpringDescription buttonGlowOut =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 320),
        bounce: 0,
      );
}

@internal
abstract final class PrismSettle {
  static const double pixel = 0.25;
  static const double channel = 0.5 / 255;

  static double? precision({
    double pixelsPerUnit = 0,
    double alphaPerUnit = 0,
  }) {
    double? result;
    if (pixelsPerUnit > 0 && pixelsPerUnit.isFinite) {
      result = pixel / pixelsPerUnit;
    }
    if (alphaPerUnit > 0 && alphaPerUnit.isFinite) {
      final alpha = channel / alphaPerUnit;
      result = result == null ? alpha : math.min(result, alpha);
    }
    return result;
  }

  static Tolerance tolerance(SpringDescription spring, double precision) {
    final omega = math.sqrt(spring.stiffness / spring.mass);
    final distance = precision / math.sqrt2;
    return Tolerance(distance: distance, velocity: distance * omega);
  }
}

SpringSimulation _prismSimulation(
  SpringDescription spring,
  double start,
  double end,
  double velocity,
  double? precision,
) => SpringSimulation(
  spring,
  start,
  end,
  velocity,
  snapToEnd: true,
  tolerance: precision == null
      ? Tolerance.defaultTolerance
      : PrismSettle.tolerance(spring, precision),
);

@internal
void springPrism(
  AnimationController controller,
  double target,
  SpringDescription spring, {
  double? velocity,
  bool immediate = false,
  double? precision,
  Duration delay = Duration.zero,
}) {
  if (immediate) {
    controller.value = target;
  } else if (controller is RetargetablePrismSpring) {
    controller.retarget(
      target,
      spring,
      velocity: velocity,
      precision: precision,
      delay: delay,
    );
  } else {
    unawaited(
      controller.animateWith(
        _delaySpring(
          _prismSimulation(
            spring,
            controller.value,
            target,
            velocity ?? controller.velocity,
            precision,
          ),
          controller.isAnimating ? Duration.zero : delay,
        ),
      ),
    );
  }
}

Simulation _delaySpring(SpringSimulation spring, Duration delay) =>
    delay == Duration.zero ? spring : _DelayedSpring(spring, delay);

class _DelayedSpring extends Simulation {
  _DelayedSpring(this.spring, Duration delay)
    : delay = delay.inMicroseconds / 1e6,
      assert(!delay.isNegative);

  final SpringSimulation spring;
  final double delay;

  @override
  double x(double time) => spring.x(math.max(0, time - delay));

  @override
  double dx(double time) => time < delay ? 0 : spring.dx(time - delay);

  @override
  bool isDone(double time) => time >= delay && spring.isDone(time - delay);
}

@internal
class RetargetablePrismSpring extends AnimationController {
  RetargetablePrismSpring({required super.vsync}) : super.unbounded();

  _RetargetedSpring? _running;

  void retarget(
    double target,
    SpringDescription spring, {
    double? velocity,
    double? precision,
    Duration delay = Duration.zero,
  }) {
    final next = _delaySpring(
      _prismSimulation(
        spring,
        value,
        target,
        velocity ?? this.velocity,
        precision,
      ),
      isAnimating ? Duration.zero : delay,
    );
    if (isAnimating && _running != null) {
      _running!.retarget(next);
    } else {
      _running = _RetargetedSpring(next);
      unawaited(super.animateWith(_running!));
    }
  }

  @override
  TickerFuture animateWith(Simulation simulation) {
    _running = null;
    return super.animateWith(simulation);
  }
}

class _RetargetedSpring extends Simulation {
  _RetargetedSpring(this._spring);

  Simulation _spring;
  double _origin = 0;
  double _time = 0;

  void retarget(Simulation spring) {
    _spring = spring;
    _origin = _time;
  }

  @override
  double x(double time) {
    _time = time;
    return _spring.x(time - _origin);
  }

  @override
  double dx(double time) => _spring.dx(time - _origin);

  @override
  bool isDone(double time) => _spring.isDone(time - _origin);
}

@internal
class NativeLensDeformation extends Simulation {
  NativeLensDeformation({
    required this.vertical,
    required this.travel,
    required this.timeScale,
    required double value,
    required double velocity,
  }) : _interruption = SpringSimulation(
         SpringDescription.withDurationAndBounce(
           duration: const Duration(milliseconds: 120),
         ),
         value,
         0,
         velocity,
         snapToEnd: true,
       );

  final bool vertical;
  final double travel;
  final double timeScale;
  final SpringSimulation _interruption;

  static const List<(double, double, double)> _samples = [
    (0, 0, 0),
    (.025, 0, 0),
    (.05, -.01049, .00775),
    (.075, -.04336, .03205),
    (.10, -.08700, .06432),
    (.125, -.13176, .09866),
    (.15, -.15794, .11942),
    (.175, -.15036, .10497),
    (.20, -.11967, .06429),
    (.225, -.07719, .01065),
    (.25, -.03424, -.04223),
    (.275, .00120, -.08324),
    (.30, .02489, -.10634),
    (.325, .03530, -.10960),
    (.35, .03553, -.09813),
    (.40, .01722, -.05032),
    (.45, -.00588, -.00129),
    (.50, -.02135, .03043),
    (.55, -.02734, .04351),
    (.60, -.02674, .04397),
    (.70, -.01736, .02915),
    (.80, -.00833, .01406),
    (.90, -.00316, .00535),
    (1.05, 0, 0),
  ];

  double _valueAt(int i) => vertical ? _samples[i].$3 : _samples[i].$2;

  double _tangent(int i) => i == 0 || i == _samples.length - 1
      ? 0
      : (_valueAt(i + 1) - _valueAt(i - 1)) /
            (_samples[i + 1].$1 - _samples[i - 1].$1);

  double _profile(double time) {
    final t = time / timeScale;
    if (t <= 0 || t >= _samples.last.$1) return 0;
    var i = 0;
    while (_samples[i + 1].$1 < t) {
      i++;
    }
    final span = _samples[i + 1].$1 - _samples[i].$1;
    final u = (t - _samples[i].$1) / span;
    final u2 = u * u;
    final u3 = u2 * u;
    return travel *
        ((2 * u3 - 3 * u2 + 1) * _valueAt(i) +
            (u3 - 2 * u2 + u) * span * _tangent(i) +
            (-2 * u3 + 3 * u2) * _valueAt(i + 1) +
            (u3 - u2) * span * _tangent(i + 1));
  }

  @override
  double x(double time) => _profile(time) + _interruption.x(time);

  @override
  double dx(double time) {
    const h = .0001;
    return (_profile(time + h) - _profile(math.max(0, time - h))) /
            (time < h ? h : 2 * h) +
        _interruption.dx(time);
  }

  @override
  bool isDone(double time) =>
      time >= _samples.last.$1 * timeScale && _interruption.isDone(time);
}
