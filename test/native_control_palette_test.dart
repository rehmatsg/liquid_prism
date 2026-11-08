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
    'dark resting segments composite the native fill over the track',
    (tester) async {
      final imageKey = GlobalKey();
      Future<List<int>> render({
        Color background = const Color(0xFF000000),
        Brightness brightness = Brightness.dark,
        bool enabled = true,
        Color? thumb,
        GlassSegmentedStyle? style,
        GlassSegmentedStyle? themed,
      }) async {
        await tester.pumpWidget(
          glassHarness(
            imageKey: imageKey,
            background: background,
            platformBrightness: brightness,
            child: LiquidPrismTheme(
              data: LiquidPrismThemeData(segmentedControl: themed),
              child: LiquidPrismSegmentedControl<int>(
                selectedValue: 0,
                onValueChanged: enabled ? (_) {} : null,
                thumbColor: thumb,
                style: style,
                children: const {
                  0: Text('One'),
                  1: Text('Two'),
                  2: Text('Three'),
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return (await pixelsAt(tester, imageKey, [
          const Offset(10, 80),
        ])).single;
      }

      for (final (background, expected) in [
        (const Color(0xFF000000), [90, 90, 95, 255]),
        (const Color(0xFF1C1C1E), [105, 105, 111, 255]),
        (const Color(0xFFFFFFFF), [226, 226, 231, 255]),
      ]) {
        final actual = await render(background: background);
        for (var channel = 0; channel < 4; channel++) {
          expect(actual[channel], closeTo(expected[channel], 1));
        }
        expect(
          DefaultTextStyle.of(tester.element(find.text('One'))).style.color,
          const Color(0xFFFFFFFF),
        );
      }
      expect(await render(enabled: false), [45, 45, 48, 255]);
      expect(await render(brightness: Brightness.light), [255, 255, 255, 255]);
      expect(
        DefaultTextStyle.of(tester.element(find.text('One'))).style.color,
        const Color(0xFF000000),
      );
      const red = Color(0xFFFF0000), blue = Color(0xFF0000FF);
      expect(
        await render(themed: const GlassSegmentedStyle(thumbColor: blue)),
        [0, 0, 255, 255],
      );
      expect(
        await render(
          themed: const GlassSegmentedStyle(thumbColor: blue),
          style: const GlassSegmentedStyle(thumbColor: red),
        ),
        [255, 0, 0, 255],
      );
      expect(
        await render(
          style: const GlassSegmentedStyle(thumbColor: blue),
          thumb: red,
        ),
        [255, 0, 0, 255],
      );
    },
  );

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
