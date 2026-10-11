import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism_example/controls_demo.dart';

void main() {
  testWidgets(
    'the public controls demo accepts switch, slider and tab gestures',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const CupertinoApp(
          home: LiquidPrismTheme(
            data: LiquidPrismThemeData(brightness: Brightness.dark),
            child: ControlsDemo(standalone: true),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('switch')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LiquidPrismSwitch>(find.byKey(const ValueKey('switch')))
            .value,
        true,
      );
      final slider = find.byKey(const ValueKey('slider'));
      await tester.drag(slider, const Offset(90, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<LiquidPrismSlider>(slider).value, greaterThan(.7));
      final segments = find.byKey(const ValueKey('segments'));
      await tester.tapAt(
        tester.getRect(segments).centerRight - const Offset(50, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<LiquidPrismSegmentedControl<int>>(segments).selectedValue,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
