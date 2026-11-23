import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';

import 'app_bar_scroll_test.dart' as scrolling;
import 'scaffold_slivers_test.dart' show phone, rows;

void main() {
  for (final sliver in [false, true]) {
    testWidgets(
      'initial downward scrolling does not flash the full header edge, sliver $sliver',
      (tester) async {
        phone(tester);
        const modes = {
          'sticky': PrismNavigationBarStyle(
            minimizationBehavior: PrismMinimizationBehavior.never,
          ),
          'away': PrismNavigationBarStyle(
            minimizationBehavior: PrismMinimizationBehavior.onScrollDown,
            minimizationRestoration: PrismMinimizationRestoration.atScrollEdge,
          ),
          'reveal': PrismNavigationBarStyle(
            minimizationBehavior: PrismMinimizationBehavior.onScrollDown,
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

            final hidden = sliver ? 'none' : 'compact';
            void edgeIs(String state) {
              final reason = '${mode.key} accessory $accessory';
              final progress = tester
                  .widget<PrismScrollEdge>(find.byType(PrismScrollEdge))
                  .progress;
              expect(
                progress,
                state == 'none' ? 0 : greaterThan(0),
                reason: reason,
              );
              final blur = find.byType(PrismEdgeBlur);
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

            controller.jumpTo(300);
            await tester.pumpAndSettle();
            edgeIs(shownOr(accessory || mode.key == 'sticky'));

            controller.jumpTo(295);
            await tester.pumpAndSettle();
            if (accessory || mode.key == 'sticky') {
              edgeIs('full');
            } else if (sliver) {
              expect(
                tester
                    .widget<PrismScrollEdge>(find.byType(PrismScrollEdge))
                    .progress,
                lessThan(.1),
                reason: '${mode.key}: a small reveal',
              );
            } else {
              edgeIs('compact');
            }
            controller.jumpTo(150);
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
                    PrismSliverAppBar(
                      title: const Text('Detail'),
                      scrollEdge: edge,
                    ),
                    ...rows(),
                  ],
                )
              : PrismScaffold(
                  title: const Text('Detail'),
                  scrollController: controller,
                  scrollEdge: edge,
                  bottomBar: const SizedBox(height: 50),
                  slivers: rows(),
                ),
        );
        List<double> progress() => tester
            .widgetList<PrismScrollEdge>(find.byType(PrismScrollEdge))
            .map((e) => e.progress)
            .toList();

        await tester.pumpWidget(page(false));
        controller.jumpTo(300);
        await tester.pumpAndSettle();
        expect(progress(), isEmpty);

        await tester.pumpWidget(page(true));
        await tester.pump();
        expect(progress(), everyElement(lessThan(.05)));
        await tester.pump(PrismScaffold.scrollEdgeFadeDuration ~/ 2);
        expect(progress(), everyElement(inExclusiveRange(.2, .8)));
        await tester.pumpAndSettle();
        expect(progress(), everyElement(1));
        expect(progress(), hasLength(sliver ? 1 : 2));

        await tester.pumpWidget(page(false));
        await tester.pump(PrismScaffold.scrollEdgeFadeDuration ~/ 2);
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
          home: PrismScaffold(
            title: const Text('Top'),
            bottomBar: const SizedBox(height: 50),
            backgroundColor: const Color(0xff123456),
            scrollController: controller,
            scrollEdgeStyle: const PrismScrollEdgeStyle(
              variant: PrismScrollEdgeVariant.hard,
              sigma: 3,
              fadeOpacity: .25,
            ),
            slivers: rows(),
          ),
        ),
      );
      controller.jumpTo(100);
      await tester.pumpAndSettle();
      Finder edge(PrismEdge side) => find.byWidgetPredicate(
        (widget) => widget is PrismScrollEdge && widget.edge == side,
      );
      final top = tester
          .widget<PrismEdgeBlur>(
            find.descendant(
              of: edge(PrismEdge.top),
              matching: find.byType(PrismEdgeBlur),
            ),
          )
          .edges
          .single;
      final bottomFinder = find.descendant(
        of: edge(PrismEdge.bottom),
        matching: find.byType(PrismEdgeBlur),
      );
      final bottom = tester.widget<PrismEdgeBlur>(bottomFinder).edges.single;
      expect(top.fadeFloor, 1);
      expect(
        bottom.fadeFloor,
        isNull,
        reason: 'the bottom fade must dissolve into the page',
      );
      expect(
        tester.getRect(bottomFinder).top,
        lessThan(tester.getRect(edge(PrismEdge.bottom)).top),
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
              return PrismScaffold(
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
            widget is PrismScrollEdge && widget.edge == PrismEdge.bottom,
      );

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
          tester.widget<PrismScrollEdge>(bottomEdge).progress,
          closeTo(strength, 1e-9),
          reason: reason,
        );
        expect(
          find.descendant(of: bottomEdge, matching: find.byType(PrismEdgeBlur)),
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
        home: PrismScaffold(
          title: const Text('Detail'),
          scrollController: controller,
          slivers: rows(),
        ),
      ),
    );
    controller.jumpTo(300);
    await tester.pump();
    expect(
      tester.widget<PrismScrollEdge>(find.byType(PrismScrollEdge)).progress,
      1,
    );
  });
}
