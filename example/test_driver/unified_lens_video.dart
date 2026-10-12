import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Hold, slow glide, fast reversal and release for all four lifted controls.
Future<void> main() async {
  final simulator = Platform.environment['PRISM_SIMULATOR_ID']!;
  final dark = Platform.environment['PRISM_LENS_DARK'] == 'true';
  final cases =
      Platform.environment['PRISM_LENS_CASES']?.split(',') ??
      ['switches', 'sliders', 'segments', 'tabs'];
  final out = Directory(Platform.environment['PRISM_LENS_OUT']!)
    ..createSync(recursive: true);
  Future<ProcessResult> simctl(List<String> args) => Process.run(
    'xcrun',
    ['simctl', ...args],
    environment: {
      'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
    },
  );
  await simctl(['launch', simulator, 'dev.rehmatsg.liquidPrismExample']);
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
  Future<Map<String, dynamic>> layout() async =>
      jsonDecode(await driver.requestData(jsonEncode({'op': 'layout'})))
          as Map<String, dynamic>;
  final manifest = <Map<String, Object?>>[];
  try {
    await driver.runUnsynchronized(() async {
      for (final name in cases) {
        await driver.requestData(
          jsonEncode({
            'op': 'scenario',
            'screen': name == 'tabs' ? 'explore' : name,
            'dark': dark,
          }),
        );
        await wait(1400);
        final initial = await layout();
        final geometry = initial['geometry'] as Map;
        final key = switch (name) {
          'switches' => 'Let it glow',
          'sliders' => 'Intensity',
          'segments' => 'Perspective',
          _ => 'showcase-navigation',
        };
        final rect = (geometry[key] as List).cast<num>();
        final left = rect[0].toDouble(), width = rect[2].toDouble();
        final y = (rect[1] + rect[3] / 2).toDouble();
        final start = switch (name) {
          'switches' => left + 42.5,
          'sliders' => left + 18.5 + (width - 37) * .62,
          'segments' => left + width / 6,
          _ => left + 4 + (width - 8) / 6,
        };
        final end = switch (name) {
          'switches' => left + 20.5,
          'sliders' => left + 18.5 + (width - 37) * .15,
          'segments' => left + width * 5 / 6,
          _ => left + 4 + (width - 8) * 5 / 6,
        };
        final recording = await Process.start(
          'xcrun',
          [
            'simctl',
            'io',
            simulator,
            'recordVideo',
            '--codec=h264',
            '${out.path}/$name-flutter-raw.mp4',
          ],
          environment: {
            'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
          },
        );
        recording.stderr.transform(utf8.decoder).listen(stdout.write);
        recording.stdout.drain<void>();
        final clock = Stopwatch()..start();
        final phases = <Map<String, Object>>[];
        final samples = <Map<String, Object?>>[];
        void phase(String value) =>
            phases.add({'phase': value, 't': clock.elapsedMilliseconds / 1000});
        Future<void> event(String type, double x) async {
          await driver.requestData(
            jsonEncode({'op': 'pointer', 'type': type, 'x': x, 'y': y}),
          );
        }

        Future<void> sample() async => samples.add({
          't': clock.elapsedMilliseconds / 1000,
          ...await layout(),
        });
        Future<void> glide(double from, double to, int duration) async {
          final travel = Stopwatch()..start();
          while (travel.elapsedMilliseconds < duration) {
            final p = (travel.elapsedMilliseconds / duration).clamp(0.0, 1.0);
            await event('move', from + (to - from) * p);
            await sample();
            await wait(16);
          }
          await event('move', to);
        }

        Future<void> hold(int duration) async {
          final clock = Stopwatch()..start();
          while (clock.elapsedMilliseconds < duration) {
            await sample();
            await wait(16);
          }
        }

        try {
          phase('Rest');
          await wait(400);
          phase('Hold');
          await event('down', start);
          await wait(1200);
          await sample();
          await simctl([
            'io',
            simulator,
            'screenshot',
            '${out.path}/$name-flutter-held.png',
          ]);
          phase('Slow glide');
          await glide(start, end, 2000);
          phase('Stationary hold');
          await hold(1000);
          phase('Fast reversal');
          await glide(end, start, 300);
          phase('Stationary hold');
          await hold(1000);
          var releaseX = start;
          if (name == 'sliders') {
            phase('Approach 95%');
            final near = left + 18.5 + (width - 37) * .95;
            await glide(start, near, 600);
            await hold(300);
            phase('Final 5% · slow glide');
            releaseX = left + width - 18.5 + .001;
            await glide(near, releaseX, 1800);
            phase('100% fill');
            await hold(500);
            final complete = await layout();
            if ((complete['values'] as Map)['level'] != 1) {
              throw StateError('Slider did not reach 100%');
            }
            await simctl([
              'io',
              simulator,
              'screenshot',
              '${out.path}/slider-100.png',
            ]);
          }
          phase('Release');
          await event('up', releaseX);
          await wait(1200);
          await sample();
        } finally {
          recording.kill(ProcessSignal.sigint);
          await recording.exitCode;
        }
        manifest.add({
          'name': name,
          'centerY': y,
          'phases': phases,
          'duration': clock.elapsedMilliseconds / 1000,
        });
        File('${out.path}/$name-flutter-motion.json').writeAsStringSync(
          jsonEncode({'samples': samples, 'initial': initial}),
        );
        File('${out.path}/flutter-manifest.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(manifest),
        );
        stdout.writeln('Recorded $name');
      }
    });
  } finally {
    await driver.close();
  }
}
