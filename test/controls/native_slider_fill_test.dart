import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/controls/control_material.dart';

void main() {
  final capture = jsonDecode(
    File('research/specs/native_slider_fill_spec.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final rtl in [false, true]) {
    testWidgets('slider fill matches native edge-range geometry, RTL=$rtl', (
      tester,
    ) async {
      var value = .5;
      late StateSetter update;
      await tester.pumpWidget(
        Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Center(
              child: SizedBox(
                width: (capture['width']! as num).toDouble(),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return PrismSlider(value: value, onChanged: (_) {});
                  },
                ),
              ),
            ),
          ),
        ),
      );
      for (final sample in capture['samples']! as List<Object?>) {
        final row = sample! as Map<String, Object?>;
        update(() => value = (row['value']! as num).toDouble());
        await tester.pumpAndSettle();
        final active = tester.getRect(find.byType(ControlTrack).last);
        final track = tester.getRect(find.byType(ControlTrack).first);
        expect(
          active.width,
          closeTo((row['fillWidth']! as num).toDouble(), .001),
          reason:
              'Native active-fill width at '
              '${(value * 100).toStringAsFixed(2)}%.',
        );
        expect(
          rtl ? active.right : active.left,
          closeTo(rtl ? track.right : track.left, .001),
        );
      }
    });
  }
}
