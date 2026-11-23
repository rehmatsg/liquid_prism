import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/rendering/edge_fade.dart';
import 'package:liquid_prism/src/rendering/layer_transform.dart';
import 'package:liquid_prism/src/rendering/prism.dart';

@immutable
/// Immutable progressive blur, haze, and fade settings for one edge.
class PrismEdgeBlurStrip {
  /// Creates an edge strip with a plateau and progressive falloff.
  const new({
    required this.edge,
    required this.extent,
    this.sigma = 0,
    this.plateau = 0,
    this.floor = 0,
    this.fadeColor,
    this.fadeOpacity = 1,
    this.fadeFloor,
    this.haze = 0,
    this.hazeOpacity = .5,
    this.hazePlateau = .34,
  }) : assert(extent >= 0, 'extent must be nonnegative'),
       assert(sigma >= 0, 'sigma must be nonnegative'),
       assert(plateau >= 0 && plateau < 1, 'plateau must be in [0, 1)'),
       assert(floor >= 0 && floor <= 1, 'floor must be in [0, 1]'),
       assert(
         fadeOpacity >= 0 && fadeOpacity <= 1,
         'fadeOpacity must be in [0, 1]',
       ),
       assert(
         fadeFloor == null || (fadeFloor >= 0 && fadeFloor <= 1),
         'fadeFloor must be null or in [0, 1]',
       ),
       assert(haze >= 0, 'haze must be nonnegative'),
       assert(
         hazeOpacity >= 0 && hazeOpacity <= 1,
         'hazeOpacity must be in [0, 1]',
       ),
       assert(
         hazePlateau >= 0 && hazePlateau <= 1,
         'hazePlateau must be in [0, 1]',
       );

  /// Edge from which the strip extends inward.
  final PrismEdge edge;

  /// Strip depth in logical pixels.
  final double extent;

  /// Maximum Gaussian blur sigma in logical pixels.
  final double sigma;

  /// Leading fraction held at full blur strength.
  final double plateau;

  /// Blur and fade strength retained at the inner edge.
  final double floor;

  /// Optional fade overlay color.
  final Color? fadeColor;

  /// Fade opacity at the outer edge.
  final double fadeOpacity;

  /// Optional fade strength retained at the inner edge.
  final double? fadeFloor;

  /// Heavy haze blur sigma in logical pixels.
  final double haze;

  /// Haze opacity at the outer edge.
  final double hazeOpacity;

  /// Leading fraction held at full haze opacity.
  final double hazePlateau;

  /// Whether this strip applies progressive blur.
  bool get blurs => sigma > 0.01 && extent > 0;

  /// Whether this strip applies a heavy haze blur.
  bool get hazes => haze > 0.01 && hazeOpacity > 0 && extent > 0;

  /// Whether this strip applies a color fade.
  bool get fades =>
      fadeColor != null && fadeColor!.a > 0 && fadeOpacity > 0 && extent > 0;

  /// Returns a copy with the supplied fields replaced.
  PrismEdgeBlurStrip copyWith({
    PrismEdge? edge,
    double? extent,
    double? sigma,
    double? plateau,
    double? floor,
    Color? fadeColor,
    double? fadeOpacity,
    double? fadeFloor,
    double? haze,
    double? hazeOpacity,
    double? hazePlateau,
  }) => PrismEdgeBlurStrip(
    edge: edge ?? this.edge,
    extent: extent ?? this.extent,
    sigma: sigma ?? this.sigma,
    plateau: plateau ?? this.plateau,
    floor: floor ?? this.floor,
    fadeColor: fadeColor ?? this.fadeColor,
    fadeOpacity: fadeOpacity ?? this.fadeOpacity,
    fadeFloor: fadeFloor ?? this.fadeFloor,
    haze: haze ?? this.haze,
    hazeOpacity: hazeOpacity ?? this.hazeOpacity,
    hazePlateau: hazePlateau ?? this.hazePlateau,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismEdgeBlurStrip &&
          other.edge == edge &&
          other.extent == extent &&
          other.sigma == sigma &&
          other.plateau == plateau &&
          other.floor == floor &&
          other.fadeColor == fadeColor &&
          other.fadeOpacity == fadeOpacity &&
          other.fadeFloor == fadeFloor &&
          other.haze == haze &&
          other.hazeOpacity == hazeOpacity &&
          other.hazePlateau == hazePlateau;

  @override
  int get hashCode => Object.hash(
    edge,
    extent,
    sigma,
    plateau,
    floor,
    fadeColor,
    fadeOpacity,
    fadeFloor,
    haze,
    hazeOpacity,
    hazePlateau,
  );

  @override
  String toString() =>
      'PrismEdgeBlurStrip(${edge.name}, extent: $extent, sigma: $sigma, '
      'plateau: $plateau, floor: $floor, fade: $fadeColor @ $fadeOpacity, '
      'haze: $haze @ $hazeOpacity)';
}

/// Progressively blurs and fades opposite edges above its content.
class PrismEdgeBlur extends StatefulWidget {
  /// Creates an effect with at most two distinct edges on one axis.
  const new({super.key, required this.edges, this.child});

