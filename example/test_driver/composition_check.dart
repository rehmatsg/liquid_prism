import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  final out = Directory(Platform.environment['PRISM_COMPOSITION_OUT']!)
    ..createSync(recursive: true);
  final simulator = Platform.environment['PRISM_SIMULATOR_ID']!;
  final manifest = <Object?>[];
  Future<void> wait() =>
      Future<void>.delayed(const Duration(milliseconds: 600));
  Future<Map<String, dynamic>> state() async =>
      jsonDecode(await driver.requestData(jsonEncode({'op': 'state'})))
          as Map<String, dynamic>;
  Future<void> capture(String name) async {
    await wait();
    final current = await state();
    if ((current['errors'] as List).isNotEmpty) {
      throw StateError(jsonEncode(current['errors']));
    }
    final result = await Process.run(
      'xcrun',
      [
        'simctl',
        'io',
        simulator,
        'screenshot',
        if (Platform.environment['PRISM_COMPOSITION_DISPLAY']
            case final display?)
          '--display=$display',
        '${out.path}/$name.png',
      ],
      environment: {
        'DEVELOPER_DIR': '/Applications/Xcode.app/Contents/Developer',
      },
    );
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    manifest.add({'name': name, ...current});
    stdout.writeln('PASS $name');
  }

  try {
    await driver.runUnsynchronized(() async {
      for (final dark in [false, true]) {
        for (final rtl in [false, true]) {
          for (final dock in [
            'automatic',
            'top',
            'bottom',
            'leading',
            'trailing',
          ]) {
            await driver.requestData(
              jsonEncode({
                'op': 'configure',
                'dark': dark,
                'rtl': rtl,
                'dock': dock,
                'fill': false,
                'textScale': 1,
              }),
            );
            await capture(
              '${dark ? 'dark' : 'light'}-${rtl ? 'rtl' : 'ltr'}-$dock',
            );
          }
        }
      }
      await driver.requestData(
        jsonEncode({
          'op': 'configure',
          'dark': false,
          'rtl': false,
          'dock': 'bottom',
          'fill': true,
        }),
      );
      await capture('fill');
      await driver.tap(find.text('Save'));
      await wait();
      if ((await state())['saves'] != 1) {
        throw StateError('Save did not activate exactly once');
      }
      await driver.tap(find.byValueKey('composition-favorite'));
      await wait();
      if ((await state())['favorites'] != 1) {
        throw StateError('Custom action did not activate exactly once');
      }
      await driver.requestData(
        jsonEncode({'op': 'configure', 'dock': 'top', 'textScale': 1.6}),
      );
      await capture('large-text-top');
      await driver.requestData(
        jsonEncode({'op': 'configure', 'dock': 'leading', 'textScale': 1}),
      );
      await driver.requestData(jsonEncode({'op': 'keyboard'}));
      for (var attempt = 0; attempt < 20; attempt++) {
        if (((await state())['keyboard'] as num) > 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (((await state())['keyboard'] as num) <= 0) {
        throw StateError('Software keyboard did not open');
      }
      await capture('keyboard-leading');
      await driver.requestData(
        jsonEncode({'op': 'configure', 'dock': 'bottom'}),
      );
      await driver.requestData(jsonEncode({'op': 'keyboard'}));
      await capture('keyboard-bottom');
      await driver.requestData(
        jsonEncode({'op': 'configure', 'dock': 'automatic'}),
      );
    });
  } finally {
    File(
      '${out.path}/manifest.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
    await driver.close();
  }
}
