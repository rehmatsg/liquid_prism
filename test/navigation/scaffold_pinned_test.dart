import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rectOf, rows;

class _Tabs extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 40;
  @override
  double get maxExtent => 40;
  @override
  Widget build(BuildContext context, double shrink, bool overlaps) =>
      const SizedBox(key: ValueKey('tabs'), height: 40);
  @override
  bool shouldRebuild(_Tabs old) => false;
}

void main() {
  survivesEdgeCases();
  for (final header in [false, true]) {
    testWidgets('a pinned header pins below the bar (header: $header)', (
      tester,
    ) async {
      phone(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: PrismScaffold(
            title: const Text('Company'),
            scrollController: controller,
            header: header ? const SizedBox(height: 120) : null,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
              SliverPersistentHeader(pinned: true, delegate: _Tabs()),
              ...rows(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const barBottom = 62 + 44 + PrismScaffold.topBarClearance;
      expect(rectOf(tester, 'tabs').top, barBottom + 80 + (header ? 120 : 0));
      controller.jumpTo(600);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(rectOf(tester, 'tabs').top, barBottom);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

void survivesEdgeCases() {
  for (final fill in [false, true]) {
    for (final refresh in [false, true]) {
      testWidgets('a pinned header lays out (fill: $fill, refresh: $refresh)', (
        tester,
      ) async {
        phone(tester);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          CupertinoApp(
            home: PrismScaffold(
              title: const Text('Company'),
              scrollController: controller,
              onRefresh: refresh ? () async {} : null,
              header: const SizedBox(height: 120),
              slivers: [
                SliverPersistentHeader(pinned: true, delegate: _Tabs()),
                if (fill)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: SizedBox(height: 50),
                  )
                else
                  ...rows(3),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final offset in [-80.0, 40.0, 300.0, 2000.0]) {
          controller.jumpTo(offset);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'at $offset');
        }
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
