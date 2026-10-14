import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// A reusable spring expressed as duration and bounce.
@immutable
class GlassSpring {
  const GlassSpring({
    this.response = const Duration(milliseconds: 400),
    this.bounce = .15,
  }) : physics = null,
       assert(bounce >= 0 && bounce < 1);

  /// Use Flutter's mass/stiffness/damping model directly.
  const GlassSpring.physical(SpringDescription this.physics)
    : response = const Duration(milliseconds: 400),
      bounce = .15;
  final SpringDescription? physics;
  final Duration response;
  final double bounce;
  SpringDescription get description =>
      physics ??
      SpringDescription.withDurationAndBounce(
        duration: response,
        bounce: bounce,
      );
  GlassSpring copyWith({Duration? response, double? bounce}) =>
      response == null && bounce == null
      ? this
      : GlassSpring(
          response: response ?? this.response,
          bounce: bounce ?? this.bounce,
        );
}

/// Partial motion overrides for switches, sliders and segmented controls.
/// Null retains each component's captured native timing.
@immutable
class GlassControlMotion {
  const GlassControlMotion({
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
  final GlassSpring? travel, tracking, lift, release, flex;
  final Duration? minimumLiftDuration, velocityDecay;

  /// Displacement per point/second. Native fit defaults to .018.
  final double? flexStrength;

  /// Maximum fractional axis deformation. Defaults to .1.
  final double? maxStretch;
  GlassControlMotion copyWith({
    GlassSpring? travel,
    GlassSpring? tracking,
    GlassSpring? lift,
    GlassSpring? release,
    GlassSpring? flex,
    Duration? minimumLiftDuration,
    double? flexStrength,
    double? maxStretch,
    Duration? velocityDecay,
  }) => GlassControlMotion(
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
  GlassControlMotion merge(GlassControlMotion? other) => other == null
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
}

/// Spatial motion shared by glass buttons and navigation controls.
///
/// Defaults use a spring intercepted during iOS 27 tab selection and fitted button
/// motion, expressed as
/// SwiftUI-style duration and bounce. [response] and [bounce] move the tab
/// pill between tabs; [pressResponse] and [pressBounce] grow a held control;
/// [releaseResponse] and [releaseBounce] let it go.
@immutable
class GlassMotion {
  const GlassMotion({
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
  final Duration response, pressResponse, releaseResponse;
  final double bounce, pressBounce, releaseBounce, pressScale, dragProjection;

  GlassMotion copyWith({
    Duration? response,
    double? bounce,
    Duration? pressResponse,
    double? pressBounce,
    Duration? releaseResponse,
    double? releaseBounce,
    double? pressScale,
    double? dragProjection,
  }) => GlassMotion(
    response: response ?? this.response,
    bounce: bounce ?? this.bounce,
    pressResponse: pressResponse ?? this.pressResponse,
    pressBounce: pressBounce ?? this.pressBounce,
    releaseResponse: releaseResponse ?? this.releaseResponse,
    releaseBounce: releaseBounce ?? this.releaseBounce,
    pressScale: pressScale ?? this.pressScale,
    dragProjection: dragProjection ?? this.dragProjection,
  );

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

/// Native parameters and remaining fitted motion, with provenance recorded in
/// `doc/native_tab_bar_spec.md`. Response maps to angular frequency 2π/response
/// and bounce maps to 1 minus the damping ratio.
@internal
abstract final class NativeMotion {
  /// Lens inset outside the resting pill while held, in logical pixels.
  static const lensInset = 8.0;

  /// Exact large-lens spec: .25 s response, damping ratio 1 on both edges.
  static final liftIn = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 250),
    bounce: 0,
  );
  static final liftOut = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 250),
    bounce: 0,
  );

  /// Housing width increase, derived from presentation transforms at two widths.
  /// This is not a recovered UIKit layout formula.
  static const barExpansion = 14.1379310344828;
  static final barScaleIn = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 320),
    bounce: 0.38,
  );
  static final barScaleOut = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 350),
    bounce: 0.39,
  );

  /// Bar-wide glow: 0.845 opacity reached in ~0.13 s, decays with τ ≈ 0.13 s.
  static const glowOpacity = 0.845;
  static final glowIn = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 150),
    bounce: 0,
  );
  static final glowOut = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 520),
    bounce: 0,
  );

  /// A radial halo centred on the lens; on release it fades while growing.
  static const haloDiameter = 93.0;
  static const haloBlurRadius = 46.5;
  static const haloOpacity = 0.284;
  static const haloReleaseScale = 4.0;
  static const haloRelease = Duration(milliseconds: 500);

  /// Fitted tracking spring; native drag creates separate .2/.3 s behaviors
  /// whose property mapping has not yet been established.
  static final tracking = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 450),
    bounce: 0.4,
  );

  /// Drag stretch per logical pixel per second of lens speed, taken off the
  /// cross axis. The filter carries the shape's momentum through a stop.
  static const stretchPerSpeed = 0.018;
  static const stretchLimit = 24.0;
  static final stretchFilter = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 330),
    bounce: 0.72,
  );

  /// A quick contact completes its lift before the lens drops. The housing
  /// releases immediately; only the lens keeps this dwell.
  static const lensDwell = Duration(milliseconds: 220);

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

