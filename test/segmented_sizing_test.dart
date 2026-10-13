import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  testWidgets(
    'fit labels uses equal widths, grows with text scale, and respects constraints',
    (tester) async {
      Future<Size> mount({
        double textScale = 1,
        double maxWidth = 700,
        GlassSegmentedStyle? style,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: LiquidPrismTheme(
                    data: const LiquidPrismThemeData(
                      segmentedControl: GlassSegmentedStyle(
                        sizing: GlassSegmentedSizing.fitLabels,
                        labelPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                      ),
                    ),
                    child: LiquidPrismSegmentedControl<int>(
                      selectedValue: 0,
                      onValueChanged: (_) {},
                      style: style,
                      children: const {
                        0: Text('Short'),
                        1: Text('A wider label'),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return tester.getSize(find.byType(LiquidPrismSegmentedControl<int>));
      }

      final fit = await mount();
      final spacing =
          tester.getCenter(find.text('A wider label')).dx -
          tester.getCenter(find.text('Short')).dx;
      expect(spacing, closeTo(fit.width / 2, .01));
      final large = await mount(textScale: 3);
      expect(large.width, greaterThan(fit.width));
      expect(large.height, greaterThan(fit.height));
      expect((await mount(textScale: 2, maxWidth: 100)).width, 100);
      expect(
        (await mount(style: const GlassSegmentedStyle(width: 240))).width,
        240,
      );
      expect(
        (await mount(
          style: const GlassSegmentedStyle(sizing: GlassSegmentedSizing.fixed),
        )).width,
        300,
      );
      final noPadding = await mount(
        style: const GlassSegmentedStyle(labelPadding: EdgeInsets.zero),
      );
      expect(fit.width - noPadding.width, 72);
    },
  );
}
