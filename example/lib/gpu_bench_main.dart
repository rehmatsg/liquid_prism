// GPU cost of glass, measured without a display: each scenario's layer tree
// is rendered offscreen as fast as the GPU accepts it, then read back so the
// clock stops only when the GPU has finished. No vsync, no thermal drift.
//
//   tool/gpu_bench/run.py            (builds, runs and tabulates)
//
// GPU_BENCH_SCENES: comma list of scenario names (default: all).
// GPU_BENCH_FRAMES: frames per timed round (default 300).
// GPU_BENCH_SHOTS: write gpu_bench_<scene>_<PRISM_EXP>.png to the temp
// folder instead of timing.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_prism/liquid_prism.dart';

final _scene = ValueNotifier<_Scenario>(_scenarios.first);

class _Scenario {
  const _Scenario(this.name, this.dark, this.build);
  final String name;
  final bool dark;
  final Widget Function() build;
}

final _scenarios = <_Scenario>[
  for (final dark in [true, false]) ...[
    _Scenario('none${dark ? '' : '-light'}', dark, () => const SizedBox()),
    _Scenario('free7${dark ? '' : '-light'}', dark, _free),
    _Scenario('chrome${dark ? '' : '-light'}', dark, () => const SizedBox()),
  ],
  _Scenario('buttons8', true, () => _grid(8, 104, 48)),
  // Content painted between surfaces: each needs its own fill capture.
  _Scenario('split8', true, () => _grid(8, 104, 48, split: true)),
  _Scenario('cards3', true, () => _grid(3, 354, 120, radius: 28)),
  _Scenario('bars4', true, () => _grid(4, 370, 64)),
];

Widget _glass(double w, double h, {double? radius, bool button = false}) {
  final shape = radius == null
      ? GlassShape.capsule
      : GlassShape.rect(cornerRadius: radius);
  final content = SizedBox(
    width: w,
    height: h,
    child: const Center(child: Text('Glass')),
  );
  return button
      ? LiquidPrismButton(
          label: 'button',
          padding: EdgeInsets.zero,
          shape: shape,
          onPressed: () {},
          child: content,
        )
      : LiquidPrism(shape: shape, child: content);
}

Widget _grid(
  int count,
  double w,
  double h, {
  double? radius,
  bool split = false,
}) => SafeArea(
  child: Center(
    child: Wrap(
      spacing: 12,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (split) const Text('·'),
          _glass(w, h, radius: radius, button: radius == null),
        ],
      ],
    ),
  ),
);

/// Seven free-standing surfaces: a card, four buttons, a bar and a puck.
Widget _free() => Stack(
  fit: StackFit.expand,
  children: [
    SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          _glass(354, 120, radius: 28),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              _glass(104, 48, button: true),
              _glass(104, 48, button: true),
              _glass(56, 56, button: true),
            ],
          ),
          const SizedBox(height: 16),
          _glass(180, 48, button: true),
          const SizedBox(height: 16),
          _glass(370, 64),
          const SizedBox(height: 8),
        ],
      ),
    ),
    Positioned(left: 140, top: 330, child: _glass(120, 52)),
  ],
);

