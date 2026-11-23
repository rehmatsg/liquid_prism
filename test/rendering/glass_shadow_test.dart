import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/rendering/prism_display.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';

import '../support/rendering.dart';

void main() {
  testWidgets('grouped material shadows inherit and respect explicit false', (
    tester,
  ) async {
    final key = GlobalKey();
    Future<List<List<int>>> render({bool? local, bool? theme}) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xffffffff),
          builder: (context, _) => PrismTheme(
            data: PrismThemeData(shadow: theme),
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 240,
                  height: 160,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0xffffffff)),
                      ),
                      Positioned(
                        left: 40,
                        top: 40,
                        width: 150,
                        height: 44,
                        child: PrismGroup(child: PrismSurface(shadow: local)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return await pixelsAt(tester, key, const [
        Offset(36, 62),
        Offset(115, 90),
      ]);
    }

    final baseline = await render();
    expect(baseline[0][0], lessThan(255));
    final off = await render(theme: false);
    expect(off.map((pixel) => pixel[0]), [255, 255]);
    expect(await render(theme: true, local: false), off);
    expect(await render(theme: false, local: true), baseline);
    expect(
      const PrismThemeData(shadow: false).merge(const PrismThemeData()).shadow,
      isFalse,
    );
    expect(
      const PrismThemeData(shadow: true).copyWith(shadow: false).shadow,
      isFalse,
    );
  });

  test(
    'shadow opt-out survives recipe copies without changing optical inputs',
    () {
      final recipe = PrismRecipe.resolve(
        PrismGlass.regular,
        Brightness.light,
        PrismRole.surface,
        customOptics: false,
      );
      final off = recipe.withShadow(false).withTint(.75).withPresence(.4);
      final on = recipe.withTint(.75).withPresence(.4);
      expect(off.uniforms, on.uniforms);
      expect(off.shadowStrength, 0);
      expect(off.faceUniforms[1], 0);
      expect(on.faceUniforms[1], greaterThan(0));
      expect(off.faceUniforms[0], on.faceUniforms[0]);
      expect(off.faceUniforms.skip(2), on.faceUniforms.skip(2));
    },
  );
  testWidgets('HDR surfaces remove extra contact shadows and restore SDR', (
    tester,
  ) async {
    final key = GlobalKey();
    addTearDown(() {
      PrismDisplay.headroom.value = 1;
    });
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xffffffff),
        builder: (context, _) => Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 240,
              height: 160,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Color(0xffffffff))),
                  Positioned(
                    left: 40,
                    top: 40,
                    width: 150,
                    height: 44,
                    child: PrismSurface(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    const points = [Offset(36, 62), Offset(115, 90)];
    final before = await pixelsAt(tester, key, points);
    PrismDisplay.headroom.value = 1.2;
    await tester.pump();
    final hdr = await pixelsAt(tester, key, points);
    expect(hdr[0][0], greaterThan(before[0][0]));
    expect(
      hdr[1][0],
      lessThan(255),
      reason: 'the native drop shadow remains visible',
    );
    PrismDisplay.headroom.value = 1;
    await tester.pump();
    expect(await pixelsAt(tester, key, points), before);
  });
  testWidgets('regular surfaces keep native shadow strength '
      'at any blur; clear casts none', (tester) async {
    final key = GlobalKey();
    Future<List<List<int>>> render(PrismGlass glass, double blur) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xffffffff),
          builder: (context, _) => Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 240,
                height: 200,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xffffffff)),
                    ),
                    Positioned(
                      left: 40,
                      top: 40,
                      width: 160,
                      height: 120,
                      child: PrismSurface(
                        glass: glass,
                        blur: blur,
                        shape: const PrismShape.rect(cornerRadius: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return await pixelsAt(tester, key, const [
        Offset(32, 100),
        Offset(120, 170),
        Offset(25, 100),
      ]);
    }

    final baseline = await render(PrismGlass.regular, 0);
    expect(
      baseline[0][0],
      lessThan(255),
      reason: 'The exterior shadow must remain visible',
    );
    expect(await render(PrismGlass.regular, 8), baseline);
    final clear = await render(PrismGlass.clear, 0);
    expect(await render(PrismGlass.clear, 8), clear);

    expect(clear[0][0], 255, reason: 'Clear surfaces cast no exterior shadow');
    expect(clear[2][0], 255);
    expect(await render(PrismGlass.regular, 0), baseline);
  });
  testWidgets(
    'buttons and tab bars cast the native control shadow at any blur',
    (tester) async {
      final key = GlobalKey();
      Future<List<List<int>>> render(PrismGlass glass, double blur) async {
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xffffffff),
            builder: (context, _) => Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 240,
                  height: 260,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0xffffffff)),
                      ),
                      Positioned(
                        left: 40,
                        top: 40,
                        width: 160,
                        height: 44,
                        child: PrismButton(
                          label: 'Button',
                          onPressed: () {},
                          style: PrismButtonStyle(
                            glass: glass,
                            blur: blur,
                            padding: EdgeInsets.zero,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: 130,
                        width: 200,
                        child: PrismTabBar(
                          selectedIndex: 0,
                          onSelected: (_) {},
                          tabs: const [
                            PrismTab(
                              label: 'First',
                              icon: SizedBox(width: 24, height: 24),
                            ),
                            PrismTab(
                              label: 'Second',
                              icon: SizedBox(width: 24, height: 24),
                            ),
                          ],
                          style: PrismTabBarStyle(glass: glass, blur: blur),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return await pixelsAt(tester, key, const [
          Offset(120, 90),
          Offset(120, 198),
        ]);
      }

      final baseline = await render(PrismGlass.regular, 0);
      for (final pixel in baseline) {
        expect(
          pixel[0],
          lessThan(255),
          reason: 'Native control exterior shadow is missing',
        );
      }
      expect(await render(PrismGlass.regular, 8), baseline);
      expect(await render(PrismGlass.clear, 0), baseline);
      expect(await render(PrismGlass.clear, 8), baseline);
    },
  );
  test('native glass controls share the captured shadow profile', () {
    final fixture = jsonDecode(
      File('test/fixtures/native_control_shadows.json').readAsStringSync(),
    ) as Map<String, Object?>;
    var checked = 0;
    for (final entry in fixture['components']! as List<Object?>) {
      final component = entry! as Map<String, Object?>;
      for (final entry in component['layers']! as List<Object?>) {
        final layer = entry! as Map<String, Object?>;
        final inputs = layer['inputs']! as Map<String, Object?>;
        expect(NativeGlassShadow.control.radius, inputs['inputShadowRadius']);
        expect(NativeGlassShadow.control.opacity, inputs['inputShadowOpacity']);
        expect(NativeGlassShadow.ringOpacity, inputs['inputRingShadowOpacity']);
        checked++;
      }
    }
    expect(checked, 7);
  });
  test('shadow inputs agree with the independent native size sweep', () {
    final fixture = jsonDecode(
      File('test/fixtures/native_shadows.json').readAsStringSync(),
    ) as Map<String, Object?>;
    var checked = 0;
    for (final entry in fixture['captures']! as List<Object?>) {
      final capture = entry! as Map<String, Object?>;
      final config = capture['configuration']! as Map<String, Object?>;
      if (config['scene'] != 'shadow-size' && config['scene'] != 'shadows') {
        continue;
      }
      for (final entry in capture['layers']! as List<Object?>) {
        final layer = entry! as Map<String, Object?>;
        final dimensions = RegExp(r'\{([\d.]+), ([\d.]+)\}\}$')
            .firstMatch(layer['bounds']! as String)!;
        final width = double.parse(dimensions[1]!);
        final height = double.parse(dimensions[2]!);
        final profile = NativeGlassShadow.resolve(
          width < height ? width : height,
          dark: config['mode'] == 'dark',
        );
        final inputs = layer['inputs']! as Map<String, Object?>;
        expect(
          profile.radius,
          closeTo(inputs['inputShadowRadius']! as num, 1e-12),
        );

        expect(
          profile.opacity,
          closeTo(inputs['inputShadowOpacity']! as num, 4e-8),
        );
        expect(
          NativeGlassShadow.ringWidth,
          inputs['inputRingShadowStrokeWidth'],
        );
        expect(
          NativeGlassShadow.ringRadius,
          inputs['inputRingShadowBlurRadius'],
        );
        expect(NativeGlassShadow.ringOpacity, inputs['inputRingShadowOpacity']);
        expect(NativeGlassShadow.offset, inputs['inputRingShadowOffset']);
        final color =
            inputs['inputShadowColorMatrixFillColor']! as Map<String, Object?>;
        final components = color['components']! as List<Object?>;
        expect(NativeGlassShadow.colorAlpha, components[3]);
        checked++;
      }
    }
    expect(checked, 21);
  });
}
