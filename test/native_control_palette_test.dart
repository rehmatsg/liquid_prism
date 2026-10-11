import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  final native = jsonDecode(
    File('doc/native_controls_spec.json').readAsStringSync(),
  ) as Map;
  for (final brightness in Brightness.values) {
    testWidgets(
      'control source colors match native ${brightness.name} and live tint',
      (tester) async {
        final imageKey = GlobalKey();
        final colors = GlassColors(brightness);
        const background = Color(0xFF141414);
        Color? tint;
        Widget harness(Widget control) => glassHarness(
          imageKey: imageKey,
          background: background,
          child: LiquidPrismTheme(
            brightness: brightness,
            data: LiquidPrismThemeData(tint: tint),
            child: control,
          ),
        );
        Future<List<int>> sample(Widget control, Offset point) async {
          await tester.pumpWidget(harness(control));
          await tester.pumpAndSettle();
          return (await pixelsAt(tester, imageKey, [point])).single;
        }

        void expectColor(List<int> actual, Color source) {
          final composite = Color.alphaBlend(source, background);
          final expected = [composite.r, composite.g, composite.b, composite.a];
          for (var i = 0; i < 4; i++) {
            expect(actual[i], closeTo(expected[i] * 255, 1));
          }
        }

        // The maximum track's source comes directly from the recorded native
        // layer, including its unquantized .1 alpha rather than an 8-bit guess.
        final layers =
            native['colors'][brightness.name]['sliderTrackLayers'] as List;
        final source = layers.first['backgroundColor']['components'] as List;
        final expectedTrack = Color.from(
          alpha: (source[1] as num).toDouble(),
          red: (source[0] as num).toDouble(),
          green: (source[0] as num).toDouble(),
          blue: (source[0] as num).toDouble(),
        );
        final slider = LiquidPrismSlider(value: .4, onChanged: (_) {});
        // The harness constrains the slider to 240 points, centered at y=80.
        expectColor(await sample(slider, const Offset(210, 80)), expectedTrack);
        expectColor(await sample(slider, const Offset(40, 80)), colors.blue);
        tint = colors.orange;
        expectColor(await sample(slider, const Offset(40, 80)), colors.orange);
        expectColor(
          await sample(
            LiquidPrismSwitch(value: true, onChanged: (_) {}),
            const Offset(96, 80),
          ),
          colors.orange,
        );
        tint = null;
        expectColor(
          await sample(
            LiquidPrismSwitch(value: true, onChanged: (_) {}),
            const Offset(96, 80),
          ),
          colors.green,
        );
        expectColor(
          await sample(
            LiquidPrismSwitch(value: false, onChanged: (_) {}),
            const Offset(144, 80),
          ),
          colors.tertiaryLabel,
        );
        expectColor(
          await sample(
            LiquidPrismSwitch(value: false, onChanged: (_) {}),
            const Offset(109, 80),
          ),
          colors.controlThumb,
        );
      },
    );
  }

  testWidgets(
    'resting thumb follows an independent continuous capsule contour',
    (tester) async {
      final imageKey = GlobalKey();
      await tester.pumpWidget(
        glassHarness(
          imageKey: imageKey,
          child: LiquidPrismSwitch(value: false, onChanged: (_) {}),
        ),
      );
      final lens = find.byType(LiquidPrism);
      final size = tester.getSize(lens);
      final boundary = tester.getTopLeft(find.byKey(imageKey));
      final origin = tester.getTopLeft(lens) - boundary;
      final smooth = Path()
        ..addRSuperellipse(
          ui.RSuperellipse.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(size.shortestSide / 2),
          ),
        );
      final inside = <Offset>[], outside = <Offset>[];
      const probes = [
        Offset(1.5, 0),
        Offset(-1.5, 0),
        Offset(0, 1.5),
        Offset(0, -1.5),
        Offset(1, 1),
        Offset(-1, 1),
        Offset(1, -1),
        Offset(-1, -1),
      ];
      for (var y = 0; y < size.height; y++) {
        for (var x = 0; x < size.width; x++) {
          final sample = Offset(
            (origin.dx + x).floorToDouble(),
            (origin.dy + y).floorToDouble(),
          );
          final p = sample + const Offset(.5, .5) - origin;
          if (probes.every((d) => smooth.contains(p + d))) inside.add(sample);
          if (probes.every((d) => !smooth.contains(p + d))) outside.add(sample);
        }
      }
      expect(inside, isNotEmpty);
      expect(outside, isNotEmpty);
      for (final pixel in await pixelsAt(tester, imageKey, inside)) {
        expect(pixel.take(3).every((channel) => channel >= 240), isTrue);
      }
      for (final pixel in await pixelsAt(tester, imageKey, outside)) {
        expect(pixel.take(3).every((channel) => channel < 230), isTrue);
      }
    },
  );
}
