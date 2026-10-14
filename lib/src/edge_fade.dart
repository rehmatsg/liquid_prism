import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// An edge of a box, in its own coordinates.
enum GlassEdge {
  top,
  bottom,
  left,
  right;

  /// Whether this edge runs along the top or bottom of the box.
  bool get isHorizontal => this == top || this == bottom;

  /// Whether this is the top or left edge: the start of its axis.
  bool get isStart => this == top || this == left;
}

/// Smoothstep easing, f(t) = 3t² − 2t³: the curve of iOS 27's scroll edge
/// effect, fitted to the mask image its variable blur reads (see
/// doc/native_scroll_edge_spec.md).
///
/// Its first derivative is zero at t = 0 and t = 1, so a fade sampled along it
/// blends into its solid and transparent regions without a visible onset.
/// [LiquidPrismEdgeBlur] ramps its blur along the same curve, so a blur and a
/// fade over one strip track each other exactly.
class GlassFadeCurve extends Curve {
  const GlassFadeCurve();

  @override
  double transformInternal(double t) => t * t * (3 - 2 * t);
}

/// Edge fades along [curve], built as gradients for any edge of a box.
///
/// ```dart
/// DecoratedBox(
///   decoration: BoxDecoration(
///     gradient: GlassEdgeFade.gradient(color: background, plateau: .3),
///   ),
/// )
/// ```
abstract final class GlassEdgeFade {
  /// The shared smootherstep curve every edge fade samples.
  static const Curve curve = GlassFadeCurve();

  // The curve sampled at 17 evenly spaced points: 16 linear segments deviate
  // from the true curve by less than 1/255 alpha. shaders/edge_blur.frag holds
  // the one unavoidable GLSL copy of the curve; keep them identical.
  static const int _samples = 17;
  static final List<double> _stops = List.unmodifiable(
    List.generate(_samples, (i) => i / (_samples - 1)),
  );
  static final List<double> _alphas = List.unmodifiable(
    List.generate(_samples, (i) => 1 - curve.transform(i / (_samples - 1))),
  );

  /// A gradient that fades [color] from fully solid at [begin] to fully
  /// transparent at [end] along [curve].
  ///
  /// [plateau] (0 ≤ plateau < 1) is the leading fraction of the extent held
  /// fully solid before the eased falloff begins, and [floor] (0–1) the
  /// fraction of the solid alpha kept at [end], for a fade that stops with a
  /// hard edge. [opacity] (0–1) caps the whole fade: even the solid edge only
  /// reaches it, with every stop scaled proportionally so the curve's
  /// endpoints stay smooth.
  ///
  /// The fade scales the alpha of the one [color] rather than blending toward
  /// transparent black, which would darken its tail. A translucent color scales
  /// correctly: each stop's alpha is `color.a * opacity * sample`.
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

  /// [gradient] for a fade that is solid at [edge] of a box and transparent
  /// [extent] inward, as a shader over [rect].
  @internal
  static Shader shader({
    required Color color,
    required Rect rect,
    required GlassEdge edge,
    double plateau = 0,
    double floor = 0,
    double opacity = 1,
  }) {
    final (begin, end) = switch (edge) {
      GlassEdge.top => (Alignment.topCenter, Alignment.bottomCenter),
      GlassEdge.bottom => (Alignment.bottomCenter, Alignment.topCenter),
      GlassEdge.left => (Alignment.centerLeft, Alignment.centerRight),
      GlassEdge.right => (Alignment.centerRight, Alignment.centerLeft),
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
