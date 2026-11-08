import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:liquid_prism/liquid_prism.dart';

Future<void> main() async {
  final key = GlobalKey<_DefaultsState>();
  var last = Offset.zero;
  final clock = Stopwatch()..start();
  enableFlutterDriverExtension(
    handler: (message) async {
      final request = jsonDecode(message!);
      final state = key.currentState!;
      switch (request['op']) {
        case 'scenario':
          state.configure(request as Map<String, dynamic>);
          await WidgetsBinding.instance.endOfFrame;
        case 'pointer':
          final point = Offset(
            (request['x'] as num).toDouble(),
            (request['y'] as num).toDouble(),
          );
          GestureBinding.instance.handlePointerEvent(switch (request['type']) {
            'down' => PointerDownEvent(
              position: point,
              pointer: 7,
              buttons: kPrimaryButton,
              timeStamp: clock.elapsed,
            ),
            'move' => PointerMoveEvent(
              position: point,
              delta: point - last,
              pointer: 7,
              buttons: kPrimaryButton,
              timeStamp: clock.elapsed,
            ),
            _ => PointerUpEvent(
              position: point,
              pointer: 7,
              timeStamp: clock.elapsed,
            ),
          });
          last = point;
        case 'state':
          return jsonEncode({
            'on': state.on,
            'off': state.off,
            'slider': state.slider,
            'segment': state.segment,
            'tab': state.tab,
          });
      }
      return 'ok';
    },
  );
  await LiquidPrism.preload();
  runApp(_Defaults(key: key));
}

class _Defaults extends StatefulWidget {
  const _Defaults({super.key});
  @override
  State<_Defaults> createState() => _DefaultsState();
}

