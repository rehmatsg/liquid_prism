import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/prism_glass.dart';
import '../theme/prism_theme.dart';
import 'layer_transform.dart';
import 'superellipse.dart';

/// Selected foreground refraction independent from the backdrop lens.
@internal
class ContentLensWindow extends StatefulWidget {
  const ContentLensWindow({
    super.key,
    required this.lens,
    required this.lift,
    required this.shape,
    required this.refraction,
    required this.depth,
    this.wrapper = 0,
    this.chromaticAberration = 0,
    this.chromaticBand = 4.8,
    this.scale = 1,
    this.origin = Offset.zero,
    required this.child,
  }) : path = null,
       selected = null,
       _selection = false;

  const ContentLensWindow.selection({
    super.key,
    required this.path,
    required this.selected,
    required this.lens,
    required this.lift,
    required this.shape,
    required this.refraction,
    required this.depth,
    this.wrapper = 0,
    this.chromaticAberration = 0,
    this.chromaticBand = 4.8,
    this.scale = 1,
    this.origin = Offset.zero,
    required this.child,
  }) : _selection = true;

  final Path? path;

  final Widget? selected;
  final bool _selection;
  final Rect lens;
  final double lift, refraction, depth, scale;

  final double wrapper;
  final double chromaticAberration, chromaticBand;
  final Offset origin;
  final PrismShape shape;
  final Widget child;

  @override
  State<ContentLensWindow> createState() => _ContentLensWindowState();
}

/// Builds the foreground lens effect packet in shader declaration order.
@internal
List<double> contentLensEffectUniforms({
  required double refraction,
  required double depth,
  required double chromaticAberration,
  required double chromaticBand,
  required double lift,
  required double scale,
  required double deviceScale,
}) => [
  refraction * scale,
  depth * scale,
  chromaticAberration * lift.clamp(0.0, 1.0) * scale * deviceScale,
  chromaticBand * scale,
];

class _ContentLensWindowState extends State<ContentLensWindow> {
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
  Widget build(BuildContext context) {
    final tone = PrismTheme.materialBrightnessOf(context) == Brightness.light
        ? 1.0
        : .16;
    Widget paint(_WindowRegion region, Widget child) => _SelectionWindowPaint(
      region: region,
      tone: tone,
      path: widget.path,
      lens: widget.lens,
      lift: widget.lift,
      shape: widget.shape,
      shader: region == _WindowRegion.outside ? null : _shader,
      refraction: widget.refraction,
      depth: widget.depth,
      wrapper: widget.wrapper,
      chromaticAberration: widget.chromaticAberration,
      chromaticBand: widget.chromaticBand,
      scale: widget.scale,
      origin: widget.origin,
      child: child,
    );
    if (!widget._selection) return paint(_WindowRegion.whole, widget.child);
    final selected = widget.selected;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        paint(_WindowRegion.outside, widget.child),
        if (selected != null && widget.path != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: paint(_WindowRegion.inside, selected),
              ),
            ),
          ),
      ],
    );
  }
}

enum _WindowRegion { whole, outside, inside }

class _SelectionWindowPaint extends SingleChildRenderObjectWidget {
  const _SelectionWindowPaint({
    required this.region,
    required this.tone,
    required this.path,
    required this.lens,
    required this.lift,
    required this.shape,
    required this.shader,
    required this.refraction,
    required this.depth,
    required this.wrapper,
    required this.chromaticAberration,
    required this.chromaticBand,
    required this.scale,
    required this.origin,
    required super.child,
  });
  final _WindowRegion region;
  final double tone;
  final Path? path;
  final Rect lens;
  final double lift, refraction, depth, wrapper, scale;
  final double chromaticAberration, chromaticBand;
  final Offset origin;
  final PrismShape shape;
  final ui.FragmentShader? shader;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSelectionWindow(region, path)
        ..configure(
          shader,
          lens,
          lift,
          shape,
          refraction,
          depth,
          chromaticAberration,
          chromaticBand,
          tone,
          wrapper,
        )
        ..setScale(scale, origin);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSelectionWindow renderObject,
  ) {
    renderObject
      ..region = region
      ..path = path
      ..configure(
        shader,
        lens,
        lift,
        shape,
        refraction,
        depth,
        chromaticAberration,
        chromaticBand,
        tone,
        wrapper,
      )
      ..setScale(scale, origin);
  }
}

