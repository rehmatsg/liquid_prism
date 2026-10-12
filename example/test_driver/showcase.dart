import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:liquid_prism_example/main.dart' as app;

Future<void> main() async {
  var last = Offset.zero;
  final clock = Stopwatch()..start();
  enableFlutterDriverExtension(
    enableTextEntryEmulation: false,
    handler: (message) async {
      final request = jsonDecode(message!);
      if (request['op'] == 'menu-state') {
        return jsonEncode({
          'native': await liquidMenus.supportsNativeMenu,
          'presented': liquidMenus.isPresented,
        });
      }
      if (request['op'] == 'text') {
        void fill(Element element) {
          if (element.widget is CupertinoTextField &&
              (element.widget as CupertinoTextField).focusNode?.hasFocus ==
                  true) {
            final field = element.widget as CupertinoTextField;
            final text = request['text'] as String;
            field.controller!.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
            field.onChanged?.call(text);
          }
          element.visitChildElements(fill);
        }

        fill(WidgetsBinding.instance.rootElement!);
      }
      if (request['op'] == 'pointer') {
        final position = Offset(
          (request['x'] as num).toDouble(),
          (request['y'] as num).toDouble(),
        );
        GestureBinding.instance.handlePointerEvent(switch (request['type']) {
          'down' => PointerDownEvent(
            position: position,
            pointer: 7,
            buttons: kPrimaryButton,
            timeStamp: clock.elapsed,
          ),
          'move' => PointerMoveEvent(
            position: position,
            delta: position - last,
            pointer: 7,
            buttons: kPrimaryButton,
            timeStamp: clock.elapsed,
          ),
          _ => PointerUpEvent(
            position: position,
            pointer: 7,
            timeStamp: clock.elapsed,
          ),
        });
        last = position;
      }
      return 'ok';
    },
  );
  await app.main();
}
