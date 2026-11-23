import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/src/rendering/layer_transform.dart';

Matrix4 _device(double dx, double dy, [double scale = 3]) =>
    Matrix4.diagonal3Values(scale, scale, 1)..translateByDouble(dx, dy, 0, 1);

void main() {
  test('aligned bounds keep their exact extent', () {
    const rect = Rect.fromLTWH(96, 556, 274, 62);
    expect(pixelAlignedInterior(rect, _device(0, 0)), rect);
    expect(pixelAlignedSplit(rect.center.dx, _device(0, 0)), 233);
  });

  test('fractional bounds shrink to the whole pixels they cover', () {
    const rect = Rect.fromLTWH(96.4, 555.6, 274, 62);
    final aligned = pixelAlignedInterior(rect, _device(0, 0))!;
    for (final edge in [
      aligned.left,
      aligned.top,
      aligned.right,
      aligned.bottom,
    ]) {
      expect(edge * 3, moreOrLessEquals((edge * 3).roundToDouble()));
    }
    expect(aligned.left, greaterThanOrEqualTo(rect.left));
    expect(aligned.top, greaterThanOrEqualTo(rect.top));
    expect(aligned.right, lessThanOrEqualTo(rect.right));
    expect(aligned.bottom, lessThanOrEqualTo(rect.bottom));
    expect(rect.left - aligned.left, greaterThan(-1 / 3));
    expect(rect.right - aligned.right, lessThan(1 / 3));
    final split = pixelAlignedSplit(aligned.center.dx, _device(0, 0)) * 3;
    expect(split, moreOrLessEquals(split.roundToDouble()));
  });

  test('a press scale and a layer offset still land on device pixels', () {
    const size = Size(274, 62);
    final centre = size.center(Offset.zero);
    final scaled = MatrixUtils.transformRect(
      Matrix4.translationValues(centre.dx, centre.dy, 0)
        ..scaleByDouble(1.037, 1.037, 1, 1)
        ..translateByDouble(-centre.dx, -centre.dy, 0, 1),
      Offset.zero & size,
    );
    final toDevice = _device(96.25, 556.1);
    final aligned = pixelAlignedInterior(scaled, toDevice)!;
    final device = MatrixUtils.transformRect(toDevice, aligned);
    for (final edge in [device.left, device.top, device.right, device.bottom]) {
      expect(edge, moreOrLessEquals(edge.roundToDouble(), epsilon: 1e-6));
    }
    expect(scaled.contains(aligned.topLeft), isTrue);
    expect(aligned.width, greaterThan(scaled.width - 2 / 3));
  });

  test('rotated or degenerate layers keep the unaligned clip', () {
    const rect = Rect.fromLTWH(10.2, 10.2, 40, 40);
    expect(pixelAlignedInterior(rect, Matrix4.rotationZ(.3)), isNull);
    expect(
      pixelAlignedInterior(const Rect.fromLTWH(.4, .4, .1, .1), _device(0, 0)),
      isNull,
    );
    expect(pixelAlignedSplit(12.3, Matrix4.rotationZ(.3)), 12.3);
  });
}
