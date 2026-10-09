import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  testWidgets(
    'rendered tab colors preserve explicit text and artwork over calibration',
    (tester) async {
      final imageKey = GlobalKey();
      const iconKey = ValueKey('color-icon');
      const sourceIcon = Icon(IconData(0x4D, fontFamily: 'Ahem'), key: iconKey);
      const labelGreen = Color(0xFF00CC44);
      const localRed = Color(0xFFDD0022);
      const textYellow = Color(0xFFFFCC00);
      Future<void> render({
        Color? appLabel = labelGreen,
        Color? appSelected,
        Color? selected,
        Color? label,
        Color? tint,
        Color? foreground,
        bool enabled = true,
        Widget icon = sourceIcon,
      }) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            background: const Color(0xFF000000),
            child: LiquidPrismTheme(
              data: LiquidPrismThemeData(
                tint: tint,
                foregroundColor: foreground,
                tabBar: GlassTabBarStyle(
                  selectedColor: appSelected,
                  labelStyle: TextStyle(color: appLabel),
                ),
              ),
              child: LiquidPrismTabBar(
                glass: Glass.identity,
                selectedIndex: 0,
                onSelected: enabled ? (_) {} : null,
                style: GlassTabBarStyle(
                  padding: EdgeInsets.zero,
                  selectedColor: selected,
                  selectionColor: const Color(0x00000000),
                  labelStyle: TextStyle(
                    color: label,
                    fontFamily: 'Ahem',
                    fontSize: 20,
                  ),
                ),
                tabs: [
                  LiquidPrismTab(label: 'M', icon: icon),
                  const LiquidPrismTab(label: 'NN', icon: SizedBox.shrink()),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
      }

      Future<List<List<int>>> samples() {
        final origin = tester.getTopLeft(find.byKey(imageKey));
        return pixelsAt(tester, imageKey, [
          tester.getCenter(find.byKey(iconKey)) - origin,
          tester.getCenter(find.text('M')) - origin,
        ]);
      }

      await render();
      expect((await samples())[1], [0, 204, 68, 255]);
      await render(appSelected: const Color(0xFF9933CC));
      expect(await samples(), [
        [153, 51, 204, 255],
        [0, 204, 68, 255],
      ]);
      await render(appSelected: const Color(0xFF9933CC), selected: localRed);
      expect(await samples(), [
        [221, 0, 34, 255],
        [0, 204, 68, 255],
      ]);
      await render(selected: localRed, label: textYellow);
      expect(await samples(), [
        [221, 0, 34, 255],
        [255, 204, 0, 255],
      ]);
      await render(
        selected: localRed,
        foreground: const Color(0xFF8844CC),
        enabled: false,
      );
      final disabled = await samples();
      expect(disabled[1], [0, 204, 68, 255]);
      // Source disabled color #4CEBEBF5 composited on the known black face.
      for (var channel = 0; channel < 3; channel++) {
        expect(disabled[0][channel], closeTo([70, 70, 73][channel], 1));
      }
      await render(
        appLabel: null,
        selected: localRed,
        foreground: const Color(0xFF8844CC),
        enabled: false,
      );
      final allDisabled = await samples();
      expect(allDisabled[0], disabled[0]);
      expect(allDisabled[1], disabled[0]);
      await render(
        icon: const Icon(
          IconData(0x4D, fontFamily: 'Ahem'),
          key: iconKey,
          color: Color(0xFF11BB66),
        ),
      );
      expect((await samples())[0], [17, 187, 102, 255]);
      await render(
        icon: const SizedBox(
          key: iconKey,
          width: 24,
          height: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ColoredBox(color: Color(0xFFFF0000))),
              Expanded(child: ColoredBox(color: Color(0xFF0000FF))),
            ],
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byKey(imageKey));
      final center = tester.getCenter(find.byKey(iconKey)) - origin;
      expect(
        await pixelsAt(tester, imageKey, [
          center - const Offset(6, 0),
          center + const Offset(6, 0),
        ]),
        [
          [255, 0, 0, 255],
          [0, 0, 255, 255],
        ],
      );
      await render(appLabel: null, tint: const Color(0x806622AA));
      for (final pixel in await samples()) {
        for (var channel = 0; channel < 3; channel++) {
          expect(pixel[channel], closeTo([51, 17, 85][channel], 1));
        }
      }
      await render();
      expect((await samples())[1], [0, 204, 68, 255]);
    },
  );

  testWidgets(
    'nested defaults update live while explicit identity and false interaction override inheritance',
    (tester) async {
      final imageKey = GlobalKey();
      const face = ValueKey('theme-face');
      const bare = SizedBox(key: face, width: 160, height: 80);
      Future<List<int>> render({
        Glass? explicit,
        bool inherit = true,
        Glass? inherited,
        Color tint = const Color(0xFF0000FF),
        double pressScale = 1.15,
      }) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            child: LiquidPrismTheme(
              data: LiquidPrismThemeData(
                glass: inherited ?? Glass.regular.interactive(),
                optics: LiquidPrismStyle.clear.copyWith(tint: tint),
                motion: GlassMotion(pressScale: pressScale),
              ),
              child: LiquidPrismTheme(
                inherit: inherit,
                data: const LiquidPrismThemeData(tint: Color(0xFFAA00CC)),
                child: LiquidPrism(glass: explicit, child: bare),
              ),
            ),
          ),
        );
        return (await pixelsAt(tester, imageKey, [
          const Offset(120, 80),
        ])).single;
      }

      expect(await render(), [0, 0, 255, 255]);
      final held = await tester.startGesture(
        tester.getCenter(find.byKey(face)),
      );
      await tester.pumpAndSettle();
      expect(visibleWidth(tester, find.byKey(face)), closeTo(184, .001));
      await held.cancel();
      await tester.pumpAndSettle();
      final withoutScale = await render(pressScale: 1);
      final colorOnly = await tester.startGesture(
        tester.getCenter(find.byKey(face)),
      );
      await tester.pumpAndSettle();
      expect(visibleWidth(tester, find.byKey(face)), 160);
      expect(
        (await pixelsAt(tester, imageKey, [const Offset(120, 80)])).single,
        isNot(withoutScale),
        reason: 'A scale of one must retain nonspatial press feedback',
      );
      await colorOnly.cancel();
      await tester.pumpAndSettle();
      expect(
        (await pixelsAt(tester, imageKey, [const Offset(120, 80)])).single,
        withoutScale,
      );
      expect(await render(tint: const Color(0xFFFF0000)), [255, 0, 0, 255]);
      await render(explicit: Glass.regular.interactive(false));
      final noFeedback = await tester.startGesture(
        tester.getCenter(find.byKey(face)),
      );
      await tester.pumpAndSettle();
      expect(visibleWidth(tester, find.byKey(face)), 160);
      await noFeedback.cancel();
      expect(await render(explicit: Glass.identity), [102, 102, 102, 255]);
      expect(find.byType(LiquidPrismPressable), findsNothing);
      final reset = await render(inherit: false);
      await tester.pumpWidget(
        glassHarness(
          imageKey: imageKey,
          child: const LiquidPrism(child: bare),
        ),
      );
      expect(
        (await pixelsAt(tester, imageKey, [const Offset(120, 80)])).single,
        reset,
      );
    },
  );

  testWidgets(
    'explicit optics and zero blur win over inherited blur with observable backdrop pixels',
    (tester) async {
      final imageKey = GlobalKey();
      final clear = LiquidPrismStyle.clear.copyWith(
        tint: const Color(0x00000000),
      );
      Future<List<List<int>>> render({
        LiquidPrismThemeData theme = const LiquidPrismThemeData(),
        LiquidPrismStyle? optics,
        double? blur,
      }) async {
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFF000000),
            builder: (context, _) => Center(
              child: RepaintBoundary(
                key: imageKey,
                child: SizedBox(
                  width: 240,
                  height: 160,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ColoredBox(color: Color(0xFF000000)),
                            ),
                            Expanded(
                              child: ColoredBox(color: Color(0xFFFFFFFF)),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: LiquidPrismTheme(
                          data: theme,
                          child: LiquidPrism(
                            optics: optics,
                            blur: blur,
                            child: const SizedBox(width: 160, height: 80),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return pixelsAt(tester, imageKey, const [
          Offset(108, 80),
          Offset(116, 80),
          Offset(124, 80),
          Offset(132, 80),
        ]);
      }

      final zero = await render(optics: clear.copyWith(frost: 0));
      final two = await render(optics: clear.copyWith(frost: 2));
      final eight = await render(optics: clear.copyWith(frost: 8));
      expect(zero, isNot(eight));
      final app = LiquidPrismThemeData(
        optics: clear.copyWith(frost: 2),
        blur: 8,
      );
      expect(await render(theme: app), eight);
      expect(await render(theme: app, optics: clear.copyWith(frost: 2)), two);
      expect(await render(theme: app, blur: 0), zero);
      expect(
        await render(theme: app, optics: clear.copyWith(frost: 8), blur: 0),
        zero,
      );
    },
  );

  testWidgets(
    'nested tab style preserves app fields and false haptics while control motion wins',
    (tester) async {
      final imageKey = GlobalKey();
      final haptics = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      Future<void> render({GlassMotion? motion, bool? feedback}) =>
          tester.pumpWidget(
            glassHarness(
              imageKey: imageKey,
              child: LiquidPrismTheme(
                data: const LiquidPrismThemeData(
                  motion: GlassMotion(pressScale: 1.15),
                  tabBar: GlassTabBarStyle(
                    iconSize: 18,
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Fixture Sans',
                    ),
                    selectedColor: Color(0xFFAA00CC),
                    height: 60,
                    haptics: true,
                  ),
                ),
                child: LiquidPrismTheme(
                  data: const LiquidPrismThemeData(
                    tabBar: GlassTabBarStyle(
                      labelStyle: TextStyle(height: 2),
                      haptics: false,
                    ),
                  ),
                  child: LiquidPrismTabBar(
                    selectedIndex: 0,
                    onSelected: (_) {},
                    motion: motion,
                    style: GlassTabBarStyle(
                      padding: EdgeInsets.zero,
                      haptics: feedback,
                    ),
                    tabs: [
                      for (final label in ['First', 'Second'])
                        LiquidPrismTab(
                          label: label,
                          icon: Builder(
                            builder: (context) => SizedBox(
                              key: ValueKey(label),
                              width: IconTheme.of(context).size,
                              height: IconTheme.of(context).size,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
      await render();
      expect(
        tester.getSize(find.byKey(const ValueKey('First'))),
        const Size(18, 18),
      );
      final label = tester.widget<Text>(find.text('First'));
      expect(label.style!.fontSize, 14);
      expect(label.style!.fontWeight, FontWeight.w800);
      expect(label.style!.fontFamily, 'Fixture Sans');
      expect(label.style!.height, 2);
      expect(label.style!.color, const Color(0xFFAA00CC));
      final pill = find.byType(LiquidPrismSelection);
      final width = visibleWidth(tester, pill);
      var pointer = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('First'))),
      );
      await tester.pumpAndSettle();
      expect(visibleWidth(tester, pill), closeTo(width * 1.15, .001));
      await pointer.cancel();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Second',
        ),
      );
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      await render(motion: const GlassMotion(pressScale: 1.02), feedback: true);
      pointer = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('First'))),
      );
      await tester.pumpAndSettle();
      expect(visibleWidth(tester, pill), closeTo(width * 1.02, .001));
      await pointer.cancel();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Second',
        ),
      );
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1));
    },
  );
}
