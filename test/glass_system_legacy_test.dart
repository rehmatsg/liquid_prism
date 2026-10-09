import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'glass_system_test.dart' show verifySystemTabAppearance;

void main() {
  testWidgets(
    'a native plugin without appearanceVersion retains iOS 26 tab treatment',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const system = MethodChannel('dev.liquidprism/system');
      final calls = <String>[];
      messenger.setMockMethodCallHandler(system, (call) async {
        calls.add(call.method);
        if (call.method == 'isSupported') return true;
        throw MissingPluginException();
      });
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(system, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      });
      await LiquidPrism.preload();
      expect(calls, ['isSupported', 'appearanceVersion']);
      await verifySystemTabAppearance(tester, legacy: true);
      expect(calls, ['isSupported', 'appearanceVersion']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
