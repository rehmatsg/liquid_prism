import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final simulator = Platform.environment['PRISM_SIMULATOR_ID']!;
  final display = Platform.environment['PRISM_DISPLAY'] ?? '1';
  final rawDir = Directory(Platform.environment['PRISM_RAW_OUT']!)
    ..createSync(recursive: true);
  final outDir = Directory(Platform.environment['PRISM_DEMO_OUT']!)
    ..createSync(recursive: true);

  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );

  Future<void> pause([int ms = 400]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<Map<String, double>> stage() async {
    final res =
        jsonDecode(await driver.requestData(jsonEncode({'op': 'stage'})))
            as Map<String, Object?>;
    return {
      for (final e in res.entries) e.key: (e.value! as num).toDouble(),
    };
  }

  Future<void> pointer(String type, double x, double y) async {
    await driver.requestData(
      jsonEncode({'op': 'pointer', 'type': type, 'x': x, 'y': y}),
    );
  }

  Future<void> drag(
    double x0,
    double y0,
    double x1,
    double y1, {
    int holdMs = 260,
    int moveMs = 700,
    int steps = 42,
  }) async {
    await pointer('down', x0, y0);
    await pause(holdMs);
    final stepMs = math.max(10, moveMs ~/ steps);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final ease = t * t * (3 - 2 * t);
      await pointer('move', x0 + (x1 - x0) * ease, y0 + (y1 - y0) * ease);
      await pause(stepMs);
    }
    await pause(120);
    await pointer('up', x1, y1);
  }

  Future<void> recordScene(
    String name,
    Future<void> Function(Map<String, double> box) script,
  ) async {
    await driver.requestData(jsonEncode({'op': 'scene', 'name': name}));
    await pause(700);
    final box = await stage();
    final rawPath = '${rawDir.path}/$name.mp4';
    final rawFile = File(rawPath);
    if (rawFile.existsSync()) rawFile.deleteSync();
    final rec = await Process.start('xcrun', [
      'simctl',
      'io',
      simulator,
      'recordVideo',
      '--display=$display',
      '--codec=h264',
      '-f',
      rawPath,
    ]);
    rec.stdout.drain<void>();
    rec.stderr.transform(utf8.decoder).listen(stderr.write);
    try {
      await pause(500);
      await script(box);
      await pause(550);
    } finally {
      rec.kill(ProcessSignal.sigint);
      await rec.exitCode;
      await pause(250);
    }

    final dpr = box['dpr']!;
    final cx = (box['x']! * dpr).round();
    final cy = (box['y']! * dpr).round();
    final cw = (box['w']! * dpr).round();
    final ch = (box['h']! * dpr).round();
    final gifPath = '${outDir.path}/$name.gif';
    final pngPath = '${rawDir.path}/$name-mid.png';

    final ff = await Process.run('ffmpeg', [
      '-y',
      '-ss',
      '0.15',
      '-i',
      rawPath,
      '-filter_complex',
      'crop=$cw:$ch:$cx:$cy,fps=24,scale=640:-1:flags=lanczos,split[s0][s1];'
          '[s0]palettegen=max_colors=192:stats_mode=diff[p];'
          '[s1][p]paletteuse=dither=bayer:bayer_scale=3',
      '-loop',
      '0',
      gifPath,
    ]);
    if (ff.exitCode != 0) {
      stderr.writeln('ffmpeg gif failed for $name: ${ff.stderr}');
      exit(1);
    }
    await Process.run('ffmpeg', [
      '-y',
      '-ss',
      '1.2',
      '-i',
      rawPath,
      '-vframes',
      '1',
      '-vf',
      'crop=$cw:$ch:$cx:$cy,scale=760:-1:flags=lanczos',
      pngPath,
    ]);
    final kb = (File(gifPath).lengthSync() / 1024).round();
    stdout.writeln('Recorded $name -> $gifPath ($kb KB)');
  }

  final only = Platform.environment['PRISM_SCENES']
      ?.split(',')
      .where((s) => s.isNotEmpty)
      .toSet();
  bool enabled(String name) => only == null || only.contains(name);

  try {
    await driver.runUnsynchronized(() async {
      for (final name in ['surface', 'clear']) {
        if (!enabled(name)) continue;
        await recordScene(name, (_) async {
          const frames = 90;
          for (var i = 0; i <= frames; i++) {
            final t = i / frames * 2 * math.pi;
            final x = -58 * math.cos(t);
            final y = -22 * math.sin(t) * math.cos(t);
            await driver.requestData(
              jsonEncode({'op': 'offset', 'x': x, 'y': y}),
            );
            await pause(28);
          }
        });
      }

      if (enabled('shapes')) {
        await recordScene('shapes', (box) async {
          final cy = box['y']! + box['h']! / 2;
          final points = [
            box['x']! + 96,
            box['x']! + 209,
            box['x']! + 318,
          ];
          for (final px in points) {
            await pointer('down', px, cy);
            await pause(340);
            await pointer('up', px, cy);
            await pause(380);
          }
        });
      }

      if (enabled('switch')) {
        await recordScene('switch', (box) async {
          final cx = box['x']! + box['w']! / 2;
          final cy = box['y']! + box['h']! / 2;
          await drag(cx - 24, cy, cx + 28, cy, holdMs: 240, moveMs: 420);
          await pause(520);
          await drag(cx + 28, cy, cx - 24, cy, holdMs: 220, moveMs: 380);
        });
      }

      if (enabled('slider')) {
        await recordScene('slider', (box) async {
          final cy = box['y']! + box['h']! / 2;
          final left = box['x']! + (box['w']! - 312) / 2;
          final start = left + 18.5 + (312 - 37) * 0.32;
          final high = left + 18.5 + (312 - 37) * 0.92;
          final low = left + 18.5 + (312 - 37) * 0.14;
          await pointer('down', start, cy);
          await pause(260);
          for (var i = 1; i <= 36; i++) {
            final t = i / 36;
            final ease = t * t * (3 - 2 * t);
            await pointer('move', start + (high - start) * ease, cy);
            await pause(18);
          }
          await pause(160);
          for (var i = 1; i <= 40; i++) {
            final t = i / 40;
            final ease = t * t * (3 - 2 * t);
            await pointer('move', high + (low - high) * ease, cy);
            await pause(18);
          }
          await pause(120);
          await pointer('up', low, cy);
        });
      }

      if (enabled('tabbar')) {
        await recordScene('tabbar', (box) async {
          final cy = box['y']! + box['h']! / 2;
          final cx = box['x']! + box['w']! / 2;
          await drag(cx - 96, cy, cx + 96, cy, holdMs: 260, moveMs: 780);
          await pause(480);
          await drag(cx + 96, cy, cx - 96, cy, holdMs: 240, moveMs: 680);
        });
      }
    });
  } finally {
    await driver.close();
  }
}