  /// Up to two distinct strips on one axis.
  final List<PrismEdgeBlurStrip> edges;

  /// Content painted beneath the edge effects.
  final Widget? child;

  /// Loads the edge blur program before the first strip is painted.
  static Future<void> preload() => Prism.initialize();

  @override
  State<PrismEdgeBlur> createState() => _PrismEdgeBlurState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<PrismEdgeBlurStrip>('edges', edges));
  }
}

bool _debugValidateEdges(List<PrismEdgeBlurStrip> edges) {
  assert(edges.length <= 2, 'PrismEdgeBlur takes at most two edges');
  if (edges.length == 2) {
    assert(
      edges[0].edge != edges[1].edge,
      'PrismEdgeBlur edges must be distinct',
    );
    assert(
      edges[0].edge.isHorizontal == edges[1].edge.isHorizontal,
      'PrismEdgeBlur edges must share one axis '
      '(top and bottom, or left and right)',
    );
  }
  return true;
}

class _PrismEdgeBlurState extends State<PrismEdgeBlur> {
  bool _loading = false;

  void _ensureProgram() {
    if (PrismShaderCache.edgeProgram != null ||
        !Prism.isShaderSupported ||
        _loading ||
        !widget.edges.any((edge) => edge.blurs)) {
      return;
    }
    _loading = true;
    unawaited(
      PrismShaderCache.ensureLoaded()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object error, StackTrace stack) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'liquid_prism',
                context: ErrorDescription(
                  'while compiling the edge blur shader',
                ),
              ),
            );
          })
          .whenComplete(() => _loading = false),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureProgram();
  }

  @override
  void didUpdateWidget(PrismEdgeBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureProgram();
  }

  @override
  Widget build(BuildContext context) {
    assert(_debugValidateEdges(widget.edges), 'invalid PrismEdgeBlur');
    return _EdgeBlurRenderWidget(
      specs: widget.edges,
      program: Prism.isShaderSupported ? PrismShaderCache.edgeProgram : null,
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      child: widget.child,
    );
  }
}

class _EdgeBlurRenderWidget extends SingleChildRenderObjectWidget {
  const new({
    required this.specs,
    required this.program,
    required this.pixelRatio,
    super.child,
  });
  final List<PrismEdgeBlurStrip> specs;
  final ui.FragmentProgram? program;
  final double pixelRatio;

  @override
  _RenderEdgeBlur createRenderObject(BuildContext context) =>
      _RenderEdgeBlur(specs, program, pixelRatio);

  @override
  void updateRenderObject(BuildContext context, _RenderEdgeBlur renderObject) {
    renderObject
      ..program = program
      ..pixelRatio = pixelRatio
      ..specs = specs;
  }
}

class _EdgePassFilter {
  new(this._shader);
  final ui.FragmentShader _shader;
  List<double> _values = const [];
  ui.ImageFilter? _filter;

  ui.ImageFilter filterFor(List<double> values) {
    final current = _filter;
    if (current != null && listEquals(values, _values)) return current;
    for (var i = 0; i < values.length; i++) {
      _shader.setFloat(2 + i, values[i]);
    }
    _values = values;
    return _filter = ui.ImageFilter.shader(
      _shader,
      filterQuality: ui.FilterQuality.low,
    );
  }

  void dispose() => _shader.dispose();
}

class _RenderEdgeBlur extends RenderProxyBox {
  new(this._specs, this._program, this.pixelRatio);

