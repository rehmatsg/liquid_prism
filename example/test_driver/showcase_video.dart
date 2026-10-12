import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final device = Platform.environment['PRISM_SIMULATOR_ID']!;
  final out = Directory(Platform.environment['PRISM_SHOWCASE_OUT']!)
    ..createSync(recursive: true);
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  final recording = await Process.start(
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
  Future<void> pause([int ms = 700]) =>
      Future<void>.delayed(Duration(milliseconds: ms));
  final scroller = find.byType('SingleChildScrollView');
  Future<void> show(SerializableFinder target) async {
    await driver.scrollUntilVisible(
      scroller,
      target,
      dyScroll: -260,
      alignment: .35,
    );
  }

  Future<void> tap(String label) async {
    await driver.tap(find.bySemanticsLabel(label));
    await pause();
  }

  Future<void> pointer(String type, double x, double y) async => driver
      .requestData(jsonEncode({'op': 'pointer', 'type': type, 'x': x, 'y': y}));
  Future<void> glide(
    SerializableFinder target,
    double dx,
    double dy, {
    int hold = 250,
  }) async {
    final start = await driver.getCenter(target);
    await pointer('down', start.dx, start.dy);
    await pause(hold);
    for (var i = 1; i <= 32; i++) {
      final t = i / 32;
      await pointer(
        'move',
        start.dx + dx * math.sin(t * math.pi / 2),
        start.dy + dy * t,
      );
      await pause(20);
    }
    await pointer('up', start.dx + dx, start.dy + dy);
    await pause();
  }

  Future<void> snapshot(String name) async {
    await Process.run(
      'xcrun',
      ['simctl', 'io', device, 'screenshot', '${out.path}/$name.png'],
      environment: {
        'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
      },
    );
  }

  Future<void> component(String title, Future<void> Function() action) async {
    final target = find.bySemanticsLabel('Explore $title');
    await show(target);
    await driver.tap(target);
    await pause(800);
    await snapshot(title.toLowerCase().replaceAll(' ', '-'));
    await action();
    await tap('Back to showcase');
  }

  try {
    await driver.runUnsynchronized(() async {
      await pause(1200);
      await snapshot('explore');
      await tap('Change artwork');
      await tap('Change artwork');
      await tap('Change artwork');
      await tap('Studio');
      await snapshot('studio');
      await glide(find.byValueKey('studio-lens'), 55, 30);
      await glide(find.byValueKey('studio-lens'), -90, -50);
      await tap('Toggle appearance');
      await snapshot('studio-dark');
      await pause(900);
      await tap('Toggle appearance');
      await show(find.bySemanticsLabel('Use mint tint'));
      await tap('Use mint tint');
      await tap('Library');
      await snapshot('library');
      await component('Glass surfaces', () async {
        await glide(find.byValueKey('studio-lens'), 70, 45);
        await tap('Select surface 1');
        await pause(700);
        await tap('Select surface 2');
      });
      await component('Buttons', () async {
        await tap('Add a prominent tap');
        await tap('Favorite');
      });
      await component('Switches', () async {
        await driver.tap(
          find.descendant(
            of: find.byType('LiquidPrismSwitch'),
            matching: find.bySemanticsLabel('Let it glow'),
            firstMatchOnly: true,
          ),
        );
        await pause(800);
      });
      await component('Sliders', () async {
        await glide(find.byValueKey('component-slider'), 80, 0);
      });
      await component('Segmented controls', () async {
        for (final label in ['Dusk', 'Night']) {
          await driver.tap(
            find.descendant(
              of: find.byType('ComponentPreview'),
              matching: find.bySemanticsLabel(label),
              firstMatchOnly: true,
            ),
          );
          await pause();
        }
      });
      await component('Tab bars', () async {
        await glide(find.bySemanticsLabel('Discover'), 170, 0, hold: 600);
        await tap('Saved');
      });
      await component('Toolbars', () async {
        final p = await driver.getCenter(find.bySemanticsLabel('Star'));
        await pointer('down', p.dx, p.dy);
        await pause(950);
        await pointer('up', p.dx, p.dy);
        await pause();
      });
      await component('Search fields', () async {
        await driver.tap(find.byType('CupertinoTextField'));
        await pause(800);
        await driver.requestData(
          jsonEncode({'op': 'text', 'text': 'A fresh start'}),
        );
        await pause(1200);
        await snapshot('search-focused');
        await tap('Cancel search');
      });
      await tap('Explore');
      await pause(1200);
    });
  } finally {
    recording.kill(ProcessSignal.sigint);
    await recording.exitCode;
    await driver.close();
  }
}
