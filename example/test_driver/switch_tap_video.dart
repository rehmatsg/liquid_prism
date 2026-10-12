import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Quick on/off taps with frame geometry for the native timing comparison.
Future<void> main() async {
  final sim = Platform.environment['PRISM_SIMULATOR_ID']!;
  final out = Directory(Platform.environment['PRISM_LENS_OUT']!)
    ..createSync(recursive: true);
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
  Future<Map<String, dynamic>> layout() async =>
      jsonDecode(await driver.requestData(jsonEncode({'op': 'layout'})))
          as Map<String, dynamic>;
  Process? video;
  try {
    await driver.runUnsynchronized(() async {
      await driver.requestData(
        jsonEncode({'op': 'scenario', 'screen': 'switches'}),
      );
      await wait(1200);
      final initial = await layout();
      final rect = (initial['geometry']['Let it glow'] as List).cast<num>();
      final x = (rect[0] + rect[2] / 2).toDouble();
      final y = (rect[1] + rect[3] / 2).toDouble();
      video = await Process.start(
        'xcrun',
        [
          'simctl',
          'io',
          sim,
          'recordVideo',
          '--codec=h264',
          '${out.path}/switch-taps-raw.mp4',
        ],
        environment: {
          'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
        },
      );
      video!.stderr.transform(utf8.decoder).listen(stdout.write);
      video!.stdout.drain<void>();
      final clock = Stopwatch()..start();
      final samples = <Map<String, Object?>>[];
      final events = <Map<String, Object?>>[];
      Future<void> pointer(String type) async {
        events.add({'type': type, 't': clock.elapsedMicroseconds / 1e6});
        await driver.requestData(
          jsonEncode({'op': 'pointer', 'type': type, 'x': x, 'y': y}),
        );
      }

      await wait(400);
      for (var i = 0; i < 4; i++) {
        await pointer('down');
        await wait(67);
        await pointer('up');
        final settling = Stopwatch()..start();
        while (settling.elapsedMilliseconds < 1000) {
          samples.add({
            't': clock.elapsedMicroseconds / 1e6,
            ...await layout(),
          });
          await wait(16);
        }
      }
      File('${out.path}/switch-taps-motion.json').writeAsStringSync(
        jsonEncode({'initial': initial, 'events': events, 'samples': samples}),
      );
      stdout.writeln('Switch center: $x, $y');
    });
  } finally {
    if (video != null) {
      video!.kill(ProcessSignal.sigint);
      await video!.exitCode;
    }
    await driver.close();
  }
}
