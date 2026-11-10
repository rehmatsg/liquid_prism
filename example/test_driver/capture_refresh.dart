import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Run against test_driver/showcase.dart on an Impeller simulator or device.
Future<void> main(List<String> args) async {
  final out = Directory(args.single)..createSync(recursive: true);
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
  Future<String> request(Map<String, Object> data) =>
      driver.requestData(jsonEncode(data));
  Future<void> capture(String name) async {
    await File('${out.path}/$name.png').writeAsBytes(await driver.screenshot());
  }

  try {
    await driver.runUnsynchronized(() async {
      await File('${out.path}/device.json')
          .writeAsString(await request({'op': 'system-chrome'}));
      for (final compact in [false, true]) {
        for (final dark in [false, true]) {
          final name =
              '${compact ? 'compact' : 'large'}-${dark ? 'dark' : 'light'}';
          await request({
            'op': 'scenario',
            'screen': 'refresh',
            'dark': dark,
            'compact': compact,
          });
          await wait(800);
          await request({'op': 'pointer', 'type': 'down', 'x': 180, 'y': 350});
          for (var y = 355; y <= 390; y += 5) {
            await request({'op': 'pointer', 'type': 'move', 'x': 180, 'y': y});
            await wait(16);
          }
          await capture('$name-early');
          for (var y = 395; y <= 450; y += 5) {
            await request({'op': 'pointer', 'type': 'move', 'x': 180, 'y': y});
            await wait(16);
          }
          await wait(180);
          await capture('$name-attached');
          for (var y = 455; y <= 750; y += 5) {
            await request({'op': 'pointer', 'type': 'move', 'x': 180, 'y': y});
            await wait(16);
          }
          await wait(350);
          await capture('$name-detached');
          await request({'op': 'pointer', 'type': 'up', 'x': 180, 'y': 750});
          await wait(300);
          await capture('$name-refreshing');
          await wait(2200);
        }
      }
    });
  } finally {
    await driver.close();
  }
}
