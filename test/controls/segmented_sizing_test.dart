import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'fit labels uses equal widths, grows with text scale, and respects constraints',
    (tester) async {
      Future<Size> mount({
        double textScale = 1,
        double maxWidth = 700,
        PrismSegmentedStyle? style,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: PrismTheme(
                    data: const PrismThemeData(
                      segmentedControl: PrismSegmentedStyle(
                        sizing: PrismSegmentedSizing.fitLabels,
                        labelPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                      ),
                    ),
                    child: PrismSegmentedControl<int>(
                      selectedValue: 0,
                      onValueChanged: (_) {},
                      children: const {
                        0: Text('Short'),
                        1: Text('A wider label'),
                      },
                      style: style,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return tester.getSize(find.byType(PrismSegmentedControl<int>));
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
        (await mount(style: const PrismSegmentedStyle(width: 240))).width,
        240,
      );
      expect(
        (await mount(
          style: const PrismSegmentedStyle(sizing: PrismSegmentedSizing.fixed),
        )).width,
        300,
      );
      final noPadding = await mount(
        style: const PrismSegmentedStyle(labelPadding: EdgeInsets.zero),
      );
      expect(fit.width - noPadding.width, 72);
    },
  );
}
