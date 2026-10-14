import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rows;

GlassToolbarItem _item(String label) => GlassToolbarItem(
  key: ValueKey(label),
  icon: const Icon(CupertinoIcons.star),
  label: label,
  onPressed: () {},
);

void main() {
  testWidgets('a capsule growing in keeps the bar row in place', (
    tester,
  ) async {
    phone(tester);
    Widget page(bool mail) => CupertinoApp(
      home: LiquidPrismScaffold(
        title: const Text('Applications'),
        actions: [
          [if (mail) _item('Mail')],
          [_item('Filter'), _item('Search')],
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
    }
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(LiquidPrismToolbar)).height, 44);
  });

  testWidgets('a vertical toolbar keeps its width as a group grows in', (
    tester,
  ) async {
    Widget toolbar(bool mail) => CupertinoApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: LiquidPrismToolbar(
          axis: Axis.vertical,
          groups: [
            [if (mail) _item('Mail')],
            [_item('Filter')],
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
