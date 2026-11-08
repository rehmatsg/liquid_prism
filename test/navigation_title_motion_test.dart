import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'app_bar_scroll_test.dart' show page;
import 'scaffold_slivers_test.dart' show phone;

double opacityOf(WidgetTester tester, String title) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(title), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  final reference = jsonDecode(
    File('test/fixtures/navigation_title_motion.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final sliver in [false, true]) {
    testWidgets(
      'zero reveal distance waits for scroll, custom fade timing works, sliver $sliver',
      (tester) async {
        phone(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          page(
            sliver: sliver,
            scroll: scroll,
            large: true,
            style: const GlassNavigationBarStyle(
              revealExtent: 0,
              largeTitleFadeDuration: Duration(milliseconds: 400),
              largeTitleFadeCurve: Curves.linear,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(opacityOf(tester, 'Large'), 1);
        expect(opacityOf(tester, 'Inline'), 0);
        scroll.jumpTo(1);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(opacityOf(tester, 'Large'), closeTo(.75, .001));
        await tester.pumpAndSettle();
        expect(opacityOf(tester, 'Inline'), 1);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('native title opacity trajectories, sliver $sliver', (
      tester,
    ) async {
      phone(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        page(
          sliver: sliver,
          scroll: scroll,
          large: true,
          style: const GlassNavigationBarStyle(),
        ),
      );
      await tester.pumpAndSettle();
      for (final direction in ['enter', 'exit']) {
        scroll.jumpTo(direction == 'enter' ? 100 : 0);
        await tester.pump();
        await tester.pump();
        var elapsed = 0;
        for (final point in reference['transitions'][direction] as List) {
          final ms = point['ms'] as int;
          await tester.pump(Duration(milliseconds: ms - elapsed));
          elapsed = ms;
          expect(
            opacityOf(tester, 'Inline'),
            closeTo(point['opacity'] as num, .015),
            reason: '$direction at $ms ms vs native presentation trace',
          );
          if (ms == 50) {
            expect(
              opacityOf(tester, 'Large'),
              closeTo(direction == 'enter' ? .8708 : .1292, .003),
            );
          }
          if (ms == 100) {
            expect(opacityOf(tester, 'Large'), closeTo(.5, .003));
          }
          if (ms >= 200) {
            expect(opacityOf(tester, 'Large'), direction == 'enter' ? 0 : 1);
          }
        }
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'reversal keeps the displayed title continuous, sliver $sliver',
      (tester) async {
        phone(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          page(
            sliver: sliver,
            scroll: scroll,
            large: true,
            style: const GlassNavigationBarStyle(),
          ),
        );
        await tester.pumpAndSettle();
        scroll.jumpTo(100);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final before = opacityOf(tester, 'Inline');
        final y = tester.getTopLeft(find.text('Inline')).dy;
        scroll.jumpTo(0);
        await tester.pump();
        expect(opacityOf(tester, 'Inline'), closeTo(before, .001));
        expect(tester.getTopLeft(find.text('Inline')).dy, closeTo(y, .001));
        await tester.pumpAndSettle();
        expect(opacityOf(tester, 'Inline'), 0);
        expect(opacityOf(tester, 'Large'), 1);
      },
    );

    testWidgets('Reduce Motion swaps titles immediately, sliver $sliver', (
      tester,
    ) async {
      phone(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        page(
          sliver: sliver,
          scroll: scroll,
          large: true,
          reduceMotion: true,
          style: const GlassNavigationBarStyle(),
        ),
      );
      await tester.pumpAndSettle();
      scroll.jumpTo(100);
      await tester.pump();
      await tester.pump();
      expect(opacityOf(tester, 'Inline'), 1);
      expect(opacityOf(tester, 'Large'), 0);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump();
      expect(opacityOf(tester, 'Inline'), 0);
      expect(opacityOf(tester, 'Large'), 1);
      expect(tester.takeException(), isNull);
    });
  }
}
