import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

const _green = Color(0xFF00FF00);
const _childKey = ValueKey('shaped-child');
const _content = SizedBox(
  key: _childKey,
  width: 160,
  height: 80,
  child: ColoredBox(color: _green),
);
final _points = [
  for (var y = 41; y < 79; y += 2)
    for (var x = 41; x < 99; x += 2) Offset(x.toDouble(), y.toDouble()),
];

class _ReferenceClip extends CustomClipper<Path> {
  const _ReferenceClip(this.smooth);
  final bool smooth;
  @override
  Path getClip(Size size) => smooth
      ? (Path()..addRSuperellipse(
          ui.RSuperellipse.fromRectAndRadius(
            Offset.zero & size,
            const Radius.circular(30),
          ),
        ))
      : (Path()..addRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            const Radius.circular(30),
          ),
        ));
  @override
  bool shouldReclip(_ReferenceClip oldClipper) => oldClipper.smooth != smooth;
}

void main() {
  testWidgets(
    'inscribed circle retains the square reference rim in rectangular layouts',
    (tester) async {
      final imageKey = GlobalKey();
      const center = Offset(120, 80);
      // Pixel centers near the diagonal circumference of an independent
      // diameter-80 circle; layout rectangles all share this same circle.
      final rimPoints = <Offset>[
        for (var y = 40; y < 120; y++)
          for (var x = 80; x < 160; x++)
            if ((x + .5 - center.dx).abs() >= 16 &&
                (y + .5 - center.dy).abs() >= 16 &&
                (Offset(x + .5, y + .5) - center).distanceSquared >= 38 * 38 &&
                (Offset(x + .5, y + .5) - center).distanceSquared <= 41 * 41)
              Offset(x.toDouble(), y.toDouble()),
      ];
      Future<List<List<int>>> render(Size layout) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            background: const Color(0xFF000000),
            child: LiquidPrism(
              shape: GlassShape.circle,
              child: SizedBox(
                key: _childKey,
                width: layout.width,
                height: layout.height,
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byKey(_childKey)), layout);
        return pixelsAt(tester, imageKey, [...rimPoints, center]);
      }

      final square = await render(const Size(80, 80));
      expect(square.last, [0, 0, 0, 255]);
      expect(
        square.take(rimPoints.length).any((pixel) => pixel[0] > 20),
        isTrue,
        reason: 'The reference must contain a visible rim over the black face',
      );
      for (final layout in [const Size(160, 80), const Size(80, 160)]) {
        final rectangle = await render(layout);
        for (var i = 0; i < rimPoints.length; i++) {
          for (var channel = 0; channel < 4; channel++) {
            expect(
              rectangle[i][channel],
              closeTo(square[i][channel], 1),
              reason: '$layout circle rim at ${rimPoints[i]}, channel $channel',
            );
          }
        }
        expect(rectangle.last, square.last);
      }
    },
  );

  testWidgets(
    'smooth and circular corners clip to distinct SDK contours after live shape changes',
    (tester) async {
      final imageKey = GlobalKey();
      Future<List<bool>> mask(Widget child) async {
        await tester.pumpWidget(glassHarness(imageKey: imageKey, child: child));
        expect(tester.getSize(find.byKey(_childKey)), const Size(160, 80));
        return (await pixelsAt(tester, imageKey, _points))
            .map((pixel) => pixel[0] == 0 && pixel[1] == 255 && pixel[2] == 0)
            .toList();
      }

      final smooth = await mask(
        const ClipPath(clipper: _ReferenceClip(true), child: _content),
      );
      final rounded = await mask(
        const ClipPath(clipper: _ReferenceClip(false), child: _content),
      );
      expect(
        smooth,
        isNot(rounded),
        reason:
            'The samples must distinguish superellipse and circular corners',
      );
      expect(
        await mask(
          const LiquidPrism(
            shape: GlassShape.rect(cornerRadius: 30),
            child: _content,
          ),
        ),
        smooth,
      );
      expect(
        await mask(
          const LiquidPrism(
            shape: GlassShape.roundedRect(cornerRadius: 30),
            child: _content,
          ),
        ),
        rounded,
      );
      expect(
        await mask(
          const LiquidPrism(
            shape: GlassShape.rect(cornerRadius: 30),
            child: _content,
          ),
        ),
        smooth,
      );
      expect(
        await mask(
          const LiquidPrism(
            glass: Glass.identity,
            shape: GlassShape.rect(cornerRadius: 30),
            child: _content,
          ),
        ),
        everyElement(isTrue),
      );
    },
  );

  testWidgets(
    'explicit shape and optics radius override app shape while shadow remains exterior',
    (tester) async {
      final imageKey = GlobalKey();
      Future<List<List<int>>> render({
        GlassShape? shape,
        LiquidPrismStyle? optics,
      }) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            child: LiquidPrismTheme(
              data: const LiquidPrismThemeData(shape: GlassShape.circle),
              child: LiquidPrism(shape: shape, optics: optics, child: _content),
            ),
          ),
        );
        return pixelsAt(tester, imageKey, const [
          Offset(42, 80),
          Offset(120, 80),
          Offset(120, 124),
          Offset(5, 5),
        ]);
      }

      final inherited = await render();
      expect(inherited.first, isNot([0, 255, 0, 255]));
      final explicitOptics = await render(
        optics: LiquidPrismStyle.clear.copyWith(cornerRadius: 0),
      );
      expect(explicitOptics[0], [0, 255, 0, 255]);
      expect(explicitOptics[1], [0, 255, 0, 255]);
      expect(
        explicitOptics[2].first,
        lessThan(102),
        reason: 'Exterior shadow must survive the clip',
      );
      expect(explicitOptics[3], [102, 102, 102, 255]);
      final explicitShape = await render(
        shape: GlassShape.circle,
        optics: LiquidPrismStyle.clear.copyWith(cornerRadius: 0),
      );
      expect(explicitShape.first, isNot([0, 255, 0, 255]));
    },
  );
}
