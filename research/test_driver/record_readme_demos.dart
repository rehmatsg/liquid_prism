import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final simulator = Platform.environment['PRISM_SIMULATOR_ID']!;
  final display = Platform.environment['PRISM_DISPLAY'] ?? '1';
  final wallpaperPath = Platform.environment['PRISM_WALLPAPER']!;
  final rawDir = Directory(Platform.environment['PRISM_RAW_OUT']!)
    ..createSync(recursive: true);
  final outDir = Directory(Platform.environment['PRISM_DEMO_OUT']!)
    ..createSync(recursive: true);

  final scaledWallpaper = '${rawDir.path}/wallpaper.jpg';
  final prep = await Process.run('ffmpeg', [
    '-y',
    '-i',
    wallpaperPath,
    '-vf',
    'scale=1800:-1:flags=lanczos',
    '-q:v',
    '2',
    scaledWallpaper,
  ]);
  if (prep.exitCode != 0) {
    stderr.writeln('Failed to prepare wallpaper: ${prep.stderr}');
    exit(1);
  }
  final wallpaperB64 = base64Encode(File(scaledWallpaper).readAsBytesSync());

  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );

  Future<void> pause([int ms = 400]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<Map<String, double>> stage() async {
    final res = jsonDecode(
      await driver.requestData(jsonEncode({'op': 'stage'})),
    ) as Map<String, Object?>;
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
    int steps = 50,
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
    final rawPath = '${rawDir.path}/$name-raw.mp4';
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
    final cx = (box['x']! * dpr).round() + 2;
    final cy = (box['y']! * dpr).round() + 2;
    final cw = (((box['w']! * dpr).round() - 4) ~/ 2) * 2;
    final ch = (((box['h']! * dpr).round() - 4) ~/ 2) * 2;
    final mp4Path = '${outDir.path}/$name.mp4';
    final pngPath = '${rawDir.path}/$name-mid.png';

    final ff = await Process.run('ffmpeg', [
      '-y',
      '-ss',
      '0.2',
      '-i',
      rawPath,
      '-vf',
      'crop=$cw:$ch:$cx:$cy',
      '-r',
      '60',
      '-c:v',
      'libx264',
      '-preset',
      'slow',
      '-crf',
      '17',
      '-pix_fmt',
      'yuv420p',
      '-movflags',
      '+faststart',
      '-an',
      mp4Path,
    ]);
    if (ff.exitCode != 0) {
      stderr.writeln('ffmpeg mp4 failed for $name: ${ff.stderr}');
      exit(1);
    }
    await Process.run('ffmpeg', [
      '-y',
      '-ss',
      '1.2',
      '-i',
      mp4Path,
      '-vframes',
      '1',
      pngPath,
    ]);
    final kb = (File(mp4Path).lengthSync() / 1024).round();
    stdout.writeln('Recorded $name -> $mp4Path (${cw}x$ch @ 60fps, $kb KB)');
  }

  final only = Platform.environment['PRISM_SCENES']
      ?.split(',')
      .where((s) => s.isNotEmpty)
      .toSet();
  bool enabled(String name) => only == null || only.contains(name);

  try {
    await driver.runUnsynchronized(() async {
      await driver.requestData(
        jsonEncode({'op': 'wallpaper', 'base64': wallpaperB64}),
      );
      await pause(600);

      for (final name in ['regular-glass', 'clear-glass']) {
        if (!enabled(name)) continue;
        await recordScene(name, (_) async {
          const frames = 130;
          for (var i = 0; i <= frames; i++) {
            final t = i / frames * 2 * math.pi;
            final x = -62 * math.cos(t);
            final y = -22 * math.sin(t) * math.cos(t);
            await driver.requestData(
              jsonEncode({'op': 'offset', 'x': x, 'y': y}),
            );
            await pause(18);
          }
        });
      }

      if (enabled('glass-shapes')) {
        await recordScene('glass-shapes', (box) async {
          final cy = box['y']! + box['h']! / 2;
          final points = [
            box['x']! + 92,
            box['x']! + 201,
            box['x']! + 308,
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
          final left = box['x']! + (box['w']! - 300) / 2;
          final start = left + 18.5 + (300 - 37) * 0.32;
          final high = left + 18.5 + (300 - 37) * 0.92;
          final low = left + 18.5 + (300 - 37) * 0.14;
          await pointer('down', start, cy);
          await pause(260);
          for (var i = 1; i <= 42; i++) {
            final t = i / 42;
            final ease = t * t * (3 - 2 * t);
            await pointer('move', start + (high - start) * ease, cy);
            await pause(16);
          }
          await pause(160);
          for (var i = 1; i <= 48; i++) {
            final t = i / 48;
            final ease = t * t * (3 - 2 * t);
            await pointer('move', high + (low - high) * ease, cy);
            await pause(16);
          }
          await pause(120);
          await pointer('up', low, cy);
        });
      }

      if (enabled('tab-bar')) {
        await recordScene('tab-bar', (box) async {
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
