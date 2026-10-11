import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';

import 'package:liquid_prism_example/controls_main.dart' as demo;

import 'package:liquid_prism/liquid_prism.dart';

Future<void> main() async {
  var last = Offset.zero;
  final clock = Stopwatch()..start();
  enableFlutterDriverExtension(
    handler: (message) async {
      final request = jsonDecode(message!);
      if (request['op'] == 'layout') {
        final result = <String, Object>{};
        final state = <String, Object>{};
        result['state'] = state;
        void visit(Element element) {
          final widget = element.widget;
          if (widget is LiquidPrismSwitch &&
              widget.key == const ValueKey('switch')) {
            state['switch'] = widget.value;
          }
          if (widget is LiquidPrismSlider &&
              widget.key == const ValueKey('slider')) {
            state['slider'] = widget.value;
          }
          if (widget is LiquidPrismSegmentedControl<int> &&
              widget.key == const ValueKey('segments')) {
            state['segments'] = widget.selectedValue;
          }
          final key = element.widget.key;
          if (key is ValueKey &&
              ['switch', 'slider', 'segments'].contains(key.value)) {
            final box = element.findRenderObject()! as RenderBox;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            result[key.value as String] = [
              rect.left,
              rect.top,
              rect.width,
              rect.height,
            ];
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
