import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  testWidgets(
    'hook routes tab, switch and accepted slider endpoint; false silences',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final events = <GlassHapticEvent>[];
      final native = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          native.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var enabled = true, value = false, slider = .5;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidPrismTheme(
            data: LiquidPrismThemeData(
              haptics: GlassHaptics((context, event) => events.add(event)),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LiquidPrismTabBar(
                      tabs: const [
                        LiquidPrismTab(label: 'A', icon: Icon(Icons.home)),
                        LiquidPrismTab(label: 'B', icon: Icon(Icons.mail)),
                      ],
                      selectedIndex: 0,
                      onSelected: (_) {},
                      onLongPressed: (_) {},
                      style: GlassTabBarStyle(haptics: enabled),
                    ),
                    LiquidPrismSwitch(
                      value: value,
                      haptics: enabled,
                      onChanged: (v) => setState(() => value = v),
                    ),
                    LiquidPrismSlider(
                      value: slider,
                      haptics: enabled,
                      onChanged: (v) => setState(() => slider = v),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('B'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(LiquidPrismSwitch));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(LiquidPrismSlider));
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await tester.pumpAndSettle();
      expect(events.map((e) => e.kind), [
        GlassHapticKind.selectionChange,
        GlassHapticKind.longPress,
        GlassHapticKind.toggle,
        GlassHapticKind.limitReached,
      ]);
      expect(events.map((e) => e.component), [
        GlassHapticComponent.tabBar,
        GlassHapticComponent.tabBar,
        GlassHapticComponent.switchControl,
        GlassHapticComponent.slider,
      ]);
      expect(
        native.where((call) => call.method == 'HapticFeedback.vibrate'),
        isEmpty,
      );
      update(() {
        enabled = false;
        slider = .5;
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('B'));
      await tester.longPress(find.text('B'));
      await tester.tap(find.byType(LiquidPrismSwitch));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await tester.pumpAndSettle();
      expect(events, hasLength(4));
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