class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) => ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.only(top: 40),
    itemCount: 12,
    itemBuilder: (context, i) {
      final hue = ((i * 37) % 360).toDouble();
      return Container(
        height: 84,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HSVColor.fromAHSV(1, hue, .8, .95).toColor(),
              HSVColor.fromAHSV(1, (hue + 90) % 360, .7, .35).toColor(),
            ],
          ),
        ),
        child: Text('Item $i\nSecond line of detail text for item $i'),
      );
    },
  );
}

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _scene,
    builder: (context, scene, _) {
      final brightness = scene.dark ? Brightness.dark : Brightness.light;
      final chrome = scene.name.startsWith('chrome');
      final background = scene.dark
          ? const Color(0xFF000000)
          : const Color(0xFFF2F2F7);
      return CupertinoApp(
        debugShowCheckedModeBanner: false,
        theme: CupertinoThemeData(brightness: brightness),
        builder: (context, child) => LiquidPrismTheme(
          data: LiquidPrismThemeData(
            brightness: brightness,
            glass: Glass.regular,
          ),
          child: child!,
        ),
        home: chrome
            ? LiquidPrismScaffold(
                backgroundColor: background,
                tabBar: LiquidPrismTabBar(
                  tabs: const [
                    LiquidPrismTab(
                      label: 'Home',
                      icon: Icon(CupertinoIcons.house),
                    ),
                    LiquidPrismTab(
                      label: 'Search',
                      icon: Icon(CupertinoIcons.search),
                    ),
                    LiquidPrismTab(
                      label: 'Saved',
                      icon: Icon(CupertinoIcons.bookmark),
                    ),
                  ],
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    const _Backdrop(),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              LiquidPrismButton(
                                label: 'Back',
                                padding: const EdgeInsets.all(12),
                                onPressed: () {},
                                child: const Icon(
                                  CupertinoIcons.chevron_back,
                                  size: 20,
                                ),
                              ),
                              const Spacer(),
                              LiquidPrismToolbarGroup(
                                size: GlassToolbarSize.navigation,
                                items: [
                                  for (final icon in [
                                    CupertinoIcons.star,
                                    CupertinoIcons.share,
                                    CupertinoIcons.ellipsis,
                                  ])
                                    GlassToolbarItem(
                                      label: 'Item',
                                      icon: Icon(icon),
                                      onPressed: () {},
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : CupertinoPageScaffold(
                backgroundColor: background,
                child: Stack(
                  fit: StackFit.expand,
                  children: [const _Backdrop(), scene.build()],
                ),
              ),
      );
    },
  );
}

Future<void> _frames(int count) async {
  for (var i = 0; i < count; i++) {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
  }
}

/// The current layer tree rendered offscreen at the view's physical size.
Future<ui.Image> _render() async {
  final view = RendererBinding.instance.renderViews.first;
  final size = view.flutterView.physicalSize;
  // ignore: invalid_use_of_protected_member
  final scene = view.layer!.buildScene(ui.SceneBuilder());
  final image = await scene.toImage(size.width.round(), size.height.round());
  scene.dispose();
  return image;
}

/// Milliseconds per offscreen frame: (until submitted, until the GPU is done).
Future<(double, double)> _measure(int frames) async {
  final clock = Stopwatch()..start();
  ui.Image? last;
  for (var i = 0; i < frames; i++) {
    final image = await _render();
    last?.dispose();
    last = image;
  }
  final submitted = clock.elapsedMicroseconds / 1000 / frames;
  await last!.toByteData();
  last.dispose();
  return (submitted, clock.elapsedMicroseconds / 1000 / frames);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  runApp(const _App());
  final only = Platform.environment['GPU_BENCH_SCENES']?.split(',');
  final frames = int.parse(Platform.environment['GPU_BENCH_FRAMES'] ?? '300');
  await _frames(10);
  for (final scene in _scenarios) {
    if (only != null && !only.contains(scene.name)) continue;
    _scene.value = scene;
    await _frames(20);
    if (Platform.environment['GPU_BENCH_SHOTS'] != null) {
      final image = await _render();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final tag = Platform.environment['PRISM_EXP'] ?? '';
      final file = File(
        '${Directory.systemTemp.path}/gpu_bench_${scene.name}_$tag.png',
      )..writeAsBytesSync(png!.buffer.asUint8List());
      stdout.writeln('GPU_BENCH_SHOT ${file.path}');
      continue;
    }
    await _measure(30);
    final rounds = <(double, double)>[];
    stdout.writeln('GPU_BENCH_BEGIN ${scene.name}');
    for (var i = 0; i < 3; i++) {
      rounds.add(await _measure(frames));
    }
    stdout.writeln('GPU_BENCH_END ${scene.name}');
    rounds.sort((a, b) => a.$2.compareTo(b.$2));
    stdout.writeln(
      'GPU_BENCH ${scene.name} submit_ms=${rounds[1].$1.toStringAsFixed(3)} '
      'frame_ms=${rounds[1].$2.toStringAsFixed(3)} '
      'best_ms=${rounds[0].$2.toStringAsFixed(3)}',
    );
  }
  stdout.writeln('GPU_BENCH_DONE');
  await stdout.flush();
  exit(0);
}
