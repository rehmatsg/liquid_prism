import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_driver/flutter_driver.dart';

/// Checks gesture ownership on a running `test_driver/controls.dart` app: the
/// controls sit in a vertical scroll view, and pointer events go through the
/// real gesture arena on the device or simulator. Prints one line per case and
/// exits non-zero on a failed expectation. Optional PRISM_SIMULATOR_ID and
/// PRISM_GESTURE_OUT save mid-gesture screenshots of the holds.
Future<void> main() async {
  final simulator = Platform.environment['PRISM_SIMULATOR_ID'];
  final outPath = Platform.environment['PRISM_GESTURE_OUT'];
  final out = outPath == null
      ? null
      : (Directory(outPath)..createSync(recursive: true));
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  var failures = 0;
  Future<Map<String, dynamic>> layout() async =>
      jsonDecode(await driver.requestData(jsonEncode({'op': 'layout'})))
          as Map<String, dynamic>;
  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
  Future<void> event(String type, double x, double y) =>
      driver.requestData(jsonEncode({'type': type, 'x': x, 'y': y}));
  Future<void> screenshot(String name) async {
    if (simulator == null || out == null) return;
    await Process.run('xcrun', [
      'simctl',
      'io',
      simulator,
      'screenshot',
      '${out.path}/$name.png',
    ]);
  }

  /// Down, [steps] moves over [ms] to (dx, dy), optional hold, then up.
  Future<void> drag(
    double x,
    double y,
    double dx,
    double dy, {
    int ms = 160,
    int steps = 10,
    int holdBefore = 0,
  }) async {
    await event('down', x, y);
    if (holdBefore > 0) await wait(holdBefore);
    for (var i = 1; i <= steps; i++) {
      await event('move', x + dx * i / steps, y + dy * i / steps);
      await wait(ms ~/ steps);
    }
    await event('up', x + dx, y + dy);
    await wait(700);
  }

  void check(String name, bool ok, Object detail) {
    stdout.writeln('${ok ? 'PASS' : 'FAIL'} $name: $detail');
    if (!ok) failures++;
  }

  Future<void> resetSlider() async {
    final l = await layout();
    final slider = (l['slider'] as List).cast<num>();
    final y = slider[1] + slider[3] / 2;
    // A track tap near 40% puts the thumb back at a known place.
    await event('down', slider[0] + 18.5 + 263 * .4, y);
    await wait(30);
    await event('up', slider[0] + 18.5 + 263 * .4, y);
    await wait(700);
  }

  Future<(double, double, double)> sliderGeometry() async {
    final l = await layout();
    final slider = (l['slider'] as List).cast<num>();
    final value = (l['state']['slider'] as num).toDouble();
    final thumbX = slider[0] + 18.5 + 263 * value;
    return (thumbX.toDouble(), (slider[1] + slider[3] / 2).toDouble(), value);
  }

  double scroll(Map<String, dynamic> l) =>
      ((l['state'] as Map)['scroll'] as num? ?? 0).toDouble();

  for (final degrees in [0.0, 30.0, 60.0]) {
    await resetSlider();
    final (x, y, before) = await sliderGeometry();
    final dx = 60.0, dy = 60 * math.tan(degrees * math.pi / 180);
    await drag(x, y, dx, dy);
    final l = await layout();
    final after = (l['state']['slider'] as num).toDouble();
    check(
      'slider thumb drag at $degrees deg',
      (after - before - dx / 263).abs() < .02 && scroll(l).abs() < .5,
      'value $before -> $after, scroll ${scroll(l)}',
    );
  }

  await resetSlider();
  {
    final (x, y, before) = await sliderGeometry();
    // A flick: about 50 points in 40 ms with a slight rise, no hold.
    await drag(x, y, 50, -14, ms: 40, steps: 4);
    final l = await layout();
    final after = (l['state']['slider'] as num).toDouble();
    check(
      'slider flick without a hold',
      after - before > .15 && scroll(l).abs() < .5,
      'value $before -> $after',
    );
  }

  await resetSlider();
  {
    final (x, y, before) = await sliderGeometry();
    final l0 = await layout();
    final slider = (l0['slider'] as List).cast<num>();
    final trackX = slider[0] + 270.0;
    await event('down', trackX, y);
    await wait(600);
    await screenshot('slider-track-hold');
    final held = await layout();
    final heldValue = (held['state']['slider'] as num).toDouble();
    await event('up', trackX, y);
    await wait(700);
    final after = ((await layout())['state']['slider'] as num).toDouble();
    check(
      'slider track hold leaves the value, release jumps',
      heldValue == before && (after - (270 - 18.5) / 263).abs() < .01,
      'held $heldValue, released $after',
    );
    await resetSlider();
    await event('down', trackX, y);
    for (var i = 1; i <= 10; i++) {
      await event('move', trackX, y + 12.0 * i);
      await wait(16);
    }
    final during = await layout();
    await event('up', trackX, y + 120);
    await wait(900);
    final value = (during['state']['slider'] as num).toDouble();
    check(
      'slider track yields a vertical drag to the scroll view',
      scroll(during).abs() > 5 && (value - .4).abs() < .01,
      'scroll during drag ${scroll(during)}, value $value',
    );
    final (tx, ty, _) = await sliderGeometry();
    await event('down', tx, ty);
    for (var i = 1; i <= 10; i++) {
      await event('move', tx, ty + 12.0 * i);
      await wait(16);
    }
    final thumbDuring = await layout();
    await event('up', tx, ty + 120);
    await wait(700);
    check(
      'slider thumb keeps a vertical drag from the scroll view',
      scroll(thumbDuring).abs() < .5,
      'scroll during drag ${scroll(thumbDuring)}',
    );
  }

  {
    var l = await layout();
    final seg = (l['segments'] as List).cast<num>();
    final y = (seg[1] + seg[3] / 2).toDouble();
    final slot = seg[2] / 3;
    double centre(int i) => (seg[0] + slot * (i + .5)).toDouble();
    // Make First selected.
    await event('down', centre(0), y);
    await wait(30);
    await event('up', centre(0), y);
    await wait(800);
    await event('down', centre(2), y);
    await wait(600);
    await screenshot('segments-unselected-hold');
    final held = await layout();
    await event('up', centre(2), y);
    await wait(800);
    l = await layout();
    check(
      'segment hold on another option commits on release',
      held['state']['segments'] == 0 && l['state']['segments'] == 2,
      'held ${held['state']['segments']}, released ${l['state']['segments']}',
    );
    await drag(centre(2), y, -slot * 2, slot * 2 * math.tan(math.pi / 3));
    l = await layout();
    check(
      'segment pill drag at 60 deg',
      l['state']['segments'] == 0 && scroll(l).abs() < .5,
      'selected ${l['state']['segments']}, scroll ${scroll(l)}',
    );
  }

  await driver.close();
  stdout.writeln(failures == 0 ? 'ALL PASSED' : '$failures FAILED');
  exit(failures == 0 ? 0 : 1);
}
