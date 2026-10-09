import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

const _contentKey = ValueKey('pressable-content');

Widget _harness({
  required VoidCallback onPressed,
  bool reduceMotion = false,
  bool selected = false,
  Key? controlKey,
  bool reparent = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: SingleChildScrollView(
      child: Column(
        children: [
          KeyedSubtree(
            key: ValueKey(reparent),
            child: LiquidPrismPressable(
              key: controlKey,
              label: 'Favorite',
              selected: selected,
              onPressed: onPressed,
              child: const SizedBox(
                key: _contentKey,
                width: 100,
                height: 100,
                child: ColoredBox(
                  color: Color(0xFF888888),
                  child: Text('Favorite'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 1500),
        ],
      ),
    ),
  ),
);

double _visibleWidth(WidgetTester tester) =>
    tester.getBottomRight(find.byKey(_contentKey)).dx -
    tester.getTopLeft(find.byKey(_contentKey)).dx;

void main() {
  testWidgets('a held press responds before the scroll arena timeout', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_harness(onPressed: () => taps++));
    final pointer = await tester.startGesture(
      tester.getCenter(find.byKey(_contentKey)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final pressedWidth = _visibleWidth(tester);
    await pointer.cancel();
    await tester.pumpAndSettle();
    expect(pressedWidth, lessThan(100));
    expect(taps, 0);
    expect(_visibleWidth(tester), closeTo(100, 0.01));
  });

  testWidgets(
    'cancel then repeated press releases recover and fire once per tap',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(onPressed: () => taps++));
      var pointer = await tester.startGesture(
        tester.getCenter(find.byKey(_contentKey)),
      );
      await tester.pump(kPressTimeout);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visibleWidth(tester), lessThan(99));

      await pointer.cancel();
      await tester.pump(const Duration(milliseconds: 16));
      expect(taps, 0);
      pointer = await tester.startGesture(
        tester.getCenter(find.byKey(_contentKey)),
      );
      await tester.pump(kPressTimeout);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visibleWidth(tester), lessThan(99));
      await pointer.up();
      await tester.tap(find.byKey(_contentKey));
      await tester.pumpAndSettle();
      expect(taps, 2);
      expect(_visibleWidth(tester), closeTo(100, 0.01));
    },
  );

  testWidgets(
    'Reduce Motion suppresses press scaling while taps remain usable',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(onPressed: () => taps++, reduceMotion: true),
      );
      final pointer = await tester.startGesture(
        tester.getCenter(find.byKey(_contentKey)),
      );
      await tester.pump(kPressTimeout);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visibleWidth(tester), 100);
      await pointer.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(_visibleWidth(tester), 100);
    },
  );

  testWidgets(
    'scroll takeover releases visual press before the pointer lifts',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(onPressed: () => taps++));
      final pointer = await tester.startGesture(
        tester.getCenter(find.byKey(_contentKey)),
      );
      await tester.pump();
      await pointer.moveBy(const Offset(0, -40));
      await pointer.moveBy(const Offset(0, -20));
      await tester.pumpAndSettle();
      final widthWhileScrolling = _visibleWidth(tester);
      final contentTop = tester.getTopLeft(find.byKey(_contentKey)).dy;
      await pointer.up();
      await tester.pumpAndSettle();
      expect(contentTop, lessThan(0));
      expect(widthWhileScrolling, closeTo(100, 0.01));
      expect(taps, 0);
    },
  );

  testWidgets('enabling Reduce Motion during a held press restores its scale', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(onPressed: () {}));
    final pointer = await tester.startGesture(
      tester.getCenter(find.byKey(_contentKey)),
    );
    await tester.pump(kPressTimeout);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_visibleWidth(tester), lessThan(99));
    await tester.pumpWidget(_harness(onPressed: () {}, reduceMotion: true));
    final reducedWidth = _visibleWidth(tester);
    await pointer.cancel();
    await tester.pumpAndSettle();
    expect(reducedWidth, 100);
  });

  testWidgets(
    'removal during a held press cancels without ancestor lookup errors',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(onPressed: () => taps++));
      final pointer = await tester.startGesture(
        tester.getCenter(find.byKey(_contentKey)),
      );
      await tester.pump(kPressTimeout);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      final exception = tester.takeException();
      await pointer.cancel();
      expect(exception, isNull);
      expect(taps, 0);

      final controlKey = GlobalKey();
      await tester.pumpWidget(
        _harness(onPressed: () => taps++, controlKey: controlKey),
      );
      final reparentedPointer = await tester.startGesture(
        tester.getCenter(find.byKey(_contentKey)),
      );
      await tester.pump(kPressTimeout);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visibleWidth(tester), lessThan(99));
      await tester.pumpWidget(
        _harness(
          onPressed: () => taps++,
          controlKey: controlKey,
          reparent: true,
        ),
      );
      final reparentedWidth = _visibleWidth(tester);
      await reparentedPointer.cancel();
      await tester.pumpAndSettle();
      expect(reparentedWidth, 100);
      expect(taps, 0);
    },
  );

  testWidgets(
    'selected button has a named accessible action that invokes once',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(onPressed: () => taps++, selected: true),
      );
      final node = tester.getSemantics(find.byType(LiquidPrismPressable));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.label, 'Favorite');
      tester.semantics.tap(find.semantics.byLabel('Favorite'));
      await tester.pump();
      expect(taps, 1);
    },
  );
}
