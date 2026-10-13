import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/src/layer_transform.dart';

// Glass computes shader geometry from its laid-out transform, but its backdrop
// is rasterized in the space its ancestor layers composite. These tests pin
// the helpers that tell the two apart, as a modal sheet's covered page scales.

const _boundary = ValueKey('boundary');

Widget _coveredPage({required double t, FilterQuality? filterQuality}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: FractionalTranslation(
        translation: Offset(0, 0.08 * t),
        child: Transform.scale(
          scale: 1 - 0.0835 * t,
          alignment: Alignment.topCenter,
          filterQuality: filterQuality,
          child: const Center(
            child: RepaintBoundary(
              key: _boundary,
              child: SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      ),
    );

({OffsetLayer layer, RenderBox box}) _probe(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(find.byKey(_boundary));
  return (layer: box.debugLayer! as OffsetLayer, box: box);
}

bool _movedAfterRaster(WidgetTester tester) {
  final (:layer, :box) = _probe(tester);
  return transformedAfterRaster(
    composited: compositedTransform(layer),
    paintOffset: layer.offset,
    global: box.getTransformTo(null),
    pixelRatio: tester.view.devicePixelRatio,
    bounds: Offset.zero & box.size,
  );
}

void main() {
  testWidgets('a plain scale transform rasterizes where layout places it', (
    tester,
  ) async {
    // Failure: a TransformLayer scale or translation is missed, so glass
    // under an animating sheet transform would be reported (or drawn) as
    // misplaced although its backdrop shares its coordinates.
    await tester.pumpWidget(_coveredPage(t: 1));
    expect(_movedAfterRaster(tester), isFalse);

    final (:layer, :box) = _probe(tester);
    final dpr = tester.view.devicePixelRatio;
    final corner = box.size.bottomRight(Offset.zero);
    expect(
      MatrixUtils.transformPoint(
        compositedTransform(layer),
        corner + layer.offset,
      ),
      offsetMoreOrLessEquals(
        MatrixUtils.transformPoint(box.getTransformTo(null), corner) * dpr,
        epsilon: 1e-6,
      ),
    );
  });

  testWidgets('a filter-quality transform scales only after rasterizing', (
    tester,
  ) async {
    // Failure: the ImageFilter.matrix layer's scale leaks into the raster
    // scale, so the tab lens would map its pixels with the post-filter scale
    // and glass would not detect that its backdrop is moved afterwards.
    await tester.pumpWidget(
      _coveredPage(t: 1, filterQuality: FilterQuality.medium),
    );
    expect(_movedAfterRaster(tester), isTrue);

    final (:layer, :box) = _probe(tester);
    expect(
      compositedTransform(layer).getMaxScaleOnAxis(),
      moreOrLessEquals(tester.view.devicePixelRatio, epsilon: 1e-9),
    );
    expect(
      box.getTransformTo(null).storage[0],
      moreOrLessEquals(1 - 0.0835, epsilon: 1e-9),
    );
  });

  testWidgets('an identity filter-quality transform is not reported', (
    tester,
  ) async {
    // Failure: a resting covered page (sheet dismissed, filter still present)
    // is flagged although nothing moves its raster.
    await tester.pumpWidget(
      _coveredPage(t: 0, filterQuality: FilterQuality.medium),
    );
    expect(_movedAfterRaster(tester), isFalse);
  });

  testWidgets('the composited transform follows each animation frame', (
    tester,
  ) async {
    // Failure: a retained layer below the transform reports the scale from
    // the frame it was last painted in, not the current one.
    await tester.pumpWidget(_coveredPage(t: 0.25));
    final first = compositedTransform(_probe(tester).layer).getMaxScaleOnAxis();
    await tester.pumpWidget(_coveredPage(t: 0.75));
    final second = compositedTransform(_probe(tester).layer)
        .getMaxScaleOnAxis();
    final dpr = tester.view.devicePixelRatio;
    expect(first, moreOrLessEquals(dpr * (1 - 0.0835 * .25), epsilon: 1e-9));
    expect(second, moreOrLessEquals(dpr * (1 - 0.0835 * .75), epsilon: 1e-9));
  });
}
