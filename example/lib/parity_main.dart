// Glass parity harness (research only; see tool/glass_parity/README.md).
//
//   flutter build ios --simulator -t lib/parity_main.dart
//
// The screen is split into two columns of a whole number of physical pixels.
// Both show the same backdrop (the right column is the left one translated by
// one column width). The left column has Liquid Prism regular glass at
// package defaults; the right column has SwiftUI `glassEffect(.regular)` at
// the same local rects, drawn by ParityChannel (ios/Runner/AppDelegate.swift)
// in a hosting view above the Flutter view. A code strip in the bottom-left
// corner makes every screenshot self-describing; tool/glass_parity/analyze.py
// decodes it.
//
// Launch arguments (read natively, so `simctl launch`, XCUITest and devicectl
// all work):
//   --parity-appearances light,dark   frames cycle appearances x patterns
//   --parity-patterns all|name,...    pattern subset
//   --parity-ack                      advance when tool writes ack-<seq>
//   --parity-dwell <seconds>          advance automatically
//   --parity-live                     wrap around; follow the Settings slider
//   --parity-settings                 restart the frames when the amount changes
//   --parity-no-native                skip the native glass
//   --parity-layout default|ladder    shape set (strip byte 11: 1 or 2)
//   --parity-clean                    delete Documents/parity/* at launch
//   -UIViewGlassTintAmount <value>    UIKit's process-local tint amount
// A tap anywhere advances to the next frame.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/liquid_prism.dart';

const _channel = MethodChannel('liquid_prism/parity');

/// Shapes in a column's local points. The vertical step edge, the gratings and
/// the lines are phased on [_centerX], which every shape is centred on.
const _centerX = 100.0;

typedef _Shape = ({String name, Rect rect, double radius, bool capsule});
typedef _Layout = ({int id, double refY, List<_Shape> shapes});

/// Layouts by name. `id` is the strip's layout byte; `refY` is the row (in
/// points, read ±2 pt) where tools take the unfiltered input. The analyzer and
/// geometry.json carry the same numbers.
final _layouts = <String, _Layout>{
  'default': (
    id: 1,
    refY: 600,
    shapes: const [
      (
        name: 'capsule',
        rect: Rect.fromLTWH(25, 120, 150, 48),
        radius: 24,
        capsule: true,
      ),
      (
        name: 'rect',
        rect: Rect.fromLTWH(25, 220, 150, 96),
        radius: 28,
        capsule: false,
      ),
      (
        name: 'square',
        rect: Rect.fromLTWH(15, 370, 170, 170),
        radius: 34,
        capsule: false,
      ),
    ],
  ),
  // Six 150-pt-wide rounded rects, radius min(28, h / 2), from y = 90 with
  // 18-pt gaps: they end at y = 776, above the strip on an 874-pt screen.
  'ladder': (
    id: 2,
    refY: 60,
    shapes: () {
      final shapes = <_Shape>[];
      var top = 90.0;
      for (final h in const [48.0, 64.0, 80.0, 104.0, 130.0, 170.0]) {
        shapes.add((
          name: 'h${h.round()}',
          rect: Rect.fromLTWH(25, top, 150, h),
          radius: math.min(28.0, h / 2),
          capsule: false,
        ));
        top += h + 18;
      }
      return shapes;
    }(),
  ),
};

/// The exact outline both glasses use: Liquid Prism's continuous-corner path.
Path _outline(_Shape s) =>
    (s.capsule ? GlassShape.capsule : GlassShape.rect(cornerRadius: s.radius))
        .path(s.rect.size)
        .shift(s.rect.topLeft);

/// Code strip: 16 x 8 cells of 5 pt, 8 pt from the left and 40 pt above the
/// bottom edge, two bytes per row, most significant bit first.
const _stripCell = 5.0;
const _stripLeft = 8.0;
const _stripBottom = 40.0;

