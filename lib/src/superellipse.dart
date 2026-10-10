// Geometry adapted from Flutter's RoundSuperellipseParam (BSD-3-Clause).
// Copyright 2013 The Flutter Authors. See LICENSES/flutter-BSD-3-Clause.txt.
import 'dart:math' as math;
import 'dart:ui';

/// Number of floats in [superellipseUniforms]: u_shapeA..u_shapeD (16) plus
/// u_curve[65] (260).
const int superellipseUniformCount = 276;

/// Uniform-radius rounded superellipse parameters, matching Flutter's contour.
/// Computed once per geometry, never per animation frame.
///
/// Layout: u_shapeA (n_top, n_right, w/2, h/2), u_shapeB (top arc circle:
/// center x, y, radius, span), u_shapeC (right arc circle), u_shapeD
/// (cos(top span), cos(right span), 0, 0), then u_curve[65]: the superellipse
/// arc vertex at angle k*pi/256 for k = 0..64, top octant in xy and right
/// octant in zw. The shader bisects over these vertices instead of evaluating
/// pow per step; the vertices are the ones the previous shader computed itself.
List<double> superellipseUniforms(Size size, double radius) {
  if (radius <= .001 || size.isEmpty) {
    return List.filled(superellipseUniformCount, 0);
  }
  final r = math.min(radius, size.shortestSide / 2);
  final top = _octant(size.width / 2, r);
  final right = _octant(size.height / 2, r);
  final values = <double>[
    top.$1,
    right.$1,
    size.width / 2,
    size.height / 2,
    ...top.$2,
    ...right.$2,
    math.cos(top.$2[3]),
    math.cos(right.$2[3]),
    0,
    0,
  ];
  final pTop = 2 / top.$1;
  final pRight = 2 / right.$1;
  for (var k = 0; k <= 64; k++) {
    final theta = k * math.pi / 256;
    final c = math.cos(theta);
    final s = math.sin(theta);
    values
      ..add(math.pow(c, pTop).toDouble())
      ..add(math.pow(s, pTop).toDouble())
      ..add(math.pow(c, pRight).toDouble())
      ..add(math.pow(s, pRight).toDouble());
  }
  assert(values.length == superellipseUniformCount);
  return values;
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
