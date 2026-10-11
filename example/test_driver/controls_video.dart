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
      await event('move', from + (to - from) * t, y);
      await wait(16);
    }
    await event('move', to, y);
  }

  try {
    await driver.runUnsynchronized(() async {
      await wait(1000);
      for (final name in ['switch', 'slider', 'segments']) {
        final rect = (layout[name] as List).cast<num>();
        final left = rect[0].toDouble(), y = (rect[1] + rect[3] / 2).toDouble();
        final width = rect[2].toDouble();
        final double start, end, reverse;
        if (name == 'switch') {
          await event('down', left + 20.5, y);
          await wait(100);
          await event('up', left + 20.5, y);
          await wait(1300);
          start = left + 42.5;
          end = left + 20.5;
          reverse = start;
        } else if (name == 'slider') {
          start = left + 18.5 + (width - 37) * .4;
          end = left + width - 18.5;
          reverse = left + 18.5;
        } else {
          start = left + width / 2;
          end = left + width * 5 / 6;
          reverse = left + width / 6;
          await event('down', start, y);
          await wait(100);
          await event('up', start, y);
          await wait(1300);
        }
        await event('down', start, y);
        await wait(1100);
        await screenshot('$name-held');
        final heldState = jsonDecode(
          await driver.requestData(jsonEncode({'op': 'layout'})),
        )['state'];
        if (name == 'switch' && heldState['switch'] != true) {
          throw StateError('Switch tap failed');
        }
        if (name == 'segments' && heldState['segments'] != 1) {
          throw StateError('Segment tap failed');
        }
        await glide(start, end, y, 2000);
        await wait(700);
        await glide(end, reverse, y, 2500);
        await wait(700);
        if (name == 'slider') {
          final state = jsonDecode(
            await driver.requestData(jsonEncode({'op': 'layout'})),
          )['state'];
          if ((state['slider'] as num) > .02) {
            throw StateError('Slider did not track the full reverse drag');
          }
        }
        await event('up', reverse, y);
        await wait(1500);
      }
      await screenshot('rest');
    });
  } finally {
    recording.kill(ProcessSignal.sigint);
    final code = await recording.exitCode;
    if (code != 0) throw StateError('Recording failed: $code');
    await driver.close();
  }
}
