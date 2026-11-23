import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism_example/showcase/widgets.dart';

final _scene = ValueNotifier<String>('surface');
final _lensOffset = ValueNotifier<Offset>(const Offset(-52, -16));
final _switchValue = ValueNotifier<bool>(false);
final _sliderValue = ValueNotifier<double>(0.32);
final _tabIndex = ValueNotifier<int>(0);
final _stageKey = GlobalKey();

Future<void> main() async {
  var last = Offset.zero;
  final clock = Stopwatch()..start();
  enableFlutterDriverExtension(
    enableTextEntryEmulation: false,
    handler: (message) async {
      final request = jsonDecode(message!) as Map<String, Object?>;
      switch (request['op']) {
        case 'scene':
          _scene.value = request['name']! as String;
          _lensOffset.value = const Offset(-52, -16);
          _switchValue.value = false;
          _sliderValue.value = 0.32;
          _tabIndex.value = 0;
          await WidgetsBinding.instance.endOfFrame;
          return 'ok';
        case 'offset':
          _lensOffset.value = Offset(
            (request['x']! as num).toDouble(),
            (request['y']! as num).toDouble(),
          );
          return 'ok';
        case 'stage':
          final box =
              _stageKey.currentContext!.findRenderObject()! as RenderBox;
          final origin = box.localToGlobal(Offset.zero);
          final dpr = WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio;
          return jsonEncode({
            'x': origin.dx,
            'y': origin.dy,
            'w': box.size.width,
            'h': box.size.height,
            'dpr': dpr,
          });
        case 'pointer':
          final position = Offset(
            (request['x']! as num).toDouble(),
            (request['y']! as num).toDouble(),
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
          return 'ok';
      }
      return 'ok';
    },
  );
  WidgetsFlutterBinding.ensureInitialized();
  await Prism.initialize();
  runApp(const _ReadmeDemoApp());
}

class _ReadmeDemoApp extends StatelessWidget {
  const _ReadmeDemoApp();

  @override
  Widget build(BuildContext context) => CupertinoApp(
    debugShowCheckedModeBanner: false,
    theme: const CupertinoThemeData(brightness: Brightness.light),
    home: PrismTheme(
      data: const PrismThemeData(brightness: Brightness.light),
      child: ColoredBox(
        color: const Color(0xFF0E1117),
        child: Center(
          child: SizedBox(
            key: _stageKey,
            width: 420,
            height: 256,
            child: ValueListenableBuilder<String>(
              valueListenable: _scene,
              builder: (context, scene, _) => switch (scene) {
                'surface' => const _SurfaceDemo(clear: false),
                'clear' => const _SurfaceDemo(clear: true),
                'shapes' => const _ShapesDemo(),
                'switch' => const _SwitchDemo(),
                'slider' => const _SliderDemo(),
                'tabbar' => const _TabBarDemo(),
                _ => const _SurfaceDemo(clear: false),
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _SurfaceDemo extends StatelessWidget {
  const _SurfaceDemo({required this.clear});
  final bool clear;

  @override
  Widget build(BuildContext context) => Art(
    variant: clear ? 1 : 0,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 22,
          left: 24,
          child: Text(
            clear ? 'CLEAR GLASS' : 'LIQUID PRISM 1.0',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Color(0xD8FFFFFF),
            ),
          ),
        ),
        ValueListenableBuilder<Offset>(
          valueListenable: _lensOffset,
          builder: (context, offset, child) =>
              Transform.translate(offset: offset, child: child),
          child: PrismSurface(
            glass: clear ? PrismGlass.clear : PrismGlass.regular,
            shape: PrismShape.rect(cornerRadius: clear ? 30 : 28),
            child: SizedBox(
              width: 220,
              height: 126,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      clear ? 'Clear optics.' : 'Hello, glass.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.5,
                        color: clear
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF101318),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clear ? 'Sharp rim refraction' : 'Live frosted lens',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: clear
                            ? const Color(0xD8FFFFFF)
                            : const Color(0xAA101318),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ShapesDemo extends StatelessWidget {
  const _ShapesDemo();

  @override
  Widget build(BuildContext context) => Art(
    variant: 1,
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrismSurface(
            glass: PrismGlass.clear.interactive(),
            shape: const PrismShape.rect(cornerRadius: 26),
            child: const SizedBox(
              width: 112,
              height: 112,
              child: Center(
                child: Icon(
                  CupertinoIcons.sparkles,
                  size: 32,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          PrismSurface(
            glass: PrismGlass.clear.interactive(),
            shape: PrismShape.circle,
            child: const SizedBox.square(
              dimension: 78,
              child: Icon(
                CupertinoIcons.add,
                size: 30,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
          const SizedBox(width: 18),
          PrismSurface(
            glass: PrismGlass.clear.interactive(),
            shape: PrismShape.capsule,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Text(
                'Capsule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SwitchDemo extends StatelessWidget {
  const _SwitchDemo();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF2F2F7),
    child: Center(
      child: ValueListenableBuilder<bool>(
        valueListenable: _switchValue,
        builder: (context, value, _) => PrismSwitch(
          label: 'Notifications',
          value: value,
          onChanged: (next) => _switchValue.value = next,
          style: const PrismSwitchStyle(scale: 2),
        ),
      ),
    ),
  );
}

class _SliderDemo extends StatelessWidget {
  const _SliderDemo();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF2F2F7),
    child: Center(
      child: SizedBox(
        width: 312,
        child: ValueListenableBuilder<double>(
          valueListenable: _sliderValue,
          builder: (context, value, _) => PrismSlider(
            label: 'Volume',
            value: value,
            onChanged: (next) => _sliderValue.value = next,
          ),
        ),
      ),
    ),
  );
}

class _TabBarDemo extends StatelessWidget {
  const _TabBarDemo();

  @override
  Widget build(BuildContext context) => Art(
    variant: 0,
    child: Center(
      child: ValueListenableBuilder<int>(
        valueListenable: _tabIndex,
        builder: (context, selected, _) => PrismTabBar(
          selectedIndex: selected,
          onSelected: (next) => _tabIndex.value = next,
          tabs: const [
            PrismTab(
              label: 'Explore',
              icon: Icon(CupertinoIcons.sparkles),
            ),
            PrismTab(
              label: 'Studio',
              icon: Icon(CupertinoIcons.slider_horizontal_3),
            ),
            PrismTab(
              label: 'Library',
              icon: Icon(CupertinoIcons.square_grid_2x2_fill),
            ),
          ],
        ),
      ),
    ),
  );
}
