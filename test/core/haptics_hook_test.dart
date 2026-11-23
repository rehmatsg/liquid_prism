import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'hook routes tab, switch and accepted slider endpoint; false silences',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final events = <PrismHapticEvent>[];
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
      var enabled = true;
      var value = false;
      var slider = .5;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: PrismTheme(
            data: PrismThemeData(
              haptics: PrismHaptics((context, event) => events.add(event)),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PrismTabBar(
                      tabs: const [
                        PrismTab(label: 'A', icon: Icon(Icons.home)),
                        PrismTab(label: 'B', icon: Icon(Icons.mail)),
                      ],
                      selectedIndex: 0,
                      onSelected: (_) {},
                      onLongPressed: (_) {},
                      style: PrismTabBarStyle(haptics: enabled),
                    ),
                    PrismSwitch(
                      value: value,
                      onChanged: (v) => setState(() => value = v),
                      style: PrismSwitchStyle(haptics: enabled),
                    ),
                    PrismSlider(
                      value: slider,
                      onChanged: (v) => setState(() => slider = v),
                      style: PrismSliderStyle(haptics: enabled),
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
      await tester.tap(find.byType(PrismSwitch));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(PrismSlider));
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await tester.pumpAndSettle();
      expect(events.map((e) => e.kind), [
        PrismHapticKind.selectionChange,
        PrismHapticKind.longPress,
        PrismHapticKind.toggle,
        PrismHapticKind.limitReached,
      ]);
      expect(events.map((e) => e.component), [
        PrismHapticComponent.tabBar,
        PrismHapticComponent.tabBar,
        PrismHapticComponent.switchControl,
        PrismHapticComponent.slider,
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
      await tester.tap(find.byType(PrismSwitch));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await tester.pumpAndSettle();
      expect(events, hasLength(4));
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
