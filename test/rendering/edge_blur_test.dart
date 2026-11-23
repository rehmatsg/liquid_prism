import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';

import '../support/rendering.dart';

void main() {
  test('the fade curve is smootherstep and the gradient samples it', () {
    expect(PrismEdgeFade.curve.transform(0), 0);
    expect(PrismEdgeFade.curve.transform(.5), .5);
    expect(PrismEdgeFade.curve.transform(1), 1);

    expect(PrismEdgeFade.curve.transform(1 / 16), lessThan(.02));
    expect(PrismEdgeFade.curve.transform(15 / 16), greaterThan(.98));

    final gradient = PrismEdgeFade.gradient(
      color: const Color(0xFF102030),
      plateau: .25,
      opacity: .5,
    );
    expect(gradient.stops!.first, 0);
    expect(gradient.stops![1], .25, reason: 'the plateau ends the solid run');
    expect(gradient.stops!.last, 1);
    expect(gradient.colors.first.a, closeTo(.5, 1e-6));
    expect(gradient.colors.last.a, 0);

    for (final color in gradient.colors) {
      expect(color.r, closeTo(0x10 / 255, 1e-6));
      expect(color.g, closeTo(0x20 / 255, 1e-6));
      expect(color.b, closeTo(0x30 / 255, 1e-6));
    }
  });

  testWidgets('a fade paints solid at the edge and nothing past the strip', (
    tester,
  ) async {
    expect(Prism.isShaderSupported, isFalse);
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      glassHarness(
        imageKey: imageKey,
        background: const Color(0xFF000000),
        child: const SizedBox(
          width: 200,
          height: 120,
          child: PrismEdgeBlur(
            edges: [
              PrismEdgeBlurStrip(
                edge: PrismEdge.top,
                extent: 60,
                sigma: 4,
                plateau: .5,
                fadeColor: Color(0xFFFFFFFF),
              ),
            ],
            child: ColoredBox(color: Color(0xFF000000)),
          ),
        ),
      ),
    );
    await tester.pump();

    final pixels = await pixelsAt(tester, imageKey, const [
      Offset(120, 22),
      Offset(120, 48),
      Offset(120, 64),
      Offset(120, 90),
    ]);
    expect(pixels[0][0], greaterThan(250));
    expect(pixels[1][0], greaterThan(250));
    expect(pixels[2][0], inInclusiveRange(100, 160));
    expect(pixels[3][0], 0);
  });

  testWidgets('a solid fade covers the content up to a fractional box edge', (
    tester,
  ) async {
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      glassHarness(
        imageKey: imageKey,
        background: const Color(0xFF000000),

        child: const SizedBox(
          width: 199,
          height: 119,
          child: PrismEdgeBlur(
            edges: [
              PrismEdgeBlurStrip(
                edge: PrismEdge.bottom,
                extent: 40,
                sigma: 0,
                plateau: .5,
                fadeColor: Color(0xFF000000),
              ),
            ],
            child: ColoredBox(color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
    await tester.pump();

    final pixels = await pixelsAt(tester, imageKey, const [
      Offset(120, 139),
      Offset(219, 130),
      Offset(120, 60),
    ]);
    expect(pixels[0][0], 0, reason: 'content leaks under the outer edge');
    expect(pixels[1][0], 0, reason: 'content leaks under the side edge');
    expect(pixels[2][0], greaterThan(250));
  });

  testWidgets('keeps child state as strips toggle', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget build(List<PrismEdgeBlurStrip> edges) => CupertinoApp(
      home: PrismEdgeBlur(
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
        PrismEdgeBlurStrip(
          edge: PrismEdge.top,
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
    Widget build(List<PrismEdgeBlurStrip> edges) => CupertinoApp(
      home: PrismEdgeBlur(
        edges: edges,
        child: const ColoredBox(color: Color(0xFF000000)),
      ),
    );
    await tester.pumpWidget(build(const []));
    final box = tester.renderObject<RenderProxyBox>(find.byType(PrismEdgeBlur));
    expect(box.needsCompositing, isFalse, reason: 'inactive: paints through');
    await tester.pumpWidget(
      build(const [
        PrismEdgeBlurStrip(
          edge: PrismEdge.top,
          extent: 60,
          fadeColor: Color(0xFF0000FF),
        ),
      ]),
    );
    expect(box.needsCompositing, isTrue);
    await tester.pumpWidget(
      build(const [
        PrismEdgeBlurStrip(edge: PrismEdge.top, extent: 60, sigma: 3),
      ]),
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
        PrismEdgeBlurStrip(edge: PrismEdge.top, extent: 10, sigma: 1),
        PrismEdgeBlurStrip(edge: PrismEdge.top, extent: 10, sigma: 1),
      ],
      const [
        PrismEdgeBlurStrip(edge: PrismEdge.top, extent: 10, sigma: 1),
        PrismEdgeBlurStrip(edge: PrismEdge.left, extent: 10, sigma: 1),
      ],
    ]) {
      await tester.pumpWidget(CupertinoApp(home: PrismEdgeBlur(edges: edges)));
      expect(tester.takeException(), isAssertionError);
    }
    await tester.pumpWidget(
      const CupertinoApp(
        home: PrismEdgeBlur(
          edges: [
            PrismEdgeBlurStrip(edge: PrismEdge.top, extent: 10, sigma: 1),
            PrismEdgeBlurStrip(edge: PrismEdge.bottom, extent: 10, sigma: 1),
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
          child: PrismScrollEdge(
            progress: progress,
            color: const Color(0xFF000000),
          ),
        ),
      ),
    );
    await tester.pumpWidget(build(0));
    expect(find.byType(PrismEdgeBlur), findsNothing);

    await tester.pumpWidget(build(1));
    final blur = find.byType(PrismEdgeBlur);
    expect(blur, findsOneWidget);

    expect(tester.getSize(blur), const Size(300, 150));
    final spec = tester.widget<PrismEdgeBlur>(blur).edges.single;
    expect(spec.edge, PrismEdge.top);
    expect(spec.extent, 150);
    expect(spec.sigma, PrismScrollEdgeStyle.defaultSigma);
    expect(spec.fadeOpacity, PrismScrollEdgeStyle.defaultFadeOpacity);

    expect(spec.plateau, closeTo(1 - 98 / 150, 1e-9));
    expect(spec.haze, PrismScrollEdgeStyle.defaultHaze);

    await tester.pumpWidget(build(.5));
    final half = tester.widget<PrismEdgeBlur>(blur).edges.single;
    expect(half.sigma, PrismScrollEdgeStyle.defaultSigma / 2);
    expect(half.fadeOpacity, PrismScrollEdgeStyle.defaultFadeOpacity / 2);
  });

  testWidgets('scroll edge style resolves theme below direct choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: PrismTheme(
          data: PrismThemeData(
            scrollEdge: PrismScrollEdgeStyle(
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
              child: PrismScrollEdge(
                progress: 1,
                style: PrismScrollEdgeStyle(sigma: 6),
              ),
            ),
          ),
        ),
      ),
    );
    final blur = find.byType(PrismEdgeBlur);
    expect(tester.getSize(blur), const Size(300, 100));
    final spec = tester.widget<PrismEdgeBlur>(blur).edges.single;
    expect(spec.sigma, 6, reason: 'the widget style wins over the theme');
    expect(spec.fadeColor, const Color(0xFF112233));
    expect(spec.fadeOpacity, .25);
    expect(
      PrismScrollEdge.progressFor(8, revealExtent: 16),
      .5,
      reason: 'progress rises over the reveal extent',
    );
    expect(PrismScrollEdge.progressFor(40), 1);
  });

  testWidgets('scroll fade springs its edges in as content scrolls past', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: PrismScrollEdge.fade(
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
    List<PrismEdgeBlurStrip> edges() =>
        tester.widget<PrismEdgeBlur>(find.byType(PrismEdgeBlur)).edges;
    expect(edges().map((e) => e.edge), [PrismEdge.bottom]);
    expect(edges().single.fadeOpacity, 1, reason: 'decided without animating');

    controller.jumpTo(200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final top = edges().firstWhere((e) => e.edge == PrismEdge.top);
    expect(top.fadeOpacity, inExclusiveRange(0, 1), reason: 'animating in');
    await tester.pumpAndSettle();
    expect(edges().firstWhere((e) => e.edge == PrismEdge.top).fadeOpacity, 1);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(edges().map((e) => e.edge), [PrismEdge.top]);
  });
}
