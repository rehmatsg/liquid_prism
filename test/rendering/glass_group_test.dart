import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import '../support/rendering.dart';

void main() {
  testWidgets(
    'unsupported renderer preserves scalar pixels and actions inside a group',
    (tester) async {
      expect(Prism.isShaderSupported, isFalse);
      final imageKey = GlobalKey();
      var taps = 0;
      Widget harness(bool grouped) {
        final controls = Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var index = 0; index < 2; index++)
              PrismButton(
                label: 'Action $index',
                onPressed: () => taps++,
                style: PrismButtonStyle(
                  glass: PrismGlass.clear.tint(
                    index == 0
                        ? const Color(0x550088FF)
                        : const Color(0x77FF3366),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: SizedBox(
                  width: 70,
                  height: 50,
                  child: Center(child: Text('$index')),
                ),
              ),
          ],
        );
        return glassHarness(
          imageKey: imageKey,
          child: grouped ? PrismGroup(child: controls) : controls,
        );
      }

      const samples = [
        Offset(5, 80),
        Offset(55, 65),
        Offset(120, 80),
        Offset(185, 65),
        Offset(235, 80),
      ];
      await tester.pumpWidget(harness(false));
      final scalar = await pixelsAt(tester, imageKey, samples);
      await tester.pumpWidget(harness(true));
      expect(await pixelsAt(tester, imageKey, samples), scalar);
      for (var index = 0; index < 2; index++) {
        final button = find.bySemanticsLabel('Action $index');
        expect(tester.getSemantics(button).flagsCollection.isButton, isTrue);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }
      expect(taps, 2);
      expect(await pixelsAt(tester, imageKey, samples), scalar);
    },
  );

  testWidgets('membership changes and GlobalKey reparent '
      'retain child state and semantics', (tester) async {
    final member = GlobalKey<_CounterState>();
    final imageKey = GlobalKey();
    Widget harness({required bool moved, required bool extra}) => glassHarness(
      imageKey: imageKey,
      child: Row(
        children: [
          for (var group = 0; group < 2; group++)
            Expanded(
              child: PrismGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (extra) const Text('Sibling'),
                    if (group == (moved ? 1 : 0))
                      Semantics(container: true, child: _Counter(key: member)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    await tester.pumpWidget(harness(moved: false, extra: false));

    await tester.tap(find.byType(PrismButton));
    await tester.pumpAndSettle();
    expect(find.text('1 tap'), findsOneWidget);
    await tester.pumpWidget(harness(moved: true, extra: true));
    expect(find.text('1 tap'), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('Counter'));
    await tester.pump();
    expect(find.text('2 tap'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Counter'))
          .flagsCollection
          .isEnabled,
      ui.Tristate.isTrue,
    );
    await tester.pumpWidget(harness(moved: false, extra: false));
    expect(find.text('2 tap'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

class _Counter extends StatefulWidget {
  const new({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => PrismButton(
    label: 'Counter',
    onPressed: () => setState(() => taps++),
    style: const PrismButtonStyle(padding: EdgeInsets.all(8)),
    child: Text('$taps tap', style: const TextStyle(fontSize: 10)),
  );
}
