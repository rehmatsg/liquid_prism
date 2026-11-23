import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/controls/control_lens.dart';
import 'package:liquid_prism/src/controls/control_material.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface_render.dart';

import '../support/rendering.dart';

final Finder backdrop = find.byWidgetPredicate(
  (widget) => widget is BackdropFilter || widget is PrismSurfaceRenderWidget,
);

void main() {
  Future<void> pumpLens(
    WidgetTester tester, {
    required double lift,
    PrismLensStyle? style,
    double rim = 0,
  }) => tester.pumpWidget(
    glassHarness(
      imageKey: GlobalKey(),
      child: SizedBox(
        width: 37,
        height: 24,
        child: ControlLens(
          lift: lift,
          role: PrismRole.controlThumb,
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
    await pumpLens(tester, lift: 0, style: const PrismLensStyle(blur: 2));
    expect(backdrop, findsOneWidget);
    await pumpLens(
      tester,
      lift: 0,
      style: const PrismLensStyle(optics: PrismOptics.clear),
    );
    expect(backdrop, findsOneWidget);
    await pumpLens(tester, lift: 0, rim: 1);
    expect(backdrop, findsOneWidget);
  });

  testWidgets('a switch adds its lens only while held', (tester) async {
    await tester.pumpWidget(
      glassHarness(
        imageKey: GlobalKey(),
        child: Center(child: PrismSwitch(value: false, onChanged: (_) {})),
      ),
    );
    final lens = find.descendant(
      of: find.byType(PrismSwitch),
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
