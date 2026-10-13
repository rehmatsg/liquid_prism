import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'package:liquid_prism_example/api_main.dart';

void main() {
  testWidgets('API example runs and keeps values in the app', (tester) async {
    await tester.pumpWidget(const ApiExample());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<LiquidPrismSwitch>(find.byType(LiquidPrismSwitch)).value,
      true,
    );
    await tester.tap(find.byType(LiquidPrismSwitch));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LiquidPrismSwitch>(find.byType(LiquidPrismSwitch)).value,
      false,
    );
    await tester.tap(find.text('Dusk'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LiquidPrismSegmentedControl<int>>(
            find.byType(LiquidPrismSegmentedControl<int>),
          )
          .selectedValue,
      1,
    );
    final favorite = find.text('Favorite · 0');
    await tester.scrollUntilVisible(
      favorite,
      150,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.tap(favorite);
    await tester.pumpAndSettle();
    expect(find.text('Favorite · 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('API example hosts suggestions under its search field', (
    tester,
  ) async {
    await tester.pumpWidget(const ApiExample());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LiquidPrismSearchField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'pr');
    await tester.pumpAndSettle();
    expect(find.text('Glass'), findsNothing);
    final suggestion = find.text('Prism');
    expect(
      tester.getTopLeft(suggestion).dy,
      greaterThan(tester.getBottomLeft(find.byType(LiquidPrism).first).dy),
    );
    await tester.tap(suggestion);
    await tester.pumpAndSettle();
    final editor = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(editor.controller!.text, 'Prism');
    expect(editor.focusNode!.hasFocus, isFalse);
    expect(find.byType(CupertinoListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