/// Pattern index (strip byte 7) → definition, in column-local points at
/// pixel centres, x = (px + 0.5) / dpr. Gray g is round(255 g). "fp" is the
/// union of the layout's shape outlines (see [_outline]).
const _definitions = <String, String>{
  'grouped': 'flat systemGroupedBackground: light (242,242,247), dark (0,0,0)',
  'white': 'flat (255,255,255)',
  'black': 'flat (0,0,0)',
  'gray50': 'flat (128,128,128)',
  'vedge': 'x < 100: 0, else 255',
  'hedge': 'bands split at each shape centre y; band k (number of centres <= y) odd: 255, even: 0',
  'lines_white': '((x - 100) mod 32) < 1: 255, else 0',
  'lines_black': '((x - 100) mod 32) < 1: 0, else 255',
  'ramp': 'gray = min(255, floor(px * 256 / colPx))',
  'grating8': 'round(255 (0.5 + 0.4 sin(2 pi (x - 100) / 8)))',
  'grating32': 'round(255 (0.5 + 0.4 sin(2 pi (x - 100) / 32)))',
  'grating64': 'round(255 (0.5 + 0.4 sin(2 pi (x - 100) / 64)))',
  'patches': '50-pt cells, colour index (floor(x/50) + 4 floor(y/50)) mod 8 of R,G,B,C,M,Y,(233,185,149),(196,186,240)',
  'photo': 'seeded smooth colour noise (six plane waves per channel)',
  'out8': 'black inside fp grown by 8 pt, white elsewhere',
  'out24': 'black inside fp grown by 24 pt, white elsewhere',
  'out48': 'black inside fp grown by 48 pt, white elsewhere',
  'out8_inv': 'white inside fp grown by 8 pt, black elsewhere',
  'out24_inv': 'white inside fp grown by 24 pt, black elsewhere',
  'out48_inv': 'white inside fp grown by 48 pt, black elsewhere',
  'in24': 'black inside fp shrunk by 24 pt, white elsewhere',
  'in24_inv': 'white inside fp shrunk by 24 pt, black elsewhere',
  'dot': '255 where |x - cx| < 6 and |y - cy| < 6 for a shape centre (cx, cy) ([c-6, c+6) at pixel centres), else 0',
  'dot_inv': '0 inside the dots, else 255',
  'bar_h': '255 where cy - 6 <= y < cy + 6 for a shape centre cy, full column width, else 0',
  'bar_h_inv': '0 inside the bars, else 255',
  'bar_v': '255 where 94 <= x < 106, else 0',
  'bar_v_inv': '0 where 94 <= x < 106, else 255',
  'vedge_mid': 'x < 100: (64,64,64), else (191,191,191)',
  'vedge_rg': 'x < 100: (255,0,0), else (0,255,0)',
  'vedge_by': 'x < 100: (0,0,255), else (255,255,0)',
  'vedge_rc': 'x < 100: (255,0,0), else (0,255,255)',
  'gray25': 'flat (64,64,64)',
  'gray75': 'flat (191,191,191)',
  'red': 'flat (255,0,0)',
  'green': 'flat (0,255,0)',
  'blue': 'flat (0,0,255)',
  'out2': 'black inside fp grown by 2 pt, white elsewhere',
  'out4': 'black inside fp grown by 4 pt, white elsewhere',
  'out12': 'black inside fp grown by 12 pt, white elsewhere',
  'out16': 'black inside fp grown by 16 pt, white elsewhere',
  'out20': 'black inside fp grown by 20 pt, white elsewhere',
  'out28': 'black inside fp grown by 28 pt, white elsewhere',
  'out32': 'black inside fp grown by 32 pt, white elsewhere',
  'out40': 'black inside fp grown by 40 pt, white elsewhere',
};
final _patterns = _definitions.keys.toList();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  final info = Map<String, Object?>.from(
    await _channel.invokeMethod<Map<Object?, Object?>>('info') ?? const {},
  );
  runApp(_ParityApp(info: info));
}

class _ParityApp extends StatefulWidget {
  const _ParityApp({required this.info});
  final Map<String, Object?> info;

  @override
  State<_ParityApp> createState() => _ParityAppState();
}

