import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rows;

void main() {
  for (final sliver in [false, true]) {
    testWidgets(
      'turning the edge on fades it in (${sliver ? 'sliver bar' : 'scaffold'})',
      (tester) async {
        phone(tester);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        Widget page(bool edge) => CupertinoApp(
          home: sliver
              ? CustomScrollView(
                  controller: controller,
                  slivers: [
                    LiquidPrismSliverAppBar(
                      title: const Text('Detail'),
                      scrollEdge: edge,
                    ),
                    ...rows(),
                  ],
                )
              : LiquidPrismScaffold(
                  title: const Text('Detail'),
                  scrollController: controller,
                  scrollEdge: edge,
                  bottomBar: const SizedBox(height: 50),
                  slivers: rows(),
                ),
        );
        List<double> progress() => tester
            .widgetList<LiquidPrismScrollEdge>(
              find.byType(LiquidPrismScrollEdge),
            )
            .map((e) => e.progress)
            .toList();

        await tester.pumpWidget(page(false));
        controller.jumpTo(300);
        await tester.pumpAndSettle();
        expect(progress(), isEmpty);

        await tester.pumpWidget(page(true));
        await tester.pump();
        expect(progress(), everyElement(lessThan(.05)));
        await tester.pump(LiquidPrismScaffold.scrollEdgeFadeDuration ~/ 2);
        expect(progress(), everyElement(inExclusiveRange(.2, .8)));
        await tester.pumpAndSettle();
        expect(progress(), everyElement(1));
        expect(progress(), hasLength(sliver ? 1 : 2));

        // Off fades out, then removes the effects.
        await tester.pumpWidget(page(false));
        await tester.pump(LiquidPrismScaffold.scrollEdgeFadeDuration ~/ 2);
        expect(progress(), everyElement(inExclusiveRange(.2, .8)));
        await tester.pumpAndSettle();
        expect(progress(), isEmpty);
      },
    );
  }

  testWidgets('an edge on from the start shows at once', (tester) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Detail'),
          scrollController: controller,
          slivers: rows(),
        ),
      ),
    );
    controller.jumpTo(300);
    await tester.pump();
    expect(
      tester
          .widget<LiquidPrismScrollEdge>(find.byType(LiquidPrismScrollEdge))
          .progress,
      1,
    );
  });
}
