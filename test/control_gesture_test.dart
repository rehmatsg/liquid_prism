import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/control_material.dart';

/// Hosts [child] at 300 points wide inside a long vertical list, the way the
/// showcase pages and settings screens place controls.
Widget listHost(Widget child, ScrollController controller) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: LiquidPrismTheme(
      brightness: Brightness.dark,
      child: ListView(
        controller: controller,
        children: [
          const SizedBox(height: 200),
          Center(child: SizedBox(width: 300, child: child)),
          const SizedBox(height: 2000),
        ],
      ),
    ),
  ),
);

/// Moves a held pointer to [offset] in ten 16 ms frames.
Future<void> glide(
  WidgetTester tester,
  TestGesture pointer,
  Offset from,
  Offset offset,
) async {
  for (var i = 1; i <= 10; i++) {
    await pointer.moveTo(from + offset * (i / 10));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Offset angled(double along, double degrees) =>
    Offset(along, along * math.tan(degrees * math.pi / 180));

void main() {
  group('slider', () {
    late double value;
    late List<double> starts, ends;
    late ScrollController scroll;
    setUp(() {
      value = .4;
      starts = [];
      ends = [];
      scroll = ScrollController();
    });
    tearDown(() => scroll.dispose());

    Future<void> mount(WidgetTester tester, {bool accept = true}) =>
        tester.pumpWidget(
          listHost(
            StatefulBuilder(
              builder: (context, setState) => LiquidPrismSlider(
                value: value,
                onChanged: (next) {
                  if (accept) setState(() => value = next);
                },
                onChangeStart: starts.add,
                onChangeEnd: ends.add,
              ),
            ),
            scroll,
          ),
        );
    Finder thumb() => find.descendant(
      of: find.byType(LiquidPrismSlider),
      matching: find.byType(ControlThumb),
    );

    for (final degrees in [30.0, 60.0]) {
      testWidgets(
        'a thumb drag $degrees degrees off axis moves the value, not the list',
        (tester) async {
          await mount(tester);
          final from = tester.getCenter(thumb());
          final pointer = await tester.startGesture(from);
          await glide(tester, pointer, from, angled(80, degrees));
          expect(scroll.offset, 0);
          expect(value, closeTo(.4 + 80 / 263, .002));
          await pointer.up();
          await tester.pumpAndSettle();
          expect(starts, [closeTo(.4, 1e-9)]);
          expect(ends, [closeTo(.4 + 80 / 263, .002)]);
        },
      );
    }

    testWidgets('a quick flick from the thumb moves the value with no hold', (
      tester,
    ) async {
      await mount(tester);
      await tester.flingFrom(
        tester.getCenter(thumb()),
        const Offset(60, -15),
        1500,
      );
      await tester.pumpAndSettle();
      expect(value, closeTo(.4 + 60 / 263, .002));
      expect(scroll.offset, 0);
      expect(ends, hasLength(1));
    });

    testWidgets('a vertical drag on the thumb keeps the list and the value', (
      tester,
    ) async {
      await mount(tester);
      final from = tester.getCenter(thumb());
      final pointer = await tester.startGesture(from);
      await glide(tester, pointer, from, const Offset(0, -150));
      await pointer.up();
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(value, closeTo(.4, 1e-9));
    });

    testWidgets('the track yields vertical drags to the list', (tester) async {
      await mount(tester);
      final rect = tester.getRect(find.byType(LiquidPrismSlider));
      final from = Offset(rect.left + 270, rect.center.dy);
      final pointer = await tester.startGesture(from);
      await glide(tester, pointer, from, const Offset(0, -150));
      await pointer.up();
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(100));
      expect(value, closeTo(.4, 1e-9));
      expect(starts, isEmpty);
      expect(ends, isEmpty);
      // A vertical drag beside the control still scrolls the list.
      scroll.jumpTo(0);
      await tester.pump();
      await tester.dragFrom(
        Offset(rect.left - 40, rect.center.dy),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(100));
    });

    testWidgets(
      'holding the track lifts nothing; release jumps there, a drag follows',
      (tester) async {
        await mount(tester);
        final rect = tester.getRect(find.byType(LiquidPrismSlider));
        final resting = tester.getRect(thumb());
        final from = Offset(rect.left + 270, rect.center.dy);
        final hold = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          tester.getRect(thumb()),
          resting,
          reason: 'Native iOS 27: a held track leaves the thumb untouched.',
        );
        expect(value, .4);
        await hold.up();
        await tester.pumpAndSettle();
        // The package's track tap: the value jumps to the contact.
        expect(value, closeTo((270 - 18.5) / 263, .002));
        expect(tester.getSize(thumb()), resting.size);

        final drag = await tester.startGesture(
          Offset(rect.left + 60, rect.center.dy),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.getSize(thumb()), resting.size);
        await glide(
          tester,
          drag,
          Offset(rect.left + 60, rect.center.dy),
          const Offset(40, 10),
        );
        expect(value, closeTo((100 - 18.5) / 263, .002));
        expect(tester.getSize(thumb()).width, greaterThan(resting.width));
        await drag.up();
        await tester.pumpAndSettle();
        expect(ends.last, closeTo((100 - 18.5) / 263, .002));
      },
    );

    testWidgets(
      'cancellation and rejected updates settle on the parent value',
      (tester) async {
        await mount(tester, accept: false);
        final from = tester.getCenter(thumb());
        final pointer = await tester.startGesture(from);
        await glide(tester, pointer, from, angled(60, 30));
        await pointer.up();
        await tester.pumpAndSettle();
        expect(value, .4);
        expect(tester.getCenter(thumb()), from);
        final cancelled = await tester.startGesture(from);
        await glide(tester, cancelled, from, angled(60, 60));
        await cancelled.cancel();
        await tester.pumpAndSettle();
        expect(tester.getCenter(thumb()), from);
        expect(ends, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('segmented control', () {
    late int value;
    late List<int> changes;
    late ScrollController scroll;
    setUp(() {
      value = 0;
      changes = [];
      scroll = ScrollController();
    });
    tearDown(() => scroll.dispose());

    Future<void> mount(WidgetTester tester, {bool accept = true}) =>
        tester.pumpWidget(
          listHost(
            StatefulBuilder(
              builder: (context, setState) => LiquidPrismSegmentedControl<int>(
                selectedValue: value,
                children: const {
                  0: Text('First'),
                  1: Text('Second'),
                  2: Text('Third'),
                },
                onValueChanged: (next) {
                  changes.add(next);
                  if (accept) setState(() => value = next);
                },
              ),
            ),
            scroll,
          ),
        );
    Finder pill() => find.descendant(
      of: find.byType(LiquidPrismSegmentedControl<int>),
      matching: find.byType(ControlThumb),
    );
    double labelOpacity(WidgetTester tester, String label) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets(
      'holding an unselected segment dims it; the selection moves on release',
      (tester) async {
        await mount(tester);
        final resting = tester.getRect(pill());
        final hold = await tester.startGesture(
          tester.getCenter(find.text('Third')),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          tester.getRect(pill()),
          resting,
          reason: 'Native iOS 27: the selection neither lifts nor moves.',
        );
        expect(labelOpacity(tester, 'Third'), .4);
        expect(labelOpacity(tester, 'Second'), 1);
        expect(changes, isEmpty);
        await hold.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.getSize(pill()).width,
          greaterThan(resting.width),
          reason: 'The selection lifts while it travels.',
        );
        await tester.pumpAndSettle();
        expect(changes, [2]);
        expect(labelOpacity(tester, 'Third'), 1);
        expect(
          tester.getCenter(pill()).dx,
          closeTo(tester.getCenter(find.text('Third')).dx, 1),
        );
      },
    );

    testWidgets(
      'a drag from an unselected segment moves the highlight, then commits',
      (tester) async {
        await mount(tester);
        final resting = tester.getRect(pill());
        final from = tester.getCenter(find.text('Third'));
        final pointer = await tester.startGesture(from);
        await glide(tester, pointer, from, const Offset(-100, 5));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.getRect(pill()), resting);
        expect(labelOpacity(tester, 'Second'), .4);
        expect(labelOpacity(tester, 'Third'), 1);
        expect(changes, isEmpty);
        await pointer.up();
        await tester.pumpAndSettle();
        expect(changes, [1]);
        // Dragged back onto the selection: nothing to commit.
        final back = await tester.startGesture(
          tester.getCenter(find.text('Third')),
        );
        await glide(
          tester,
          back,
          tester.getCenter(find.text('Third')),
          const Offset(-100, 0),
        );
        await back.up();
        await tester.pumpAndSettle();
        expect(changes, [1, 1]);
        expect(value, 1);
      },
    );

    testWidgets('a pill drag 60 degrees off axis selects, not scrolls', (
      tester,
    ) async {
      await mount(tester);
      final from = tester.getCenter(find.text('First'));
      final pointer = await tester.startGesture(from);
      await glide(tester, pointer, from, angled(200, 60));
      await tester.pump(const Duration(milliseconds: 300));
      expect(scroll.offset, 0);
      expect(
        tester.getCenter(pill()).dx,
        closeTo(tester.getCenter(find.text('Third')).dx, 2),
      );
      await pointer.up();
      await tester.pumpAndSettle();
      expect(changes, [2]);
    });

    testWidgets(
      'an unselected segment yields a vertical drag; cancel and reject settle',
      (tester) async {
        await mount(tester, accept: false);
        final third = tester.getCenter(find.text('Third'));
        final pointer = await tester.startGesture(third);
        await glide(tester, pointer, third, const Offset(0, -150));
        await pointer.up();
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(100));
        expect(changes, isEmpty);
        expect(labelOpacity(tester, 'Third'), 1);
        scroll.jumpTo(0);
        await tester.pump();
        final resting = tester.getRect(pill());
        final cancelled = await tester.startGesture(third);
        await glide(tester, cancelled, third, const Offset(-100, 0));
        await cancelled.cancel();
        await tester.pumpAndSettle();
        expect(changes, isEmpty);
        expect(labelOpacity(tester, 'Second'), 1);
        await tester.tap(find.text('Second'));
        await tester.pumpAndSettle();
        expect(changes, [1]);
        expect(value, 0);
        expect(tester.getRect(pill()), resting);
      },
    );
  });

  testWidgets('a switch drag 60 degrees off axis toggles inside a list', (
    tester,
  ) async {
    var value = false;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      listHost(
        StatefulBuilder(
          builder: (context, setState) => Align(
            child: LiquidPrismSwitch(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
        scroll,
      ),
    );
    final from =
        tester.getCenter(find.byType(LiquidPrismSwitch)) - const Offset(11, 0);
    final pointer = await tester.startGesture(from);
    await glide(tester, pointer, from, angled(30, 60));
    await pointer.up();
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(value, isTrue);
  });
}
