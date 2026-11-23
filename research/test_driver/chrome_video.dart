import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Reproducible simulator interaction and video capture for toolbar/search.
Future<void> main() async {
  final simulator = Platform.environment['PRISM_SIMULATOR_ID']!;
  final out = Directory(Platform.environment['PRISM_CONTROLS_OUT']!)
    ..createSync(recursive: true);
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
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
  final layouts = <String, dynamic>{};
  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
  Future<Map<String, dynamic>> layout() async =>
      jsonDecode(await driver.requestData(jsonEncode({'op': 'layout'})))
          as Map<String, dynamic>;
  Future<void> event(String type, double x, double y) async {
    await driver.requestData(jsonEncode({'type': type, 'x': x, 'y': y}));
  }

  Future<void> tap(String key, {int hold = 100}) async {
    final box = ((await layout())[key] as List).cast<num>();
    final x = (box[0] + box[2] / 2).toDouble(),
        y = (box[1] + box[3] / 2).toDouble();
    await event('down', x, y);
    await wait(hold);
    await event('up', x, y);
    await wait(700);
  }

  Future<void> snapshot(String name) async {
    layouts[name] = await layout();
    final result = await Process.run(
      'xcrun',
      ['simctl', 'io', simulator, 'screenshot', '${out.path}/$name.png'],
      environment: {
        'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
      },
    );
    if (result.exitCode != 0) throw StateError('${result.stderr}');
  }

  Future<void> type(String text) async {
    for (var i = 1; i <= text.length; i++) {
      await driver.requestData(
        jsonEncode({'op': 'text', 'text': text.substring(0, i)}),
      );
      await wait(160);
    }
  }

  try {
    await driver.runUnsynchronized(() async {
      await wait(1000);
      await snapshot('dark-rest');
      await tap('favorite', hold: 1000);
      await tap('share');
      await tap('more', hold: 700);
      await tap('previous', hold: 1000);
      await tap('next');
      await tap('compose', hold: 1000);
      await tap('editor');
      await wait(800);
      await snapshot('dark-focused');
      await type('Prism');
      await wait(600);
      await snapshot('dark-filled');
      await tap('Clear search');
      await wait(400);
      await type('Glass');
      await wait(600);
      await tap('Cancel search', hold: 700);
      await wait(1000);
      await tap('appearance');
      await snapshot('light-rest');
      await tap('favorite', hold: 900);
      await tap('compose', hold: 900);
      await tap('editor');
      await wait(800);
      await type('Search');
      await wait(600);
      await snapshot('light-filled');
      await tap('Cancel search');
      await wait(1000);
      File('${out.path}/layout.json').writeAsStringSync(jsonEncode(layouts));
    });
  } finally {
    recording.kill(ProcessSignal.sigint);
    final code = await recording.exitCode;
    await driver.close();
    if (code != 0) throw StateError('Recording failed: $code');
  }
}