  final _contentLayer = LayerHandle<_EdgeContentLayer>();
  final _inputClipLayer = LayerHandle<ClipRectLayer>();
  final _stripClipLayers = [
    LayerHandle<ClipPathLayer>(),
    LayerHandle<ClipPathLayer>(),
  ];
  final _passLayers = [
    LayerHandle<_EdgePassLayer>(),
    LayerHandle<_EdgePassLayer>(),
  ];
  final _fadeLayer = LayerHandle<_EdgeFadeLayer>();

  final _hazeClipLayers = [
    LayerHandle<ClipRectLayer>(),
    LayerHandle<ClipRectLayer>(),
  ];
  final _hazeLayers = [
    LayerHandle<_EdgeHazeLayer>(),
    LayerHandle<_EdgeHazeLayer>(),
  ];

  List<_EdgePassFilter>? _screenFilters;
  List<_EdgePassFilter>? _textureFilters;
  ({ui.ImageFilter inner, ui.ImageFilter outer, ui.ImageFilter filter})?
  _textureCompose;

  List<_EdgePassFilter> _createPassFilters() => [
    _EdgePassFilter(PrismShaderCache.createEdgeShader()!),
    _EdgePassFilter(PrismShaderCache.createEdgeShader()!),
  ];

  bool _isolated = false;

  List<PrismEdgeBlurStrip> _specs;
  List<PrismEdgeBlurStrip> get specs => _specs;
  set specs(List<PrismEdgeBlurStrip> value) {
    if (listEquals(value, _specs)) return;
    final wasActive = _isActive;
    _specs = value;
    if (_isActive != wasActive) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  ui.FragmentProgram? _program;
  ui.FragmentProgram? get program => _program;
  set program(ui.FragmentProgram? value) {
    if (identical(value, _program)) return;
    final wasActive = _isActive;
    _program = value;
    _disposeFilters();
    if (_isActive != wasActive) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  double pixelRatio;

  Iterable<PrismEdgeBlurStrip> get _blurs =>
      _program == null ? const [] : _specs.where((spec) => spec.blurs);
  Iterable<PrismEdgeBlurStrip> get _fades => _specs.where((spec) => spec.fades);
  Iterable<PrismEdgeBlurStrip> get _hazes =>
      PrismShaderCache.edgeProgram == null
      ? const []
      : _specs.where((spec) => spec.hazes);
  bool get _blurring => _blurs.isNotEmpty;
  bool get _hazing => _hazes.isNotEmpty;
  bool get _isActive => _blurring || _hazing || _fades.isNotEmpty;
  bool get hasChild => child != null;

  @override
  bool get alwaysNeedsCompositing => _isActive;

  @override
  void detach() {
    _contentLayer.layer?.blur = null;
    _fadeLayer.layer?.blur = null;
    for (final handle in _passLayers) {
      handle.layer?.blur = null;
    }
    for (final handle in _hazeLayers) {
      handle.layer?.blur = null;
    }
    super.detach();
  }

  @override
  void dispose() {
    _releaseLayers();
    _disposeFilters();
    _fadePicture?.dispose();
    super.dispose();
  }

  void _releaseLayers() {
    _contentLayer.layer?.blur = null;
    _contentLayer.layer = null;
    _inputClipLayer.layer = null;
    _fadeLayer.layer?.blur = null;
    _fadeLayer.layer = null;
    _releaseHazes(from: 0);
    for (var pass = 0; pass < 2; pass++) {
      _stripClipLayers[pass].layer = null;
      _passLayers[pass].layer?.blur = null;
      _passLayers[pass].layer = null;
    }
  }

  void _releaseHazes({required int from}) {
    for (var i = from; i < _hazeLayers.length; i++) {
      _hazeClipLayers[i].layer = null;
      _hazeLayers[i].layer?.blur = null;
      _hazeLayers[i].layer = null;
    }
  }

  void _disposeFilters() {
    for (final filter in [...?_screenFilters, ...?_textureFilters]) {
      filter.dispose();
    }
    _screenFilters = null;
    _textureFilters = null;
    _textureCompose = null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_isActive || size.isEmpty) {
      _releaseLayers();
      super.paint(context, offset);
      return;
    }
    final content = (_contentLayer.layer ??= _EdgeContentLayer())
      ..blur = this
      ..paintOffset = offset;
    context.pushLayer(content, _paintContent, offset);

    if (_blurring) {
      final strips = _stripPath(_blurs);
      final bounds = strips.getBounds();
      for (var pass = 0; pass < 2; pass++) {
        final passLayer = (_passLayers[pass].layer ??= _EdgePassLayer(pass))
          ..blur = this;
        _stripClipLayers[pass].layer = context.pushClipPath(
          needsCompositing,
          offset,
          bounds,
          strips,
          (context, offset) => context.pushLayer(
            passLayer,
            (context, offset) =>
                context.pushLayer(passLayer.filter, (_, _) {}, offset),
            offset,
          ),
          clipBehavior: Clip.hardEdge,
          oldLayer: _stripClipLayers[pass].layer,
        );
      }
    } else {
      for (var pass = 0; pass < 2; pass++) {
        _stripClipLayers[pass].layer = null;
        _passLayers[pass].layer?.blur = null;
        _passLayers[pass].layer = null;
      }
    }
    var hazes = 0;
    for (final spec in _hazes) {
      final strip = _stripRect(spec);
      if (strip.isEmpty) continue;
      final haze = (_hazeLayers[hazes].layer ??= _EdgeHazeLayer())
        ..blur = this
        ..sigma = spec.haze
        ..bounds = strip.shift(offset);
      _hazeClipLayers[hazes].layer = context.pushClipRect(
        needsCompositing,
        offset,
        strip,
        (context, offset) => context.pushLayer(
          haze,
          (context, offset) =>
              context.pushLayer(haze.filter, (context, offset) {
                final canvas = context.canvas
                  ..save()
                  ..translate(offset.dx, offset.dy);
                _paintHazeWeight(canvas, spec);
                canvas.restore();
              }, offset),
          offset,
        ),
        oldLayer: _hazeClipLayers[hazes].layer,
      );
      hazes++;
    }
    _releaseHazes(from: hazes);
    if (_fades.isNotEmpty) {
      final fade = (_fadeLayer.layer ??= _EdgeFadeLayer())
        ..blur = this
        ..offset = offset;
      context.pushLayer(fade, (_, _) {}, offset);
    } else {
      _fadeLayer.layer?.blur = null;
      _fadeLayer.layer = null;
    }
  }

  Path _stripPath(Iterable<PrismEdgeBlurStrip> specs) {
    final path = Path();
    for (final spec in specs) {
      path.addRect(_stripRect(spec));
    }
    return path;
  }

  Rect _stripRect(PrismEdgeBlurStrip spec) {
    final width = size.width;
    final height = size.height;
    return switch (spec.edge) {
      PrismEdge.top => Rect.fromLTWH(0, 0, width, spec.extent.clamp(0, height)),
      PrismEdge.bottom => Rect.fromLTWH(
        0,
        height - spec.extent.clamp(0, height),
        width,
        spec.extent.clamp(0, height),
      ),
      PrismEdge.left => Rect.fromLTWH(
        0,
        0,
        spec.extent.clamp(0, width),
        height,
      ),
      PrismEdge.right => Rect.fromLTWH(
        width - spec.extent.clamp(0, width),
        0,
        spec.extent.clamp(0, width),
        height,
      ),
    };
  }

  void _paintContent(PaintingContext context, Offset offset) {
    _inputClipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintCoveragePinnedChild,
      oldLayer: _inputClipLayer.layer,
    );
  }

