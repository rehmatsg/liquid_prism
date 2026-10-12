import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:liquid_prism_example/main.dart' as app;
import 'package:liquid_prism_example/showcase/app.dart' as showcase;
import 'package:liquid_prism_example/showcase/component_page.dart' as detail;
import 'package:liquid_prism_example/showcase/model.dart' as state;
import 'package:liquid_prism_example/showcase/pages.dart' as pages;
import 'package:liquid_prism_example/showcase/previews.dart' as previews;
import 'package:liquid_prism_example/showcase/widgets.dart' as design;

Future<void> main() async {
  var last = Offset.zero;
  final clock = Stopwatch()..start();
  enableFlutterDriverExtension(
    enableTextEntryEmulation: false,
    handler: (message) async {
      final request = jsonDecode(message!);
      if (request['op'] == 'scenario') {
        StatefulElement? home;
        void locate(Element element) {
          if (element.widget is showcase.ShowcaseHome) {
            home = element as StatefulElement;
          }
          element.visitChildElements(locate);
        }

        locate(WidgetsBinding.instance.rootElement!);
        final model = (home!.widget as showcase.ShowcaseHome).model;
        model.change(() {
          model.dark = request['dark'] == true;
          model.clear = request['clear'] == true;
          model.accent = request['accent'] ?? 'blue';
          model.labels = request['labels'] != false;
          model.wallpaper = request['wallpaper'] ?? 0;
          model.frost = (request['frost'] as num?)?.toDouble() ?? 4;
          model.refraction = (request['refraction'] as num?)?.toDouble() ?? 24;
          model.enabled = true;
          model.level = .62;
          model.segment = 0;
          model.taps = 0;
          model.favorite = false;
        });
        final navigator = Navigator.of(home!);
        navigator.popUntil((route) => route.isFirst);
        final screen = request['screen'] as String;
        final root = ['explore', 'studio', 'library'].indexOf(screen);
        final dynamic homeState = home!.state;
        homeState.select(root < 0 ? 2 : root);
        await WidgetsBinding.instance.endOfFrame;
        for (final controller in homeState.scroll as List<ScrollController>) {
          if (controller.hasClients) controller.jumpTo(0);
        }
        if (root < 0) {
          final info = state.components.firstWhere((c) => c.id == screen);
          navigator.push<void>(
            CupertinoPageRoute(
              builder: (_) => detail.ComponentPage(info: info, model: model),
            ),
          );
        }
        return 'ok';
      }
      if (request['op'] == 'layout' || request['op'] == 'scroll-panel') {
        final geometry = <String, List<double>>{};
        final glass = <Map<String, Object?>>[];
        double? textScale;
        state.ShowcaseModel? model;
        Element? scrollTarget;
        const panels = {
          'Look & feel': 'look-feel',
          'A color story': 'palette',
          'The optics': 'optics',
          'Behind the glass': 'artwork',
          '01 / Controls': 'explore-controls',
        };
        String? panelName(Element element) {
          String? name;
          void search(Element child) {
            if (child.widget is design.Eyebrow) {
              name ??= panels[(child.widget as design.Eyebrow).text];
            }
            child.visitChildElements(search);
          }

          search(element);
          return name;
        }

        void visit(Element element) {
          final widget = element.widget;
          if (widget is showcase.ShowcaseHome) {
            textScale = MediaQuery.textScalerOf(element).scale(1);
            model = widget.model;
          }
          final box = element.findRenderObject();
          if (box is RenderBox && box.hasSize && box.attached) {
            final rect = MatrixUtils.transformRect(
              box.getTransformTo(null),
              Offset.zero & box.size,
            );
            final frame = [rect.left, rect.top, rect.width, rect.height];
            String? name;
            if (widget is LiquidPrismSwitch) name = widget.label;
            if (widget is LiquidPrismSlider) name = widget.label;
            if (widget is LiquidPrismSegmentedControl) name = widget.label;
            if (widget is LiquidPrismButton) name = widget.label;
            if (widget is LiquidPrismTabBar) {
              name = widget.key == const ValueKey('showcase-navigation')
                  ? 'showcase-navigation'
                  : 'component-tabs';
            }
            if (widget is pages.HeroCanvas) name = 'hero-canvas';
            if (widget is previews.LensPlayground) name = 'lens-canvas';
            if (widget is previews.ComponentPreview) name = 'preview';
            if (widget is design.Panel) name = panelName(element);
            if (widget.key is ValueKey<String>) {
              final key = (widget.key as ValueKey<String>).value;
              if ([
                'studio-lens',
                'demo-toolbar',
                'library-search',
                'demo-search',
              ].contains(key)) {
                name = key;
              }
            }
            if (widget is Text &&
                widget.data == 'A little glass.\nA lot of possibility.') {
              name = 'explore-title';
            }
            if (name != null) {
              geometry[name] = frame;
              if (name == request['panel']) scrollTarget = element;
            }
            if (widget is LiquidPrism) {
              String? owner;
              element.visitAncestorElements((ancestor) {
                final w = ancestor.widget;
                if (w is LiquidPrismSwitch) owner = w.label;
                if (w is LiquidPrismSlider) owner = w.label;
                if (w is LiquidPrismSegmentedControl) owner = w.label;
                return owner == null;
              });
              glass.add({
                // Development-only inspection of the package renderer.
                // ignore: invalid_use_of_internal_member
                'role': widget.role.toString(),
                'owner': owner,
                'frame': frame,
              });
            }
          }
          element.visitChildElements(visit);
        }

        visit(WidgetsBinding.instance.rootElement!);
        if (request['op'] == 'scroll-panel') {
          if (scrollTarget == null) return 'missing panel';
          await Scrollable.ensureVisible(scrollTarget!, alignment: 0);
          return 'ok';
        }
        return jsonEncode({
          'geometry': geometry,
          'glass': glass,
          'textScale': textScale,
          'values': {
            'level': model?.level,
            'enabled': model?.enabled,
            'segment': model?.segment,
          },
        });
      }
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
