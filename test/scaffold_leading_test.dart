import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  Widget app({
    bool imply = true,
    bool fullscreenDialog = false,
    TextDirection direction = TextDirection.ltr,
  }) => CupertinoApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) =>
        Directionality(textDirection: direction, child: child!),
    home: Builder(
      builder: (context) => LiquidPrismScaffold(
        body: Center(
          child: CupertinoButton(
            onPressed: () => Navigator.of(context).push<void>(
              CupertinoPageRoute(
                fullscreenDialog: fullscreenDialog,
                builder: (_) => LiquidPrismScaffold(
                  automaticallyImplyLeading: imply,
                  body: const Center(child: Text('Detail')),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  testWidgets('the root route gets no leading; a pushed one gets back', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.byType(LiquidPrismBackButton), findsNothing);
    final rootPadding = MediaQuery.paddingOf(tester.element(find.text('Open')));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
    // A top bar now exists: the body clears its 44-point row by 14.
    final padding = MediaQuery.paddingOf(tester.element(find.text('Detail')));
    expect(padding.top, rootPadding.top + 44 + 14);
    // The chevron sits half a point toward its tip.
    final circle = tester.getCenter(find.byType(LiquidPrism));
    final glyph = tester.getCenter(find.byIcon(CupertinoIcons.chevron_back));
    expect(glyph.dx - circle.dx, closeTo(-.5, .01));

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(LiquidPrismBackButton), findsNothing);
  });

  testWidgets('a fullscreen dialog gets a close mark', (tester) async {
    await tester.pumpWidget(app(fullscreenDialog: true));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    final circle = tester.getCenter(find.byType(LiquidPrism));
    final glyph = tester.getCenter(find.byIcon(CupertinoIcons.xmark));
    expect(glyph.dx - circle.dx, closeTo(0, .01), reason: 'no shift');
  });

  testWidgets('opting out leaves the route without a top bar', (tester) async {
    await tester.pumpWidget(app(imply: false));
    final rootPadding = MediaQuery.paddingOf(tester.element(find.text('Open')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidPrismBackButton), findsNothing);
    final padding = MediaQuery.paddingOf(tester.element(find.text('Detail')));
    expect(padding.top, rootPadding.top);
  });

  testWidgets('the chevron shift mirrors in right-to-left layouts', (
    tester,
  ) async {
    await tester.pumpWidget(app(direction: TextDirection.rtl));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final circle = tester.getCenter(find.byType(LiquidPrism));
    final glyph = tester.getCenter(find.byIcon(CupertinoIcons.chevron_back));
    expect(glyph.dx - circle.dx, closeTo(.5, .01));
  });

  testWidgets('a custom icon and action replace the defaults', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismBackButton(
          icon: const Icon(CupertinoIcons.arrow_left),
          label: 'Return',
          onPressed: () => pressed++,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Return'));
    expect(pressed, 1);
    expect(find.byIcon(CupertinoIcons.arrow_left), findsOneWidget);
  });
}