class _DefaultsState extends State<_Defaults> {
  bool dark = false, disabled = false, off = false, on = true;
  double tint = .5, slider = .62;
  int segment = 0, tab = 0;
  String pattern = 'grouped';
  double? frost;
  double period = 32;
  void configure(Map<String, dynamic> data) => setState(() {
    dark = data['dark'] == true;
    disabled = data['disabled'] == true;
    pattern = data['pattern'] as String? ?? 'grouped';
    tint = (data['tint'] as num?)?.toDouble() ?? .5;
    frost = (data['frost'] as num?)?.toDouble();
    period = (data['period'] as num?)?.toDouble() ?? 32;
    off = false;
    on = true;
    slider = (data['slider'] as num?)?.toDouble() ?? .62;
    segment = (data['segment'] as num?)?.toInt() ?? 0;
    tab = (data['tab'] as num?)?.toInt() ?? 0;
  });
  @override
  Widget build(BuildContext context) {
    final brightness = dark ? Brightness.dark : Brightness.light;
    final colors = GlassColors(brightness);
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.blue,
      ),
      home: LiquidPrismTheme(
        data: LiquidPrismThemeData(
          brightness: brightness,
          tint: colors.blue,
          glassTint: tint,
          blur: frost,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final center = constraints.maxWidth / 2;
            Widget at(
              double x,
              double y,
              double width,
              double height,
              Widget child,
            ) => Positioned(
              left: x - width / 2,
              top: y - height / 2,
              width: width,
              height: height,
              child: child,
            );
            Widget surface(String text, Glass glass, GlassShape shape) =>
                LiquidPrism(
                  glass: glass,
                  shape: shape,
                  child: Center(
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 17, color: colors.label),
                    ),
                  ),
                );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _Backdrop(
                    pattern: pattern,
                    dark: dark,
                    period: period,
                  ),
                ),
                at(
                  105,
                  140,
                  150,
                  48,
                  surface('Regular', Glass.regular, GlassShape.capsule),
                ),
                at(
                  center * 2 - 105,
                  140,
                  150,
                  48,
                  surface('Clear', Glass.clear, GlassShape.capsule),
                ),
                at(
                  105,
                  250,
                  150,
                  96,
                  surface(
                    'Surface',
                    Glass.regular,
                    const GlassShape.rect(cornerRadius: 28),
                  ),
                ),
                at(
                  center * 2 - 105,
                  250,
                  150,
                  96,
                  surface(
                    'Tinted',
                    Glass.regular.tint(colors.blue.withValues(alpha: .3)),
                    const GlassShape.rect(cornerRadius: 28),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 320,
                  width: 210,
                  height: 60,
                  child: Center(
                    child: LiquidPrismButton(
                      label: 'Glass',
                      onPressed: disabled ? null : () {},
                      child: const Text('Glass'),
                    ),
                  ),
                ),
                Positioned(
                  left: center * 2 - 210,
                  top: 320,
                  width: 210,
                  height: 60,
                  child: Center(
                    child: LiquidPrismButton(
                      label: 'Prominent',
                      variant: GlassButtonVariant.prominent,
                      onPressed: disabled ? null : () {},
                      child: const Text('Prominent'),
                    ),
                  ),
                ),
                at(
                  105,
                  430,
                  63,
                  44,
                  LiquidPrismSwitch(
                    label: 'Off',
                    value: off,
                    onChanged: disabled ? null : (v) => setState(() => off = v),
                  ),
                ),
                at(
                  center * 2 - 105,
                  430,
                  63,
                  44,
                  LiquidPrismSwitch(
                    label: 'On',
                    value: on,
                    onChanged: disabled ? null : (v) => setState(() => on = v),
                  ),
                ),
                at(
                  center,
                  510,
                  342,
                  44,
                  LiquidPrismSlider(
                    label: 'slider',
                    value: slider,
                    onChanged: disabled
                        ? null
                        : (v) => setState(() => slider = v),
                  ),
                ),
                at(
                  center,
                  590,
                  342,
                  44,
                  LiquidPrismSegmentedControl<int>(
                    label: 'Segments',
                    selectedValue: segment,
                    onValueChanged: disabled
                        ? null
                        : (v) => setState(() => segment = v),
                    children: const {
                      0: Text('First'),
                      1: Text('Second'),
                      2: Text('Third'),
                    },
                  ),
                ),
                at(
                  center,
                  670,
                  342,
                  44,
                  const LiquidPrismSearchField(placeholder: 'Search'),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 21,
                  child: Center(
                    child: LiquidPrismTabBar(
                      selectedIndex: tab,
                      onSelected: disabled
                          ? null
                          : (v) => setState(() => tab = v),
                      tabs: const [
                        LiquidPrismTab(
                          label: 'Home',
                          icon: Icon(CupertinoIcons.house_fill),
                        ),
                        LiquidPrismTab(
                          label: 'Search',
                          icon: Icon(CupertinoIcons.search),
                        ),
                        LiquidPrismTab(
                          label: 'Profile',
                          icon: Icon(CupertinoIcons.person_fill),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Backdrop extends StatefulWidget {
  const _Backdrop({
    required this.pattern,
    required this.dark,
    required this.period,
  });
  final String pattern;
  final bool dark;
  final double period;
  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop> {
  ui.Image? image;
  String? signature;
  @override
  void dispose() {
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!['grayx', 'grayy'].contains(widget.pattern)) {
      final color = switch (widget.pattern) {
        'white' => const Color(0xFFFFFFFF),
        'grouped' =>
          widget.dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        'cell' =>
          widget.dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
        _ => widget.dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      };
      return ColoredBox(color: color);
    }
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final next = '${widget.pattern}:${widget.period}:$size:$dpr';
    if (signature != next) {
      signature = next;
      final width = (size.width * dpr).round(),
          height = (size.height * dpr).round();
      final bytes = Uint8List(width * height * 4);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final coordinate = widget.pattern == 'grayx' ? x : y;
          final value =
              ((.5 +
                          .35 *
                              math.cos(
                                2 *
                                    math.pi *
                                    (coordinate + .5) /
                                    dpr /
                                    widget.period,
                              )) *
                      255)
                  .round();
          final offset = (y * width + x) * 4;
          bytes[offset] = value;
          bytes[offset + 1] = value;
          bytes[offset + 2] = value;
          bytes[offset + 3] = 255;
        }
      }
      ui.decodeImageFromPixels(bytes, width, height, ui.PixelFormat.rgba8888, (
        result,
      ) {
        if (!mounted || signature != next) {
          result.dispose();
          return;
        }
        setState(() {
          image?.dispose();
          image = result;
        });
      });
    }
    return RawImage(
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
    );
  }
}
