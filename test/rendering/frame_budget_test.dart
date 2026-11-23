import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/controls/prism_pressable.dart'
    show PrismPressFeedback;
import 'package:liquid_prism/src/core/prism_motion.dart';

Future<int> _barPaints(Future<void> Function() scroll) async {
  var paints = 0;
  debugOnProfilePaint = (renderObject) {
    if (renderObject is RenderCustomMultiChildLayoutBox) paints++;
  };
  try {
    await scroll();
  } finally {
    debugOnProfilePaint = null;
  }
  return paints;
}

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(402 * 3, 874 * 3)
      ..padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3)
      ..viewPadding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
  }

  group('PrismSettle', () {
    test('a settled spring never strays further than its precision', () {
      final random = math.Random(7);
      for (final (duration, bounce) in [
        (.29, .35),
        (.39, .48),
        (.32, 0.0),
        (.33, .72),
        (.5, .3),
      ]) {
        final spring = SpringDescription.withDurationAndBounce(
          duration: Duration(microseconds: (duration * 1e6).round()),
          bounce: bounce,
        );
        for (var trial = 0; trial < 20; trial++) {
          final precision = [.0005, .002, .01][trial % 3];
          final start = random.nextDouble() * 2 - 1;
          final velocity = (random.nextDouble() * 2 - 1) * 20;
          final settled = SpringSimulation(
            spring,
            start,
            0,
            velocity,
            tolerance: PrismSettle.tolerance(spring, precision),
          );
          final free = SpringSimulation(spring, start, 0, velocity);
          var t = 0.0;
          while (!settled.isDone(t)) {
            t += 1 / 120;
          }

          for (var later = t; later < t + 3; later += 1 / 240) {
            expect(free.x(later).abs(), lessThanOrEqualTo(precision));
          }
          final byDefault = SpringSimulation(spring, start, 0, velocity);
          var d = 0.0;
          while (!byDefault.isDone(d)) {
            d += 1 / 120;
          }
          if (precision >= .002) expect(t, lessThanOrEqualTo(d));
        }
      }
    });

    test('precision combines pixel and colour bounds', () {
      expect(PrismSettle.precision(), isNull);
      expect(
        PrismSettle.precision(pixelsPerUnit: 100),
        PrismSettle.pixel / 100,
      );
      expect(
        PrismSettle.precision(pixelsPerUnit: 10, alphaPerUnit: 1),
        PrismSettle.channel,
      );
    });
  });

  testWidgets('a released button stops ticking once its motion is invisible', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: PrismButton(
            label: 'Go',
            onPressed: () {},
            child: const SizedBox(width: 100, height: 20),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PrismButton)),
    );
    for (var i = 0; i < 48; i++) {
      await tester.pump(const Duration(microseconds: 8333));
    }
    await gesture.up();
    var elapsed = Duration.zero;
    const frame = Duration(microseconds: 8333);
    while (tester.binding.hasScheduledFrame) {
      await tester.pump(frame);
      elapsed += frame;
    }

    expect(elapsed, lessThan(const Duration(milliseconds: 750)));
    final feedback = tester.widget<PrismPressFeedback>(
      find
          .descendant(
            of: find.byType(PrismButton),
            matching: find.byType(PrismPressFeedback),
          )
          .first,
    );
    expect(feedback.scale, 1);
    expect(feedback.progress, 0);
  });

  testWidgets('scrolling under a collapsed scaffold bar does not repaint it', (
    tester,
  ) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: PrismScaffold(
          backgroundColor: const Color(0xFF101010),
          largeTitle: const Text('Large'),
          title: const Text('Title'),
          toolbar: [
            PrismToolbarItem(
              icon: const Icon(CupertinoIcons.star),
              label: 'Star',
              onPressed: () {},
            ),
          ],
          body: ListView.builder(
            controller: controller,
            itemCount: 200,
            itemBuilder: (context, index) =>
                SizedBox(height: 44, child: Text('Row $index')),
          ),
        ),
      ),
    );
    controller.jumpTo(300);
    await tester.pumpAndSettle();
    expect(find.byType(PrismScrollEdge), findsOneWidget);
    final paints = await _barPaints(() async {
      for (var i = 1; i <= 20; i++) {
        controller.jumpTo(300 + i * 7.0);
        await tester.pump();
      }
    });
    expect(paints, 0);

    final title = find.text('Large');
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(title).dy;
    controller.jumpTo(20);
    await tester.pump();
    expect(tester.getTopLeft(title).dy, lessThan(top));
  });

  testWidgets('scrolling under a pinned sliver bar does not repaint it', (
    tester,
  ) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            PrismSliverAppBar(
              title: const Text('Inline'),
              largeTitle: const Text('Large'),
              toolbar: [
                PrismToolbarItem(
                  icon: const Icon(CupertinoIcons.star),
                  label: 'Star',
                  onPressed: () {},
                ),
              ],
            ),
            SliverList.builder(
              itemCount: 200,
              itemBuilder: (context, index) =>
                  SizedBox(height: 44, child: Text('Row $index')),
            ),
          ],
        ),
      ),
    );
    controller.jumpTo(600);
    await tester.pumpAndSettle();
    final paints = await _barPaints(() async {
      for (var i = 1; i <= 20; i++) {
        controller.jumpTo(600 + i * 7.0);
        await tester.pump();
      }
    });
    expect(paints, 0);
  });
}
