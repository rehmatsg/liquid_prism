import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// Flutter twin of `research/probes/native_edge_sampling_probe`: the same
/// black/white band scenes, fixed in screen coordinates, under the scaffold's
/// soft scroll edge. Steps through every scene and hands each one to
/// `research/probes/native_edge_sampling_probe/run_flutter_ios.sh` through
/// files in the app's Documents/edge_probe folder (`current` <-> `ack`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prism.initialize();
  runApp(
    const CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: Brightness.light),
      home: _Probe(),
    ),
  );
}

class _Band {
  const _Band(this.y0, this.y1, {this.fromBottom = false, this.red = false});
  final double y0;
  final double y1;
  final bool fromBottom;
  final bool red;

  Map<String, Object> toJson() => {
    'y0': y0,
    'y1': y1,
    'gray': 0,
    'fromBottom': fromBottom,
    'red': red,
  };
}

class _Scene {
  const _Scene(
    this.style,
    this.name,
    this.background,
    this.bands, {
    this.text = false,
  });

  /// `soft` is the package default; `nohaze` drops the heavy blur; `off`
  /// disables the effect (to see what the simulator adds on its own).
  final String style;
  final String name;
  final double background;
  final List<_Band> bands;
  final bool text;

  String get id => '${style}_$name';

  Map<String, Object> toJson() => {
    'name': id,
    'style': style,
    'background': background,
    'bands': [for (final b in bands) b.toJson()],
    'text': text,
  };
}

const _marker = _Band(380, 382, red: true);

