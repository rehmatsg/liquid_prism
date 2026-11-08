import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism_example/composition_main.dart';

Future<void> main() async {
  final key = GlobalKey<CompositionExampleState>();
  final errors = <String>[];
  final report = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    report?.call(details);
  };
  enableFlutterDriverExtension(
    enableTextEntryEmulation: false,
    handler: (message) async {
      final request = jsonDecode(message!) as Map<String, dynamic>;
      final state = key.currentState!;
      if (request['op'] == 'configure') {
        state.configure(
          dark: request['dark'] as bool?,
          rtl: request['rtl'] as bool?,
          fill: request['fill'] as bool?,
          textScale: (request['textScale'] as num?)?.toDouble(),
          dock: request['dock'] == null
              ? null
              : GlassTabBarPlacement.values.byName(request['dock'] as String),
          size: request['size'] == null
              ? null
              : GlassControlSize.values.byName(request['size'] as String),
        );
        state.editorFocus.unfocus();
        await WidgetsBinding.instance.endOfFrame;
      }
      if (request['op'] == 'keyboard') {
        state.scroll.jumpTo(state.scroll.position.maxScrollExtent);
        await WidgetsBinding.instance.endOfFrame;
        state.editorFocus.requestFocus();
      }
      if (request['op'] == 'state') {
        final geometry = <String, Object?>{};
        void visit(Element element) {
          final widget = element.widget;
          if (widget.key is ValueKey<String>) {
            final box = element.findRenderObject();
            if (box is RenderBox && box.hasSize) {
              final rect = MatrixUtils.transformRect(
                box.getTransformTo(null),
                Offset.zero & box.size,
              );
              geometry[(widget.key as ValueKey<String>).value] = [
                rect.left,
                rect.top,
                rect.width,
                rect.height,
              ];
            }
          }
          element.visitChildElements(visit);
        }

        visit(WidgetsBinding.instance.rootElement!);
        return jsonEncode({
          'errors': errors,
          'viewSize': [
            WidgetsBinding
                    .instance
                    .platformDispatcher
                    .views
                    .first
                    .physicalSize
                    .width /
                WidgetsBinding
                    .instance
                    .platformDispatcher
                    .views
                    .first
                    .devicePixelRatio,
            WidgetsBinding
                    .instance
                    .platformDispatcher
                    .views
                    .first
                    .physicalSize
                    .height /
                WidgetsBinding
                    .instance
                    .platformDispatcher
                    .views
                    .first
                    .devicePixelRatio,
          ],
          'geometry': geometry,
          'keyboard':
              WidgetsBinding
                  .instance
                  .platformDispatcher
                  .views
                  .first
                  .viewInsets
                  .bottom /
              WidgetsBinding
                  .instance
                  .platformDispatcher
                  .views
                  .first
                  .devicePixelRatio,
          'tab': state.tab,
          'saves': state.saves,
          'favorites': state.favorites,
        });
      }
      return 'ok';
    },
  );
  await LiquidPrism.preload();
  runApp(CompositionExample(key: key));
}
