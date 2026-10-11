import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism_example/chrome_demo.dart';

void main() {
  testWidgets('search demo matches captured resting and keyboard geometry', (
    tester,
  ) async {
    final source = jsonDecode(
      File('../doc/native_chrome_spec.json').readAsStringSync(),
    );
    Rect reference(String profile) {
      final frame =
          source['profiles'][profile]['surfaces'][0]['windowFrame'] as String;
      final values = RegExp(r'-?\d+(?:\.\d+)?')
          .allMatches(frame)
          .map((m) => double.parse(m[0]!))
          .toList();
      return Rect.fromLTWH(values[0], values[1], values[2], values[3]);
    }

    void match(Rect actual, Rect expected) {
      expect(actual.left, closeTo(expected.left, .01));
      expect(actual.top, closeTo(expected.top, .01));
      expect(actual.width, closeTo(expected.width, .01));
      expect(actual.height, closeTo(expected.height, .01));
    }

    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      const CupertinoApp(home: ChromeDemo(standalone: true)),
    );
    await tester.pumpAndSettle();
    final editor = find.byType(CupertinoTextField);
    match(tester.getRect(editor), reference('dark-search-rest'));
    await tester.tap(editor);
    tester.view.viewInsets = const FakeViewPadding(bottom: 1005);
    await tester.pumpAndSettle();
    match(tester.getRect(editor), reference('dark-search-focused'));
    expect(tester.takeException(), isNull);
  });
}
