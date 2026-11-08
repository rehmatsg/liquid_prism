import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism_example/composition_main.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets(
      'composition example adapts all docks at $size with large text',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = size;
        addTearDown(tester.view.reset);
        final key = GlobalKey<CompositionExampleState>();
        await tester.pumpWidget(CompositionExample(key: key));
        for (final dock in GlassTabBarPlacement.values) {
          for (final rtl in [false, true]) {
            key.currentState!.configure(dock: dock, rtl: rtl, textScale: 1.6);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$dock RTL $rtl');
          }
        }
      },
    );
  }
}
