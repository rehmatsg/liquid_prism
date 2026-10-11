import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  // Compare public rendering geometry to the independent native capture, rather
  // than duplicating package constants in an expected-value test.
  final profiles =
      (jsonDecode(File('doc/native_controls_spec.json').readAsStringSync())
              as Map)['profiles']
          as Map;
  Size nativeSize(String name, String phase) {
    final bounds =
        (phase == 'restingTrack'
                ? profiles[name]['restingTrackBounds']
                : profiles[name][phase]['bounds'])
            as String;
    final values = RegExp(r'-?\d+(?:\.\d+)?')
        .allMatches(bounds)
        .map((m) => double.parse(m[0]!))
        .toList();
    return Size(values[2], values[3]);
  }

  for (final name in ['switch', 'slider', 'segmented']) {
    testWidgets('$name pill matches the native resting and held bounds', (
      tester,
    ) async {
      final Widget control = switch (name) {
        'switch' => LiquidPrismSwitch(value: false, onChanged: (_) {}),
        'slider' => LiquidPrismSlider(value: .4, onChanged: (_) {}),
        _ => LiquidPrismSegmentedControl<int>(
          selectedValue: 0,
          onValueChanged: (_) {},
          children: const {
            0: Text('First'),
            1: Text('Second'),
            2: Text('Third'),
          },
        ),
      };
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Center(
              child: SizedBox(
                width: 300,
                child: Align(heightFactor: 1, child: control),
              ),
            ),
          ),
        ),
      );
      final lens = find.byType(LiquidPrism);
      void expectBounds(String phase) {
        final actual = tester.getSize(lens), expected = nativeSize(name, phase);
        expect(actual.width, closeTo(expected.width, .01));
        expect(actual.height, closeTo(expected.height, .01));
      }

      final track = tester.getSize(find.byType(ClipPath).first);
      final nativeTrack = nativeSize(name, 'restingTrack');
      expect(track.width, closeTo(nativeTrack.width, .01));
      expect(track.height, closeTo(nativeTrack.height, .01));
      expectBounds('restingLens');
      final gesture = await tester.startGesture(tester.getCenter(lens));
      await tester.pumpAndSettle();
      expectBounds('heldLens');
      await gesture.cancel();
      await tester.pumpAndSettle();
      expectBounds('restingLens');
    });
  }
}