/// When a glass spring may stop: once its remaining motion cannot be seen.
///
/// Flutter's default spring tolerance waits for the velocity to fall below
/// 0.001 units per second, which for a unit-range spring means an amplitude
/// near 0.0001: frames keep being produced for a few hundred milliseconds
/// after the last visible change. A precision instead bounds what is left.
@internal
abstract final class GlassSettle {
  /// Largest remaining movement, in physical pixels, a settled spring skips.
  static const pixel = 0.25;

  /// Largest remaining colour or opacity change a settled spring skips: half
  /// an 8-bit step.
  static const channel = 0.5 / 255;

  /// The value-space precision at which a spring's remaining motion moves
  /// nothing by more than [pixel] physical pixels, given [pixelsPerUnit], and
  /// changes no colour by more than [channel], given [alphaPerUnit] (the
  /// largest colour change one unit of value can make). Null when neither
  /// bound is known, which keeps Flutter's default tolerance.
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

  /// A tolerance under which no later moment of the spring departs from its
  /// target by more than [precision].
  ///
  /// A damped spring never gains energy, so from displacement x and velocity
  /// v it can still reach at most sqrt(x² + (v/ω)²), ω its natural angular
  /// frequency. Bounding |x| by precision/√2 and |v| by ω·precision/√2 keeps
  /// that reach, and so the jump made when the spring snaps to its end,
  /// within [precision].
  static Tolerance tolerance(SpringDescription spring, double precision) {
    final omega = math.sqrt(spring.stiffness / spring.mass);
    final distance = precision / math.sqrt2;
    return Tolerance(distance: distance, velocity: distance * omega);
  }
}

SpringSimulation _glassSimulation(
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
      : GlassSettle.tolerance(spring, precision),
);

/// Retargets from the displayed position with uninterrupted velocity.
///
/// [precision] is the value-space change below which the spring's remaining
/// motion is invisible (see [GlassSettle.precision]); null keeps Flutter's
/// default tolerance.
@internal
void springGlass(
  AnimationController controller,
  double target,
  SpringDescription spring, {
  double? velocity,
  bool immediate = false,
  double? precision,
}) {
  if (immediate) {
    controller.value = target;
  } else if (controller is RetargetableGlassSpring) {
    controller.retarget(
      target,
      spring,
      velocity: velocity,
      precision: precision,
    );
  } else {
    unawaited(
      controller.animateWith(
        _glassSimulation(
          spring,
          controller.value,
          target,
          velocity ?? controller.velocity,
          precision,
        ),
      ),
    );
  }
}

/// A continuously driven spring. Retargeting changes the simulation on the
/// existing ticker: restarting an AnimationController on every pointer sample
/// repeatedly consumes its zero-time frame and makes a drag lag or stall.
@internal
class RetargetableGlassSpring extends AnimationController {
  RetargetableGlassSpring({required super.vsync}) : super.unbounded();

  _RetargetedSpring? _running;

  void retarget(
    double target,
    SpringDescription spring, {
    double? velocity,
    double? precision,
  }) {
    final next = _glassSimulation(
      spring,
      value,
      target,
      velocity ?? this.velocity,
      precision,
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
  SpringSimulation _spring;
  double _origin = 0, _time = 0;

  void retarget(SpringSimulation spring) {
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

/// A fitted two-axis launch response, sampled from the lens transform rather
/// than its bounds. A single speed/area-preserving stretch cannot reproduce the
/// tall launch, wide arrival and slower second rebound. Samples are relative
/// to the bar scale, in seconds after contact (iOS 27, hold-other-dark).
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
  final double travel, timeScale;
  final SpringSimulation _interruption;

  static const _samples = <(double, double, double)>[
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
    final u2 = u * u, u3 = u2 * u;
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