List<_Scene> _allScenes() {
  final list = <_Scene>[];
  void add(
    String style,
    String name,
    double bg,
    List<_Band> bands, {
    bool text = false,
  }) => list.add(_Scene(style, name, bg, [...bands, _marker], text: text));
  for (final style in ['soft', 'nohaze']) {
    add(style, 'white', 1, []);
    add(style, 'black', 0, []);
    if (style == 'soft') {
      add(style, 'gray', 0.5, []);
      for (final d in const <double>[2, 8, 24]) {
        add(style, 'band${d.toInt()}', 1, [_Band(-400, d)]);
      }
      add(style, 'band8x', 1, [const _Band(0, 8)]);
    }
    for (final y in const <double>[0, 8, 16, 32, 48, 64, 96, 128]) {
      add(style, 'line${y.toInt()}', 1, [_Band(y, y + 4)]);
    }
    if (style == 'soft') {
      for (final y in const <double>[150, 160]) {
        add(style, 'below${y.toInt()}', 1, [_Band(y, 700)]);
      }
      add(style, 'bband8', 1, [const _Band(-400, 8, fromBottom: true)]);
      for (final y in const <double>[0, 16]) {
        add(style, 'bline${y.toInt()}', 1, [_Band(y, y + 4, fromBottom: true)]);
      }
      add(style, 'stripes', 1, [
        for (var y = 0.0; y < 300; y += 4) _Band(y, y + 2),
      ]);
    }
    add(style, 'text', 1, [], text: true);
  }
  add('off', 'white', 1, []);
  add('off', 'black', 0, []);
  for (final y in const <double>[0, 16]) {
    add('off', 'line${y.toInt()}', 1, [_Band(y, y + 4)]);
  }
  add('off', 'text', 1, [], text: true);
  return list;
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final _scenes = _allScenes();
  final _scroll = ScrollController(initialScrollOffset: 2000);
  var _index = 0;
  // iOS gives Dart no HOME; the temp dir sits inside the app's container.
  late final Directory _dir = Directory(
    '${Directory.systemTemp.parent.path}/Documents/edge_probe',
  );

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_dir.existsSync()) _dir.deleteSync(recursive: true);
    _dir.createSync(recursive: true);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final view = View.of(context);
    final size = view.physicalSize / view.devicePixelRatio;
    File('${_dir.path}/meta.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'screen': '{{0, 0}, {${size.width}, ${size.height}}}',
        'scale': view.devicePixelRatio,
        'padding': MediaQuery.paddingOf(context).toString(),
        'scenes': [for (final s in _scenes) s.toJson()],
      }),
    );
    for (var i = 0; i < _scenes.length; i++) {
      setState(() => _index = i);
      // The scroll edge fades on/off over 0.9 s when toggled.
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      final id = _scenes[i].id;
      File('${_dir.path}/current').writeAsStringSync(id);
      final ack = File('${_dir.path}/ack');
      while (!ack.existsSync() || ack.readAsStringSync().trim() != id) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    File('${_dir.path}/done').writeAsStringSync('done');
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scenes[_index];
    final screenHeight = MediaQuery.sizeOf(context).height;
    final style = PrismScrollEdgeStyle(
      variant: PrismScrollEdgeVariant.soft,
      haze: scene.style == 'nohaze' ? 0 : null,
    );
    // The effect boxes match native's strips on the folded iPhone Duo (top
    // 120 pt, bottom 108.3 pt); the effect reaches defaultExtension past them.
    const reach = PrismScrollEdgeStyle.defaultExtension;
    const white = Color(0xFFFFFFFF);
    final on = scene.style != 'off';
    return PrismTheme(
      brightness: Brightness.light,
      child: ColoredBox(
        color: white,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scroll,
                child: _Pattern(scene: scene, screenHeight: screenHeight),
              ),
            ),
            if (on)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120 - reach,
                child: PrismScrollEdge(progress: 1, color: white, style: style),
              ),
            if (on)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 108.33 - reach,
                child: PrismScrollEdge(
                  edge: PrismEdge.bottom,
                  progress: 1,
                  color: white,
                  style: style,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pattern extends LeafRenderObjectWidget {
  const _Pattern({required this.scene, required this.screenHeight});
  final _Scene scene;
  final double screenHeight;

  @override
  _RenderPattern createRenderObject(BuildContext context) =>
      _RenderPattern(scene, screenHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderPattern renderObject) {
    renderObject
      ..scene = scene
      ..screenHeight = screenHeight
      ..markNeedsPaint();
  }
}

/// Paints the scene in screen coordinates, whatever the scroll offset.
class _RenderPattern extends RenderBox {
  _RenderPattern(this.scene, this.screenHeight);
  _Scene scene;
  double screenHeight;

  @override
  void performLayout() {
    size = constraints.constrain(Size(constraints.maxWidth, 5000));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final global = localToGlobal(Offset.zero);
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx - global.dx, offset.dy - global.dy);
    final top = global.dy;
    final width = size.width;
    Color gray(double v) => Color.from(alpha: 1, red: v, green: v, blue: v);
    canvas.drawRect(
      Rect.fromLTWH(0, top, width, size.height),
      Paint()..color = gray(scene.background),
    );
    for (final band in scene.bands) {
      final y0 = band.fromBottom ? screenHeight - band.y1 : band.y0;
      final y1 = band.fromBottom ? screenHeight - band.y0 : band.y1;
      canvas.drawRect(
        Rect.fromLTRB(0, y0, width, y1),
        Paint()..color = band.red ? const Color(0xFFFF0000) : gray(0),
      );
    }
    if (scene.text) {
      const colors = [
        Color(0xFFFF3B30),
        Color(0xFF34C759),
        Color(0xFF007AFF),
        Color(0xFFFF9500),
      ];
      for (var i = 0; i < 30; i++) {
        final y = -9.0 + 22 * i;
        canvas.drawRect(
          Rect.fromLTWH(16, y + 4, 60, 14),
          Paint()..color = colors[i % 4],
        );
        final painter = TextPainter(
          text: TextSpan(
            text: 'Scroll edge sampling $i — quick brown fox',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF000000),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(86, y + 11 - painter.height / 2));
        painter.dispose();
      }
    }
    canvas.restore();
  }
}
