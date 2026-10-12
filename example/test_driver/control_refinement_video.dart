import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Shows held rims, direction changes and uninterrupted shadows in Studio.
Future<void> main() async {
  final device = Platform.environment['PRISM_SIMULATOR_ID']!;
  final out = Directory(Platform.environment['PRISM_CONTROLS_OUT']!)
    ..createSync(recursive: true);
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  Future<void> pause(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));
  Future<void> pointer(String type, double x, double y) async {
    await driver.requestData(
      jsonEncode({'op': 'pointer', 'type': type, 'x': x, 'y': y}),
    );
  }

  Future<void> snapshot(String name) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'io', device, 'screenshot', '${out.path}/$name.png'],
      environment: {
        'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
      },
    );
    if (result.exitCode != 0) throw StateError('${result.stderr}');
  }

  Future<void> glide(double from, double to, double y, int ms) async {
    final clock = Stopwatch()..start();
    while (clock.elapsedMilliseconds < ms) {
      final t = (clock.elapsedMilliseconds / ms).clamp(0.0, 1.0);
      await pointer('move', from + (to - from) * t, y);
      await pause(16);
    }
    await pointer('move', to, y);
  }

  Future<void> show(SerializableFinder target) async {
    await driver.scrollUntilVisible(
      find.byType('SingleChildScrollView'),
      target,
      dyScroll: -220,
      alignment: .35,
    );
    await pause(500);
  }

  Process? recording;
  try {
    await driver.tap(find.bySemanticsLabel('Studio'));
    final slider = find.descendant(
      of: find.byType('LiquidPrismSlider'),
      matching: find.bySemanticsLabel('Frost'),
      firstMatchOnly: true,
    );
    await show(slider);
    recording = await Process.start(
      'xcrun',
      [
        'simctl',
        'io',
        device,
        'recordVideo',
        '-f',
        '--codec=h264',
        '${out.path}/raw.mp4',
      ],
      environment: {
        'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
      },
    );
    recording.stderr.transform(utf8.decoder).listen(stdout.write);
    await driver.runUnsynchronized(() async {
      for (final dark in [false, true]) {
        if (dark) {
          await driver.tap(find.bySemanticsLabel('Toggle appearance'));
          await show(slider);
        }
        final left = await driver.getTopLeft(slider);
        final right = await driver.getBottomRight(slider);
        final y = (left.dy + right.dy) / 2;
        final low = left.dx + 18.5;
        final high = right.dx - 18.5;
        // Tap first so the following grab has a known thumb center.
        final start = low + (high - low) * .4;
        await pointer('down', start, y);
        await pointer('up', start, y);
        await pause(700);
        await pointer('down', start, y);
        await pause(700);
        await snapshot('slider-${dark ? 'dark' : 'light'}-held');
        await glide(start, high - 15, y, 1100);
        await glide(high - 15, low + 15, y, 450);
        await glide(low + 15, start, y, 700);
        await pause(300);
        await pointer('up', start, y);
        await pause(600);

        final segments = find.descendant(
          of: find.byType('LiquidPrismSegmentedControl<int>'),
          matching: find.bySemanticsLabel('Artwork'),
          firstMatchOnly: true,
        );
        await show(segments);
        final a = await driver.getTopLeft(segments);
        final b = await driver.getBottomRight(segments);
        final segmentY = (a.dy + b.dy) / 2;
        final first = a.dx + (b.dx - a.dx) / 6;
        final last = a.dx + (b.dx - a.dx) * 5 / 6;
        await pointer('down', first, segmentY);
        await pointer('up', first, segmentY);
        await pause(500);
        await pointer('down', first, segmentY);
        await pause(700);
        await snapshot('segment-${dark ? 'dark' : 'light'}-held');
        await glide(first, last, segmentY, 1400);
        await glide(last, first, segmentY, 1600);
        await pause(300);
        await pointer('up', first, segmentY);
        await pause(600);
      }
      await driver.tap(find.bySemanticsLabel('Toggle appearance'));
    });
  } finally {
    recording?.kill(ProcessSignal.sigint);
    if (recording != null && await recording.exitCode != 0) {
      throw StateError('Recording failed');
    }
    await driver.close();
  }
}
