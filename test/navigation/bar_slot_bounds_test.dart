import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rectOf, rows;

PrismToolbarItem _item(String label) => PrismToolbarItem(
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
  List<PrismToolbarContent> toolbar = const [],
}) => CupertinoApp(
  home: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: sliver
        ? CustomScrollView(
            slivers: [
              PrismSliverAppBar(
                leading: leading,
                title: title,
                trailing: trailing,
                toolbar: toolbar,
              ),
              ...rows(),
            ],
          )
        : PrismScaffold(
            leading: leading,
            title: title,
            trailing: trailing,
            toolbar: toolbar,
            slivers: rows(),
          ),
  ),
);

void main() {
  for (final sliver in [false, true]) {
    for (final rtl in [false, true]) {
      final name = '${sliver ? 'sliver bar' : 'scaffold'}, rtl: $rtl';
      testWidgets('a wide leading widget stops before the toolbar ($name)', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(
          _bar(
            sliver: sliver,
            rtl: rtl,

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
            toolbar: [_item('Preferences')],
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
            toolbar: [_item('Save')],
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final title = rectOf(tester, 'title');
        final toolbar = tester.getRect(find.byType(PrismToolbar));

        const row = 17 * 2 * 1.2 + 8;
        expect(title.height, lessThanOrEqualTo(row + .01));
        expect(title.center.dy, closeTo(62 + row / 2, .01));
        expect(toolbar.center.dy, closeTo(62 + row / 2, .01));
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
