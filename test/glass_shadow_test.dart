import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

import 'package:liquid_prism/src/recipe.dart';

void main() {
  testWidgets(
    'regular shadow has half the clear opacity independently of blur',
    (tester) async {
      final key = GlobalKey();
      Future<List<List<int>>> render(Glass glass, double blur) async {
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
                        child: LiquidPrism(
                          glass: glass,
                          blur: blur,
                          shape: const GlassShape.rect(cornerRadius: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return pixelsAt(tester, key, const [
          Offset(32, 100),
          Offset(120, 170),
          Offset(25, 100),
        ]);
      }

      final baseline = await render(Glass.regular, 0);
      expect(
        baseline[0][0],
        lessThan(255),
        reason: 'The exterior shadow must remain visible',
      );
      expect(await render(Glass.regular, 8), baseline);
      final clear = await render(Glass.clear, 0);
      expect(await render(Glass.clear, 8), clear);
      for (var i = 0; i < baseline.length; i++) {
        expect(255 - baseline[i][0], closeTo((255 - clear[i][0]) / 2, 1));
      }
      expect(await render(Glass.regular, 0), baseline);
    },
  );
  testWidgets(
    'buttons and tab bars cast the native control shadow at any blur',
    (tester) async {
      final key = GlobalKey();
      Future<List<List<int>>> render(Glass glass, double blur) async {
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
                        child: LiquidPrismButton(
                          glass: glass,
                          blur: blur,
                          label: 'Button',
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: 130,
                        width: 200,
                        child: LiquidPrismTabBar(
                          glass: glass,
                          blur: blur,
                          selectedIndex: 0,
                          onSelected: (_) {},
                          tabs: const [
                            LiquidPrismTab(
                              label: 'First',
                              icon: SizedBox(width: 24, height: 24),
                            ),
                            LiquidPrismTab(
                              label: 'Second',
                              icon: SizedBox(width: 24, height: 24),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return pixelsAt(tester, key, const [Offset(120, 90), Offset(120, 198)]);
      }

      final baseline = await render(Glass.regular, 0);
      for (final pixel in baseline) {
        expect(
          pixel[0],
          lessThan(255),
          reason: 'Native control exterior shadow is missing',
        );
      }
      expect(await render(Glass.regular, 8), baseline);
      expect(await render(Glass.clear, 0), baseline);
      expect(await render(Glass.clear, 8), baseline);
    },
  );
  test('native glass controls share the captured shadow profile', () {
    final fixture = jsonDecode(
      File('test/fixtures/native_control_shadows.json').readAsStringSync(),
    ) as Map;
    var checked = 0;
    for (final component in fixture['components'] as List) {
      for (final layer in component['layers'] as List) {
        final inputs = layer['inputs'] as Map;
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
    ) as Map<String, dynamic>;
    var checked = 0;
    for (final capture in fixture['captures'] as List) {
      final config = capture['configuration'] as Map;
      if (config['scene'] != 'shadow-size' && config['scene'] != 'shadows') {
        continue;
      }
      for (final layer in capture['layers'] as List) {
        final dimensions = RegExp(r'\{([\d.]+), ([\d.]+)\}\}$')
            .firstMatch(layer['bounds'] as String)!;
        final width = double.parse(dimensions[1]!);
        final height = double.parse(dimensions[2]!);
        final profile = NativeGlassShadow.resolve(
          width < height ? width : height,
          dark: config['mode'] == 'dark',
        );
        final inputs = layer['inputs'] as Map;
        expect(
          profile.radius,
          closeTo(inputs['inputShadowRadius'] as num, 1e-12),
        );
        // Native opacity is float32. Dart evaluates interpolation in float64.
        expect(
          profile.opacity,
          closeTo(inputs['inputShadowOpacity'] as num, 4e-8),
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
        final components =
            inputs['inputShadowColorMatrixFillColor']['components'] as List;
        expect(NativeGlassShadow.colorAlpha, components[3]);
        checked++;
      }
    }
    expect(checked, 21);
  });
}
