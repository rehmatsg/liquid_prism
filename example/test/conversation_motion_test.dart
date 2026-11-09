import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism_example/showcase/conversation_page.dart';

void main() {
  testWidgets('conversation title cycles through all three compositions', (
    tester,
  ) async {
    await tester.pumpWidget(const CupertinoApp(home: ConversationPage()));
    await tester.pumpAndSettle();
    LiquidPrismTitle title() => tester.widget(find.byType(LiquidPrismTitle));
    expect(title().avatar, isNotNull);
    for (final mode in [1, 2, 0]) {
      await tester.tap(find.text('Maya'));
      await tester.pumpAndSettle();
      expect(title().avatar != null, mode == 0);
      expect(title().leading != null, mode == 1);
      expect(
        find.text('Are we still on for coffee on Saturday?'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