class _ParityAppState extends State<_ParityApp> {
  late final List<String> _args = [
    for (final a in (widget.info['arguments'] as List? ?? const [])) '$a',
  ];
  late final Directory _dir = Directory(widget.info['documents'] as String);

  String? _arg(String name) {
    final i = _args.indexOf(name);
    return i >= 0 && i + 1 < _args.length ? _args[i + 1] : null;
  }

  late final bool _live = _args.contains('--parity-live');
  late final bool _settingsMode = _args.contains('--parity-settings');
  late final bool _ack = _args.contains('--parity-ack');
  late final bool _native = !_args.contains('--parity-no-native');
  late final String _layoutName = _layouts.containsKey(_arg('--parity-layout'))
      ? _arg('--parity-layout')!
      : 'default';
  late final _Layout _layout = _layouts[_layoutName]!;
  List<_Shape> get _shapes => _layout.shapes;
  bool _geometryWritten = false;
  late final double? _dwell = double.tryParse(_arg('--parity-dwell') ?? '');
  late final List<(bool, int)> _frames = () {
    final appearances = (_arg('--parity-appearances') ?? 'light,dark').split(
      ',',
    );
    final names = _arg('--parity-patterns') ?? 'all';
    final patterns = names == 'all'
        ? List.generate(_patterns.length, (i) => i)
        : [for (final n in names.split(',')) _patterns.indexOf(n)]
              .where((i) => i >= 0)
              .toList();
    return [
      for (final a in appearances)
        for (final p in patterns) (a.trim() == 'dark', p),
    ];
  }();

  int _frame = 0;
  int _seq = 0;
  int _epoch = 0;
  int _generation = 0;
  bool _ready = false;
  bool _done = false;
  double? _nativeAmount;
  double? _epochAmount;
  ui.Image? _image;
  (bool, int)? _imageKey;
  final _captured = <String>[];
  final _dumped = <String>{};
  (bool, int)? _shownNative;
  Timer? _poll;
  int _token = 0;
  Size? _layoutFor;

  bool get _dark => _frames[_frame].$1;
  int get _pattern => _frames[_frame].$2;
  double? get _flutterAmount =>
      LiquidPrismSystemChrome.deviceGlassTintAmount.value;

