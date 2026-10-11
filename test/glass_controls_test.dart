import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

const _faceKey = ValueKey('control-face');
const _emptyFace = SizedBox(
  key: _faceKey,
  width: 100,
  height: 60,
  child: ColoredBox(color: Color(0x00000000)),
);

void main() {
  testWidgets('bare interactive glass expands and preserves the child action', (
    tester,
  ) async {
    var taps = 0;
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      glassHarness(
        imageKey: imageKey,
        child: LiquidPrism(
          glass: Glass.clear.interactive(),
          child: Semantics(
            label: 'Child favorite',
            button: true,
            onTap: () => taps++,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => taps++,
              child: _emptyFace,
            ),
          ),
        ),
      ),
    );
    final face = find.byKey(_faceKey);
    final pointer = await tester.startGesture(tester.getCenter(face));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(visibleWidth(tester, face), greaterThan(100));
    await tester.pumpAndSettle();
    expect(
      visibleWidth(tester, face),
      closeTo(100 * const GlassMotion().pressScale, 0.1),
    );
    await pointer.cancel();
    await tester.pumpAndSettle();
    expect(visibleWidth(tester, face), closeTo(100, 0.01));
    expect(taps, 0);
    expect(find.bySemanticsLabel('Child favorite'), findsOneWidget);
    await tester.tap(face);
    await tester.pumpAndSettle();
    expect(taps, 1);
    tester.semantics.tap(find.semantics.byLabel('Child favorite'));
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('Reduce Motion retains held color feedback without scaling', (
    tester,
  ) async {
    var taps = 0;
    final imageKey = GlobalKey();
    Widget harness(bool reduceMotion) => glassHarness(
      imageKey: imageKey,
      reduceMotion: reduceMotion,
      child: LiquidPrismButton(
        label: 'Glass action',
        glass: Glass.clear.tint(const Color(0x550088FF)),
        onPressed: () => taps++,
        padding: EdgeInsets.zero,
        child: _emptyFace,
      ),
    );
    await tester.pumpWidget(harness(true));
    final face = find.byKey(_faceKey);
    final resting = await pixelsAt(tester, imageKey, [const Offset(120, 80)]);
    final pointer = await tester.startGesture(tester.getCenter(face));
    await tester.pump();
    final held = await pixelsAt(tester, imageKey, [const Offset(120, 80)]);
    expect(visibleWidth(tester, face), 100);
    await pointer.up();
    await tester.pumpAndSettle();
    final released = await pixelsAt(tester, imageKey, [const Offset(120, 80)]);
    expect(taps, 1);
    expect(released, resting);
    expect(held, isNot(resting));
    await tester.pumpWidget(harness(false));
    final changing = await tester.startGesture(tester.getCenter(face));
    await tester.pumpAndSettle();
    expect(visibleWidth(tester, face), greaterThan(100));
    await tester.pumpWidget(harness(true));
    expect(visibleWidth(tester, face), 100);
    expect(await pixelsAt(tester, imageKey, [const Offset(120, 80)]), held);
    await changing.cancel();
    await tester.pumpAndSettle();
    expect(await pixelsAt(tester, imageKey, [const Offset(120, 80)]), resting);
    expect(taps, 1);
  });

  testWidgets(
    'glass button owns one expansion and ignores a secondary release',
    (tester) async {
      var taps = 0;
      final imageKey = GlobalKey();
      await tester.pumpWidget(
        glassHarness(
          imageKey: imageKey,
          child: LiquidPrismButton(
            label: 'Action',
            glass: Glass.regular.interactive(),
            onPressed: () => taps++,
            padding: EdgeInsets.zero,
            child: _emptyFace,
          ),
        ),
      );
      final face = find.byKey(_faceKey);
      final center = tester.getCenter(face);
      final first = await tester.startGesture(center, pointer: 1);
      await tester.pumpAndSettle();
      expect(
        visibleWidth(tester, face),
        closeTo(100 * const GlassMotion().pressScale, 0.1),
      );
      final second = await tester.startGesture(center, pointer: 2);
      await second.up();
      await tester.pumpAndSettle();
      expect(
        visibleWidth(tester, face),
        closeTo(100 * const GlassMotion().pressScale, 0.1),
      );
      expect(taps, 0);
      await first.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(visibleWidth(tester, face), closeTo(100, 0.01));

      final canceled = await tester.startGesture(center, pointer: 3);
      await tester.pumpAndSettle();
      await canceled.moveBy(const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(visibleWidth(tester, face), closeTo(100, 0.01));
      await canceled.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    },
  );

  testWidgets('disable during contact rejects stale releases after reenable', (
    tester,
  ) async {
    var enabled = false;
    var taps = 0;
    late StateSetter update;
    final imageKey = GlobalKey();
    await tester.pumpWidget(
      glassHarness(
        imageKey: imageKey,
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidPrismButton(
              label: 'Action',
              onPressed: enabled ? () => taps++ : null,
              padding: EdgeInsets.zero,
              child: _emptyFace,
            );
          },
        ),
      ),
    );
    final face = find.byKey(_faceKey);
    final center = tester.getCenter(face);
    final initiallyDisabled = await tester.startGesture(center, pointer: 1);
    update(() => enabled = true);
    await tester.pump();
    await initiallyDisabled.up();
    await tester.pumpAndSettle();
    expect(taps, 0, reason: 'A contact that began disabled cannot activate.');
    for (final withSecondPointer in [false, true]) {
      final first = await tester.startGesture(center, pointer: 1);
      await tester.pumpAndSettle();
      expect(visibleWidth(tester, face), greaterThan(100));
      update(() => enabled = false);
      await tester.pump();
      expect(visibleWidth(tester, face), 100);
      final disabled = tester.getSemantics(find.bySemanticsLabel('Action'));
      expect(disabled.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(
        disabled.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      update(() => enabled = true);
      await tester.pump();
      final second = withSecondPointer
          ? await tester.startGesture(center, pointer: 2)
          : null;
      await first.up();
      expect(
        taps,
        0,
        reason:
            'Disabled contact must never activate; second pointer: '
            '$withSecondPointer',
      );
      await second?.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(visibleWidth(tester, face), closeTo(100, 0.01));
    }
    await tester.tap(face);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets(
    'keyboard and semantics activate once while async taps may overlap',
    (tester) async {
      final pending = <Completer<void>>[];
      var completed = 0;
      var enabled = true;
      late StateSetter update;
      final imageKey = GlobalKey();
      Future<void> action() async {
        final completer = Completer<void>();
        pending.add(completer);
        await completer.future;
        completed++;
      }

      await tester.pumpWidget(
        glassHarness(
          imageKey: imageKey,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return LiquidPrismButton(
                label: 'Run action',
                selected: true,
                onPressed: enabled ? action : null,
                child: const SizedBox(
                  key: _faceKey,
                  width: 100,
                  height: 60,
                  child: Text('Run action'),
                ),
              );
            },
          ),
        ),
      );
      final face = find.byKey(_faceKey);
      await tester.tap(face);
      await tester.tap(face);
      await tester.pump();
      expect(pending, hasLength(2));
      expect(completed, 0);
      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Run action'),
      );
      expect(semantics.label, 'Run action');
      expect(semantics.flagsCollection.isSelected, ui.Tristate.isTrue);
      tester.semantics.tap(find.semantics.byLabel('Run action'));
      await tester.pump();
      expect(pending, hasLength(3));
      Focus.of(tester.element(face)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(pending, hasLength(4));
      update(() => enabled = false);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(face);
      await tester.pumpAndSettle();
      expect(pending, hasLength(4));
      for (final completer in pending) {
        completer.complete();
      }
      await tester.pump();
      expect(completed, 4);
    },
  );

  testWidgets(
    'glass reparent and removal cancel a held press without actions',
    (tester) async {
      final imageKey = GlobalKey();
      final buttonKey = GlobalKey();
      var taps = 0;
      Widget harness(bool moved) => glassHarness(
        imageKey: imageKey,
        child: KeyedSubtree(
          key: ValueKey(moved),
          child: LiquidPrismButton(
            key: buttonKey,
            label: 'Action',
            onPressed: () => taps++,
            padding: EdgeInsets.zero,
            child: _emptyFace,
          ),
        ),
      );
      await tester.pumpWidget(harness(false));
      final face = find.byKey(_faceKey);
      final held = await tester.startGesture(tester.getCenter(face));
      await tester.pumpAndSettle();
      expect(visibleWidth(tester, face), greaterThan(100));
      await tester.pumpWidget(harness(true));
      expect(visibleWidth(tester, face), 100);
      await held.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      final removed = await tester.startGesture(tester.getCenter(face));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await removed.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(taps, 0);
    },
  );
}
