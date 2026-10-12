import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

Widget host(Widget child, {bool rtl = false, bool reduced = false}) =>
    Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: LiquidPrismTheme(
          brightness: Brightness.dark,
          child: Center(
            child: SizedBox(
              width: 300,
              child: Align(heightFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'switch impacts follow toggles and drag boundaries without release duplicates',
    (tester) async {
      final impacts = <Object?>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          impacts.add(call.arguments);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      var value = false, enabled = true, haptics = true;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return LiquidPrismSwitch(
                value: value,
                label: 'Power',
                haptics: haptics,
                onChanged: enabled
                    ? (next) => setState(() => value = next)
                    : null,
              );
            },
          ),
        ),
      );
      final control = find.byType(LiquidPrismSwitch);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(impacts, ['HapticFeedbackType.lightImpact']);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(impacts, hasLength(1), reason: 'An unchanged state is silent.');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('Power'));
      await tester.pumpAndSettle();
      expect(impacts, hasLength(3));

      update(() => value = false);
      await tester.pumpAndSettle();
      expect(impacts, hasLength(3), reason: 'External updates are silent.');
      final start = tester.getCenter(control);
      final drag = await tester.startGesture(start);
      await drag.moveTo(start + const Offset(40, 0));
      await tester.pump();
      expect(impacts, hasLength(4));
      await drag.moveTo(start + const Offset(45, 0));
      await tester.pump();
      expect(impacts, hasLength(4));
      await drag.moveTo(start);
      await tester.pump();
      expect(impacts, hasLength(5));
      await drag.up();
      await tester.pumpAndSettle();
      expect(value, isFalse);
      expect(impacts, hasLength(5));

      final held = await tester.startGesture(start);
      await tester.pumpAndSettle();
      await held.cancel();
      await tester.pumpAndSettle();
      expect(impacts, hasLength(5));
      update(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(impacts, hasLength(5));
      update(() {
        enabled = true;
        haptics = false;
      });
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(impacts, hasLength(5));
      expect(impacts.toSet(), {'HapticFeedbackType.lightImpact'});
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('switch tap, drag, controlled rejection and keyboard', (
    tester,
  ) async {
    var value = false, accept = true;
    var changes = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => LiquidPrismSwitch(
            value: value,
            label: 'Power',
            onChanged: (next) {
              changes++;
              setState(() {
                if (accept) value = next;
              });
            },
          ),
        ),
      ),
    );
    final control = find.byType(LiquidPrismSwitch);
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(changes, 1);
    await tester.drag(control, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(changes, 2);
    accept = false;
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(value, isFalse);
    final node = tester.getSemantics(find.bySemanticsLabel('Power'));
    expect(node.flagsCollection.isToggled, ui.Tristate.isFalse);
    accept = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('slider updates a real range, snaps, cancels and clamps RTL', (
    tester,
  ) async {
    var value = 14.0;
    final starts = <double>[], ends = <double>[];
    Widget build(bool rtl) => host(
      StatefulBuilder(
        builder: (context, setState) => LiquidPrismSlider(
          value: value,
          min: 10,
          max: 20,
          divisions: 10,
          label: 'Volume',
          onChanged: (next) => setState(() => value = next),
          onChangeStart: starts.add,
          onChangeEnd: ends.add,
        ),
      ),
      rtl: rtl,
    );
    await tester.pumpWidget(build(false));
    final slider = find.byType(LiquidPrismSlider);
    final rect = tester.getRect(slider);
    final gesture = await tester.startGesture(
      Offset(rect.left + 123.7, rect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(value, 19);
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(value, 16);
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(value, 19);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(starts, [14]);
    expect(ends, [19]);
    await tester.pumpWidget(build(true));
    await tester.drag(slider, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(value, 20);
    final cancel = await tester.startGesture(tester.getCenter(slider));
    await cancel.moveBy(const Offset(25, 0));
    await tester.pump();
    await cancel.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(ends.length, 3);
  });

  for (final rtl in [false, true]) {
    testWidgets('slider thumb follows contact each frame, RTL=$rtl', (
      tester,
    ) async {
      var value = .5;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => LiquidPrismSlider(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
          rtl: rtl,
        ),
      );
      final thumb = find.descendant(
        of: find.byType(LiquidPrismSlider),
        matching: find.byType(LiquidPrism),
      );
      final start = tester.getCenter(thumb);
      final contact = await tester.startGesture(start);
      await tester.pumpAndSettle();
      for (final offset in [40.0, -50.0, 90.0, 0.0]) {
        await contact.moveTo(start + Offset(offset, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getCenter(thumb).dx, closeTo(start.dx + offset, .01));
        expect(value, closeTo(.5 + offset / 263 * (rtl ? -1 : 1), .0001));
      }
      await contact.up();
      await tester.pumpAndSettle();
      expect(tester.getCenter(thumb), start);
    });
  }

  testWidgets('segmented tabs commit once on release and expose selection', (
    tester,
  ) async {
    var value = 0, changes = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => LiquidPrismSegmentedControl<int>(
            selectedValue: value,
            children: const {
              0: Text('First'),
              1: Text('Second'),
              2: Text('Third'),
            },
            onValueChanged: (next) => setState(() {
              value = next;
              changes++;
            }),
          ),
        ),
      ),
    );
    final control = find.byType(LiquidPrismSegmentedControl<int>);
    final rect = tester.getRect(control);
    final gesture = await tester.startGesture(
      Offset(rect.left + 50, rect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(value, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(value, 2);
    expect(changes, 1);
    expect(
      tester.getSemantics(find.text('Third')).flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    tester.semantics.tap(find.semantics.byLabel('Second'));
    await tester.pumpAndSettle();
    expect(value, 1);
  });

  testWidgets(
    'disabled controls ignore pointers and expose disabled semantics',
    (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidPrismSwitch(value: true, onChanged: null, label: 'Power'),
              LiquidPrismSlider(value: .4, onChanged: null, label: 'Volume'),
              LiquidPrismSegmentedControl<int>(
                selectedValue: 0,
                onValueChanged: null,
                children: {0: Text('First'), 1: Text('Second')},
              ),
            ],
          ),
        ),
      );
      for (final label in ['Power', 'Volume', 'First', 'Second']) {
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(label))
              .flagsCollection
              .isEnabled,
          ui.Tristate.isFalse,
        );
      }
      await tester.drag(find.byType(LiquidPrismSlider), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reduce Motion and disposal leave no active animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(LiquidPrismSwitch(value: false, onChanged: (_) {}), reduced: true),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LiquidPrismSwitch)),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    await gesture.cancel();
    await tester.pumpWidget(
      host(LiquidPrismSwitch(value: false, onChanged: (_) {})),
    );
    final held = await tester.startGesture(
      tester.getCenter(find.byType(LiquidPrismSwitch)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    await held.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
