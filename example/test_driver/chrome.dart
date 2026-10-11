import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:flutter_driver/driver_extension.dart';

import 'package:liquid_prism_example/chrome_main.dart' as demo;

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
      if (request['op'] == 'text') {
        final field = WidgetsBinding.instance.rootElement!;
        void fill(Element element) {
          if (element.widget is CupertinoTextField) {
            final text = request['text'] as String;
            (element.widget as CupertinoTextField).controller!.value =
                TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(offset: text.length),
                );
          }
          element.visitChildElements(fill);
        }

        fill(field);
        return 'ok';
      }
      if (request['op'] == 'layout') {
        final result = <String, Object>{};
        void visit(Element element) {
          final widget = element.widget;
          final name = widget.key is ValueKey
              ? '${(widget.key as ValueKey).value}'
              : widget is CupertinoTextField
              ? 'editor'
              : null;
          if (name != null && element.findRenderObject() is RenderBox) {
            final box = element.findRenderObject() as RenderBox;
            if (box.hasSize) {
              final a = box.localToGlobal(Offset.zero),
                  b = box.localToGlobal(box.size.bottomRight(Offset.zero));
              result[name] = [a.dx, a.dy, b.dx - a.dx, b.dy - a.dy];
            }
          }
          if (widget is LiquidPrismPressable &&
              (widget.label == 'Clear search' ||
                  widget.label == 'Cancel search')) {
            final box = element.findRenderObject() as RenderBox;
            final a = box.localToGlobal(Offset.zero),
                b = box.localToGlobal(box.size.bottomRight(Offset.zero));
            result[widget.label] = [a.dx, a.dy, b.dx - a.dx, b.dy - a.dy];
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
