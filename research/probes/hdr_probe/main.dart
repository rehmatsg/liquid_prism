// Research entry point; run from example/ with -t ../tool/hdr_probe/main.dart.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/liquid_prism.dart';

const _native = MethodChannel('liquid_prism/hdr_probe');
final _boundary = GlobalKey();
final _shadowlessCircle = GlobalKey();
final _circle = GlobalKey();
final _capsule = GlobalKey();
// Light and dark columns, each with regular then clear Prism/native rows.
final _prism = {
  for (final dark in [false, true])
    for (final clear in [false, true]) (dark, clear): GlobalKey(),
};
final _nativeRows = {
  for (final dark in [false, true])
    for (final clear in [false, true]) (dark, clear): GlobalKey(),
};
final _shadowless = _prism[(false, true)]!;
final _group = _prism[(false, false)]!;
final _report = <String>[];
bool _hdrEnabled = const bool.fromEnvironment('PRISM_HDR', defaultValue: true);
void _log(Object value) {
  print(value);
  _report.add(value.toString());
}

/// Stress mode cycles backdrops behind unlabelled glass every few seconds; a
/// tap pauses on the current one. The first backdrop is the plain split page.
const _stress = bool.fromEnvironment('PRISM_STRESS');
const _labels = _stress ? <String>[] : ['A', 'Software'];
const _backdrops = [
  'plain', 'grey', 'stripes', 'gradient', 'checker', 'text', 'blobs', //
];
Widget? _label(bool dark, int index) => _stress
    ? null
    : Center(
        child: Text(
          _labels[index],
          style: TextStyle(
            color: Color(dark ? 0xffffffff : 0xff000000),
            fontFamily: '.SF Pro Text',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

Widget _pair(bool dark, bool clear, {required bool native}) {
  final measured = !native && !dark && !clear;
  final glass = clear ? Glass.clear : Glass.regular;
  final row = Row(
    key: (native ? _nativeRows : _prism)[(dark, clear)],
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      SizedBox(
        key: measured
            ? _circle
            : (!native && !dark && clear ? _shadowlessCircle : null),
        width: 44,
        height: 44,
        child: native
            ? null
            : LiquidPrism(glass: glass, child: _label(dark, 0)),
      ),
      SizedBox(
        key: measured ? _capsule : null,
        width: 120,
        height: 44,
        child: native
            ? null
            : LiquidPrism(glass: glass, child: _label(dark, 1)),
      ),
    ],
  );
  return native || const bool.fromEnvironment('PRISM_UNGROUPED')
      ? row
      : LiquidPrismGroup(child: row);
}

Widget _column(bool dark) => Expanded(
  child: LiquidPrismTheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    child: Column(
      children: [
        const SizedBox(height: 150),
        for (final clear in [false, true])
          for (final native in [false, true]) ...[
            SizedBox(
              height: 20,
              child: _stress
                  ? null
                  : Text(
                      '${native ? 'Native' : 'Prism'} · '
                      '${clear ? 'clear' : 'regular'} · '
                      '${dark ? 'dark' : 'light'}',
                      style: TextStyle(
                        color: Color(dark ? 0xffffffff : 0xff000000),
                        fontSize: 12,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            _pair(dark, clear, native: native),
            const SizedBox(height: 20),
          ],
      ],
    ),
  ),
);

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  var _index = 0;
  var _paused = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (_stress) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_paused) setState(() => _index = (_index + 1) % _backdrops.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _paused = !_paused),
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _Backdrop(_index)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_column(false), _column(true)],
        ),
        if (_stress)
          Positioned(
            left: 12,
            top: 96,
            child: ColoredBox(
              color: const Color(0xff000000),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '$_index ${_backdrops[_index]}${_paused ? ' · paused' : ''}'
                  ' · rows: Prism regular, native regular, Prism clear, '
                  'native clear · left light, right dark',
                  style: const TextStyle(color: Color(0xffffffff), fontSize: 9),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

const _lorem =
    'Liquid Glass is a material that bends and concentrates light in real '
    'time. It forms a distinct functional layer for controls and navigation '
    'that floats above content. Sphinx of black quartz, judge my vow. Pack my '
    'box with five dozen liquor jugs. How vexingly quick daft zebras jump. '
    'The five boxing wizards jump quickly. Jackdaws love my big sphinx of '
    'quartz. Waltz, bad nymph, for quick jigs vex. Glib jocks quiz nymph to '
    'vex dwarf. Two driven jocks help fax my big quiz. The quick brown fox '
    'jumps over the lazy dog. Bright vixens jump; dozy fowl quack. Quick wafting '
    'zephyrs vex bold Jim. Crazy Fredrick bought many very exquisite opal '
    'jewels. We promptly judged antique ivory buckles for the next prize. '
    'A mad boxer shot a quick, gloved jab to the jaw of his dizzy opponent. '
    'Sixty zippers were quickly picked from the woven jute bag. Amazingly few '
    'discotheques provide jukeboxes. Heavy boxes perform quick waltzes and '
    'jigs. Jinxed wizards pluck ivy from the big quilt. Big fjords vex quick '
    'waltz nymph. The job requires extra pluck and zeal from every young wage '
    'earner. A quart jar of oil mixed with zinc oxide makes a very bright '
    'paint. Whenever the black fox jumped the squirrel gazed suspiciously. '
    'Liquid Glass is a material that bends and concentrates light in real '
    'time. It forms a distinct functional layer for controls and navigation '
    'that floats above content. Sphinx of black quartz, judge my vow. Pack my '
    'box with five dozen liquor jugs. How vexingly quick daft zebras jump.';

class _Backdrop extends CustomPainter {
  const _Backdrop(this.index);
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    final paint = Paint();
    switch (_backdrops[index]) {
      case 'plain':
        canvas.drawRect(all, paint..color = const Color(0xffffffff));
        canvas.drawRect(
          Rect.fromLTRB(size.width / 2, 0, size.width, size.height),
          paint..color = const Color(0xff000000),
        );
      case 'grey':
        canvas.drawRect(all, paint..color = const Color(0xff808080));
      // Patterned backdrops repeat every 90 pt vertically, the row pitch, so
      // each Prism row and the native row below it cover identical content.
      case 'stripes':
        const colors = [
          0xffff3b30, 0xffffcc00, 0xff34c759, 0xff007aff, 0xffffffff, //
          0xff000000,
        ];
        for (var i = 0; i * 15.0 < size.height; i++) {
          canvas.drawRect(
            Rect.fromLTWH(0, i * 15.0, size.width, 15),
            paint..color = Color(colors[i % colors.length]),
          );
        }
      case 'gradient':
        canvas.drawRect(
          all,
          paint
            ..shader = ui.Gradient.linear(
              Offset.zero,
              Offset(size.width, 0),
              const [Color(0xff0a84ff), Color(0xffff2d55), Color(0xffffd60a)],
              const [0, .5, 1],
            ),
        );
      case 'checker':
        canvas.drawRect(all, paint..color = const Color(0xffffffff));
        paint.color = const Color(0xff000000);
        for (var y = 0; y * 9.0 < size.height; y++) {
          for (var x = y % 2; x * 9.0 < size.width; x += 2) {
            canvas.drawRect(Rect.fromLTWH(x * 9.0, y * 9.0, 9, 9), paint);
          }
        }
      case 'text':
        canvas.drawRect(all, paint..color = const Color(0xffffffff));
        final text = TextPainter(
          text: const TextSpan(
            text: _lorem,
            style: TextStyle(
              color: Color(0xff000000),
              fontSize: 12,
              height: 1.25,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 6,
        )..layout(maxWidth: size.width);
        for (var y = 0.0; y < size.height; y += 90) {
          text.paint(canvas, Offset(0, y));
        }
        text.dispose();
      case 'blobs':
        canvas.drawRect(all, paint..color = const Color(0xff1c1c1e));
        const blobs = [
          (.08, 20.0, 0xffff9f0a), (.3, 60.0, 0xff30d158), //
          (.45, 15.0, 0xff64d2ff), (.6, 55.0, 0xffff375f), //
          (.78, 30.0, 0xffffffff), (.93, 70.0, 0xffbf5af2),
        ];
        for (var top = -90.0; top < size.height; top += 90) {
          for (final (x, y, color) in blobs) {
            final centre = Offset(size.width * x, top + y);
            canvas.drawCircle(
              centre,
              40,
              Paint()
                ..shader = ui.Gradient.radial(centre, 40, [
                  Color(color),
                  Color(color).withValues(alpha: 0),
                ]),
            );
          }
        }
    }
  }

  @override
  bool shouldRepaint(_Backdrop oldDelegate) => oldDelegate.index != index;
}

Rect _rect(GlobalKey key) {
  final box = key.currentContext!.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload(enableHDR: _hdrEnabled);
  final program = await ui.FragmentProgram.fromAsset(
    '../tool/hdr_probe/probe.frag',
  );
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(key: _boundary, child: const _Probe()),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final flutterRects = [_rect(_circle), _rect(_capsule)];
  List<List<double>> rectsAt(GlobalKey key) {
    final dx = _rect(key).left - _rect(_group).left;
    return [
      for (final r in flutterRects)
        [r.left + dx, _rect(key).top, r.width, r.height, 22, 1],
    ];
  }

  const parity = MethodChannel('liquid_prism/parity');
  for (final MapEntry(key: (dark, clear), value: key) in _nativeRows.entries) {
    await parity.invokeMethod<void>('show', {
      'rects': rectsAt(key),
      'dark': dark,
      'generation': 1,
      'slot': '${dark ? 'dark' : 'light'}-${clear ? 'clear' : 'regular'}',
      'clear': clear,
      'labels': _labels,
    });
  }
  final nativeFull = _nativeRows[(false, false)]!;
  _log('HDR_PROBE native reference rects ${jsonEncode(rectsAt(nativeFull))}');
  _log(
    'HDR_PROBE flutter rects ${jsonEncode([
      for (final r in flutterRects) [r.left, r.top, r.width, r.height],
    ])}',
  );
  for (final delay in [1, 2]) {
    await Future<void>.delayed(Duration(seconds: delay));
    _log(
      'HDR_PROBE native ${jsonEncode(await _native.invokeMethod<Object?>('info'))}',
    );
  }
  _log(
    'HDR_PROBE native shadow inputs ${jsonEncode(await parity.invokeMethod<Object?>('shadowInfo'))}',
  );
  _log(
    'HDR_PROBE clear dump ${await parity.invokeMethod<Object?>("dump", {"name": "hdr-clear", "slot": "light-clear"})}',
  );
  await _readback(program);
  if (const bool.fromEnvironment('PRISM_HDR_CYCLE')) {
    for (final enabled in [false, true]) {
      await LiquidPrism.preload(enableHDR: enabled);
      _hdrEnabled = enabled;
      await Future<void>.delayed(const Duration(seconds: 2));
      _log('HDR_PROBE cycle enabled=$enabled');
      _log(
        'HDR_PROBE native ${jsonEncode(await _native.invokeMethod<Object?>('info'))}',
      );
      await _readback(program);
    }
  }
}

Future<void> _readback(ui.FragmentProgram program) async {
  for (final format in [
    ui.TargetPixelFormat.dontCare,
    ui.TargetPixelFormat.rgbaFloat32,
  ]) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = _Patches(program);
    painter.paint(canvas, const Size(400, 60));
    final picture = recorder.endRecording();
    final image = picture.toImageSync(400, 60, targetFormat: format);
    final data = (await image.toByteData(
      format: ui.ImageByteFormat.rawExtendedRgba128,
    ))!;
    final samples = [
      for (final x in [50, 150, 250, 350])
        data.getFloat32((30 * 400 + x) * 16, Endian.host),
    ];
    _log('HDR_PROBE patches $format ${image.colorSpace} $samples');
    image.dispose();
    picture.dispose();
  }
  final render =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: 3);
  final data = (await image.toByteData(
    format: ui.ImageByteFormat.rawExtendedRgba128,
  ))!;
  var peak = 0.0;
  for (var i = 0; i < data.lengthInBytes; i += 16) {
    final r = data.getFloat32(i, Endian.host);
    if (r > peak) peak = r;
  }
  _log('HDR_PROBE scene ${image.colorSpace} peak=$peak');
  final circle = _circle.currentContext!.findRenderObject()! as RenderBox;
  final circleRect =
      render.globalToLocal(circle.localToGlobal(Offset.zero)) & circle.size;
  final radius = circleRect.width / 2 - .7;
  final arc = <String, double>{};
  for (final degrees in [0, 15, 30, 45, 60, 75, 90]) {
    final angle = degrees * math.pi / 180;
    final x = ((circleRect.center.dx + radius * math.sin(angle)) * 3).floor();
    final y = ((circleRect.center.dy - radius * math.cos(angle)) * 3).floor();
    arc['$degrees'] = data.getFloat32((y * image.width + x) * 16, Endian.host);
  }
  _log('HDR_PROBE circle arc ${jsonEncode(arc)}');
  for (final entry in {'shadowless': _shadowless, 'group': _group}.entries) {
    final box = entry.value.currentContext!.findRenderObject()! as RenderBox;
    final origin = render.globalToLocal(box.localToGlobal(Offset.zero));
    final bounds = (origin & box.size);
    var regionPeak = 0.0;
    for (
      var y = (bounds.top * 3).ceil();
      y < (bounds.bottom * 3).floor();
      y++
    ) {
      for (
        var x = (bounds.left * 3).ceil();
        x < (bounds.right * 3).floor();
        x++
      ) {
        final value = data.getFloat32((y * image.width + x) * 16, Endian.host);
        if (value > regionPeak) regionPeak = value;
      }
    }
    final samples = [
      for (final fraction in [.125, .375, .625, .875])
        data.getFloat32(
          (((bounds.center.dy * 3).floor()) * image.width +
                  ((bounds.left + bounds.width * fraction) * 3).floor()) *
              16,
          Endian.host,
        ),
    ];
    _log('HDR_PROBE region ${entry.key} peak=$regionPeak samples=$samples');
  }
  final stem =
      '${Directory.systemTemp.path}/prism-hdr-${_hdrEnabled ? 'hdr' : 'standard'}';
  await File('$stem.rgba32f').writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  await File('$stem.json').writeAsString(
    jsonEncode({
      'width': image.width,
      'height': image.height,
      'encoding': 'srgb',
      'scale': 3,
      'circle': [
        circleRect.center.dx * 3,
        circleRect.center.dy * 3,
        circleRect.width * 1.5,
      ],
      'native': await _native.invokeMethod<Object?>('info'),
      'shadowlessCircle': [
        _rect(_shadowlessCircle).center.dx * 3,
        _rect(_shadowlessCircle).center.dy * 3,
        66,
      ],
    }),
  );
  await File('${Directory.systemTemp.path}/prism-hdr.log')
      .writeAsString(_report.join('\n'));
  image.dispose();
}

class _Patches extends CustomPainter {
  _Patches(this.program);
  final ui.FragmentProgram program;
  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    shader.dispose();
  }

  @override
  bool shouldRepaint(_Patches oldDelegate) => false;
}
