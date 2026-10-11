import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/native_colors.dart';
import 'package:liquid_prism/src/recipe.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/native_colors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('all named colors preserve native source RGB and semantic alpha', () {
    for (final colors in [GlassColors.light, GlassColors.dark]) {
      final mode = colors.brightness == Brightness.dark ? 'dark' : 'light';
      final named = <String, Color>{
        for (final entry in colors.accents.entries)
          'system${entry.key[0].toUpperCase()}${entry.key.substring(1)}Color':
              entry.value,
        'labelColor': colors.label,
        'secondaryLabelColor': colors.secondaryLabel,
        'tertiaryLabelColor': colors.tertiaryLabel,
        'quaternaryLabelColor': colors.quaternaryLabel,
        'systemFillColor': colors.systemFill,
        'secondarySystemFillColor': colors.secondarySystemFill,
        'tertiarySystemFillColor': colors.tertiarySystemFill,
        'quaternarySystemFillColor': colors.quaternarySystemFill,
      };
      expect(named.length, 20);
      for (final entry in named.entries) {
        final native = fixture['palette'][entry.key][mode]['rgba'] as List;
        final actual = [
          entry.value.r,
          entry.value.g,
          entry.value.b,
          entry.value.a,
        ];
        for (var i = 0; i < 4; i++) {
          expect(
            actual[i],
            closeTo(native[i] as num, 2e-7),
            reason: '$mode ${entry.key} channel $i',
          );
        }
      }
      expect(colors.disabledLabel, colors.tertiaryLabel);
      expect(() => colors.accents['blue'] = colors.red, throwsUnsupportedError);
    }
  });

  test('every captured tint uses full native RGB rows and caller opacity', () {
    for (final row in fixture['tints'] as List) {
      final colors = row['mode'] == 'dark'
          ? GlassColors.dark
          : GlassColors.light;
      final source = colors.accents[row['name']]!;
      final glass = row['variant'] == 'clear' ? Glass.clear : Glass.regular;
      final native = row['matrix'] as List;
      final expected = [
        for (final i in [0, 5, 10]) ...[
          ...native.sublist(i, i + 3),
          native[i + 4],
        ],
      ];
      for (final alpha in [1.0, .5, 0.0]) {
        final recipe = GlassRecipe.resolve(
          glass.tint(source.withValues(alpha: alpha)),
          colors.brightness,
          GlassRole.surface,
          customOptics: false,
        );
        expect(
          recipe.tintMatrix,
          expected,
          reason: '${row['variant']} ${row['mode']} ${row['name']}',
        );
        expect(recipe.tintAlpha, alpha);
        expect(recipe.uniforms.sublist(4, 16), expected);
        expect(recipe.uniforms.length, 20);
      }
    }
  });

  test('pill matrices preserve native floats and convert only offsets', () {
    for (final mode in ['light', 'dark']) {
      final native = fixture['selection'][mode]['matrix'] as List;
      final expected = [
        for (var i = 0; i < 20; i++)
          (native[i] as num).toDouble() * (i % 5 == 4 ? 255 : 1),
      ];
      expect(
        mode == 'dark' ? nativeDarkSelection : nativeLightSelection,
        expected,
      );
    }
  });

  testWidgets(
    'palette follows theme changes while material appearance stays independent',
    (tester) async {
      late GlassColors colors;
      late Brightness material;
      Future<void> render(Brightness brightness) => tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.light),
          child: LiquidPrismTheme(
            data: LiquidPrismThemeData(
              brightness: brightness,
              materialBrightness: Brightness.light,
            ),
            child: LiquidPrismTheme(
              child: Builder(
                builder: (context) {
                  colors = GlassColors.of(context);
                  material = LiquidPrismTheme.materialBrightnessOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await render(Brightness.dark);
      expect(colors.purple, GlassColors.dark.purple);
      expect(material, Brightness.light);
      await render(Brightness.light);
      expect(colors.purple, GlassColors.light.purple);
      expect(material, Brightness.light);
    },
  );
}
