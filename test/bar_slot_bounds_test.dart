import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rows, rectOf;

GlassToolbarItem _item(String label) => GlassToolbarItem(
  icon: const Icon(CupertinoIcons.star),
  label: label,
  onPressed: () {},
);

Widget _bar({
  required bool sliver,
  required bool rtl,
  Widget? leading,
  Widget? title,
  Widget? trailing,
  List<Object> actions = const [],
}) => CupertinoApp(
  home: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: sliver
        ? CustomScrollView(
            slivers: [
              LiquidPrismSliverAppBar(
                leading: leading,
                title: title,
                trailing: trailing,
                actions: actions,
              ),
              ...rows(),
            ],
          )
        : LiquidPrismScaffold(
            leading: leading,
            title: title,
            trailing: trailing,
            actions: actions,
            slivers: rows(),
          ),
  ),
);

void main() {
  for (final sliver in [false, true]) {
    for (final rtl in [false, true]) {
      final name = '${sliver ? 'sliver bar' : 'scaffold'}, rtl: $rtl';
      testWidgets('a wide leading widget stops before the actions ($name)', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(
          _bar(
            sliver: sliver,
            rtl: rtl,
            // As wide as it is allowed: a menu trigger with a long label.
            leading: const SizedBox(
              key: ValueKey('switcher'),
              width: double.infinity,
              height: 36,
            ),
            trailing: const SizedBox(
              key: ValueKey('pill'),
              width: 60,
              height: 30,
            ),
            actions: [_item('Preferences')],
          ),
        );
        await tester.pumpAndSettle();
        final leading = rectOf(tester, 'switcher');
        final pill = rectOf(tester, 'pill');
        if (rtl) {
          expect(leading.right, 402 - 16);
          expect(leading.left, pill.right + 12);
        } else {
          expect(leading.left, 16);
          expect(leading.right, pill.left - 12);
        }
      });

      testWidgets('a two-line title fits the row at large text ($name)', (
        tester,
      ) async {
        phone(tester);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          _bar(
            sliver: sliver,
            rtl: rtl,
            title: const Column(
              key: ValueKey('title'),
              mainAxisSize: MainAxisSize.min,
              children: [Text('Product Engineer'), Text('Acme')],
            ),
            actions: [_item('Save')],
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final title = rectOf(tester, 'title');
        final actions = tester.getRect(find.byType(LiquidPrismToolbarGroup));
        // Within the bar's row: the row's height at this text size.
        final row = 17 * 2 * 1.2 + 8;
        expect(title.height, lessThanOrEqualTo(row + .01));
        expect(title.center.dy, closeTo(62 + row / 2, .01));
        expect(actions.center.dy, closeTo(62 + row / 2, .01));
      });
    }
  }

  testWidgets('a title that fits keeps its size', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      _bar(
        sliver: false,
        rtl: false,
        title: const Text('Inbox', key: ValueKey('title')),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.getSize(find.text('Inbox'));
    expect(rectOf(tester, 'title').size, text);
  });
}
