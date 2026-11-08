import 'dart:ui' as ui;

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
  group('compositedAncestorClip', () {
    void nest(List<ContainerLayer> ancestors, Layer target) {
      for (var i = 0; i < ancestors.length - 1; i++) {
        ancestors[i].append(ancestors[i + 1]);
      }
      ancestors.last.append(target);
      addTearDown(ancestors.first.dispose);
    }

    test('contours map through local transforms and root pixel scale', () {
      const bounds = Rect.fromLTWH(0, 0, 100, 100);
      final contours = <String, ContainerLayer Function()>{
        'rounded': () => ClipRRectLayer(
          clipRRect: RRect.fromRectAndRadius(bounds, const Radius.circular(20)),
        ),
        'superellipse': () => ClipRSuperellipseLayer(
          clipRSuperellipse: ui.RSuperellipse.fromRectAndRadius(
            bounds,
            const Radius.circular(20),
          ),
        ),
        'path': () => ClipPathLayer(clipPath: Path()..addOval(bounds)),
      };
      for (final scale in [1.0, 3.0]) {
        for (final contour in contours.entries) {
          final target = ContainerLayer();
          nest([
            TransformLayer(transform: Matrix4.diagonal3Values(scale, scale, 1)),
            contour.value(),
            TransformLayer(
              transform: Matrix4.diagonal3Values(2, 2, 1)
                ..setTranslationRaw(10, 20, 0),
            ),
          ], target);
          final clip = compositedAncestorClip(target)!;
          expect(
            clip.getBounds(),
            const Rect.fromLTWH(-5, -10, 50, 50),
            reason: contour.key,
          );
          expect(
            clip.contains(const Offset(20, 15)),
            isTrue,
            reason: contour.key,
          );
          expect(
            clip.contains(const Offset(-4, -9)),
            isFalse,
            reason: contour.key,
          );
        }
      }
    });

    test('rectangles intersect shapes without leaving the rectangular fast path unnecessarily', () {
      final plain = ContainerLayer();
      nest([
        ClipRectLayer(clipRect: const Rect.fromLTWH(40, 10, 30, 50)),
      ], plain);
      expect(compositedAncestorClip(plain), isNull);
      for (final rect in [
        const Rect.fromLTWH(40, 10, 30, 50),
        const Rect.fromLTWH(120, 0, 10, 10),
      ]) {
        final target = ContainerLayer();
        nest([
          ClipRRectLayer(
            clipRRect: RRect.fromRectAndRadius(
              const Rect.fromLTWH(0, 0, 100, 100),
              const Radius.circular(20),
            ),
          ),
          ClipRectLayer(clipRect: rect),
        ], target);
        final clip = compositedAncestorClip(target)!;
        if (rect.left == 40) {
          expect(clip.getBounds(), rect);
          expect(clip.contains(const Offset(50, 30)), isTrue);
          expect(clip.contains(const Offset(20, 30)), isFalse);
        } else {
          expect(clip.computeMetrics(), isEmpty);
          expect(clip.contains(const Offset(50, 30)), isFalse);
        }
      }
    });

    test('raster boundaries retain inner clips and their own clip but exclude outer clips', () {
      const inner = Rect.fromLTWH(50, 50, 100, 100);
      final boundaries = <String, ContainerLayer Function()>{
        'translucent': () => OpacityLayer(alpha: 128),
        'opaque': () => OpacityLayer(alpha: 255),
        'saved clip': () => ClipRectLayer(
          clipRect: const Rect.fromLTWH(80, 80, 40, 40),
          clipBehavior: Clip.antiAliasWithSaveLayer,
        ),
      };
      for (final boundary in boundaries.entries) {
        final target = ContainerLayer();
        nest([
          ClipRectLayer(clipRect: const Rect.fromLTWH(0, 0, 40, 40)),
          boundary.value(),
          ClipRRectLayer(
            clipRRect: RRect.fromRectAndRadius(
              inner,
              const Radius.circular(20),
            ),
          ),
        ], target);
        final clip = compositedAncestorClip(target)!;
        if (boundary.key == 'opaque') {
          expect(clip.computeMetrics(), isEmpty);
        } else {
          expect(
            clip.getBounds(),
            boundary.key == 'saved clip'
                ? const Rect.fromLTWH(80, 80, 40, 40)
                : inner,
          );
          expect(clip.contains(const Offset(100, 100)), isTrue);
          expect(clip.contains(const Offset(51, 51)), isFalse);
        }
      }
    });

    test('a singular transform safely clips everything even without shaped ancestry', () {
      final target = ContainerLayer();
      nest([
        TransformLayer(transform: Matrix4.diagonal3Values(0, 0, 1)),
      ], target);
      final clip = compositedAncestorClip(target);
      expect(clip, isNotNull);
      expect(clip!.computeMetrics(), isEmpty);
      expect(clip.contains(Offset.zero), isFalse);
    });
  });

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
