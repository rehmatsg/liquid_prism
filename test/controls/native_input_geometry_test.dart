import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/rendering/surface.dart';

void main() {
  final capture = jsonDecode(
    File('research/specs/native_controls_spec.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final profiles = capture['profiles']! as Map<String, Object?>;
  Size nativeSize(String name, String phase) {
    final profile = profiles[name]! as Map<String, Object?>;
    final bounds = phase == 'restingTrack'
        ? profile['restingTrackBounds']! as String
        : (profile[phase]! as Map<String, Object?>)['bounds']! as String;
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
        'switch' => PrismSwitch(value: false, onChanged: (_) {}),
        'slider' => PrismSlider(value: .4, onChanged: (_) {}),
        _ => PrismSegmentedControl<int>(
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
      final lens = find.byType(RawPrismSurface);
      void expectBounds(String phase) {
        final actual = tester.getSize(lens);
        final expected = nativeSize(name, phase);
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
