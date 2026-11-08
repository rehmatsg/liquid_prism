import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rows;

GlassToolbarItem _item(
  String label, {
  VoidCallback? onPressed,
  bool keyed = true,
}) => GlassToolbarItem(
  key: keyed ? ValueKey(label) : null,
  icon: Icon(CupertinoIcons.star, key: ValueKey('icon-$label')),
  label: label,
  onPressed: onPressed ?? () {},
);

void main() {
  testWidgets(
    'regrouping existing actions keeps them fully present and usable',
    (tester) async {
      const labels = ['Mail', 'Filter', 'Search'];
      for (final (axis, keyed) in [
        for (final axis in [Axis.horizontal, Axis.vertical])
          for (final keyed in [true, false]) (axis, keyed),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final taps = <String, int>{};
        Widget toolbar(int partition) {
          final items = [
            for (final label in labels)
              _item(
                label,
                keyed: keyed,
                onPressed: () =>
                    taps.update(label, (count) => count + 1, ifAbsent: () => 1),
              ),
          ];
          return CupertinoApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: LiquidPrismToolbar(
                axis: axis,
                content: [
                  if (partition != 0) ...[
                    GlassToolbarGroup(items: items.sublist(0, partition)),
                    GlassToolbarGroup(items: items.sublist(partition)),
                  ] else
                    ...items,
                ],
              ),
            ),
          );
        }

        void fullyPresent(int partition) {
          for (final label in labels) {
            final icon = find.byKey(ValueKey('icon-$label'));
            expect(
              icon,
              findsOneWidget,
              reason: '$axis keyed $keyed partition $partition $label',
            );
            expect(
              LiquidPrismPresence.of(tester.element(icon)),
              1,
              reason: '$axis keyed $keyed partition $partition $label',
            );
            for (final opacity in tester.widgetList<Opacity>(
              find.ancestor(of: icon, matching: find.byType(Opacity)),
            )) {
              expect(
                opacity.opacity,
                1,
                reason: '$axis keyed $keyed partition $partition $label',
              );
            }
          }
        }

        await tester.pumpWidget(toolbar(0));
        await tester.pumpAndSettle();
        var expectedTaps = 0;
        for (final partition in [1, 2, 0]) {
          await tester.pumpWidget(toolbar(partition));
          fullyPresent(partition);
          for (final label in labels) {
            await tester.tapAt(
              tester.getCenter(find.byKey(ValueKey('icon-$label'))),
            );
          }
          await tester.pump();
          expectedTaps++;
          for (final label in labels) {
            expect(taps[label], expectedTaps);
          }
          await tester.pump(const Duration(milliseconds: 40));
          fullyPresent(partition);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('a capsule growing in keeps the bar row in place', (
    tester,
  ) async {
    phone(tester);
    Widget page(bool mail) => CupertinoApp(
      home: LiquidPrismScaffold(
        title: const Text('Applications'),
        toolbar: [
          GlassToolbarGroup(items: [if (mail) _item('Mail')]),
          GlassToolbarGroup(items: [_item('Filter'), _item('Search')]),
        ],
        slivers: rows(),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(true));
    // The bar offers the screen's height; the entering group must not take
    // it, or every capsule centres in the middle of the screen.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final toolbar = tester.getRect(find.byType(LiquidPrismToolbar));
      expect(toolbar.top, 62);
      expect(toolbar.height, 44);
      if (i == 0) {
        expect(
          LiquidPrismPresence.of(
            tester.element(find.byKey(const ValueKey('icon-Mail'))),
          ),
          inExclusiveRange(0, 1),
        );
      }
    }
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(LiquidPrismToolbar)).height, 44);
    expect(
      LiquidPrismPresence.of(
        tester.element(find.byKey(const ValueKey('icon-Mail'))),
      ),
      1,
    );
  });

  testWidgets('a vertical toolbar keeps its width as a group grows in', (
    tester,
  ) async {
    Widget toolbar(bool mail) => CupertinoApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: LiquidPrismToolbar(
          axis: Axis.vertical,
          content: [
            GlassToolbarGroup(items: [if (mail) _item('Mail')]),
            GlassToolbarGroup(items: [_item('Filter')]),
          ],
        ),
      ),
    );
    await tester.pumpWidget(toolbar(false));
    await tester.pumpAndSettle();
    final width = tester.getSize(find.byType(LiquidPrismToolbar)).width;
    await tester.pumpWidget(toolbar(true));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getSize(find.byType(LiquidPrismToolbar)).width, width);
    }
  });
}
