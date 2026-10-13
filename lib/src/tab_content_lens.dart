import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'layer_transform.dart';
import 'material.dart';
import 'superellipse.dart';

/// The selected foreground portal, separate from the housing's backdrop lens.
/// Filtering the child preserves custom icon state, focus and semantics.
///
/// With a [color], the child is painted again inside [path] in that colour
/// and only that copy is refracted (tabs). Without one, the whole child is
/// refracted where it lies under [lens] (segment labels).
class ContentLensWindow extends StatefulWidget {
  const ContentLensWindow({
    super.key,
    this.path,
    this.color,
    required this.lens,
    required this.lift,
    required this.shape,
    required this.refraction,
    required this.depth,
    this.scale = 1,
    this.origin = Offset.zero,
    required this.child,
  });
  final Path? path;
  final Color? color;
  final Rect lens;
  final double lift, refraction, depth, scale;
  final Offset origin;
  final GlassShape shape;
  final Widget child;

  @override
  State<ContentLensWindow> createState() => _ContentLensWindowState();
}

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
  Widget build(BuildContext context) => _SelectionWindowPaint(
    path: widget.path,
    color: widget.color,
    lens: widget.lens,
    lift: widget.lift,
    shape: widget.shape,
    shader: _shader,
    refraction: widget.refraction,
    depth: widget.depth,
    scale: widget.scale,
    origin: widget.origin,
    child: widget.child,
  );
}

/// Paints its child once, then again clipped to [path] with every pixel
/// recoloured to [color]: the selected tint shows wherever the pill is.
///
/// The housing's flex [scale] is applied here, beneath the refraction filter,
/// rather than by an ancestor transform. A filter layer under an animating
/// scale is placed on whole device pixels each frame, so while the pill lifted
/// the selected copy popped between pixels against the smoothly scaling rest.
class _SelectionWindowPaint extends SingleChildRenderObjectWidget {
  const _SelectionWindowPaint({
    required this.path,
    required this.color,
    required this.lens,
    required this.lift,
    required this.shape,
    required this.shader,
    required this.refraction,
    required this.depth,
    required this.scale,
    required this.origin,
    required super.child,
  });
  final Path? path;
  final Color? color;
  final Rect lens;
  final double lift, refraction, depth, scale;
  final Offset origin;
  final GlassShape shape;
  final ui.FragmentShader? shader;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSelectionWindow(path, color)
        ..configure(shader, lens, lift, shape, refraction, depth)
        ..setScale(scale, origin);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSelectionWindow renderObject,
  ) {
    renderObject
      ..path = path
      ..color = color
      ..configure(shader, lens, lift, shape, refraction, depth)
      ..setScale(scale, origin);
  }
}

class _RenderSelectionWindow extends RenderProxyBox {
  _RenderSelectionWindow(this._path, this._color);
  Path? _path;
  Color? _color;
  set path(Path? value) {
    if (identical(value, _path)) return;
    final toggled = (value == null) != (_path == null);
    _path = value;
    if (toggled) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  set color(Color? value) {
    if (value == _color) return;
    final toggled = (value == null) != (_color == null);
    _color = value;
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

  /// The flex scale about [_origin], or null at rest.
  Matrix4? get _transform => _scale == 1
      ? null
      : (Matrix4.translationValues(_origin.dx, _origin.dy, 0)
          ..scaleByDouble(_scale, _scale, 1, 1)
          ..translateByDouble(-_origin.dx, -_origin.dy, 0, 1));

  ui.FragmentShader? _shader;
  Rect _lens = Rect.zero;
  double _lift = 0, _refraction = 14, _depth = 11.2;
  GlassShape _shape = GlassShape.capsule;
  void configure(
    ui.FragmentShader? shader,
    Rect lens,
    double lift,
    GlassShape shape,
    double refraction,
    double depth,
  ) {
    if (shader == _shader &&
        lens == _lens &&
        lift == _lift &&
        shape == _shape &&
        refraction == _refraction &&
        depth == _depth) {
      return;
    }
    final refracted = _refractsContent;
    _shader = shader;
    _lens = lens;
    _lift = lift;
    _shape = shape;
    _refraction = refraction;
    _depth = depth;
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

  /// Whether the selected foreground is refracted by the content lens.
  bool get _refractsContent =>
      _shader != null && _lift >= .001 && _refraction != 0;

  /// The content lens for a raster at [deviceScale] physical pixels per point.
  ui.ImageFilter _contentFilter(double deviceScale) {
    final shader = _shader!;
    // The filter sits outside the flex scale, so its lens is the scaled
    // contour; lengths in points scale with it.
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
    // The filter reads the whole foreground row, which stays put while the
    // pill moves; the lens is expressed relative to that row.
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
      _refraction * _scale,
      _depth * _scale,
    ];
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i + 2, values[i]);
    }
    return ui.ImageFilter.shader(shader);
  }

