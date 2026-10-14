import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  testWidgets(
    'tab hold fires once, cancels selection and settles before release',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final changes = <int>[], holds = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: LiquidPrismTabBar(
              tabs: const [
                LiquidPrismTab(label: 'A', icon: Icon(Icons.home)),
                LiquidPrismTab(label: 'B', icon: Icon(Icons.mail)),
              ],
              selectedIndex: 0,
              onSelected: changes.add,
              onLongPressed: holds.add,
              style: const GlassTabBarStyle(haptics: false),
            ),
          ),
        ),
      );
      final selection = find.byKey(const ValueKey('tab-selection'));
      final resting = tester.getRect(selection);
      expect(
        tester.getSemantics(find.bySemanticsLabel('B')),
        matchesSemantics(
          label: 'B',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ),
      );
      final pointer = await tester.startGesture(
        tester.getCenter(find.text('B')),
      );
      await tester.pump(kLongPressTimeout - const Duration(milliseconds: 1));
      expect(holds, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(holds, [1]);
      await tester.pumpAndSettle();
      expect(tester.getRect(selection), resting);
      await tester.pump(const Duration(seconds: 1));
      await pointer.moveBy(const Offset(-50, 0));
      await pointer.up();
      await tester.pumpAndSettle();
      expect(holds, [1]);
      expect(changes, isEmpty);
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(changes, [1]); // Parent rejected: selection still returns to A.
      expect(tester.getRect(selection), resting);
      semantics.dispose();
    },
  );

  testWidgets(
    'drag, cancel, external update and multitouch suppress tab hold',
    (tester) async {
      final changes = <int>[], holds = <int>[];
      var selected = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return LiquidPrismTabBar(
                  tabs: const [
                    LiquidPrismTab(label: 'A', icon: Icon(Icons.home)),
                    LiquidPrismTab(label: 'B', icon: Icon(Icons.mail)),
                  ],
                  selectedIndex: selected,
                  onSelected: changes.add,
                  onLongPressed: holds.add,
                  style: const GlassTabBarStyle(haptics: false),
                );
              },
            ),
          ),
        ),
      );
      var finger = await tester.startGesture(tester.getCenter(find.text('A')));
      await finger.moveBy(const Offset(30, 0));
      await tester.pump(kLongPressTimeout);
      await finger.up();
      await tester.pumpAndSettle();
      expect(holds, isEmpty);
      expect(changes, hasLength(1));
      changes.clear();
      finger = await tester.startGesture(tester.getCenter(find.text('A')));
      await finger.cancel();
      await tester.pump(kLongPressTimeout);
      finger = await tester.startGesture(tester.getCenter(find.text('A')));
      update(() => selected = 1);
      await tester.pump();
      await tester.pump(kLongPressTimeout);
      await finger.up();
      await tester.pumpAndSettle();
      finger = await tester.startGesture(tester.getCenter(find.text('A')));
      final second = await tester.startGesture(
        tester.getCenter(find.text('B')),
        pointer: 2,
      );
      await tester.pump(kLongPressTimeout);
      await second.up();
      await finger.up();
      await tester.pumpAndSettle();
      expect(holds, isEmpty);
      expect(changes, isEmpty);
    },
  );
}
