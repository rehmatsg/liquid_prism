import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  testWidgets('an unavailable native plugin retains functional Flutter glass', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dev.liquidprism/system');
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      throw MissingPluginException();
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await LiquidPrism.preload();
    expect(calls, ['isSupported']);
    var taps = 0;
    await tester.pumpWidget(
      glassHarness(
        imageKey: GlobalKey(),
        child: LiquidPrismButton(
          label: 'Fallback action',
          onPressed: () => taps++,
          child: const Text('Fallback'),
        ),
      ),
    );
    expect(find.byType(UiKitView), findsNothing);
    await tester.tap(find.byType(LiquidPrismButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
