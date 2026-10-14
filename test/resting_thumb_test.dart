import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/control_lens.dart';
import 'package:liquid_prism/src/control_material.dart';
import 'package:liquid_prism/src/recipe.dart';

import 'support/rendering.dart';

/// The backdrop passes: the shader glass, or the fallback blur in tests.
final backdrop = find.byWidgetPredicate(
  (widget) =>
      widget is BackdropFilter ||
      widget.runtimeType.toString() == '_GlassRenderWidget',
);

void main() {
  Future<void> pumpLens(
    WidgetTester tester, {
    required double lift,
    GlassLensStyle? style,
    double rim = 0,
  }) => tester.pumpWidget(
    glassHarness(
      imageKey: GlobalKey(),
      child: SizedBox(
        width: 37,
        height: 24,
        child: ControlLens(
          lift: lift,
          role: GlassRole.controlThumb,
          restingColor: const Color(0xFFFFFFFF),
          style: style,
          rim: rim,
        ),
      ),
    ),
  );

  testWidgets('a resting thumb paints its fill without a backdrop pass', (
    tester,
  ) async {
    await pumpLens(tester, lift: 0);
    expect(backdrop, findsNothing);
    final fill = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(ControlLens),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(fill.color, const Color(0xFFFFFFFF));

    await pumpLens(tester, lift: .01);
    expect(backdrop, findsOneWidget);
  });

  testWidgets('custom optics, frost and the tab glint keep the glass at rest', (
    tester,
  ) async {
    await pumpLens(tester, lift: 0, style: const GlassLensStyle(blur: 2));
    expect(backdrop, findsOneWidget);
    await pumpLens(
      tester,
      lift: 0,
      style: const GlassLensStyle(optics: LiquidPrismStyle()),
    );
    expect(backdrop, findsOneWidget);
    await pumpLens(tester, lift: 0, rim: 1);
    expect(backdrop, findsOneWidget);
  });

  testWidgets('a switch adds its lens only while held', (tester) async {
    await tester.pumpWidget(
      glassHarness(
        imageKey: GlobalKey(),
        child: Center(
          child: LiquidPrismSwitch(value: false, onChanged: (_) {}),
        ),
      ),
    );
    final lens = find.descendant(
      of: find.byType(LiquidPrismSwitch),
      matching: backdrop,
    );
    expect(lens, findsNothing);
    final pointer = await tester.startGesture(
      tester.getCenter(find.byType(ControlThumb)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(lens, findsOneWidget);
    await pointer.cancel();
    await tester.pumpAndSettle();
    expect(lens, findsNothing);
  });
}