class _RenderSelectionWindow extends RenderProxyBox {
  _RenderSelectionWindow(this._region, this._path);
  _WindowRegion _region;
  Path? _path;
  set region(_WindowRegion value) {
    if (value == _region) return;
    _region = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  set path(Path? value) {
    if (identical(value, _path)) return;
    final toggled = (value == null) != (_path == null);
    _path = value;
    if (toggled) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  double _scale = 1;
  Offset _origin = Offset.zero;
  void setScale(double scale, Offset origin) {
    if (scale == _scale && origin == _origin) return;
    _scale = scale;
    _origin = origin;
    markNeedsPaint();
  }

  Matrix4? get _transform => _scale == 1
      ? null
      : (Matrix4.translationValues(_origin.dx, _origin.dy, 0)
          ..scaleByDouble(_scale, _scale, 1, 1)
          ..translateByDouble(-_origin.dx, -_origin.dy, 0, 1));

  ui.FragmentShader? _shader;
  Rect _lens = Rect.zero;
  double _lift = 0, _refraction = 14, _depth = 11.2;
  double _chromaticAberration = 0, _chromaticBand = 4.8, _tone = 0;
  double _wrapper = 0;
  PrismShape _shape = PrismShape.capsule;
  void configure(
    ui.FragmentShader? shader,
    Rect lens,
    double lift,
    PrismShape shape,
    double refraction,
    double depth,
    double chromaticAberration,
    double chromaticBand,
    double tone,
    double wrapper,
  ) {
    if (shader == _shader &&
        lens == _lens &&
        lift == _lift &&
        shape == _shape &&
        refraction == _refraction &&
        depth == _depth &&
        chromaticAberration == _chromaticAberration &&
        chromaticBand == _chromaticBand &&
        tone == _tone &&
        wrapper == _wrapper) {
      return;
    }
    final refracted = _refractsContent;
    _shader = shader;
    _lens = lens;
    _lift = lift;
    _shape = shape;
    _refraction = refraction;
    _depth = depth;
    _chromaticAberration = chromaticAberration;
    _chromaticBand = chromaticBand;
    _tone = tone;
    _wrapper = wrapper;
    if (refracted != _refractsContent) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final local = _transform;
    if (local != null) transform.multiply(local);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: _transform,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );

  Size? _contourSize;
  double? _contourRadius;
  List<double> _contour = [];

  bool get _refractsContent =>
      _shader != null &&
      _lift >= .001 &&
      (_refraction != 0 ||
          _wrapper != 0 ||
          (_chromaticAberration > 0 && _chromaticBand > 0));

  ui.ImageFilter _contentFilter(double deviceScale) {
    final shader = _shader!;
    final local = _shape.rect(_lens.size).shift(_lens.topLeft);
    final contour = Rect.fromCenter(
      center: _origin + (local.center - _origin) * _scale,
      width: local.width * _scale,
      height: local.height * _scale,
    );
    final radius = _shape.radius * _scale;
    if (_contourSize != contour.size || _contourRadius != radius) {
      _contourSize = contour.size;
      _contourRadius = radius;
      _contour = superellipseUniforms(contour.size, radius);
    }
    final values = [
      contour.left,
      contour.top,
      contour.width,
      contour.height,
      deviceScale,
      _lift,
      radius,
      _shape.isSmooth ? 1.0 : 0.0,
      ..._contour,
      ...contentLensEffectUniforms(
        refraction: _refraction,
        depth: _depth,
        chromaticAberration: _chromaticAberration,
        chromaticBand: _chromaticBand,
        lift: _lift,
        scale: _scale,
        deviceScale: deviceScale,
      ),
      _tone,
      _wrapper * _scale,
    ];
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i + 2, values[i]);
    }
    return ui.ImageFilter.shader(shader, filterQuality: FilterQuality.low);
  }

