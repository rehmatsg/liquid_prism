// Sustained-load benchmark with scripted, real gestures. One build per renderer:
//   flutter run --profile -t lib/bench_main.dart --dart-define=MODE=prism
// MODE: none | prism | prismnoscale | prismnoblur | chrome | lge | lgeblur.
// DURATION: seconds of scripted use. `chrome` is the app-chrome layout: a
// scaffold with tab bar, toolbar group, round button and search field.
//
// Synthesized pointer events go through Flutter's gesture arena, so scrolling
// uses real fling physics, buttons run their press response and pages use the
// Cupertino transition and back swipe. A 40 s script repeats: fling the feed,
// drag a glass puck, press buttons, open a detail page (tap back and swipe
// back). Every 10 s a `BENCH {json}` line reports frame, CPU, thermal and
// battery statistics; `BENCH_DONE` ends the run.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:liquid_prism/liquid_prism.dart';

const _mode = String.fromEnvironment('MODE', defaultValue: 'prism');
const _duration = int.fromEnvironment('DURATION', defaultValue: 600);
const _channel = MethodChannel('liquid_prism/bench');

/// Liquid Prism's regular frost, applied to the blurred LGE variant.
const _frost = 3.3;

final _navigator = GlobalKey<NavigatorState>();
final _openKey = GlobalKey();
final _backKey = GlobalKey();
final _buttonKeys = [GlobalKey(), GlobalKey(), GlobalKey()];
final _puck = ValueNotifier(const Offset(140, 330));
String _phase = 'start';

/// Cleared at the end of the run so the device idles on a static frame.
void _setPhase(String phase) {
  _phase = phase;
  debugPrint('PHASE $phase ${DateTime.now().millisecondsSinceEpoch}');
}

/// IDLE builds hold a static frame with the screen awake (cooldown between runs).
bool _running = !bool.fromEnvironment('IDLE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  await LiquidGlassShaders.ensureLoaded();
  await _channel.invokeMethod<void>('setup', {'brightness': 0.5});
  runApp(const _BenchApp());
  try {
    File('${Directory.systemTemp.path}/bench.log').writeAsStringSync('');
  } catch (_) {}
  _Stats().start();
  if (_running) {
    SchedulerBinding.instance.addPostFrameCallback((_) => _Script().run());
  } else {
    _setPhase('idle');
  }
}

class _BenchApp extends StatelessWidget {
  const _BenchApp();
  @override
  Widget build(BuildContext context) => CupertinoApp(
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: const CupertinoThemeData(brightness: Brightness.dark),
    builder: (context, child) => LiquidPrismTheme(
      data: const LiquidPrismThemeData(
        brightness: Brightness.dark,
        glass: Glass.regular,
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
        child: child!,
      ),
    ),
    home: const _FeedPage(),
  );
}

// ---------------------------------------------------------------------------
// Pages

class _FeedPage extends StatelessWidget {
  const _FeedPage();
  @override
  Widget build(BuildContext context) {
    if (_mode == 'chrome') return const _ChromeFeedPage();
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 150, bottom: 120),
            itemCount: 600,
            itemBuilder: (context, i) => _Tile(i),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _surface(354, 120, 28, const Text('Feed card')),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 12,
                  children: [
                    _button(_buttonKeys[0], 104, 48, const Text('One')),
                    _button(_buttonKeys[1], 104, 48, const Text('Two')),
                    _button(
                      _buttonKeys[2],
                      56,
                      56,
                      const Icon(CupertinoIcons.heart),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _button(
                  _openKey,
                  180,
                  48,
                  const Text('Open details'),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const _DetailPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _surface(370, 64, 32, const Text('Tab bar')),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // A glass puck the script drags around (moving glass).
          ValueListenableBuilder(
            valueListenable: _puck,
            builder: (context, offset, child) =>
                Positioned(left: offset.dx, top: offset.dy, child: child!),
            child: GestureDetector(
              onPanUpdate: (d) => _puck.value += d.delta,
              child: _surface(120, 52, 26, const Text('Drag')),
            ),
          ),
        ],
      ),
    );
  }
}

/// The consumer layout: scrolling content under a tab bar, a navigation
/// toolbar group, a round back button and a search field. The script's keys
/// map onto the toolbar items and the back button.
class _ChromeFeedPage extends StatefulWidget {
  const _ChromeFeedPage();
  @override
  State<_ChromeFeedPage> createState() => _ChromeFeedPageState();
}