  final _warp = LayerHandle<_ContentLensLayer>();
  final _clip = LayerHandle<ClipPathLayer>();
  final _outsideClip = LayerHandle<ClipPathLayer>();
  final _filter = LayerHandle<ColorFilterLayer>();
  final _scaled = LayerHandle<TransformLayer>();
  final _outsideScaled = LayerHandle<TransformLayer>();

  /// Paints [painter] under the flex scale, reusing [handle]'s layer.
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
  bool get alwaysNeedsCompositing =>
      _path != null || (_color == null && _refractsContent);

  /// Paints [inner] through the content lens filter.
  void _refract(
    PaintingContext context,
    Offset offset,
    PaintingContextCallback inner,
  ) {
    // Clip inside the filter, not around it. Impeller sizes a filter's input
    // to its clip; a clip that follows the pill moves that input by fractions
    // of a pixel each frame, so the shader resampled the glyphs at a shifting
    // phase and they shook in place. The shader only pulls samples inward from
    // the contour, so clipping first leaves its output unchanged.
    final lens = _warp.layer ??= _ContentLensLayer(this);
    lens.invalidate();
    final layer = lens.filter..offset = offset;
    context.pushLayer(
      lens,
      (context, _) => context.pushLayer(layer, (context, _) {
        // Establish the full foreground source extent. Glyph-only ink bounds
        // otherwise shift the shader's lens coordinate system.
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
    if (child == null) return;
    final path = _path;
    if (path == null) {
      _clip.layer = null;
      _outsideClip.layer = null;
      _filter.layer = null;
      _warp.layer = null;
      _scaled.layer = null;
      void plain(PaintingContext context, Offset offset) => _underScale(
        context,
        offset,
        _outsideScaled,
        (context, offset) => context.paintChild(child, offset),
      );
      if (_color == null && _refractsContent) {
        _refract(context, offset, plain);
      } else {
        _warp.layer = null;
        plain(context, offset);
      }
      return;
    }
    // The selected and unselected copies occupy complementary regions.
    // Painting both at the same pixel leaves unselected fringes around glyphs.
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
    void selected(PaintingContext context, Offset offset) {
      final color = _color;
      if (color == null) {
        _filter.layer = null;
        context.paintChild(child, offset);
        return;
      }
      _filter.layer = context.pushColorFilter(
        offset,
        ui.ColorFilter.mode(color, BlendMode.srcIn),
        (context, offset) => context.paintChild(child, offset),
        oldLayer: _filter.layer,
      );
    }

    void clipped(PaintingContext context, Offset offset) => _underScale(
      context,
      offset,
      _scaled,
      (context, offset) => _clip.layer = context.pushClipPath(
        needsCompositing,
        offset,
        path.getBounds(),
        path,
        selected,
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

  @override
  void dispose() {
    _clip.layer = null;
    _outsideClip.layer = null;
    _filter.layer = null;
    _warp.layer = null;
    _scaled.layer = null;
    _outsideScaled.layer = null;
    super.dispose();
  }
}

/// Configures the content lens filter at composition. The filter maps its
/// raster with the composited device scale, which an animating ancestor
/// transform changes without repainting the tab bar beneath a repaint
/// boundary. The composited scale, unlike the laid-out one, also excludes an
/// ancestor `ImageFilter.matrix`, which scales this raster only afterwards.
class _ContentLensLayer extends ContainerLayer {
  _ContentLensLayer(this.window);
  final _RenderSelectionWindow window;
  // The handle keeps the child alive while it is detached between repaints.
  final _filter = LayerHandle<ImageFilterLayer>(ImageFilterLayer());
  ImageFilterLayer get filter => _filter.layer!;
  double? _deviceScale;

  /// Rebuilds the filter at the next composition; the window repainted.
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
