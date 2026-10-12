part of 'tab_bar.dart';

/// The selected foreground portal, separate from the housing's backdrop lens.
/// Filtering the child preserves custom icon state, focus and semantics.
class _SelectionWindow extends StatefulWidget {
  const _SelectionWindow({
    required this.path,
    required this.color,
    required this.lens,
    required this.lift,
    required this.shape,
    required this.child,
  });
  final Path? path;
  final Color color;
  final Rect lens;
  final double lift;
  final GlassShape shape;
  final Widget child;

  @override
  State<_SelectionWindow> createState() => _SelectionWindowState();
}

class _SelectionWindowState extends State<_SelectionWindow> {
  static Future<ui.FragmentProgram>? _program;
  static Future<ui.Image>? _sampler;
  ui.FragmentShader? _shader;

  static Future<ui.Image> _linearSampler() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(1, 1);
    } finally {
      picture.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    if (ui.ImageFilter.isShaderFilterSupported) _load();
  }

  Future<void> _load() async {
    try {
      final program = await (_program ??= ui.FragmentProgram.fromAsset(
        'packages/liquid_prism/shaders/tab_content.frag',
      ));
      final sampler = await (_sampler ??= _linearSampler());
      if (mounted) {
        final shader = program.fragmentShader()
          ..setImageSampler(0, sampler, filterQuality: FilterQuality.low);
        setState(() => _shader = shader);
      }
    } catch (error, stack) {
      _program = null;
      _sampler = null;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'liquid_prism',
          context: ErrorDescription('while compiling the tab foreground lens'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SelectionWindowPaint(
    path: widget.path,
    color: widget.color,
    lens: widget.lens,
    lift: widget.lift,
    shape: widget.shape,
    shader: _shader,
    pixelRatio: MediaQuery.devicePixelRatioOf(context),
    child: widget.child,
  );
}