class _ChromeFeedPageState extends State<_ChromeFeedPage> {
  var _tab = 0;
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiquidPrismScaffold(
      backgroundColor: const Color(0xFF000000),
      tabBar: LiquidPrismTabBar(
        tabs: const [
          LiquidPrismTab(label: 'Home', icon: Icon(CupertinoIcons.house)),
          LiquidPrismTab(label: 'Search', icon: Icon(CupertinoIcons.search)),
          LiquidPrismTab(label: 'Saved', icon: Icon(CupertinoIcons.bookmark)),
          LiquidPrismTab(label: 'Profile', icon: Icon(CupertinoIcons.person)),
        ],
        selectedIndex: _tab,
        onSelected: (index) => setState(() => _tab = index),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 150, bottom: 160),
            itemCount: 600,
            itemBuilder: (context, i) => _Tile(i),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      LiquidPrismButton(
                        key: _openKey,
                        label: 'Open details',
                        padding: const EdgeInsets.all(12),
                        onPressed: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const _DetailPage(),
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.chevron_back,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      LiquidPrismToolbarGroup(
                        size: GlassToolbarSize.navigation,
                        items: [
                          GlassToolbarItem(
                            key: _buttonKeys[0],
                            label: 'Favorite',
                            icon: const Icon(CupertinoIcons.star),
                            onPressed: () {},
                          ),
                          GlassToolbarItem(
                            key: _buttonKeys[1],
                            label: 'Share',
                            icon: const Icon(CupertinoIcons.share),
                            onPressed: () {},
                          ),
                          GlassToolbarItem(
                            key: _buttonKeys[2],
                            label: 'More',
                            icon: const Icon(CupertinoIcons.ellipsis),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                LiquidPrismSearchField(controller: _query, restingInset: 20),
                const SizedBox(height: 12),
              ],
            ),
          ),
          ValueListenableBuilder(
            valueListenable: _puck,
            builder: (context, offset, child) =>
                Positioned(left: offset.dx, top: offset.dy, child: child!),
            child: GestureDetector(
              onPanUpdate: (d) => _puck.value += d.delta,
              child: LiquidPrism(
                glass: Glass.clear,
                shape: GlassShape.capsule,
                child: const SizedBox(
                  width: 120,
                  height: 52,
                  child: Center(child: Text('Drag')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF101014),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GridView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 140, 12, 40),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 900,
            itemBuilder: (context, i) => _Tile(i * 7, compact: true),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  spacing: 12,
                  children: [
                    _button(
                      _backKey,
                      56,
                      56,
                      const Icon(CupertinoIcons.back),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: _surface(286, 56, 28, const Text('Details')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass per renderer. Shapes and sizes are identical across modes.

Widget _surface(double w, double h, double r, Widget child) {
  final content = SizedBox(
    width: w,
    height: h,
    child: Center(child: child),
  );
  return switch (_mode) {
    'prism' || 'prismnoscale' || 'prismnoblur' => LiquidPrism(
      shape: _prismShape(w, h, r),
      blur: _mode == 'prismnoblur' ? 0 : null,
      child: content,
    ),
    'lge' || 'lgeblur' => LiquidGlassLens(style: _lgeStyle(r), child: content),
    _ => _plain(r, content),
  };
}

Widget _button(
  Key key,
  double w,
  double h,
  Widget child, {
  VoidCallback? onTap,
}) {
  final content = SizedBox(
    width: w,
    height: h,
    child: Center(child: child),
  );
  return switch (_mode) {
    'prism' || 'prismnoscale' || 'prismnoblur' => LiquidPrismButton(
      key: key,
      blur: _mode == 'prismnoblur' ? 0 : null,
      // Isolates the cost of the press scale transform on backdrop filters.
      motion: _mode == 'prismnoscale' ? const GlassMotion(pressScale: 1) : null,
      label: 'button',
      padding: EdgeInsets.zero,
      shape: _prismShape(w, h, h / 2),
      onPressed: onTap ?? () {},
      child: content,
    ),
    'lge' || 'lgeblur' => GestureDetector(
      key: key,
      onTap: onTap ?? () {},
      child: LiquidGlassLens(
        style: _lgeStyle(h / 2),
        touch: const LiquidGlassTouch(flex: LiquidGlassFlex()),
        child: content,
      ),
    ),
    _ => GestureDetector(
      key: key,
      onTap: onTap ?? () {},
      child: _plain(h / 2, content),
    ),
  };
}

GlassShape _prismShape(double w, double h, double r) => w == h
    ? GlassShape.circle
    : r * 2 >= h
    ? GlassShape.capsule
    : GlassShape.rect(cornerRadius: r);

LiquidGlassStyle _lgeStyle(double r) => LiquidGlassStyle(
  shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: r),
  appearance: LiquidGlassAppearance(
    blur: _mode == 'lgeblur'
        ? const LiquidGlassBlur(sigmaX: _frost, sigmaY: _frost)
        : const LiquidGlassBlur(),
  ),
);

Widget _plain(double r, Widget child) => DecoratedBox(
  decoration: ShapeDecoration(
    color: const Color(0x33FFFFFF),
    shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(r)),
  ),
  child: child,
);

/// Busy, high-contrast content: photo-like gradients, stripes and text.
class _Tile extends StatelessWidget {
  const _Tile(this.index, {this.compact = false});
  final int index;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final hue = ((index * 37) % 360).toDouble();
    final tile = DecoratedBox(
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
      child: CustomPaint(
        painter: _Stripes(index),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: compact
              ? Text(
                  '#$index',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item $index',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text('The quick brown fox jumps over the lazy dog.'),
                  ],
                ),
        ),
      ),
    );
    if (compact) return tile;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(height: 108, child: tile),
    );
  }
}

class _Stripes extends CustomPainter {
  _Stripes(this.index);
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x66000000);
    for (var x = (index % 3) * 6.0; x < size.width * .4; x += 14) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * .6 + x, 0, 3, size.height),
        paint,
      );
    }
    canvas.drawCircle(
      Offset(size.width * .85, size.height * .5),
      size.height * .28,
      Paint()..color = const Color(0xCCFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_Stripes old) => old.index != index;
}