  void _paintCoveragePinnedChild(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.canvas.drawRect(offset & size, _coveragePaint);
    super.paint(context, offset);
  }

  static final Paint _coveragePaint = Paint()..color = const Color(0x01000000);

  ui.Picture? _fadePicture;
  List<Object> _fadeSignature = const [];

  ui.Picture _fadeFor(Offset offset) {
    final signature = <Object>[offset, size, ..._fades];
    if (_fadePicture != null && listEquals(signature, _fadeSignature)) {
      return _fadePicture!;
    }
    _fadeSignature = signature;
    _fadePicture?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(offset.dx, offset.dy);
    _drawFades(canvas);
    return _fadePicture = recorder.endRecording();
  }

  void _drawFades(Canvas canvas) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size, doAntiAlias: false);
    for (final spec in _fades) {
      final rect = _stripRect(spec);
      if (rect.isEmpty) continue;
      canvas.drawRect(
        _overhang(rect, spec.edge),
        Paint()
          ..isAntiAlias = false
          ..shader = PrismEdgeFade.shader(
            color: spec.fadeColor!,
            rect: rect,
            edge: spec.edge,
            plateau: spec.plateau,
            floor: spec.fadeFloor ?? spec.floor,
            opacity: spec.fadeOpacity,
          ),
      );
    }
    canvas.restore();
  }

  static const double _fadeBleed = 1;

  static Rect _overhang(Rect strip, PrismEdge edge) {
    const bleed = _fadeBleed;
    return switch (edge) {
      PrismEdge.top => Rect.fromLTRB(
        strip.left - bleed,
        strip.top - bleed,
        strip.right + bleed,
        strip.bottom,
      ),
      PrismEdge.bottom => Rect.fromLTRB(
        strip.left - bleed,
        strip.top,
        strip.right + bleed,
        strip.bottom + bleed,
      ),
      PrismEdge.left => Rect.fromLTRB(
        strip.left - bleed,
        strip.top - bleed,
        strip.right,
        strip.bottom + bleed,
      ),
      PrismEdge.right => Rect.fromLTRB(
        strip.left,
        strip.top - bleed,
        strip.right + bleed,
        strip.bottom + bleed,
      ),
    };
  }

  ui.ImageFilter _textureFrameFilter() {
    final passes = _textureFilters ??= _createPassFilters();
    final horizontal = passes[0].filterFor(
      _uniforms(pass: 0, frame: _textureFrame),
    );
    final vertical = passes[1].filterFor(
      _uniforms(pass: 1, frame: _textureFrame),
    );
    final cached = _textureCompose;
    if (cached != null &&
        identical(cached.inner, horizontal) &&
        identical(cached.outer, vertical)) {
      return cached.filter;
    }
    final filter = ui.ImageFilter.compose(outer: vertical, inner: horizontal);
    _textureCompose = (inner: horizontal, outer: vertical, filter: filter);
    return filter;
  }

  Offset _screenOrigin = Offset.zero;
  (double, double, double, double) _screenMatrix = (1, 0, 0, 1);

  void _locateOnScreen() {
    final transform = getTransformTo(null);
    final m = transform.storage;
    final dpr = pixelRatio;
    _screenOrigin = MatrixUtils.transformPoint(transform, Offset.zero) * dpr;
    _screenMatrix = (m[0] * dpr, m[1] * dpr, m[4] * dpr, m[5] * dpr);
  }

  ui.ImageFilter _screenFrameFilter(int pass) {
    final passes = _screenFilters ??= _createPassFilters();
    return passes[pass].filterFor(
      _uniforms(
        pass: pass,
        frame: _screenFrame,
        origin: _screenOrigin,
        matrix: _screenMatrix,
      ),
    );
  }

  static const double _screenFrame = 0;
  static const double _textureFrame = 1;

  void _paintHazeWeight(Canvas canvas, PrismEdgeBlurStrip spec) {
    final rect = _stripRect(spec);
    final (begin, end) = switch (spec.edge) {
      PrismEdge.top => (rect.topCenter, rect.bottomCenter),
      PrismEdge.bottom => (rect.bottomCenter, rect.topCenter),
      PrismEdge.left => (rect.centerLeft, rect.centerRight),
      PrismEdge.right => (rect.centerRight, rect.centerLeft),
    };
    final weight = Color.from(
      alpha: spec.hazeOpacity,
      red: 0,
      green: 0,
      blue: 0,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          begin,
          end,
          [weight, weight, weight.withValues(alpha: 0)],
          [0, spec.hazePlateau.clamp(0, 1), 1],
        ),
    );
  }

  List<double> _uniforms({
    required int pass,
    required double frame,
    Offset origin = Offset.zero,
    (double, double, double, double) matrix = (1, 0, 0, 1),
  }) {
    PrismEdgeBlurStrip? start;
    PrismEdgeBlurStrip? end;
    for (final spec in _blurs) {
      if (spec.edge.isStart) {
        start = spec;
      } else {
        end = spec;
      }
    }
    final edge = (start ?? end)!.edge;
    final (a, b, c, d) = matrix;
    final det = a * d - b * c;
    final inverse = det.abs() < 1e-9
        ? (1.0, 0.0, 0.0, 1.0)
        : (d / det, -b / det, -c / det, a / det);
    return [
      pass.toDouble(),
      if (edge.isHorizontal) 1 else 0,
      frame,
      size.width,
      size.height,
      origin.dx,
      origin.dy,
      0,
      a,
      b,
      c,
      d,
      inverse.$1,
      inverse.$2,
      inverse.$3,
      inverse.$4,
      start?.extent ?? 0,
      start?.sigma ?? 0,
      start?.plateau ?? 0,
      start?.floor ?? 0,
      end?.extent ?? 0,
      end?.sigma ?? 0,
      end?.plateau ?? 0,
      end?.floor ?? 0,
    ];
  }
}

