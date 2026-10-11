import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Record the reproducible tap/hold/drag fixture on a running simulator app.
Future<void> main() async {
  final simulator = Platform.environment['PRISM_SIMULATOR_ID']!;
  final out = Directory(Platform.environment['PRISM_CONTROLS_OUT']!)
    ..createSync(recursive: true);
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  final layout = jsonDecode(
    await driver.requestData(jsonEncode({'op': 'layout'})),
  ) as Map<String, dynamic>;
  File('${out.path}/layout.json').writeAsStringSync(jsonEncode(layout));
  final recording = await Process.start(
    'xcrun',
    [
      'simctl',
      'io',
      simulator,
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
  recording.stdout.transform(utf8.decoder).listen(stdout.write);
  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
  Future<void> event(String type, double x, double y) async {
    await driver.requestData(jsonEncode({'type': type, 'x': x, 'y': y}));
  }

  Future<void> screenshot(String name) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'io', simulator, 'screenshot', '${out.path}/$name.png'],
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
      await event('move', y, from + (to - from) * t);
      await wait(16);
    }
    await event('move', y, to);
  }

  try {
    await driver.runUnsynchronized(() async {
      await wait(1000);
      final open = (layout['open'] as List).cast<num>();
      final ox = (open[0] + open[2] / 2).toDouble(),
          oy = (open[1] + open[3] / 2).toDouble();
      await event('down', ox, oy);
      await wait(100);
      await event('up', ox, oy);
      await wait(1400);
      await screenshot('medium');
      var sheet =
          (jsonDecode(
                    await driver.requestData(jsonEncode({'op': 'layout'})),
                  )['sheet']
                  as List)
              .cast<num>();
      final x = (sheet[0] + sheet[2] / 2).toDouble();
      var y = (sheet[1] + 12).toDouble();
      await event('down', x, y);
      await wait(500);
      await glide(y, 100, x, 2000);
      await event('up', x, 100);
      await wait(1400);
      await screenshot('large');
      sheet =
          (jsonDecode(
                    await driver.requestData(jsonEncode({'op': 'layout'})),
                  )['sheet']
                  as List)
              .cast<num>();
      y = (sheet[1] + 12).toDouble();
      await event('down', x, y);
      await wait(300);
      await glide(y, 480, x, 2000);
      await event('up', x, 480);
      await wait(1400);
      await screenshot('medium-again');
      final field =
          (jsonDecode(
                    await driver.requestData(jsonEncode({'op': 'layout'})),
                  )['field']
                  as List)
              .cast<num>();
      final fx = (field[0] + field[2] / 2).toDouble(),
          fy = (field[1] + field[3] / 2).toDouble();
      await event('down', fx, fy);
      await wait(100);
      await event('up', fx, fy);
      await wait(1800);
      await screenshot('keyboard');
      await driver.requestData(jsonEncode({'op': 'hide-keyboard'}));
      await wait(1200);
      // Return to medium before the final downward dismissal.
      sheet =
          (jsonDecode(
                    await driver.requestData(jsonEncode({'op': 'layout'})),
                  )['sheet']
                  as List)
              .cast<num>();
      y = (sheet[1] + 10).toDouble();
      await event('down', x, y);
      await glide(y, 480, x, 1600);
      await event('up', x, 480);
      await wait(1400);
      sheet =
          (jsonDecode(
                    await driver.requestData(jsonEncode({'op': 'layout'})),
                  )['sheet']
                  as List)
              .cast<num>();
      y = (sheet[1] + 12).toDouble();
      await event('down', x, y);
      await glide(y, 820, x, 1600);
      await event('up', x, 820);
      await wait(1400);
    });
  } finally {
    recording.kill(ProcessSignal.sigint);
    final code = await recording.exitCode;
    if (code != 0) throw StateError('Recording failed: $code');
    await driver.close();
  }
}
