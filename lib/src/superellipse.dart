// Geometry adapted from Flutter's RoundSuperellipseParam (BSD-3-Clause).
// Copyright 2013 The Flutter Authors. See LICENSES/flutter-BSD-3-Clause.txt.
import 'dart:math' as math;
import 'dart:ui';

/// Uniform-radius rounded superellipse parameters, matching Flutter's contour.
/// Computed once per geometry, never per animation frame.
List<double> superellipseUniforms(Size size, double radius) {
  if (radius <= .001 || size.isEmpty) return List.filled(12, 0);
  final r = math.min(radius, size.shortestSide / 2);
  final top = _octant(size.width / 2, r);
  final right = _octant(size.height / 2, r);
  return [
    top.$1,
    right.$1,
    size.width / 2,
    size.height / 2,
    ...top.$2,
    ...right.$2,
  ];
}

(double, List<double>) _octant(double a, double radius) {
  final ratio = 2 * a / radius;
  double n, k;
  if (ratio > 5) {
    n = 1.559599389 * (ratio - 5) + _table.last.$1;
    k = .522807185 * (ratio - 5) + _table.last.$2;
  } else {
    final t = ratio < 2.5 ? (ratio - 2) * 10 : (ratio - 2.5) * 2 + 5;
    final index = t.floor().clamp(0, _table.length - 2);
    final f = t - index;
    n = _table[index].$1 * (1 - f) + _table[index + 1].$1 * f;
    k = _table[index].$2 * (1 - f) + _table[index + 1].$2 * f;
  }
  final x = (1 - 1 / k) * a;
  final y = math.pow(1 - math.pow(x / a, n), 1 / n) * a;
  final slope = math.pow(x / y, n - 1);
  final d = (x - slope * y) / (1 - slope);
  final g = .29289321881 * radius;
  final circleRadius = (a - d - g) * math.sqrt2;
  final point = Offset(x, y);
  final middle = Offset(a - g, a - g);
  final delta = middle - point;
  final perpendicular = Offset(-delta.dy, delta.dx) / delta.distance;
  final center =
      (point + middle) / 2 -
      perpendicular *
          math.sqrt(
            math.max(
              0,
              circleRadius * circleRadius - delta.distanceSquared / 4,
            ),
          );
  final v = point - center;
  final span = (math.atan2(v.dy, v.dx) - math.pi / 4).abs();
  return (n, [center.dx, center.dy, circleRadius, span]);
}

const _table = <(double, double)>[
  (2, 1.13276676),
  (2.18349805, 1.20311921),
  (2.33888662, 1.28698796),
  (2.48660575, 1.36351941),
  (2.62226596, 1.44717976),
  (2.75148990, 1.53385819),
  (3.36298265, 1.98288283),
  (4.08649929, 2.23811846),
  (4.85481134, 2.47563463),
  (5.62945551, 2.72948597),
  (6.43023796, 2.98020421),
];
