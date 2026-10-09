import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  testWidgets(
    'explicit button artwork remains literal across backdrop and tint changes',
    (tester) async {
      final imageKey = GlobalKey();
      const tint = Color(0xFF805040);
      const source = Color(0xFFCC1133);
      Future<List<List<int>>> render({
        required Brightness brightness,
        required Color background,
        Color accent = tint,
        bool composited = false,
      }) async {
        const mask = SizedBox(
          width: 20,
          height: 30,
          child: ColoredBox(color: source),
        );
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            background: background,
            child: LiquidPrismTheme(
              brightness: brightness,
              tint: accent,
              child: LiquidPrismButton(
                label: 'Color action',
                padding: EdgeInsets.zero,
                onPressed: () {},
                child: SizedBox(
                  width: 160,
                  height: 80,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 90,
                        top: 25,
                        child: composited ? RepaintBoundary(child: mask) : mask,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return pixelsAt(tester, imageKey, const [
          Offset(100, 80),
          Offset(140, 80),
        ]);
      }

      for (final brightness in [Brightness.dark, Brightness.light]) {
        for (final background in [
          const Color(0xFF202020),
          const Color(0xFFB0B0B0),
        ]) {
          final pixels = await render(
            brightness: brightness,
            background: background,
          );
          expect(pixels.last, [
            204,
            17,
            51,
            255,
          ], reason: '$brightness on $background preserves explicit artwork');
        }
      }
      final composited = await render(
        brightness: Brightness.dark,
        background: const Color(0xFF666666),
        composited: true,
      );
      expect(composited.last, [204, 17, 51, 255]);
      final translucentTint = await render(
        brightness: Brightness.dark,
        background: const Color(0xFF666666),
        accent: const Color(0x80805040),
      );
      expect(translucentTint.last, [204, 17, 51, 255]);
    },
  );

  testWidgets(
    'transparent tint and tint removal preserve a custom base material',
    (tester) async {
      final imageKey = GlobalKey();
      final style = LiquidPrismStyle.clear.copyWith(
        tint: const Color(0xFF0000FF),
      );
      Future<List<int>> render(Glass glass, {bool customStyle = true}) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            child: LiquidPrism(
              glass: glass,
              optics: customStyle ? style : null,
              child: const SizedBox(width: 160, height: 80),
            ),
          ),
        );
        return (await pixelsAt(tester, imageKey, [
          const Offset(120, 80),
        ])).single;
      }

      const material = Glass.clear;
      final base = await render(material);
      expect(base, [0, 0, 255, 255]);
      final tinted = material.tint(const Color(0x80FF0000));
      expect(await render(tinted), [128, 0, 127, 255]);
      expect(await render(tinted.interactive().interactive(false)), [
        128,
        0,
        127,
        255,
      ]);
      expect(await render(material), base);
      expect(await render(tinted.tint(const Color(0x00FF0000))), base);
      expect(await render(tinted.tint(null)), base);
      final defaultBase = await render(material, customStyle: false);
      expect(await render(tinted, customStyle: false), isNot(defaultBase));
      expect(
        await render(tinted.tint(const Color(0x00FF0000)), customStyle: false),
        defaultBase,
      );
      expect(await render(tinted.tint(null), customStyle: false), defaultBase);
    },
  );

  testWidgets('shape clips an inscribed circle without changing child layout', (
    tester,
  ) async {
    const childKey = ValueKey('shape-content');
    final imageKey = GlobalKey();
    var taps = 0;
    Future<List<List<int>>> render({
      Glass glass = Glass.clear,
      GlassShape? shape,
    }) async {
      await tester.pumpWidget(
        glassHarness(
          imageKey: imageKey,
          child: LiquidPrism(
            glass: glass,
            shape: shape,
            optics: LiquidPrismStyle.clear.copyWith(cornerRadius: 40),
            child: Semantics(
              label: 'Child content',
              button: true,
              onTap: () => taps++,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => taps++,
                excludeFromSemantics: true,
                child: const SizedBox(
                  key: childKey,
                  width: 160,
                  height: 80,
                  child: ColoredBox(color: Color(0xFF00FF00)),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(childKey)), const Size(160, 80));
      return pixelsAt(tester, imageKey, const [
        Offset(50, 50),
        Offset(50, 80),
        Offset(120, 80),
        Offset(190, 80),
      ]);
    }

    const green = [0, 255, 0, 255];
    final rounded = await render();
    expect(rounded[0], isNot(green));
    expect(rounded[1], green);
    final rectangle = await render(
      shape: const GlassShape.rect(cornerRadius: 0),
    );
    expect(rectangle, everyElement(green));
    final circle = await render(shape: GlassShape.circle);
    expect(circle[1], isNot(green));
    expect(circle[2], green);
    expect(circle[3], isNot(green));
    final identity = await render(
      glass: Glass.identity.tint(const Color(0xFFFF0000)).interactive(),
      shape: GlassShape.circle,
    );
    expect(identity, everyElement(green));
    final child = find.byKey(childKey);
    final pointer = await tester.startGesture(tester.getCenter(child));
    await tester.pumpAndSettle();
    expect(visibleWidth(tester, child), 160);
    await pointer.up();
    await tester.pump();
    expect(taps, 1);
    expect(find.bySemanticsLabel('Child content'), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('Child content'));
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('live explicit appearance overrides platform fallback material', (
    tester,
  ) async {
    final imageKey = GlobalKey();
    Future<List<int>> render(Brightness platform, Brightness? override) async {
      const lens = LiquidPrism(child: SizedBox(width: 160, height: 80));
      await tester.pumpWidget(
        glassHarness(
          imageKey: imageKey,
          platformBrightness: platform,
          child: override == null
              ? lens
              : LiquidPrismTheme(brightness: override, child: lens),
        ),
      );
      return (await pixelsAt(tester, imageKey, [const Offset(120, 80)])).single;
    }

    final dark = await render(Brightness.dark, null);
    final light = await render(Brightness.light, null);
    expect(light.first, greaterThan(dark.first));
    expect(await render(Brightness.light, Brightness.dark), dark);
    expect(await render(Brightness.dark, Brightness.light), light);
  });

  testWidgets(
    'selected material grades the backdrop and leaves foreground intact',
    (tester) async {
      final imageKey = GlobalKey();
      Future<List<List<int>>> render(
        Brightness brightness,
        bool selected,
      ) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            platformBrightness: brightness,
            child: LiquidPrismSelection(
              selected: selected,
              child: const SizedBox(
                width: 160,
                height: 80,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: ColoredBox(color: Color(0xFFFF0000)),
                  ),
                ),
              ),
            ),
          ),
        );
        return pixelsAt(tester, imageKey, const [
          Offset(120, 80),
          Offset(180, 80),
        ]);
      }

      final unselected = await render(Brightness.dark, false);
      final dark = await render(Brightness.dark, true);
      final light = await render(Brightness.light, true);
      expect(dark.first.first, lessThan(unselected.first.first));
      expect(light.first.first, lessThan(unselected.first.first));
      expect(dark.last, [255, 0, 0, 255]);
      expect(light.last, [255, 0, 0, 255]);
      expect(await render(Brightness.light, false), unselected);
    },
  );

  testWidgets(
    'prominent button applies theme tint to its face and preserves contrast',
    (tester) async {
      final imageKey = GlobalKey();
      Future<List<List<int>>> render(GlassButtonStyle style, Color tint) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            child: LiquidPrismTheme(
              brightness: Brightness.dark,
              tint: tint,
              child: LiquidPrismButton(
                label: 'Action',
                buttonStyle: style,
                onPressed: () {},
                padding: EdgeInsets.zero,
                child: SizedBox(
                  width: 160,
                  height: 80,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Builder(
                      builder: (context) => SizedBox(
                        width: 30,
                        height: 30,
                        child: ColoredBox(
                          color: DefaultTextStyle.of(context).style.color!,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return pixelsAt(tester, imageKey, const [
          Offset(120, 80),
          Offset(180, 80),
        ]);
      }

      const purple = Color(0xFFAA00CC);
      final plain = await render(GlassButtonStyle.glass, purple);
      expect(plain.last[0], greaterThan(plain.last[1]));
      expect(plain.last[2], greaterThan(plain.last[1]));
      final prominent = await render(GlassButtonStyle.glassProminent, purple);
      expect(prominent.first, [170, 0, 204, 255]);
      expect(prominent.first, isNot(plain.first));
      expect(prominent.last, [255, 255, 255, 255]);
      final changed = await render(
        GlassButtonStyle.glassProminent,
        const Color(0xFF00AA44),
      );
      expect(changed.first, [0, 170, 68, 255]);
      expect(changed.last, prominent.last);
    },
  );
}