bool _isolatesBackdrop(Layer layer) {
  for (Layer? ancestor = layer.parent; ancestor != null;) {
    final isolating = switch (ancestor) {
      OpacityLayer(:final alpha) => alpha != null && alpha < 255,
      ImageFilterLayer() ||
      ShaderMaskLayer() ||
      ColorFilterLayer() ||
      BackdropFilterLayer() => true,
      ClipRectLayer(:final clipBehavior) ||
      ClipRRectLayer(:final clipBehavior) ||
      ClipRSuperellipseLayer(:final clipBehavior) ||
      ClipPathLayer(
        :final clipBehavior,
      ) => clipBehavior == Clip.antiAliasWithSaveLayer,
      _ => false,
    };
    if (isolating) return true;
    ancestor = ancestor.parent;
  }
  return false;
}

class _EdgeContentLayer extends ContainerLayer {
  _RenderEdgeBlur? blur;

  Offset paintOffset = Offset.zero;

  ui.ClipRectEngineLayer? _outputClip;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void dispose() {
    _outputClip?.dispose();
    _outputClip = null;
    super.dispose();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    final isolated = owner != null && owner.attached && _isolatesBackdrop(this);
    owner?._isolated = isolated;
    if (!isolated || !owner.hasChild || !owner._blurring) {
      if (owner != null && owner.attached) owner._locateOnScreen();
      engineLayer = null;
      addChildrenToScene(builder);
      return;
    }
    final previousClip = _outputClip;
    _outputClip = builder.pushClipRect(
      paintOffset & owner.size,
      oldLayer: previousClip,
    );
    previousClip?.dispose();
    engineLayer = builder.pushImageFilter(
      owner._textureFrameFilter(),
      oldLayer: engineLayer as ui.ImageFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder
      ..pop()
      ..pop();
  }
}

class _EdgePassLayer extends ContainerLayer {
  new(this.pass);