// ---------------------------------------------------------------------------
// Gesture script

class _Script {
  final _clock = Stopwatch()..start();
  var _pointer = 100;

  Duration get _ts => _clock.elapsed;
  Future<void> _frame() => SchedulerBinding.instance.endOfFrame;
  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));
  void _send(PointerEvent e) => GestureBinding.instance.handlePointerEvent(e);

  Offset _center(GlobalKey key) {
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// A finger drag sampled once per frame, so velocity tracking sees real
  /// timestamps and a fast drag ends in a fling.
  Future<void> _drag(
    Offset from,
    Offset Function(double t) path,
    int ms,
  ) async {
    final id = _pointer++;
    _send(PointerDownEvent(pointer: id, position: from, timeStamp: _ts));
    final start = _clock.elapsedMilliseconds;
    var last = from;
    while (true) {
      await _frame();
      final t = math.min(1.0, (_clock.elapsedMilliseconds - start) / ms);
      final p = path(t);
      _send(
        PointerMoveEvent(
          pointer: id,
          position: p,
          delta: p - last,
          timeStamp: _ts,
        ),
      );
      last = p;
      if (t >= 1 || !_running) break;
    }
    _send(PointerUpEvent(pointer: id, position: last, timeStamp: _ts));
  }

  Future<void> _line(Offset a, Offset b, int ms) async {
    if (_running) await _drag(a, (t) => Offset.lerp(a, b, t)!, ms);
  }

  Future<void> _tap(GlobalKey key, {int hold = 90}) async {
    if (!_running || key.currentContext == null) return;
    final p = _center(key);
    final id = _pointer++;
    _send(PointerDownEvent(pointer: id, position: p, timeStamp: _ts));
    await _wait(hold);
    _send(PointerUpEvent(pointer: id, position: p, timeStamp: _ts));
  }

  /// Returns to the feed when a scripted swipe did not complete its pop, so
  /// every cycle starts from the same page stack.
  Future<void> _home() async {
    final nav = _navigator.currentState!;
    if (!nav.canPop()) return;
    nav.popUntil((route) => route.isFirst);
    debugPrint('SCRIPT reset to feed');
    await _wait(800);
  }

  Future<void> run() async {
    while (_running) {
      await _home();
      // Feed: alternating flings, mostly downward.
      _setPhase('scroll');
      for (var i = 0; i < 10; i++) {
        final up = i % 4 == 3;
        await _line(
          Offset(200, up ? 300 : 640),
          Offset(200, up ? 620 : 260),
          110,
        );
        await _wait(1100);
      }
      // Moving glass: drag the puck around an ellipse for 8 s.
      _setPhase('drag');
      final origin = _puck.value;
      await _drag(
        origin + const Offset(60, 26),
        (t) =>
            origin +
            const Offset(60, 26) +
            Offset(
              math.sin(t * 6 * math.pi) * 110,
              (1 - math.cos(t * 4 * math.pi)) * 90,
            ),
        8000,
      );
      _puck.value = origin;
      // Press and hold each button.
      _setPhase('press');
      for (var i = 0; i < 6; i++) {
        await _tap(_buttonKeys[i % 3], hold: 350);
        await _wait(500);
      }
      // Navigation: tap in, scroll the grid, tap back; tap in, swipe back.
      _setPhase('nav:push');
      await _tap(_openKey);
      await _wait(900);
      _setPhase('nav:grid');
      for (var i = 0; i < 3; i++) {
        await _line(const Offset(200, 700), const Offset(200, 300), 120);
        await _wait(800);
      }
      _setPhase('nav:pop');
      await _tap(_backKey);
      await _wait(1200);
      await _home();
      _setPhase('nav:push');
      await _tap(_openKey);
      await _wait(1200);
      _setPhase('nav:swipe');
      await _line(const Offset(6, 420), const Offset(330, 420), 320);
      await _wait(1500);
      await _home();
    }
  }
}

