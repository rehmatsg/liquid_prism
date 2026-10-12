import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Captures both implementations in matching states on one simulator.
/// Install/launch NativeShowcase with --inspect, and run showcase.dart first.
Future<void> main() async {
  final device = Platform.environment['PRISM_SIMULATOR_ID']!;
  final out = Directory(Platform.environment['PRISM_COMPARE_OUT']!)
    ..createSync(recursive: true);
  const native = 'com.rehmat.glassshowcase.native';
  const flutter = 'dev.rehmatsg.liquidPrismExample';
  Future<ProcessResult> simctl(List<String> args) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', ...args],
      environment: {
        'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
      },
    );
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    return result;
  }

  await simctl(['launch', device, flutter]);
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );

  final container = (await simctl([
    'get_app_container',
    device,
    native,
    'data',
  ])).stdout.toString().trim();
  final documents = Directory('$container/Documents');
  Future<void> pause(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));
  final filter = Platform.environment['PRISM_COMPARE_CASES']?.split(',');
  final screens = [
    'explore',
    'studio',
    'library',
    'surfaces',
    'buttons',
    'switches',
    'sliders',
    'segments',
    'tabs',
    'toolbar',
    'menus',
    'search',
    'sheets',
  ];
  final cases = <Map<String, Object>>[];
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final screen in screens) {
      cases.add({'id': '$screen-$mode', 'screen': screen, 'dark': dark});
    }
    for (final panel in [
      'look-feel',
      'optics',
      'artwork',
      'explore-controls',
    ]) {
      final screen = panel == 'explore-controls' ? 'explore' : 'studio';
      cases.add({
        'id': '$panel-$mode',
        'screen': screen,
        'dark': dark,
        'scroll': panel,
      });
    }
  }
  final manifest = File('${out.path}/manifest.json');
  final completed = manifest.existsSync()
      ? (jsonDecode(manifest.readAsStringSync()) as List)
            .map((entry) => Map<String, Object>.from(entry as Map))
            .toList()
      : <Map<String, Object>>[];
  try {
    await driver.runUnsynchronized(() async {
      for (final scenario in cases) {
        final id = scenario['id']! as String;
        if (filter != null && !filter.contains(id)) continue;
        await simctl(['launch', device, flutter]);
        await pause(300);
        await driver.requestData(jsonEncode({'op': 'scenario', ...scenario}));
        await pause(1100);
        if (scenario['scroll'] != null) {
          final response = await driver.requestData(
            jsonEncode({'op': 'scroll-panel', 'panel': scenario['scroll']}),
          );
          if (response != 'ok') throw StateError('$id: $response');
          await pause(500);
        }
        final flutterData = await driver.requestData(
          jsonEncode({'op': 'layout'}),
        );
        final decoded = jsonDecode(flutterData) as Map<String, dynamic>;
        if (decoded['geometry'] is! Map) {
          throw StateError(
            'Restart showcase.dart to register comparison handlers',
          );
        }
        File('${out.path}/$id-flutter.json').writeAsStringSync(flutterData);
        await simctl([
          'io',
          device,
          'screenshot',
          '${out.path}/$id-flutter.png',
        ]);

        await simctl(['launch', device, native, '--inspect']);
        await pause(1200);
        final data = File('${documents.path}/$id.json');
        if (data.existsSync()) data.deleteSync();
        File('${documents.path}/command.json')
            .writeAsStringSync(jsonEncode({...scenario, 'snapshot': id}));
        await pause(1600);
        if (!data.existsSync()) throw StateError('No native geometry for $id');
        final captured = jsonDecode(data.readAsStringSync()) as Map;
        if (captured['dark'] != scenario['dark']) {
          throw StateError('Native appearance was not applied for $id');
        }
        data.copySync('${out.path}/$id-native.json');
        await simctl([
          'io',
          device,
          'screenshot',
          '${out.path}/$id-native.png',
        ]);
        completed.removeWhere((entry) => entry['id'] == id);
        completed.add(scenario);
        stdout.writeln('Captured $id');
        File('${out.path}/manifest.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(completed),
        );
      }
      // Resume Flutter before the driver's final frame-sync request: iOS
      // suspends the VM service while the native reference is foreground.
      await simctl(['launch', device, flutter]);
      await pause(300);
    });
  } finally {
    await driver.close();
  }
}
