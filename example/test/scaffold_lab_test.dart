import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism_example/showcase/scaffold_lab_options.dart';
import 'package:liquid_prism_example/showcase/scaffold_lab_page.dart';

void main() {
  for (final width in [320.0, 440.0]) {
    for (final mode in ['slivers', 'body', 'nested', 'standalone']) {
      testWidgets('lab $mode lays out customized chrome at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final options = ScaffoldLabOptions()
          ..bodyMode = mode == 'body'
          ..scrollDepth = mode == 'nested' ? 1 : 0
          ..sliverAppBar = mode == 'standalone'
          ..rtl = width == 440
          ..placement = width == 440 ? GlassChromePlacement.rightRail : null
          ..titleKind = 3
          ..titleAlignment = GlassTitleAlignment.leading
          ..tabs = true
          ..trailing = true
          ..minimization = GlassToolbarMinimizationBehavior.onScrollDown
          ..values.addAll({
            'controlRowHeight': 52,
            'gutter': 12,
            'titleFontSize': 18,
            'tabBarMaxWidth': 240,
            'bottomBarMaxWidth': 260,
          });
        await tester.pumpWidget(
          CupertinoApp(home: ScaffoldLabPage(initialOptions: options)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scroll = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first;
        await tester.drag(scroll, const Offset(0, -300));
        await tester.pumpAndSettle();
        await tester.drag(scroll, const Offset(0, 150));
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scroll).position.pixels,
          greaterThan(0),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidPrismTabBar), findsOneWidget);
      });
    }
  }

  for (final behavior in GlassToolbarMinimizationBehavior.values) {
    testWidgets('lab accessory stays visible with $behavior', (tester) async {
      final options = ScaffoldLabOptions()..minimization = behavior;
      await tester.pumpWidget(
        CupertinoApp(home: ScaffoldLabPage(initialOptions: options)),
      );
      await tester.pumpAndSettle();
      final scroll = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first;
      final toggle = find.byKey(const ValueKey('lab-Accessory row'));
      await tester.scrollUntilVisible(toggle, 250, scrollable: scroll);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      final accessory = tester.getRect(
        find.byKey(const ValueKey('lab-accessory')),
      );
      expect(accessory.top, greaterThanOrEqualTo(0));
      expect(accessory.bottom, lessThan(600));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('all advanced sections fit a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const sections = [
      'Structure and placement',
      'Alignment and minimization',
      'Navigation geometry',
      'Title motion',
      'Title capsule',
      'Docks',
      'Scroll edge',
      'title typography',
      'largeTitle typography',
      'subtitle typography',
      'largeSubtitle typography',
    ];
    final options = ScaffoldLabOptions()..expanded.addAll(sections);
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: ScaffoldLabPage(initialOptions: options),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    for (final section in sections) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('lab-expand-$section')),
        350,
        scrollable: scroll,
        maxScrolls: 60,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'lab controls change title composition and reset native overrides',
    (tester) async {
      final options = ScaffoldLabOptions()
        ..expanded.add('Structure and placement');
      await tester.pumpWidget(
        CupertinoApp(home: ScaffoldLabPage(initialOptions: options)),
      );
      await tester.pumpAndSettle();
      final composition = find.byKey(const ValueKey('lab-Title composition'));
      await tester.scrollUntilVisible(
        composition,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(composition);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidPrismTitle), findsOneWidget);
      await tester.tap(composition);
      await tester.pumpAndSettle();
      expect(
        tester.widget<LiquidPrismTitle>(find.byType(LiquidPrismTitle)).avatar,
        isNotNull,
      );
      final geometry = find.byKey(
        const ValueKey('lab-expand-Navigation geometry'),
      );
      await tester.scrollUntilVisible(
        geometry,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(geometry), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(geometry);
      await tester.pumpAndSettle();
      final enabled = find.byKey(const ValueKey('lab-enable-controlRowHeight'));
      await Scrollable.ensureVisible(tester.element(enabled), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(enabled);
      await tester.pumpAndSettle();
      final heightSlider = find.byKey(const ValueKey('lab-controlRowHeight'));
      await Scrollable.ensureVisible(
        tester.element(heightSlider),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.drag(heightSlider, const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LiquidPrismScaffold>(find.byType(LiquidPrismScaffold))
            .navigationBarStyle!
            .controlRowHeight,
        greaterThan(44),
      );
      final reset = find.byKey(const ValueKey('lab-reset'));
      await tester.scrollUntilVisible(
        reset,
        500,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LiquidPrismScaffold>(find.byType(LiquidPrismScaffold))
            .title,
        isA<Text>(),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
