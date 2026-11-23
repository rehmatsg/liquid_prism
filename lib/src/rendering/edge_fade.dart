import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Edge of a rectangular box in local coordinates.
enum PrismEdge {
  top,
  bottom,
  left,
  right;

  /// Whether this edge runs horizontally along the top or bottom.
  bool get isHorizontal => this == top || this == bottom;

  /// Whether this edge is at the start of its axis (top or left).
  bool get isStart => this == top || this == left;
}

/// Smoothstep easing curve used by edge fades and edge blurs.
class PrismFadeCurve extends Curve {
  /// Creates a smoothstep fade curve.
  const PrismFadeCurve();

  @override
  double transformInternal(double t) => t * t * (3 - 2 * t);
}

/// Smoothstep edge fade gradients aligned with [PrismEdgeBlur].
abstract final class PrismEdgeFade {
  /// Shared smoothstep curve sampled by edge fades.
  static const Curve curve = PrismFadeCurve();

  static const int _samples = 17;
  static final List<double> _stops = List<double>.unmodifiable(
    List<double>.generate(_samples, (i) => i / (_samples - 1)),
  );
  static final List<double> _alphas = List<double>.unmodifiable(
    List<double>.generate(
      _samples,
      (i) => 1 - curve.transform(i / (_samples - 1)),
    ),
  );

  /// Creates a gradient fading [color] from [begin] to [end] along [curve].
  static LinearGradient gradient({
    required Color color,
    AlignmentGeometry begin = Alignment.topCenter,
    AlignmentGeometry end = Alignment.bottomCenter,
    double plateau = 0,
    double floor = 0,
    double opacity = 1,
  }) {
    assert(plateau >= 0 && plateau < 1, 'plateau must be in [0, 1)');
    assert(floor >= 0 && floor <= 1, 'floor must be in [0, 1]');
    assert(opacity >= 0 && opacity <= 1, 'opacity must be in [0, 1]');
    final peak = color.a * opacity;
    return LinearGradient(
      begin: begin,
      end: end,
      stops: [
        if (plateau > 0) 0,
        for (final stop in _stops) plateau + stop * (1 - plateau),
      ],
      colors: [
        if (plateau > 0) color.withValues(alpha: peak),
        for (final alpha in _alphas)
          color.withValues(alpha: peak * (floor + (1 - floor) * alpha)),
      ],
    );
  }

  @internal
  static Shader shader({
    required Color color,
    required Rect rect,
    required PrismEdge edge,
    double plateau = 0,
    double floor = 0,
    double opacity = 1,
  }) {
    final (begin, end) = switch (edge) {
      PrismEdge.top => (Alignment.topCenter, Alignment.bottomCenter),
      PrismEdge.bottom => (Alignment.bottomCenter, Alignment.topCenter),
      PrismEdge.left => (Alignment.centerLeft, Alignment.centerRight),
      PrismEdge.right => (Alignment.centerRight, Alignment.centerLeft),
    };
    return gradient(
      color: color,
      begin: begin,
      end: end,
      plateau: plateau,
      floor: floor,
      opacity: opacity,
    ).createShader(rect);
  }
}
