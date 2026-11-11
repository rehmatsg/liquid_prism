import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rows;
import 'app_bar_scroll_test.dart' as scrolling;

void main() {
  for (final sliver in [false, true]) {
    testWidgets(
      'initial downward scrolling does not flash the full header edge, sliver $sliver',
      (tester) async {
        phone(tester);
        const modes = {
          'sticky': GlassNavigationBarStyle(
            minimizationBehavior: GlassToolbarMinimizationBehavior.never,
          ),
          'away': GlassNavigationBarStyle(
            minimizationBehavior: GlassToolbarMinimizationBehavior.onScrollDown,
            minimizationRestoration:
                GlassToolbarMinimizationRestoration.atScrollEdge,
          ),
          'reveal': GlassNavigationBarStyle(
            minimizationBehavior: GlassToolbarMinimizationBehavior.onScrollDown,
          ),
        };
        for (final mode in modes.entries) {
          for (final accessory in [false, true]) {
            await tester.pumpWidget(const SizedBox.shrink());
            final controller = ScrollController();
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              scrolling.page(
                sliver: sliver,
                scroll: controller,
                style: mode.value,
                accessory: accessory
                    ? const PreferredSize(
                        preferredSize: Size.fromHeight(36),
                        child: Text('Pinned accessory'),
                      )
                    : null,
              ),
            );
            await tester.pumpAndSettle();
            // A scaffold bar leaving without a reveal keeps the compact edge
            // over the status bar (62 on this phone); the sliver bar has none.
            final hidden = sliver ? 'none' : 'compact';
            void edgeIs(String state) {
              final reason = '${mode.key} accessory $accessory';
              final progress = tester
                  .widget<LiquidPrismScrollEdge>(
                    find.byType(LiquidPrismScrollEdge),
                  )
                  .progress;
              expect(
                progress,
                state == 'none' ? 0 : greaterThan(0),
                reason: reason,
              );
              final blur = find.byType(LiquidPrismEdgeBlur);
              expect(
                blur,
                state == 'none' ? findsNothing : findsOneWidget,
                reason: reason,
              );
              if (state == 'none') return;
              expect(
                tester.getRect(blur).bottom,
                state == 'compact' ? 62 : greaterThan(62),
                reason: '$reason: $state edge',
              );
            }

            String shownOr(bool full) => full ? 'full' : hidden;
            for (final offset in [1.0, 5.0, 8.0, 30.0]) {
              controller.jumpTo(offset);
              await tester.pumpAndSettle();
              edgeIs(shownOr(accessory || mode.key == 'sticky'));
            }
            controller.jumpTo(25);
            await tester.pumpAndSettle();
            edgeIs(shownOr(accessory || mode.key != 'away'));
            controller.jumpTo(100);
            await tester.pumpAndSettle();
            edgeIs(shownOr(accessory || mode.key == 'sticky'));
            controller.jumpTo(95);
            await tester.pumpAndSettle();
            edgeIs(shownOr(accessory || mode.key != 'away'));
            controller.jumpTo(0);
            await tester.pumpAndSettle();
            edgeIs('none');
            controller.jumpTo(8);
            await tester.pumpAndSettle();
            edgeIs(shownOr(accessory || mode.key == 'sticky'));
            expect(tester.takeException(), isNull);
          }
        }
      },
    );

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

  testWidgets(
    'the scaffold bottom edge dissolves even when its top edge is hard',
    (tester) async {
      phone(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: LiquidPrismScaffold(
            title: const Text('Top'),
            bottomBar: const SizedBox(height: 50),
            backgroundColor: const Color(0xff123456),
            scrollController: controller,
            scrollEdgeStyle: const GlassScrollEdgeStyle(
              variant: GlassScrollEdgeVariant.hard,
              sigma: 3,
              fadeOpacity: .25,
            ),
            slivers: rows(),
          ),
        ),
      );
      controller.jumpTo(100);
      await tester.pumpAndSettle();
      Finder edge(GlassEdge side) => find.byWidgetPredicate(
        (widget) => widget is LiquidPrismScrollEdge && widget.edge == side,
      );
      final top = tester
          .widget<LiquidPrismEdgeBlur>(
            find.descendant(
              of: edge(GlassEdge.top),
              matching: find.byType(LiquidPrismEdgeBlur),
            ),
          )
          .edges
          .single;
      final bottomFinder = find.descendant(
        of: edge(GlassEdge.bottom),
        matching: find.byType(LiquidPrismEdgeBlur),
      );
      final bottom = tester
          .widget<LiquidPrismEdgeBlur>(bottomFinder)
          .edges
          .single;
      expect(top.fadeFloor, 1);
      expect(
        bottom.fadeFloor,
        isNull,
        reason: 'the bottom fade must dissolve into the page',
      );
      expect(
        tester.getRect(bottomFinder).top,
        lessThan(tester.getRect(edge(GlassEdge.bottom)).top),
      );
      expect(bottom.sigma, 3);
      expect(bottom.fadeOpacity, .25);
    },
  );

  testWidgets(
    'the bottom edge fades out over a collapsing bar\'s last 16 points',
    (tester) async {
      phone(tester);
      double? height = 50;
      late StateSetter update;
      await tester.pumpWidget(
        CupertinoApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return LiquidPrismScaffold(
                title: const Text('Top'),
                bottomBar: height == null ? null : SizedBox(height: height),
                slivers: rows(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bottomEdge = find.byWidgetPredicate(
        (widget) =>
            widget is LiquidPrismScrollEdge && widget.edge == GlassEdge.bottom,
      );
      // Content remains below at rest, so only the bar's height limits it.
      for (final (bar, strength) in <(double?, double)>[
        (50, 1),
        (16, 1),
        (8, .5),
        (0, 0),
        (null, 0),
        (50, 1),
      ]) {
        update(() => height = bar);
        await tester.pump();
        await tester.pump();
        final reason = 'bar height $bar';
        if (bar == null) {
          expect(bottomEdge, findsNothing, reason: reason);
          continue;
        }
        expect(
          tester.widget<LiquidPrismScrollEdge>(bottomEdge).progress,
          closeTo(strength, 1e-9),
          reason: reason,
        );
        expect(
          find.descendant(
            of: bottomEdge,
            matching: find.byType(LiquidPrismEdgeBlur),
          ),
          strength == 0 ? findsNothing : findsOneWidget,
          reason: reason,
        );
      }
    },
  );

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
