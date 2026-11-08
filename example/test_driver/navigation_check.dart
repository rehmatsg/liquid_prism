import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  final out = Directory(Platform.environment['PRISM_NAVIGATION_OUT']!)
    ..createSync(recursive: true);
  final simulator = Platform.environment['PRISM_SIMULATOR_ID']!;
  final manifest = <Object?>[];
  final referencePath = Platform.environment['PRISM_NAVIGATION_REFERENCE'];
  final reference = referencePath == null
      ? const <dynamic>[]
      : jsonDecode(File(referencePath).readAsStringSync()) as List;
  double offset(Map<String, Object> entry, String phase, bool dark) {
    if (reference.isEmpty) return phase == 'down' ? 480 : 300;
    final native = reference.cast<Map<String, dynamic>>().firstWhere(
      (state) =>
          state['appearance'] == (dark ? 'dark' : 'light') &&
          state['mode'] == (entry['large'] == true ? 'large' : 'inline') &&
          state['minimization'] == entry['behavior'] &&
          state['restoration'] == (entry['restoration'] ?? 'automatic') &&
          state['phase'] == phase,
    );
    final minimized = entry['behavior'] == 'onScrollDown'
        ? phase == 'down' || entry['restoration'] == 'atScrollEdge'
        : entry['behavior'] == 'onScrollUp' && phase == 'up';
    final inset =
        (entry['large'] == true ? 168.13 : 116) - (minimized ? 54 : 0);
    return inset + 16 - (native['row0'] as List)[1] as double;
  }

  Future<Map<String, dynamic>> request(Map<String, Object?> value) async =>
      jsonDecode(await driver.requestData(jsonEncode(value)))
          as Map<String, dynamic>;
  Future<void> capture(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final state = await request({'op': 'state'});
    if ((state['errors'] as List).isNotEmpty) {
      throw StateError('${state['errors']}');
    }
    final capture = await Process.run(
      'xcrun',
      ['simctl', 'io', simulator, 'screenshot', '${out.path}/$name.png'],
      environment: {
        'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
      },
    );
    if (capture.exitCode != 0) throw StateError('${capture.stderr}');
    manifest.add({'name': name, ...state});
    stdout.writeln('PASS $name');
  }

  try {
    await driver.runUnsynchronized(() async {
      for (final sliver in [false, true]) {
        for (final dark
            in Platform.environment['PRISM_NAVIGATION_TRACES_ONLY'] == 'true'
                ? <bool>[]
                : [false, true]) {
          final prefix =
              '${sliver ? 'sliver' : 'scaffold'}-${dark ? 'dark' : 'light'}';
          for (final entry in [
            {'name': 'large-never', 'large': true, 'behavior': 'never'},
            {'name': 'inline-never', 'large': false, 'behavior': 'never'},
            {
              'name': 'large-onScrollDown-automatic',
              'large': true,
              'behavior': 'onScrollDown',
            },
            {
              'name': 'inline-onScrollDown-automatic',
              'large': false,
              'behavior': 'onScrollDown',
            },
            {
              'name': 'inline-onScrollDown-atScrollEdge',
              'large': false,
              'behavior': 'onScrollDown',
              'restoration': 'atScrollEdge',
            },
            {
              'name': 'inline-onScrollUp-automatic',
              'large': false,
              'behavior': 'onScrollUp',
            },
          ]) {
            await request({
              'op': 'configure',
              'sliver': sliver,
              'dark': dark,
              ...entry,
            });
            final name = '$prefix-${entry['name']}';
            await capture('$name-rest');
            await request({
              'op': 'scroll',
              'offset': offset(entry, 'down', dark),
            });
            await capture('$name-down');
            await request({
              'op': 'scroll',
              'offset': offset(entry, 'up', dark),
            });
            await capture('$name-up');
          }
          await request({
            'op': 'configure',
            'sliver': sliver,
            'dark': dark,
            'rtl': true,
            'alignment': 'leading',
            'textScale': 1.8,
          });
          await capture('$prefix-rtl-large-text');
        }
        await request({'op': 'configure', 'sliver': sliver});
        await Future<void>.delayed(const Duration(milliseconds: 200));
        for (final transition in ['enter', 'exit']) {
          final samples = await driver.requestData(
            jsonEncode({
              'op': 'trace',
              'offset': transition == 'enter' ? 100 : 0,
            }),
          );
          File('${out.path}/${sliver ? 'sliver' : 'scaffold'}-$transition.json')
              .writeAsStringSync(samples);
        }
      }
    });
    stdout.writeln('PASS ${manifest.length} captures and 4 motion traces');
  } finally {
    File(
      '${out.path}/manifest.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
    await driver.close();
  }
}