  final int pass;
  _RenderEdgeBlur? blur;

  final _filter = LayerHandle<BackdropFilterLayer>(BackdropFilterLayer());
  BackdropFilterLayer get filter => _filter.layer!;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void dispose() {
    _filter.layer = null;
    super.dispose();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    if (owner == null || !owner.attached) return;
    if (owner._isolated && owner.hasChild) return;
    filter
      ..filter = owner._screenFrameFilter(pass)
      ..backdropKey = null;
    final clip = compositedAncestorClip(this);
    if (clip != null) builder.pushClipPath(clip);
    addChildrenToScene(builder);
    if (clip != null) builder.pop();
  }
}

class _EdgeHazeLayer extends ContainerLayer {
  _RenderEdgeBlur? blur;
  double sigma = 0;

  Rect bounds = Rect.zero;

  final _filter = LayerHandle<BackdropFilterLayer>(BackdropFilterLayer());
  BackdropFilterLayer get filter => _filter.layer!;

  ({double sigma, Rect bounds, ui.ImageFilter filter})? _cached;

  ui.ImageFilter _blurFilter() {
    final cached = _cached;
    if (cached != null && cached.sigma == sigma && cached.bounds == bounds) {
      return cached.filter;
    }
    final filter = ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: ui.TileMode.decal,
      bounds: bounds,
    );
    _cached = (sigma: sigma, bounds: bounds, filter: filter);
    return filter;
  }

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void dispose() {
    _filter.layer = null;
    super.dispose();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    if (owner == null || !owner.attached) return;
    if (owner._isolated) return;
    filter
      ..filter = _blurFilter()
      ..backdropKey = null;
    final clip = compositedAncestorClip(this);
    if (clip != null) builder.pushClipPath(clip);
    addChildrenToScene(builder);
    if (clip != null) builder.pop();
  }
}

class _EdgeFadeLayer extends ContainerLayer {
  _RenderEdgeBlur? blur;
  Offset offset = Offset.zero;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    if (owner == null || !owner.attached) return;
    final clip = compositedAncestorClip(this);
    if (clip != null) builder.pushClipPath(clip);
    builder.addPicture(Offset.zero, owner._fadeFor(offset));
    if (clip != null) builder.pop();
  }
}
