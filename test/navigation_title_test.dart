import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  for (final rtl in [false, true]) {
    for (final hard in [false, true]) {
      testWidgets(
        'titles collapse with accessory, ${rtl ? 'RTL' : 'LTR'}, ${hard ? 'hard' : 'soft'} edge',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: LiquidPrismScaffold(
                  title: const Text('Inline'),
                  largeTitle: const Text('Large'),
                  navigationBarStyle: const GlassNavigationBarStyle(
                    revealExtent: 80,
                  ),
                  leading: const SizedBox(width: 44, height: 44),
                  actions: [
                    GlassToolbarItem(
                      icon: const Icon(Icons.mail),
                      label: 'Mail',
                      onPressed: () {},
                    ),
                  ],
                  accessory: const PreferredSize(
                    preferredSize: Size.fromHeight(32),
                    child: SizedBox(key: Key('accessory')),
                  ),
                  scrollEdgeStyle: GlassScrollEdgeStyle(
                    variant: hard
                        ? GlassScrollEdgeVariant.hard
                        : GlassScrollEdgeVariant.soft,
                  ),
                  body: ListView(
                    controller: scroll,
                    children: const [SizedBox(height: 2000)],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.semantics.byLabel('Large'), findsOne);
          expect(find.semantics.byLabel('Inline'), findsNothing);
          final expanded = tester
              .getTopLeft(find.byKey(const Key('accessory')))
              .dy;
          final largeRect = tester.getRect(find.text('Large'));
          if (rtl) {
            expect(largeRect.right, closeTo(800 - 16, 1));
          } else {
            expect(largeRect.left, 16);
          }
          scroll.jumpTo(100);
          await tester.pumpAndSettle();
          expect(find.semantics.byLabel('Inline'), findsOne);
          expect(find.semantics.byLabel('Large'), findsNothing);
          expect(
            tester.getTopLeft(find.byKey(const Key('accessory'))).dy,
            lessThan(expanded),
          );
          expect(
            tester.getSemantics(find.bySemanticsLabel('Inline')),
            matchesSemantics(label: 'Inline', isHeader: true),
          );
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }
  testWidgets(
    'large title collapse also works without scroll edge at large text',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: LiquidPrismScaffold(
              scrollEdge: false,
              title: const Text('Title'),
              largeTitle: const Text('Large title'),
              body: ListView(
                controller: scroll,
                children: const [SizedBox(height: 2000)],
              ),
            ),
          ),
        ),
      );
      scroll.jumpTo(200);
      await tester.pumpAndSettle();
      expect(find.text('Title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the large title rides the scroll, then swaps on a timer', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidPrismScaffold(
          title: const Text('Inline'),
          largeTitle: const Text('Large'),
          body: ListView(
            controller: scroll,
            children: const [SizedBox(height: 2000)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    double opacityOf(String text) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
        )
        .opacity;
    final rest = tester.getTopLeft(find.text('Large')).dy;
    // Before its 52-point row has scrolled away, it moves with the content.
    scroll.jumpTo(30);
    await tester.pump();
    expect(tester.getTopLeft(find.text('Large')).dy, closeTo(rest - 30, .01));
    expect(opacityOf('Large'), 1);
    expect(opacityOf('Inline'), 0);
    // Past the row the swap runs on time, not with the scroll.
    scroll.jumpTo(52.5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacityOf('Large'), inExclusiveRange(0, 1));
    expect(opacityOf('Inline'), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(opacityOf('Large'), 0);
    expect(opacityOf('Inline'), 1);
    scroll.jumpTo(10);
    await tester.pumpAndSettle();
    expect(opacityOf('Large'), 1);
    expect(opacityOf('Inline'), 0);
  });
}
