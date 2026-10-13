import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  test('the fade curve is smootherstep and the gradient samples it', () {
    expect(GlassEdgeFade.curve.transform(0), 0);
    expect(GlassEdgeFade.curve.transform(.5), .5);
    expect(GlassEdgeFade.curve.transform(1), 1);
    // Flat at both ends: the first samples barely move.
    expect(GlassEdgeFade.curve.transform(1 / 16), lessThan(.01));
    expect(GlassEdgeFade.curve.transform(15 / 16), greaterThan(.99));

    final gradient = GlassEdgeFade.gradient(
      color: const Color(0xFF102030),
      plateau: .25,
      opacity: .5,
    );
    expect(gradient.stops!.first, 0);
    expect(gradient.stops![1], .25, reason: 'the plateau ends the solid run');
    expect(gradient.stops!.last, 1);
    expect(gradient.colors.first.a, closeTo(.5, 1e-6));
    expect(gradient.colors.last.a, 0);
    // The fade scales alpha of the one color; it never turns black.
    for (final color in gradient.colors) {
      expect(color.r, closeTo(0x10 / 255, 1e-6));
      expect(color.g, closeTo(0x20 / 255, 1e-6));
      expect(color.b, closeTo(0x30 / 255, 1e-6));
    }
  });

  testWidgets('a fade paints solid at the edge and nothing past the strip', (
    tester,
  ) async {
    expect(LiquidPrism.isShaderSupported, isFalse);
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      glassHarness(
        imageKey: imageKey,
        background: const Color(0xFF000000),
        child: SizedBox(
          width: 200,
          height: 120,
          child: LiquidPrismEdgeBlur(
            edges: const [
              GlassEdgeBlur(
                edge: GlassEdge.top,
                extent: 60,
                sigma: 4,
                plateau: .5,
                fadeColor: Color(0xFFFFFFFF),
              ),
            ],
            child: const ColoredBox(color: Color(0xFF000000)),
          ),
        ),
      ),
    );
    await tester.pump();
    // The harness centres a 200 x 120 box in 240 x 160.
    final pixels = await pixelsAt(tester, imageKey, const [
      Offset(120, 22), // 2 px into the strip: solid
      Offset(120, 48), // the plateau's end: still solid
      Offset(120, 64), // halfway down the falloff: half
      Offset(120, 90), // past the strip: untouched
    ]);
    expect(pixels[0][0], greaterThan(250));
    expect(pixels[1][0], greaterThan(250));
    expect(pixels[2][0], inInclusiveRange(100, 160));
    expect(pixels[3][0], 0);
  });

  testWidgets('keeps child state as strips toggle', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget build(List<GlassEdgeBlur> edges) => CupertinoApp(
      home: LiquidPrismEdgeBlur(
        edges: edges,
        child: ListView.builder(
          controller: controller,
          itemCount: 100,
          itemBuilder: (context, index) =>
              SizedBox(height: 40, child: Text('Row $index')),
        ),
      ),
    );
    await tester.pumpWidget(build(const []));
    controller.jumpTo(400);
    await tester.pump();
    await tester.pumpWidget(
      build(const [
        GlassEdgeBlur(
          edge: GlassEdge.top,
          extent: 60,
          sigma: 3,
          fadeColor: Color(0xFFFFFFFF),
        ),
      ]),
    );
    await tester.pump();
    expect(controller.offset, 400, reason: 'the list state survived');
    await tester.pumpWidget(build(const []));
    expect(controller.offset, 400);
  });

  testWidgets('composites only while a strip is active', (tester) async {
    Widget build(List<GlassEdgeBlur> edges) => CupertinoApp(
      home: LiquidPrismEdgeBlur(
        edges: edges,
        child: const ColoredBox(color: Color(0xFF000000)),
      ),
    );
    await tester.pumpWidget(build(const []));
    final box = tester.renderObject<RenderProxyBox>(
      find.byType(LiquidPrismEdgeBlur),
    );
    expect(box.needsCompositing, isFalse, reason: 'inactive: paints through');
    await tester.pumpWidget(
      build(const [
        GlassEdgeBlur(
          edge: GlassEdge.top,
          extent: 60,
          fadeColor: Color(0xFF0000FF),
        ),
      ]),
    );
    expect(box.needsCompositing, isTrue);
    await tester.pumpWidget(
      build(const [GlassEdgeBlur(edge: GlassEdge.top, extent: 60, sigma: 3)]),
    );
    expect(
      box.needsCompositing,
      isFalse,
      reason: 'a blur without the shader paints nothing',
    );
  });

  testWidgets('rejects two edges of one side or of mixed axes', (tester) async {
    for (final edges in [
      const [
        GlassEdgeBlur(edge: GlassEdge.top, extent: 10, sigma: 1),
        GlassEdgeBlur(edge: GlassEdge.top, extent: 10, sigma: 1),
      ],
      const [
        GlassEdgeBlur(edge: GlassEdge.top, extent: 10, sigma: 1),
        GlassEdgeBlur(edge: GlassEdge.left, extent: 10, sigma: 1),
      ],
    ]) {
      await tester.pumpWidget(
        CupertinoApp(home: LiquidPrismEdgeBlur(edges: edges)),
      );
      expect(tester.takeException(), isAssertionError);
    }
    await tester.pumpWidget(
      const CupertinoApp(
        home: LiquidPrismEdgeBlur(
          edges: [
            GlassEdgeBlur(edge: GlassEdge.top, extent: 10, sigma: 1),
            GlassEdgeBlur(edge: GlassEdge.bottom, extent: 10, sigma: 1),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll edge paints nothing at rest and a strip past its box', (
    tester,
  ) async {
    Widget build(double progress) => CupertinoApp(
      home: Center(
        child: SizedBox(
          width: 300,
          height: 100,
          child: LiquidPrismScrollEdge(
            progress: progress,
            color: const Color(0xFF000000),
          ),
        ),
      ),
    );
    await tester.pumpWidget(build(0));
    expect(find.byType(LiquidPrismEdgeBlur), findsNothing);

    await tester.pumpWidget(build(1));
    final blur = find.byType(LiquidPrismEdgeBlur);
    expect(blur, findsOneWidget);
    // The default effect reaches 20 points below the bar's box.
    expect(tester.getSize(blur), const Size(300, 120));
    final spec = tester.widget<LiquidPrismEdgeBlur>(blur).edges.single;
    expect(spec.edge, GlassEdge.top);
    expect(spec.extent, 120);
    expect(spec.sigma, GlassScrollEdgeStyle.defaultSigma);
    expect(spec.fadeOpacity, GlassScrollEdgeStyle.defaultFadeOpacity);
    // Full strength holds down to 48 points above the strip's end.
    expect(spec.plateau, closeTo(1 - 48 / 120, 1e-9));

    await tester.pumpWidget(build(.5));
    final half = tester.widget<LiquidPrismEdgeBlur>(blur).edges.single;
    expect(half.sigma, GlassScrollEdgeStyle.defaultSigma / 2);
    expect(half.fadeOpacity, GlassScrollEdgeStyle.defaultFadeOpacity / 2);
  });

  testWidgets('scroll edge style resolves theme below direct choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismTheme(
          data: const LiquidPrismThemeData(
            scrollEdge: GlassScrollEdgeStyle(
              sigma: 8,
              extension: 0,
              fadeColor: Color(0xFF112233),
              fadeOpacity: .25,
            ),
          ),
          child: Center(
            child: SizedBox(
              width: 300,
              height: 100,
              child: LiquidPrismScrollEdge(
                progress: 1,
                style: const GlassScrollEdgeStyle(sigma: 6),
              ),
            ),
          ),
        ),
      ),
    );
    final blur = find.byType(LiquidPrismEdgeBlur);
    expect(tester.getSize(blur), const Size(300, 100));
    final spec = tester.widget<LiquidPrismEdgeBlur>(blur).edges.single;
    expect(spec.sigma, 6, reason: 'the widget style wins over the theme');
    expect(spec.fadeColor, const Color(0xFF112233));
    expect(spec.fadeOpacity, .25);
    expect(
      LiquidPrismScrollEdge.progressFor(8, revealExtent: 16),
      .5,
      reason: 'progress rises over the reveal extent',
    );
    expect(LiquidPrismScrollEdge.progressFor(40), 1);
  });

  testWidgets('scroll fade springs its edges in as content scrolls past', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScrollFade(
          color: const Color(0xFF000000),
          sigma: 0,
          child: ListView.builder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (context, index) =>
                SizedBox(height: 40, child: Text('Row $index')),
          ),
        ),
      ),
    );
    await tester.pump();
    List<GlassEdgeBlur> edges() => tester
        .widget<LiquidPrismEdgeBlur>(find.byType(LiquidPrismEdgeBlur))
        .edges;
    expect(edges().map((e) => e.edge), [GlassEdge.bottom]);
    expect(edges().single.fadeOpacity, 1, reason: 'decided without animating');

    controller.jumpTo(200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final top = edges().firstWhere((e) => e.edge == GlassEdge.top);
    expect(top.fadeOpacity, inExclusiveRange(0, 1), reason: 'animating in');
    await tester.pumpAndSettle();
    expect(edges().firstWhere((e) => e.edge == GlassEdge.top).fadeOpacity, 1);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(edges().map((e) => e.edge), [GlassEdge.top]);
  });
}
