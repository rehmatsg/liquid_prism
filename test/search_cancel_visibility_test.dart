import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  Widget app(Widget field, {GlassSearchStyle? theme}) => CupertinoApp(
    home: LiquidPrismTheme(
      data: LiquidPrismThemeData(search: theme),
      child: Center(child: SizedBox(width: 360, child: field)),
    ),
  );

  testWidgets('by default the cancel action shows only while focused', (
    tester,
  ) async {
    await tester.pumpWidget(app(const LiquidPrismSearchField()));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Cancel search'), findsNothing);
  });

  testWidgets('always: an unfocused field shows cancel, which closes', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'designer');
    addTearDown(controller.dispose);
    var cancelled = 0;
    await tester.pumpWidget(
      app(
        LiquidPrismSearchField(
          controller: controller,
          cancelVisibility: GlassSearchCancelVisibility.always,
          onCancel: () => cancelled++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cancel = find.bySemanticsLabel('Cancel search');
    expect(cancel, findsOneWidget);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(cancelled, 1);
    expect(controller.text, isEmpty);
  });

  testWidgets('the theme sets it; the widget and showCancelButton win', (
    tester,
  ) async {
    const always = GlassSearchStyle(
      cancelVisibility: GlassSearchCancelVisibility.always,
    );
    await tester.pumpWidget(app(const LiquidPrismSearchField(), theme: always));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Cancel search'), findsOneWidget);

    await tester.pumpWidget(
      app(
        const LiquidPrismSearchField(
          cancelVisibility: GlassSearchCancelVisibility.focused,
        ),
        theme: always,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Cancel search'), findsNothing);

    await tester.pumpWidget(
      app(
        const LiquidPrismSearchField(
          showCancelButton: false,
          cancelVisibility: GlassSearchCancelVisibility.always,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Cancel search'), findsNothing);
  });
}
