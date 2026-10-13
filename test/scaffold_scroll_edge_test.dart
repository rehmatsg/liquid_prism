import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

const _body = Key('body');

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(402, 874)
      ..padding = const FakeViewPadding(top: 62, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
  }

  Widget app({
    bool scrollEdge = true,
    Widget? leading,
    List<GlassToolbarItem> actions = const [],
    Color? background = const Color(0xFF101010),
    required ScrollController controller,
  }) => CupertinoApp(
    debugShowCheckedModeBanner: false,
    home: LiquidPrismScaffold(
      scrollEdge: scrollEdge,
      backgroundColor: background,
      leading: leading,
      actions: actions,
      body: ListView.builder(
        key: _body,
        controller: controller,
        itemCount: 60,
        itemBuilder: (context, index) =>
            SizedBox(height: 44, child: Text('Row $index')),
      ),
    ),
  );

  testWidgets(
    'the scaffold draws the effect under its top bar while scrolled',
    (tester) async {
      phone(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          controller: controller,
          actions: [
            GlassToolbarItem(
              icon: const Icon(CupertinoIcons.star),
              label: 'Star',
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(find.byType(LiquidPrismScrollEdge), findsOneWidget);
      expect(
        find.byType(LiquidPrismEdgeBlur),
        findsNothing,
        reason: 'nothing paints at rest',
      );
      final effect = tester.getRect(find.byType(LiquidPrismScrollEdge));
      expect(effect.top, 0);
      expect(effect.height, 62 + LiquidPrismScaffold.topBarHeight);
      expect(effect.width, 402);

      controller.jumpTo(8);
      await tester.pump();
      final blur = find.byType(LiquidPrismEdgeBlur);
      expect(blur, findsOneWidget);
      final spec = tester.widget<LiquidPrismEdgeBlur>(blur).edges.single;
      expect(spec.sigma, GlassScrollEdgeStyle.defaultSigma / 2);
      expect(spec.fadeColor, const Color(0xFF101010));
      expect(spec.extent, 62 + 44 + GlassScrollEdgeStyle.defaultExtension);

      controller.jumpTo(100);
      await tester.pump();
      expect(
        tester.widget<LiquidPrismEdgeBlur>(blur).edges.single.sigma,
        GlassScrollEdgeStyle.defaultSigma,
      );
      // Painted over the body and under the actions.
      final order = [
        find.byKey(_body),
        find.byType(LiquidPrismScrollEdge),
        find.byType(LiquidPrismToolbarGroup),
      ].map((finder) => tester.getRect(finder)).toList();
      expect(order, hasLength(3));
      final scaffold = tester.element(find.byType(LiquidPrismScaffold));
      final painted = <Type>[];
      scaffold.visitChildren((child) {
        void visit(Element element) {
          final widget = element.widget;
          if (widget is LiquidPrismScrollEdge) {
            painted.add(LiquidPrismScrollEdge);
          }
          if (widget is LiquidPrismToolbarGroup) {
            painted.add(LiquidPrismToolbarGroup);
          }
          if (widget.key == _body) painted.add(ListView);
          element.visitChildren(visit);
        }

        visit(child);
      });
      expect(painted, [
        ListView,
        LiquidPrismScrollEdge,
        LiquidPrismToolbarGroup,
      ]);

      controller.jumpTo(0);
      await tester.pump();
      expect(blur, findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('no top bar or an opt-out leaves the body alone', (tester) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller: controller));
    expect(find.byType(LiquidPrismScrollEdge), findsNothing);

    await tester.pumpWidget(
      app(
        controller: controller,
        scrollEdge: false,
        leading: LiquidPrismToolbarGroup(
          size: GlassToolbarSize.navigation,
          items: [
            GlassToolbarItem(
              icon: const Icon(CupertinoIcons.back),
              label: 'Back',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    controller.jumpTo(100);
    await tester.pump();
    expect(find.byType(LiquidPrismScrollEdge), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('without a background the effect blurs only', (tester) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        controller: controller,
        background: null,
        leading: const SizedBox(width: 44, height: 44),
      ),
    );
    controller.jumpTo(100);
    await tester.pump();
    final spec = tester
        .widget<LiquidPrismEdgeBlur>(find.byType(LiquidPrismEdgeBlur))
        .edges
        .single;
    expect(spec.fadeColor, isNull);
    expect(spec.sigma, GlassScrollEdgeStyle.defaultSigma);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