  @override
  void initState() {
    super.initState();
    _nativeAmount = (widget.info['amount'] as num?)?.toDouble();
    _epochAmount = _nativeAmount;
    LiquidPrismSystemChrome.deviceGlassTintAmount.addListener(_rebuild);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'amountChanged') {
        final args = call.arguments as Map;
        _amountChanged((args['amount'] as num?)?.toDouble());
      }
      return null;
    });
    try {
      _dir.createSync(recursive: true);
      final clean = _args.contains('--parity-clean');
      for (final f in _dir.listSync()) {
        final name = f.uri.pathSegments.last;
        if (clean || name.startsWith('ready-') || name.startsWith('ack-')) {
          f.deleteSync(recursive: true);
        }
      }
    } catch (_) {}
    _log({'event': 'launch', 'arguments': _args, 'info': widget.info});
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LiquidPrismSystemChrome.deviceGlassTintAmount.removeListener(_rebuild);
    _poll?.cancel();
    super.dispose();
  }

  void _amountChanged(double? amount) {
    final changed =
        (amount == null) != (_epochAmount == null) ||
        (amount != null && (amount - _epochAmount!).abs() > 1e-6);
    if (!changed) return;
    _epochAmount = amount;
    _nativeAmount = amount;
    _epoch++;
    _generation++;
    _shownNative = null;
    _log({'event': 'amountChanged', 'amount': amount, 'epoch': _epoch});
    if (_settingsMode) {
      _frame = 0;
      _done = false;
    }
    if (_layoutFor != null) unawaited(_show());
  }

  void _log(Map<String, Object?> entry) {
    try {
      File('${_dir.path}/log.jsonl').writeAsStringSync(
        '${jsonEncode({'time': DateTime.now().toIso8601String(), ...entry})}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  ({double col, int colPx, double dpr, Size size, int heightPx}) _geometry(
    BuildContext context,
  ) {
    final view = View.of(context);
    final dpr = view.devicePixelRatio;
    final colPx = view.physicalSize.width ~/ 2;
    return (
      col: colPx / dpr,
      colPx: colPx,
      dpr: dpr,
      size: view.physicalSize / dpr,
      heightPx: view.physicalSize.height.round(),
    );
  }

  Future<void> _status(String label) =>
      _channel.invokeMethod('status', {'label': label});

  /// Shows the current frame, waits for both glasses to settle, then
  /// announces it as ready (status element, file and code strip).
  Future<void> _show() async {
    final token = ++_token;
    _poll?.cancel();
    setState(() => _ready = false);
    unawaited(_status('busy $_seq'));
    final g = _geometry(context);
    if (!_geometryWritten) {
      _geometryWritten = true;
      _writeGeometry(g.dpr, g.colPx, g.heightPx);
    }
    final key = (_dark, _pattern);
    if (_imageKey != key) {
      final image = await _buildImage(
        _patterns[_pattern],
        _shapes,
        _dark,
        g.colPx,
        g.heightPx,
        g.dpr,
      );
      if (token != _token) return;
      _image?.dispose();
      _image = image;
      _imageKey = key;
    }
    var settle = const Duration(milliseconds: 500);
    if (_native && _shownNative != (_dark, _generation)) {
      _shownNative = (_dark, _generation);
      await _channel.invokeMethod('show', {
        'dark': _dark,
        'generation': _generation,
        'rects': [
          for (final s in _shapes)
            [
              s.rect.left + g.col,
              s.rect.top,
              s.rect.width,
              s.rect.height,
              s.radius,
              s.capsule ? 1.0 : 0.0,
            ],
        ],
      });
      settle = const Duration(milliseconds: 1600);
    }
    if (!mounted || token != _token) return;
    setState(() {});
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(settle);
    // The package reads the setting on its own channel; give it a moment to
    // catch up with the native getter before announcing the frame.
    for (var i = 0; i < 30; i++) {
      final info = await _channel.invokeMethod<Map<Object?, Object?>>('info');
      _nativeAmount = (info?['amount'] as num?)?.toDouble();
      final flutter = _flutterAmount;
      if (_nativeAmount == null ||
          (flutter != null && (flutter - _nativeAmount!).abs() < 1e-6)) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted || token != _token) return;
    _seq++;
    setState(() => _ready = true);
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || token != _token) return;
    final appearance = _dark ? 'dark' : 'light';
    final amountTag = _nativeAmount == null
        ? 'nil'
        : _nativeAmount!.toStringAsFixed(4);
    final mode = _live ? 'live' : (_settingsMode ? 'settings' : 'arg');
    final pattern = _patterns[_pattern];
    // Once per (amount, appearance, layout), and on the default layout also
    // for each of white, black and vedge, named with the pattern showing.
    final first = _dumped.add('$_epoch-$appearance-$amountTag-$_layoutName');
    final probe =
        _layoutName == 'default' &&
        const {'white', 'black', 'vedge'}.contains(pattern);
    if (_native && (first || probe)) {
      await _channel.invokeMethod('dump', {
        'name': 'filters-$appearance-t$amountTag-$mode-$_layoutName-$pattern',
      });
    }
    final record = {
      'seq': _seq,
      'frame': _frame,
      'frames': _frames.length,
      'epoch': _epoch,
      'pattern': _patterns[_pattern],
      'layout': _layoutName,
      'appearance': appearance,
      'nativeAmount': _nativeAmount,
      'flutterAmount': _flutterAmount,
      'dpr': g.dpr,
      'colPx': g.colPx,
    };
    try {
      File('${_dir.path}/ready-$_seq.json')
          .writeAsStringSync(jsonEncode(record));
    } catch (_) {}
    _log({'event': 'ready', ...record});
    await _status(
      'ready $_seq ${_frame + 1}/${_frames.length} e$_epoch a$amountTag '
      '$appearance ${_patterns[_pattern]}',
    );
    _waitForAdvance(token);
  }

  void _waitForAdvance(int token) {
    final started = DateTime.now();
    final seq = _seq;
    if (!_ack && _dwell == null) return;
    _poll = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (token != _token) {
        timer.cancel();
        return;
      }
      final acked = _ack && File('${_dir.path}/ack-$seq').existsSync();
      final dwell = _dwell;
      final dwelled =
          dwell != null &&
          DateTime.now().difference(started).inMilliseconds > dwell * 1000;
      if (acked || dwelled) {
        timer.cancel();
        _advance();
      }
    });
  }

  void _advance() {
    if (!_ready || _done) return;
    if (_frame + 1 < _frames.length) {
      _frame++;
      unawaited(_show());
      return;
    }
    if (_live) {
      _frame = 0;
      unawaited(_show());
      return;
    }
    final amount = _nativeAmount?.toStringAsFixed(4) ?? 'nil';
    if (!_captured.contains(amount)) _captured.add(amount);
    _log({'event': 'done', 'epoch': _epoch, 'amount': _nativeAmount});
    setState(() => _done = true);
    unawaited(_status('done $_seq e$_epoch a$amount'));
  }

  @override
  Widget build(BuildContext context) {
    final g = _geometry(context);
    if (_layoutFor != g.size) {
      final first = _layoutFor == null;
      _layoutFor = g.size;
      if (first) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _show());
      }
    }
    final dark = _dark;
    final textColor = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final panel = dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final amount = _nativeAmount?.toStringAsFixed(4) ?? 'nil';
    final flutter = _flutterAmount?.toStringAsFixed(4) ?? 'nil';
    final lines = [
      'native $amount  flutter $flutter  ${dark ? 'dark' : 'light'}',
      '${_patterns[_pattern]}  frame ${_frame + 1}/${_frames.length}  '
          'seq $_seq  e$_epoch${_ready ? '' : '  settling'}',
      if (_settingsMode && _done)
        'captured amount $amount — change the slider again',
      if (_settingsMode && _captured.isNotEmpty)
        'captured: ${_captured.join(', ')}',
    ];
    final bytes = _stripBytes(g.dpr, g.colPx, dark);
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(platformBrightness: dark ? Brightness.dark : Brightness.light),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _BackdropPainter(_image, g.col)),
              ),
              for (final s in _shapes)
                Positioned.fromRect(
                  rect: s.rect,
                  child: LiquidPrism(
                    shape: s.capsule
                        ? GlassShape.capsule
                        : GlassShape.rect(cornerRadius: s.radius),
                  ),
                ),
              Positioned(
                left: _stripLeft,
                top: g.size.height - _stripBottom - 8 * _stripCell,
                width: 16 * _stripCell,
                height: 8 * _stripCell,
                child: CustomPaint(painter: _StripPainter(bytes)),
              ),
              Positioned(
                left: _stripLeft + 16 * _stripCell + 8,
                right: 8,
                bottom: _stripBottom,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    color: panel,
                    padding: const EdgeInsets.all(3),
                    child: Text(
                      lines.join('\n'),
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.25,
                        color: textColor,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exact geometry of every layout for this screen, next to the shots.
  void _writeGeometry(double dpr, int colPx, int heightPx) {
    List<double> px(Rect r) => [
      for (final v in [r.left, r.top, r.width, r.height]) v * dpr,
    ];
    final layouts = {
      for (final MapEntry(key: name, value: l) in _layouts.entries)
        name: {
          'id': l.id,
          'refRowPt': l.refY,
          'refRowPx': l.refY * dpr,
          'refBandPt': 2,
          'shapes': [
            for (final s in l.shapes)
              {
                'name': s.name,
                'kind': s.capsule ? 'capsule' : 'rect',
                'rectPt': [
                  s.rect.left,
                  s.rect.top,
                  s.rect.width,
                  s.rect.height,
                ],
                'rectPx': px(s.rect),
                'centerPx': [s.rect.center.dx * dpr, s.rect.center.dy * dpr],
                'radiusPt': s.capsule ? s.rect.shortestSide / 2 : s.radius,
                'radiusPx':
                    (s.capsule ? s.rect.shortestSide / 2 : s.radius) * dpr,
              },
          ],
        },
    };
    final geometry = {
      'dpr': dpr,
      'colPx': colPx,
      'colPt': colPx / dpr,
      'screenPx': [colPx * 2, heightPx],
      'rightColumnOffsetPx': colPx,
      'rects':
          'left column, physical pixels [left, top, width, height]; '
          'the native shape is the same rect shifted right by colPx',
      'outline':
          'Flutter: GlassShape.capsule / GlassShape.rect(cornerRadius) '
          '(RoundedSuperellipseBorder, continuous corners). Native: SwiftUI '
          'Capsule(style: .continuous) / RoundedRectangle(cornerRadius:, '
          'style: .continuous).',
      'masks':
          'outN = fill(fp) + stroke(fp outline, width 2N pt, round '
          'join); inN = fill(fp) then stroke(width 2N) in the background '
          'colour; drawn without anti-aliasing at physical resolution',
      'pixelCentres': 'local point x = (px + 0.5) / dpr',
      'strip':
          '16 x 8 cells of 5 pt, left 8 pt, bottom 40 pt; see '
          'tool/glass_parity/README.md',
      'layouts': layouts,
      'patterns': [
        for (final (i, name) in _patterns.indexed)
          {'index': i, 'name': name, 'definition': _definitions[name]},
      ],
    };
    try {
      File(
        '${_dir.path}/geometry.json',
      ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(geometry));
    } catch (_) {}
  }

  /// magic A7 5C · native amount ×10000 (2 bytes, FFFF = none) · Flutter
  /// amount ×10000 (2) · flags (dark, live, settings, native, ready) ·
  /// pattern · DPR ×10 · column px (2) · layout id · epoch · seq ·
  /// checksum (sum of the previous bytes) · 0.
  List<int> _stripBytes(double dpr, int colPx, bool dark) {
    int amount(double? a) => a == null ? 0xFFFF : (a * 10000).round();
    final native = amount(_nativeAmount);
    final flutter = amount(_flutterAmount);
    final flags =
        (dark ? 1 : 0) |
        (_live ? 2 : 0) |
        (_settingsMode ? 4 : 0) |
        (_native ? 8 : 0) |
        (_ready ? 16 : 0);
    final bytes = [
      0xA7, 0x5C, native >> 8, native & 0xFF, flutter >> 8, flutter & 0xFF, //
      flags, _pattern, (dpr * 10).round(), colPx >> 8, colPx & 0xFF,
      _layout.id, _epoch & 0xFF, _seq & 0xFF,
    ];
    return [...bytes, bytes.fold(0, (a, b) => a + b) & 0xFF, 0];
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.bytes);
  final List<int> bytes;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = const Color(0xFFFFFFFF);
    final black = Paint()..color = const Color(0xFF000000);
    for (var i = 0; i < bytes.length; i++) {
      for (var bit = 0; bit < 8; bit++) {
        final on = (bytes[i] >> (7 - bit)) & 1 == 1;
        final col = (i % 2) * 8 + bit;
        final row = i ~/ 2;
        canvas.drawRect(
          Rect.fromLTWH(
            col * _stripCell,
            row * _stripCell,
            _stripCell,
            _stripCell,
          ),
          on ? white : black,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) => !listEquals(old.bytes, bytes);
}

/// Draws the column image at 1:1 physical pixels in both columns.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.image, this.col);
  final ui.Image? image;
  final double col;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF000000),
    );
    final image = this.image;
    if (image == null) return;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    for (final dx in [0.0, col]) {
      canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH(dx, 0, col, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.image != image || old.col != col;
}

Future<ui.Image> _buildImage(
  String name,
  List<_Shape> shapes,
  bool dark,
  int width,
  int height,
  double dpr,
) {
  if (name.startsWith('out') || name.startsWith('in')) {
    return _mask(name, shapes, width, height, dpr);
  }
  final pixels = _pixels(name, shapes, dark, width, height, dpr);
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// `outN`, `inN` and their `_inv`: fp grown or shrunk by N pt through a
/// round-join stroke of the exact outline, without anti-aliasing.
Future<ui.Image> _mask(
  String name,
  List<_Shape> shapes,
  int width,
  int height,
  double dpr,
) {
  final inverse = name.endsWith('_inv');
  final base = inverse ? name.substring(0, name.length - 4) : name;
  final grow = base.startsWith('out');
  final distance = double.parse(base.substring(grow ? 3 : 2));
  final inside = inverse ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  final outside = inverse ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width / dpr, height / dpr),
    Paint()
      ..color = outside
      ..isAntiAlias = false,
  );
  final fill = Paint()
    ..color = inside
    ..isAntiAlias = false;
  final stroke = Paint()
    ..color = grow ? inside : outside
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2 * distance
    ..strokeJoin = StrokeJoin.round;
  for (final s in shapes) {
    canvas.drawPath(_outline(s), fill);
  }
  for (final s in shapes) {
    canvas.drawPath(_outline(s), stroke);
  }
  final picture = recorder.endRecording();
  return picture.toImage(width, height).whenComplete(picture.dispose);
}

Uint8List? _photoCache;
(int, int)? _photoSize;

/// One column of [name] at physical resolution. Coordinates are local points
/// at pixel centres; tool/glass_parity/analyze.py mirrors these definitions.
Uint8List _pixels(
  String name,
  List<_Shape> shapes,
  bool dark,
  int w,
  int h,
  double dpr,
) {
  double x(int px) => (px + .5) / dpr;
  int g8(double v) => (v.clamp(0.0, 1.0) * 255).round();
  final out = Uint8List(w * h * 4);
  // A pattern that only varies along x: one row, repeated.
  void rows(int Function(int px, int channel) value) {
    for (var px = 0; px < w; px++) {
      for (var c = 0; c < 3; c++) {
        out[px * 4 + c] = value(px, c);
      }
      out[px * 4 + 3] = 255;
    }
    for (var y = 1; y < h; y++) {
      out.setRange(y * w * 4, (y + 1) * w * 4, out);
    }
  }

  void flat(int r, int g, int b) => rows((_, c) => [r, g, b][c]);
  switch (name) {
    case 'grouped':
      dark ? flat(0, 0, 0) : flat(242, 242, 247);
    case 'white':
      flat(255, 255, 255);
    case 'black':
      flat(0, 0, 0);
    case 'gray50':
      flat(128, 128, 128);
    case 'vedge':
      rows((px, _) => x(px) < _centerX ? 0 : 255);
    case 'lines_white' || 'lines_black':
      final white = name == 'lines_white';
      rows((px, _) {
        final on = ((x(px) - _centerX) % 32) < 1;
        return on == white ? 255 : 0;
      });
    case 'ramp':
      rows((px, _) => math.min(255, px * 256 ~/ w));
    case 'grating8' || 'grating32' || 'grating64':
      final period = double.parse(name.substring(7));
      rows(
        (px, _) =>
            g8(.5 + .4 * math.sin(2 * math.pi * (x(px) - _centerX) / period)),
      );
    case 'hedge':
      // Bands whose boundaries cross each shape's centre.
      final edges = [for (final s in shapes) s.rect.center.dy];
      for (var py = 0; py < h; py++) {
        final y = (py + .5) / dpr;
        final band = edges.where((e) => y >= e).length;
        final v = band.isOdd ? 255 : 0;
        for (var px = 0; px < w; px++) {
          final i = (py * w + px) * 4;
          out[i] = out[i + 1] = out[i + 2] = v;
          out[i + 3] = 255;
        }
      }
    case 'patches':
      const colors = [
        [255, 0, 0], [0, 255, 0], [0, 0, 255], [0, 255, 255], //
        [255, 0, 255], [255, 255, 0], [233, 185, 149], [196, 186, 240],
      ];
      for (var py = 0; py < h; py++) {
        final row = ((py + .5) / dpr) ~/ 50;
        for (var px = 0; px < w; px++) {
          final color = colors[(x(px) ~/ 50 + 4 * row) % 8];
          final i = (py * w + px) * 4;
          out[i] = color[0];
          out[i + 1] = color[1];
          out[i + 2] = color[2];
          out[i + 3] = 255;
        }
      }
    case 'vedge_mid':
      rows((px, _) => x(px) < _centerX ? 64 : 191);
    case 'vedge_rg' || 'vedge_by' || 'vedge_rc':
      final (left, right) = switch (name) {
        'vedge_rg' => ([255, 0, 0], [0, 255, 0]),
        'vedge_by' => ([0, 0, 255], [255, 255, 0]),
        _ => ([255, 0, 0], [0, 255, 255]),
      };
      rows((px, c) => (x(px) < _centerX ? left : right)[c]);
    case 'gray25':
      flat(64, 64, 64);
    case 'gray75':
      flat(191, 191, 191);
    case 'red':
      flat(255, 0, 0);
    case 'green':
      flat(0, 255, 0);
    case 'blue':
      flat(0, 0, 255);
    case 'bar_v' || 'bar_v_inv':
      final on = name == 'bar_v' ? 255 : 0;
      rows((px, _) => (x(px) >= 94 && x(px) < 106) ? on : 255 - on);
    case 'dot' || 'dot_inv' || 'bar_h' || 'bar_h_inv':
      final on = name.endsWith('_inv') ? 0 : 255;
      final dots = name.startsWith('dot');
      for (var py = 0; py < h; py++) {
        final y = (py + .5) / dpr;
        for (var px = 0; px < w; px++) {
          final inside = shapes.any((s) {
            final c = s.rect.center;
            final inY = y >= c.dy - 6 && y < c.dy + 6;
            return inY && (!dots || (x(px) >= c.dx - 6 && x(px) < c.dx + 6));
          });
          final v = inside ? on : 255 - on;
          final i = (py * w + px) * 4;
          out[i] = out[i + 1] = out[i + 2] = v;
          out[i + 3] = 255;
        }
      }
    case 'photo':
      if (_photoSize != (w, h)) {
        _photoCache = _photo(w, h, dpr);
        _photoSize = (w, h);
      }
      return _photoCache!;
  }
  return out;
}

/// Smooth multi-frequency colour noise: per channel, six plane waves with
/// seeded directions, periods (16–220 pt), amplitudes and phases.
Uint8List _photo(int w, int h, double dpr) {
  var state = 0x2545F491;
  double rand() {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    return (state & 0xFFFFFF) / 0x1000000;
  }

  final out = Uint8List(w * h * 4);
  final acc = Float64List(w * h);
  for (var c = 0; c < 3; c++) {
    acc.fillRange(0, acc.length, .5);
    final weights = [for (var k = 0; k < 6; k++) .4 + rand()];
    final total = weights.fold(0.0, (a, b) => a + b);
    for (var k = 0; k < 6; k++) {
      final theta = rand() * math.pi;
      final period = 16 * math.pow(220 / 16, rand());
      final phase = rand() * 2 * math.pi;
      final amp = .45 * weights[k] / total;
      final kx = 2 * math.pi * math.cos(theta) / period / dpr;
      final ky = 2 * math.pi * math.sin(theta) / period / dpr;
      final sx = Float64List(w), cx = Float64List(w);
      for (var px = 0; px < w; px++) {
        final a = kx * (px + .5) + phase;
        sx[px] = amp * math.sin(a);
        cx[px] = amp * math.cos(a);
      }
      for (var py = 0; py < h; py++) {
        final b = ky * (py + .5);
        final sy = math.sin(b), cy = math.cos(b);
        final base = py * w;
        for (var px = 0; px < w; px++) {
          acc[base + px] += sx[px] * cy + cx[px] * sy;
        }
      }
    }
    for (var i = 0; i < acc.length; i++) {
      out[i * 4 + c] = (acc[i].clamp(0.0, 1.0) * 255).round();
    }
  }
  for (var i = 3; i < out.length; i += 4) {
    out[i] = 255;
  }
  return out;
}
