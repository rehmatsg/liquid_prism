import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';

import 'package:liquid_prism_example/sheet_main.dart' as demo;

Future<void> main() async {
  var last = Offset.zero;
  final clock = Stopwatch()..start();
  enableFlutterDriverExtension(
    enableTextEntryEmulation: false,
    handler: (message) async {
      final request = jsonDecode(message!);
      if (request['op'] == 'hide-keyboard') {
        FocusManager.instance.primaryFocus?.unfocus();
        return 'ok';
      }
      if (request['op'] == 'layout') {
        final result = <String, Object>{};
        void visit(Element element) {
          final widget = element.widget;
          final name =
              widget.key == const ValueKey('liquid-prism-sheet-surface')
              ? 'sheet'
              : widget.key is ValueKey &&
                    (widget.key as ValueKey).value == 'open-sheet'
              ? 'open'
              : widget.key == const ValueKey('sheet-field')
              ? 'field'
              : null;
          if (name != null) {
            final box = element.findRenderObject() as RenderBox;
            final a = box.localToGlobal(Offset.zero),
                b = box.localToGlobal(box.size.bottomRight(Offset.zero));
            result[name] = [a.dx, a.dy, b.dx - a.dx, b.dy - a.dy];
          }
          element.visitChildElements(visit);
        }

        visit(WidgetsBinding.instance.rootElement!);
        return jsonEncode(result);
      }
      final pos = Offset(
        (request['x'] as num).toDouble(),
        (request['y'] as num).toDouble(),
      );
      GestureBinding.instance.handlePointerEvent(switch (request['type']) {
        'down' => PointerDownEvent(
          position: pos,
          pointer: 7,
          buttons: kPrimaryButton,
          timeStamp: clock.elapsed,
        ),
        'move' => PointerMoveEvent(
          position: pos,
          delta: pos - last,
          pointer: 7,
          buttons: kPrimaryButton,
          timeStamp: clock.elapsed,
        ),
        _ => PointerUpEvent(
          position: pos,
          pointer: 7,
          timeStamp: clock.elapsed,
        ),
      });
      last = pos;
      return 'ok';
    },
  );
  await demo.main();
}
