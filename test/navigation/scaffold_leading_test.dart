import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/rendering/surface.dart';

void main() {
  Widget app({
    bool imply = true,
    bool fullscreenDialog = false,
    TextDirection direction = TextDirection.ltr,
    PrismToolbarStyle? toolbar,
  }) => CupertinoApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => Directionality(
      textDirection: direction,
      child: PrismTheme(
        data: PrismThemeData(toolbar: toolbar),
        child: child!,
      ),
    ),
    home: Builder(
      builder: (context) => PrismScaffold(
        body: Center(
          child: CupertinoButton(
            onPressed: () => Navigator.of(context).push<void>(
              CupertinoPageRoute(
                fullscreenDialog: fullscreenDialog,
                builder: (_) => PrismScaffold(
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
    expect(find.byType(PrismBackButton), findsNothing);
    final rootPadding = MediaQuery.paddingOf(tester.element(find.text('Open')));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);

    final padding = MediaQuery.paddingOf(tester.element(find.text('Detail')));
    expect(padding.top, rootPadding.top + 44 + PrismScaffold.topBarClearance);

    final circle = tester.getCenter(find.byType(RawPrismSurface));
    final glyph = tester.getCenter(find.byIcon(CupertinoIcons.chevron_back));
    expect(glyph.dx - circle.dx, closeTo(-.5, .01));

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(PrismBackButton), findsNothing);
  });

  testWidgets('a fullscreen dialog gets a close mark', (tester) async {
    await tester.pumpWidget(app(fullscreenDialog: true));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    final circle = tester.getCenter(find.byType(RawPrismSurface));
    final glyph = tester.getCenter(find.byIcon(CupertinoIcons.xmark));
    expect(glyph.dx - circle.dx, closeTo(0, .01), reason: 'no shift');
  });

  testWidgets('opting out leaves the route without a top bar', (tester) async {
    await tester.pumpWidget(app(imply: false));
    final rootPadding = MediaQuery.paddingOf(tester.element(find.text('Open')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(PrismBackButton), findsNothing);
    final padding = MediaQuery.paddingOf(tester.element(find.text('Detail')));
    expect(padding.top, rootPadding.top);
  });

  testWidgets('the chevron shift mirrors in right-to-left layouts', (
    tester,
  ) async {
    await tester.pumpWidget(app(direction: TextDirection.rtl));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final circle = tester.getCenter(find.byType(RawPrismSurface));
    final glyph = tester.getCenter(find.byIcon(CupertinoIcons.chevron_back));
    expect(glyph.dx - circle.dx, closeTo(.5, .01));
  });

  testWidgets('a custom icon and action replace the defaults', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: PrismBackButton(
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

  testWidgets('themed glyphs reach the implied button', (tester) async {
    const toolbar = PrismToolbarStyle(
      backIcon: Icon(CupertinoIcons.arrow_left),
      closeIcon: Icon(CupertinoIcons.clear_circled),
      backIconShift: 1,
      backIconMirrors: false,
    );

    await tester.pumpWidget(
      app(direction: TextDirection.rtl, toolbar: toolbar),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.chevron_back), findsNothing);
    final circle = tester.getCenter(find.byType(RawPrismSurface));
    final glyph = tester.getCenter(find.byIcon(CupertinoIcons.arrow_left));
    expect(glyph.dx - circle.dx, closeTo(-1, .01));

    await tester.pumpWidget(Container());
    await tester.pumpWidget(app(fullscreenDialog: true, toolbar: toolbar));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.clear_circled), findsOneWidget);
  });

  testWidgets(
    'local back button style overrides the theme, explicit zero included',
    (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: PrismTheme(
            data: PrismThemeData(
              toolbar: PrismToolbarStyle(
                backIcon: Icon(CupertinoIcons.arrow_left),
                backIconShift: 2,
              ),
            ),
            child: Center(
              child: PrismBackButton(
                icon: Icon(CupertinoIcons.back),
                style: PrismToolbarStyle(backIconShift: 0),
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(CupertinoIcons.arrow_left), findsNothing);
      final circle = tester.getCenter(find.byType(RawPrismSurface));
      final glyph = tester.getCenter(find.byIcon(CupertinoIcons.back));
      expect(glyph.dx - circle.dx, closeTo(0, .01));
    },
  );
}
