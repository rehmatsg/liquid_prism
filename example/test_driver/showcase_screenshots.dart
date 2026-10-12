import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Saves a screenshot of each showcase screen, in light and dark appearance.
///
/// Launch `showcase.dart` on a simulator first, then run with
/// `DART_VM_SERVICE_URL`, `PRISM_SIMULATOR_ID` and `PRISM_SCREENSHOT_OUT`.
/// Optional: `PRISM_SCREENSHOT_PREFIX` names the files (for example `duo`),
/// `PRISM_SCREENSHOT_DISPLAY` picks a display on multi-display simulators, and
/// `PRISM_SCREENSHOT_CASES=explore,tabs` limits the screens, and
/// `PRISM_SCREENSHOT_SIDEBAR=true` shows tabs in a sidebar at regular width.
Future<void> main() async {
  final env = Platform.environment;
  final device = env['PRISM_SIMULATOR_ID']!;
  final out = Directory(env['PRISM_SCREENSHOT_OUT']!)
    ..createSync(recursive: true);
  final prefix = env['PRISM_SCREENSHOT_PREFIX'] ?? 'showcase';
  final display = switch (env['PRISM_SCREENSHOT_DISPLAY']) {
    null || '' => null,
    final value => value,
  };
  final cases = switch (env['PRISM_SCREENSHOT_CASES']) {
    null || '' => [
      'explore',
      'studio',
      'library',
      'tabs',
      'toolbar',
      'menus',
      'buttons',
    ],
    final value => value.split(','),
  };
  final sidebar = env['PRISM_SCREENSHOT_SIDEBAR'] == 'true';
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: env['DART_VM_SERVICE_URL'],
  );
  try {
    for (final dark in [false, true]) {
      for (final screen in cases) {
        await driver.requestData(
          jsonEncode({
            'op': 'scenario',
            'screen': screen,
            'dark': dark,
            'sidebar': sidebar,
          }),
        );
        // Let route transitions and glass springs settle.
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        final file =
            '${out.path}/$prefix-$screen-${dark ? 'dark' : 'light'}.png';
        final result = await Process.run('xcrun', [
          'simctl',
          'io',
          device,
          'screenshot',
          if (display != null) '--display=$display',
          file,
        ]);
        if (result.exitCode != 0) throw StateError('${result.stderr}');
        stdout.writeln(file);
      }
    }
  } finally {
    await driver.close();
  }
}
