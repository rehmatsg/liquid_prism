import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  for (final fill in [null, const Color(0x80442288)]) {
    testWidgets('toolbar press fill is opt-in: $fill', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: LiquidPrismToolbarGroup(
              style: GlassToolbarStyle(pressedColor: fill),
              items: [
                GlassToolbarItem(
                  icon: const Icon(CupertinoIcons.add),
                  label: 'Add',
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      final fills = find.descendant(
        of: find.byType(LiquidPrismPressable),
        matching: find.byType(ColoredBox),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(CupertinoIcons.add)),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      if (fill == null) {
        expect(fills, findsNothing);
      } else {
        final color = tester.widget<ColoredBox>(fills).color;
        expect(color.a, greaterThan(0));
        expect(color.a, lessThanOrEqualTo(fill.a));
        expect(color.r, fill.r);
        expect(color.g, fill.g);
        expect(color.b, fill.b);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      if (fill != null) expect(tester.widget<ColoredBox>(fills).color.a, 0);
    });
  }
}
