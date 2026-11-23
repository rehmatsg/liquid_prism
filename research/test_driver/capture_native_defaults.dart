import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: env['DART_VM_SERVICE_URL'],
  );
  final output = Directory(env['PRISM_DEFAULTS_OUT']!)
    ..createSync(recursive: true);
  final scenarios = jsonDecode(File(args[0]).readAsStringSync()) as List;
  final device = env['PRISM_SIMULATOR_ID']!;
  Future<void> capture(String id) async {
    final result = await Process.run('xcrun', [
      'simctl',
      'io',
      device,
      'screenshot',
      '${output.path}/$id-flutter.png',
    ]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    stdout.writeln(id);
  }

  try {
    await driver.runUnsynchronized(() async {
      if (args.contains('--states')) {
        final groups = <String, Map<String, dynamic>>{};
        for (final entry in scenarios.cast<Map>()) {
          final state = entry['state'] as String;
          final id = entry['id'] as String;
          groups[id.substring(0, id.length - state.length - 1)] =
              Map<String, dynamic>.from(entry);
        }
        for (final entry in groups.entries) {
          await driver.requestData(
            jsonEncode({'op': 'scenario', ...entry.value}),
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
          const targets = {
            'button': [105.0, 350.0],
            'prominent': [297.0, 350.0],
            'off': [86.1, 430.0],
            'on': [315.9, 430.0],
            'slider': [242.04, 510.0],
            'segment': [87.0, 590.0],
            'tab': [115.0, 822.0],
          };
          for (final target in targets.entries) {
            Future<void> pointer(String type) async {
              await driver.requestData(
                jsonEncode({
                  'op': 'pointer',
                  'type': type,
                  'x': target.value[0],
                  'y': target.value[1],
                }),
              );
            }

            await pointer('down');
            await Future<void>.delayed(
              Duration(
                milliseconds:
                    args.contains('--tabs-only') && target.key != 'tab'
                    ? 250
                    : 900,
              ),
            );
            if (!args.contains('--tabs-only') || target.key == 'tab') {
              await capture('${entry.key}-${target.key}-held');
            }
            await pointer('up');
            await Future<void>.delayed(
              Duration(
                milliseconds:
                    args.contains('--tabs-only') && target.key != 'tab'
                    ? 400
                    : 750,
              ),
            );
            if (!args.contains('--tabs-only') || target.key == 'tab') {
              await capture('${entry.key}-${target.key}-released');
            }
          }
        }
      } else {
        for (final scenario in scenarios) {
          await driver.requestData(
            jsonEncode({'op': 'scenario', ...scenario as Map}),
          );
          await Future<void>.delayed(const Duration(milliseconds: 700));
          await capture(scenario['id'] as String);
        }
      }
    });
  } finally {
    await driver.close();
  }
}
