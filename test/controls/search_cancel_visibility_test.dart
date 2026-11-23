import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  Widget app(Widget field, {PrismSearchStyle? theme}) => CupertinoApp(
    home: PrismTheme(
      data: PrismThemeData(search: theme),
      child: Center(child: SizedBox(width: 360, child: field)),
    ),
  );

  testWidgets('by default the cancel action shows only while focused', (
    tester,
  ) async {
    await tester.pumpWidget(app(const PrismSearchField()));
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
        PrismSearchField(
          controller: controller,
          onCancel: () => cancelled++,
          style: const PrismSearchStyle(
            cancelVisibility: PrismSearchCancelVisibility.always,
          ),
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

  testWidgets(
    'local cancel visibility overrides theme and respects showCancelButton',
    (tester) async {
      const always = PrismSearchStyle(
        cancelVisibility: PrismSearchCancelVisibility.always,
      );
      await tester.pumpWidget(app(const PrismSearchField(), theme: always));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Cancel search'), findsOneWidget);

      await tester.pumpWidget(
        app(
          const PrismSearchField(
            style: PrismSearchStyle(
              cancelVisibility: PrismSearchCancelVisibility.focused,
            ),
          ),
          theme: always,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Cancel search'), findsNothing);

      await tester.pumpWidget(
        app(
          const PrismSearchField(
            style: PrismSearchStyle(
              showCancelButton: false,
              cancelVisibility: PrismSearchCancelVisibility.always,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Cancel search'), findsNothing);
    },
  );
}