// ---------------------------------------------------------------------------
// Statistics

/// Mirrors the report lines into the app's temporary directory so a run
/// launched without an attached console (xctrace, devicectl) can be read back:
/// `devicectl device copy from --domain-type appDataContainer ... tmp/bench.log`.
void _log(String line) {
  try {
    File('${Directory.systemTemp.path}/bench.log')
        .writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {}
}

class _Stats {
  final _timings = <(String, FrameTiming)>[];
  final _start = DateTime.now();
  DateTime _prev = DateTime.now();
  double? _cpu0, _battery0;
  double _cpuPrev = 0;
  bool _done = false;

  void start() {
    SchedulerBinding.instance.addTimingsCallback(
      (list) => _timings.addAll([for (final f in list) (_phase, f)]),
    );
    _loop();
  }

  static double _pct(List<double> v, double p) {
    if (v.isEmpty) return 0;
    v.sort();
    return v[math.min(v.length - 1, (v.length * p).floor())];
  }

  static Map<String, Object?> _frames(List<FrameTiming> frames, double window) {
    final raster = [
      for (final f in frames) f.rasterDuration.inMicroseconds / 1000,
    ];
    final build = [
      for (final f in frames) f.buildDuration.inMicroseconds / 1000,
    ];
    return {
      'frames': frames.length,
      'fps': window > 0 ? frames.length / window : 0,
      'rasterP50': _pct(raster, .5),
      'rasterP90': _pct(raster, .9),
      'rasterP99': _pct(raster, .99),
      'buildP50': _pct(build, .5),
      // A 120 Hz frame misses its deadline when build or raster exceeds 8.33 ms.
      'slow': frames
          .where(
            (f) =>
                f.buildDuration.inMicroseconds > 8333 ||
                f.rasterDuration.inMicroseconds > 8333,
          )
          .length,
    };
  }

  Future<void> _loop() async {
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 10));
      final stats = (await _channel.invokeMapMethod<String, Object?>('stats'))!;
      final now = DateTime.now();
      final cpu = (stats['cpu']! as num).toDouble();
      final battery = (stats['battery']! as num).toDouble();
      _cpu0 ??= cpu;
      _battery0 ??= battery;
      final window = now.difference(_prev).inMicroseconds / 1e6;
      final batch = List.of(_timings);
      _timings.clear();
      final phases = <String, Object?>{};
      for (final phase in batch.map((e) => e.$1).toSet()) {
        phases[phase] = _frames([
          for (final e in batch)
            if (e.$1 == phase) e.$2,
        ], 0);
      }
      final line = <String, Object?>{
        'mode': _mode,
        't': now.difference(_start).inSeconds,
        ..._frames([for (final e in batch) e.$2], window),
        'phases': phases,
        'cpuPct': (cpu - _cpuPrev) / window * 100,
        'thermal': stats['thermal'],
        'battery': battery,
        'batteryState': stats['batteryState'],
        'lowPower': stats['lowPower'],
        'brightness': stats['brightness'],
        'done': _done,
      };
      _cpuPrev = cpu;
      _prev = now;
      debugPrint('BENCH ${jsonEncode(line)}');
      _log('BENCH ${jsonEncode(line)}');
      if (!_done && now.difference(_start).inSeconds >= _duration) {
        _done = true;
        _running = false;
        _setPhase('idle');
        final done =
            'BENCH_DONE ${jsonEncode({'mode': _mode, 'seconds': now.difference(_start).inSeconds, 'cpuSeconds': cpu - _cpu0!, 'batteryDrop': _battery0! - battery})}';
        debugPrint(done);
        _log(done);
      }
    }
  }
}
