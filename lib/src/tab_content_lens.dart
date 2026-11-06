import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'layer_transform.dart';
import 'material.dart';
import 'superellipse.dart';

/// The selected foreground portal, separate from the housing's backdrop lens.
/// Filtering the child preserves custom icon state, focus and semantics.
///
/// The default constructor refracts the whole child where it lies under
/// [lens] (segment labels). [ContentLensWindow.selection] (tabs) paints
/// [child] outside [path] and the display-only [selected] copy inside it,
/// refracting only that copy: native keeps an unselected and a selected copy
/// of the bar's foreground and shows the selected one through the pill, so a
/// tab seen through the moving pill takes its selected icon and weight.
class ContentLensWindow extends StatefulWidget {
  const ContentLensWindow({
    super.key,
    required this.lens,
    required this.lift,
    required this.shape,
    required this.refraction,
    required this.depth,
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
    this.chromaticAberration = 0,
    this.chromaticBand = 4.8,
    this.scale = 1,
    this.origin = Offset.zero,
    required this.child,
  }) : _selection = true;

  /// The pill's window; null paints only [child], unrefracted.
  final Path? path;

  /// Painted inside [path], without hit testing or semantics; [child] keeps
  /// both. Built only while the window is open.
  final Widget? selected;
  final bool _selection;
  final Rect lens;
  final double lift, refraction, depth, scale;
  final double chromaticAberration, chromaticBand;
  final Offset origin;
  final GlassShape shape;
  final Widget child;

  @override
  State<ContentLensWindow> createState() => _ContentLensWindowState();
}

/// u_effect after the contour: displacement/depth in scaled points, effective
/// split in raster pixels, band depth in scaled points. Also used by packet tests.
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
    Widget paint(_WindowRegion region, Widget child) => _SelectionWindowPaint(
      region: region,
      path: widget.path,
      lens: widget.lens,
      lift: widget.lift,
      shape: widget.shape,
      // Only the refracted copy needs the content lens.
      shader: region == _WindowRegion.outside ? null : _shader,
      refraction: widget.refraction,
      depth: widget.depth,
      chromaticAberration: widget.chromaticAberration,
      chromaticBand: widget.chromaticBand,
      scale: widget.scale,
      origin: widget.origin,
      child: child,
    );
    if (!widget._selection) return paint(_WindowRegion.whole, widget.child);
    final selected = widget.selected;
    // The base copy stays the first child whether or not the window is open,
    // so opening it never rebuilds the tabs' focus or icon state.
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

/// Which part of its child a [_SelectionWindowPaint] shows.
enum _WindowRegion {
  /// Everything, refracted where it lies under the lens (segment labels).
  whole,

  /// Everything outside the window, unrefracted (the unselected tab copy).
  outside,

  /// Only the window, refracted (the selected tab copy).
  inside,
}

/// Paints one region of its child relative to the pill's [path].
///
/// The housing's flex [scale] is applied here, beneath the refraction filter,
/// rather than by an ancestor transform. A filter layer under an animating
/// scale is placed on whole device pixels each frame, so while the pill lifted
/// the selected copy popped between pixels against the smoothly scaling rest.
class _SelectionWindowPaint extends SingleChildRenderObjectWidget {
  const _SelectionWindowPaint({
    required this.region,
    required this.path,
    required this.lens,
    required this.lift,
    required this.shape,
    required this.shader,
    required this.refraction,
    required this.depth,
    required this.chromaticAberration,
    required this.chromaticBand,
    required this.scale,
    required this.origin,
    required super.child,
  });
  final _WindowRegion region;
  final Path? path;
  final Rect lens;
  final double lift, refraction, depth, scale;
  final double chromaticAberration, chromaticBand;
  final Offset origin;
  final GlassShape shape;
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

  /// The flex scale about [_origin], or null at rest.
  Matrix4? get _transform => _scale == 1
      ? null
      : (Matrix4.translationValues(_origin.dx, _origin.dy, 0)
          ..scaleByDouble(_scale, _scale, 1, 1)
          ..translateByDouble(-_origin.dx, -_origin.dy, 0, 1));

  ui.FragmentShader? _shader;
  Rect _lens = Rect.zero;
  double _lift = 0, _refraction = 14, _depth = 11.2;
  double _chromaticAberration = 0, _chromaticBand = 4.8;
  GlassShape _shape = GlassShape.capsule;
  void configure(
    ui.FragmentShader? shader,
    Rect lens,
    double lift,
    GlassShape shape,
    double refraction,
    double depth,
    double chromaticAberration,
    double chromaticBand,
  ) {
    if (shader == _shader &&
        lens == _lens &&
        lift == _lift &&
        shape == _shape &&
        refraction == _refraction &&
        depth == _depth &&
        chromaticAberration == _chromaticAberration &&
        chromaticBand == _chromaticBand) {
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
      _shader != null &&
      _lift >= .001 &&
      (_refraction != 0 || (_chromaticAberration > 0 && _chromaticBand > 0));

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
      ...contentLensEffectUniforms(
        refraction: _refraction,
        depth: _depth,
        chromaticAberration: _chromaticAberration,
        chromaticBand: _chromaticBand,
        lift: _lift,
        scale: _scale,
        deviceScale: deviceScale,
      ),
    ];
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i + 2, values[i]);
    }
    return ui.ImageFilter.shader(shader);
  }

  final _warp = LayerHandle<_ContentLensLayer>();
  final _clip = LayerHandle<ClipPathLayer>();
  final _outsideClip = LayerHandle<ClipPathLayer>();
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
  bool get alwaysNeedsCompositing => switch (_region) {
    _WindowRegion.whole => _refractsContent,
    _WindowRegion.outside || _WindowRegion.inside => _path != null,
  };

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
      // The selected and unselected copies occupy complementary regions.
      // Painting both at the same pixel leaves unselected fringes around
      // glyphs.
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
