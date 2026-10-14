import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rows, rectOf;

GlassToolbarItem _item(String label) => GlassToolbarItem(
  icon: const Icon(CupertinoIcons.star),
  label: label,
  onPressed: () {},
);

void main() {
  const pill = SizedBox(key: ValueKey('pill'), width: 60, height: 30);

  for (final rtl in [false, true]) {
    for (final sliver in [false, true]) {
      final name = '${sliver ? 'sliver bar' : 'scaffold'}, rtl: $rtl';
      testWidgets('trailing sits before the capsules ($name)', (tester) async {
        phone(tester);
        var taps = 0;
        final tappable = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: pill,
        );
        final actions = [_item('Filter')];
        await tester.pumpWidget(
          CupertinoApp(
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: sliver
                  ? CustomScrollView(
                      slivers: [
                        LiquidPrismSliverAppBar(
                          title: const Text('Matches'),
                          actions: actions,
                          trailing: tappable,
                        ),
                        ...rows(),
                      ],
                    )
                  : LiquidPrismScaffold(
                      title: const Text('Matches'),
                      actions: actions,
                      trailing: tappable,
                      slivers: rows(),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final capsule = tester.getRect(find.byType(LiquidPrismToolbarGroup));
        final trailing = rectOf(tester, 'pill');
        if (rtl) {
          expect(trailing.left, capsule.right + 8);
        } else {
          expect(trailing.right, capsule.left - 8);
        }
        // Centred on the controls' row.
        expect(trailing.center.dy, closeTo(capsule.center.dy, .01));
        // The title leads and stops before it.
        final title = tester.getRect(find.text('Matches'));
        if (rtl) {
          expect(title.left, greaterThanOrEqualTo(trailing.right));
        } else {
          expect(title.right, lessThanOrEqualTo(trailing.left));
          expect(title.left, 16);
        }
        await tester.tap(find.byKey(const ValueKey('pill')));
        expect(taps, 1);
      });
    }
  }

  testWidgets('without actions trailing takes the trailing edge', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(trailing: pill, slivers: rows()),
      ),
    );
    await tester.pumpAndSettle();
    final trailing = rectOf(tester, 'pill');
    expect(trailing.right, 402 - 16);
    expect(trailing.center.dy, closeTo(62 + 22, .01));
  });
}
