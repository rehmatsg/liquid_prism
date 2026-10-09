import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  testWidgets(
    'selection blur softens only its backdrop through custom fills and leaves content sharp',
    (tester) async {
      final imageKey = GlobalKey();
      const content = SizedBox(
        width: 160,
        height: 80,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 20,
            height: 16,
            child: ColoredBox(color: Color(0xFF00FF00)),
          ),
        ),
      );
      Future<void> render({Color? color, double? blur, bool selected = true}) {
        final selection = blur == null
            ? LiquidPrismSelection(
                selected: selected,
                color: color,
                child: content,
              )
            : LiquidPrismSelection(
                selected: selected,
                color: color,
                blur: blur,
                child: content,
              );
        return tester.pumpWidget(
          _stepScene(
            imageKey: imageKey,
            width: 240,
            steps: 2,
            child: selection,
          ),
        );
      }

      for (final color in [
        null,
        const Color(0x00000000),
        const Color(0x55336699),
      ]) {
        await render(color: color, blur: 0);
        final sharp = await _profile(tester, imageKey, 120);
        expect(sharp.take(4).toSet(), hasLength(1));
        expect(sharp.skip(4).toSet(), hasLength(1));
        await render(color: color);
        final softened = await _profile(tester, imageKey, 120);
        expect(
          softened[3],
          greaterThan(sharp[3] + 4),
          reason: '$color left edge',
        );
        expect(
          softened[4],
          lessThan(sharp[4] - 4),
          reason: '$color right edge',
        );
        expect(softened.toSet().length, greaterThan(sharp.toSet().length + 2));

        expect(
          await pixelsAt(tester, imageKey, const [
            Offset(42, 42),
            Offset(197, 42),
            Offset(119, 38),
            Offset(120, 38),
          ]),
          [
            [0, 0, 0, 255],
            [255, 255, 255, 255],
            [0, 0, 0, 255],
            [255, 255, 255, 255],
          ],
          reason: 'The fill and blur stay inside the capsule silhouette',
        );
        await render(color: color, blur: 8);
        final foreground = await pixelsAt(tester, imageKey, const [
          Offset(109, 48),
          Offset(110, 48),
          Offset(129, 48),
          Offset(130, 48),
        ]);
        expect(foreground[0], isNot([0, 255, 0, 255]));
        expect(foreground[1], [0, 255, 0, 255]);
        expect(foreground[2], [0, 255, 0, 255]);
        expect(foreground[3], isNot([0, 255, 0, 255]));
        await render(color: color, blur: 8, selected: false);
        expect(await _profile(tester, imageKey, 120), [
          0,
          0,
          0,
          0,
          255,
          255,
          255,
          255,
        ]);
      }
    },
  );

  testWidgets(
    'tab pill blur is independent of bar zero and follows live overrides and selection',
    (tester) async {
      final imageKey = GlobalKey();
      var selected = 0;
      final requests = <int>[];
      Future<void> render({
        double? appBlur,
        double? localBlur,
        bool inherit = true,
      }) async {
        await tester.pumpWidget(
          _stepScene(
            imageKey: imageKey,
            width: 360,
            steps: 6,
            child: LiquidPrismTheme(
              data: LiquidPrismThemeData(
                tabBar: GlassTabBarStyle(selectionBlur: appBlur),
              ),
              child: LiquidPrismTheme(
                inherit: inherit,
                child: StatefulBuilder(
                  builder: (context, update) => LiquidPrismTabBar(
                    rendering: GlassRendering.shader,
                    blur: 0,
                    optics: LiquidPrismStyle.clear.copyWith(
                      tint: const Color(0x00000000),
                    ),
                    selectedIndex: selected,
                    onSelected: (index) => update(() {
                      requests.add(index);
                      selected = index;
                    }),
                    style: GlassTabBarStyle(
                      padding: EdgeInsets.zero,
                      labelBehavior: GlassTabLabelBehavior.never,
                      selectionColor: const Color(0x00000000),
                      selectionBlur: localBlur,
                      haptics: false,
                    ),
                    tabs: const [
                      LiquidPrismTab(label: 'A', icon: SizedBox.shrink()),
                      LiquidPrismTab(label: 'B', icon: SizedBox.shrink()),
                      LiquidPrismTab(label: 'C', icon: SizedBox.shrink()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      Future<List<List<int>>> profiles() async => [
        for (final x in [60.0, 180.0, 300.0])
          await _profile(tester, imageKey, x),
      ];

      await render(localBlur: 0);
      final zero = await profiles();
      await render();
      final defaults = await profiles();
      expect(defaults[0], isNot(zero[0]));
      expect(defaults.skip(1), zero.skip(1));
      await render(appBlur: 8);
      final inherited = await profiles();
      expect(inherited[0][3], greaterThan(zero[0][3]));
      expect(inherited[0][4], lessThan(zero[0][4]));
      expect(inherited.skip(1), zero.skip(1));
      await render(appBlur: 8, localBlur: 0);
      expect(await profiles(), zero);
      await render(appBlur: 0, localBlur: 8);
      expect(await profiles(), inherited);
      await render(appBlur: 8, inherit: false);
      expect(await profiles(), defaults);
      await render(appBlur: 0);
      expect(await profiles(), zero);
      await render(appBlur: 8);
      expect(await profiles(), inherited);

      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'B',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(requests, [1]);
      final moved = await profiles();
      expect(moved[0], zero[0]);
      expect(moved[1], inherited[0]);
      expect(moved[2], zero[2]);
    },
  );
}

const _edgeOffsets = <double>[-16, -8, -4, -1, 0, 3, 7, 15];

Future<List<int>> _profile(
  WidgetTester tester,
  GlobalKey imageKey,
  double center,
) async => (await pixelsAt(tester, imageKey, [
  for (final offset in _edgeOffsets) Offset(center + offset, 80),
])).map((pixel) => pixel[0]).toList();

Widget _stepScene({
  required GlobalKey imageKey,
  required double width,
  required int steps,
  required Widget child,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => MediaQuery(
    data: const MediaQueryData(
      disableAnimations: true,
      platformBrightness: Brightness.dark,
    ),
    child: Center(
      child: RepaintBoundary(
        key: imageKey,
        child: SizedBox(
          width: width,
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < steps; i++)
                    Expanded(
                      child: ColoredBox(
                        color: Color(i.isEven ? 0xFF000000 : 0xFFFFFFFF),
                      ),
                    ),
                ],
              ),
              Center(child: child),
            ],
          ),
        ),
      ),
    ),
  ),
);