  final _warp = LayerHandle<_ContentLensLayer>();
  final _clip = LayerHandle<ClipPathLayer>();
  final _outsideClip = LayerHandle<ClipPathLayer>();
  final _scaled = LayerHandle<TransformLayer>();
  final _outsideScaled = LayerHandle<TransformLayer>();

  void _underScale(
    PaintingContext context,
    Offset offset,
    LayerHandle<TransformLayer> handle,
    PaintingContextCallback painter,
  ) {
    final local = _transform;
    if (local == null) {
      handle.layer = null;
      painter(context, offset);
    } else {
      handle.layer = context.pushTransform(
        needsCompositing,
        offset,
        local,
        painter,
        oldLayer: handle.layer,
      );
    }
  }

  @override
  bool get alwaysNeedsCompositing => switch (_region) {
    _WindowRegion.whole => _refractsContent,
    _WindowRegion.outside || _WindowRegion.inside => _path != null,
  };

  void _refract(
    PaintingContext context,
    Offset offset,
    PaintingContextCallback inner,
  ) {
    final lens = _warp.layer ??= _ContentLensLayer(this);
    lens.invalidate();
    final layer = lens.filter..offset = offset;
    context.pushLayer(
      lens,
      (context, _) => context.pushLayer(layer, (context, _) {
        context.canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = const Color(0x00000000)
            ..blendMode = BlendMode.src,
        );
        inner(context, Offset.zero);
      }, offset),
      offset,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final path = _path;
    if (child == null || (_region == _WindowRegion.inside && path == null)) {
      _clearLayers();
      return;
    }
    if (_region == _WindowRegion.whole || path == null) {
      _clip.layer = null;
      _outsideClip.layer = null;
      _scaled.layer = null;
      void plain(PaintingContext context, Offset offset) => _underScale(
        context,
        offset,
        _outsideScaled,
        (context, offset) => context.paintChild(child, offset),
      );
      if (_region == _WindowRegion.whole && _refractsContent) {
        _refract(context, offset, plain);
      } else {
        _warp.layer = null;
        plain(context, offset);
      }
      return;
    }
    if (_region == _WindowRegion.outside) {
      _warp.layer = null;
      _clip.layer = null;
      _scaled.layer = null;
      final outside = Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        path,
      );
      _underScale(
        context,
        offset,
        _outsideScaled,
        (context, offset) => _outsideClip.layer = context.pushClipPath(
          needsCompositing,
          offset,
          Offset.zero & size,
          outside,
          (context, offset) => context.paintChild(child, offset),
          oldLayer: _outsideClip.layer,
        ),
      );
      return;
    }
    _outsideClip.layer = null;
    _outsideScaled.layer = null;
    void clipped(PaintingContext context, Offset offset) => _underScale(
      context,
      offset,
      _scaled,
      (context, offset) => _clip.layer = context.pushClipPath(
        needsCompositing,
        offset,
        path.getBounds(),
        path,
        (context, offset) => context.paintChild(child, offset),
        oldLayer: _clip.layer,
      ),
    );

    if (!_refractsContent) {
      _warp.layer = null;
      clipped(context, offset);
      return;
    }
    _refract(context, offset, clipped);
  }

  void _clearLayers() {
    _clip.layer = null;
    _outsideClip.layer = null;
    _warp.layer = null;
    _scaled.layer = null;
    _outsideScaled.layer = null;
  }

  @override
  void dispose() {
    _clearLayers();
    super.dispose();
  }
}

class _ContentLensLayer extends ContainerLayer {
  _ContentLensLayer(this.window);
  final _RenderSelectionWindow window;
  final _filter = LayerHandle<ImageFilterLayer>(ImageFilterLayer());
  ImageFilterLayer get filter => _filter.layer!;
  double? _deviceScale;

  void invalidate() => _deviceScale = null;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final scale = compositedTransform(this).getMaxScaleOnAxis();
    if (scale != _deviceScale || filter.imageFilter == null) {
      _deviceScale = scale;
      filter.imageFilter = window._contentFilter(scale);
    }
    addChildrenToScene(builder);
  }

  @override
  void dispose() {
    _filter.layer = null;
    super.dispose();
  }
}
