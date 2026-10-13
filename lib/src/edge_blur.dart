part of 'glass.dart';

/// One progressively blurred edge strip for [LiquidPrismEdgeBlur].
///
/// The strip is [extent] logical pixels deep from [edge]. Blur holds full
/// [sigma] for the leading [plateau] fraction, then falls off along
/// [GlassEdgeFade.curve]. A [fadeColor] adds a fade of the same depth and
/// plateau over the strip, solid at the edge up to [fadeOpacity], so blur and
/// fade track each other exactly.
@immutable
class GlassEdgeBlur {
  const GlassEdgeBlur({
    required this.edge,
    required this.extent,
    this.sigma = 0,
    this.plateau = 0,
    this.fadeColor,
    this.fadeOpacity = 1,
  }) : assert(extent >= 0),
       assert(sigma >= 0),
       assert(plateau >= 0 && plateau < 1),
       assert(fadeOpacity >= 0 && fadeOpacity <= 1);

  /// Which edge of the box the strip sits on.
  final GlassEdge edge;

  /// Depth of the strip in logical pixels.
  final double extent;

  /// Maximum Gaussian sigma at the edge, in logical pixels. Zero blurs nothing;
  /// a fade may still apply.
  final double sigma;

  /// Leading fraction of the strip (0 ≤ plateau < 1) held at full strength
  /// before the smootherstep falloff begins.
  final double plateau;

  /// Fades the strip toward this color, solid at the edge. Null fades nothing.
  final Color? fadeColor;

  /// The fade's opacity at the edge, 0–1.
  final double fadeOpacity;

  /// Whether the strip blurs.
  bool get blurs => sigma > 0.01 && extent > 0;

  /// Whether the strip fades.
  bool get fades =>
      fadeColor != null && fadeColor!.a > 0 && fadeOpacity > 0 && extent > 0;

  GlassEdgeBlur copyWith({
    GlassEdge? edge,
    double? extent,
    double? sigma,
    double? plateau,
    Color? fadeColor,
    double? fadeOpacity,
  }) => GlassEdgeBlur(
    edge: edge ?? this.edge,
    extent: extent ?? this.extent,
    sigma: sigma ?? this.sigma,
    plateau: plateau ?? this.plateau,
    fadeColor: fadeColor ?? this.fadeColor,
    fadeOpacity: fadeOpacity ?? this.fadeOpacity,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassEdgeBlur &&
          other.edge == edge &&
          other.extent == extent &&
          other.sigma == sigma &&
          other.plateau == plateau &&
          other.fadeColor == fadeColor &&
          other.fadeOpacity == fadeOpacity;

  @override
  int get hashCode =>
      Object.hash(edge, extent, sigma, plateau, fadeColor, fadeOpacity);

  @override
  String toString() =>
      'GlassEdgeBlur(${edge.name}, extent: $extent, sigma: $sigma, '
      'plateau: $plateau, fade: $fadeColor @ $fadeOpacity)';
}

/// Blurs and fades up to two opposite edges of its [child] progressively,
/// the way iOS softens content scrolled under a bar.
///
/// Each [GlassEdgeBlur] runs as a two-pass fragment shader whose sigma varies
/// per pixel across the strip, as backdrop passes clipped to the strip and
/// composited above the child, so the child paints as it would unwrapped and
/// glass inside it stays live. The fade paints over the blur.
///
/// Inside a [LiquidPrismGroup] or [LiquidPrismScaffold], the strips join the
/// group's shared captures: their passes are painted with the members'
/// hoisted frost and the members' optical passes read a capture taken before
/// the fade, with the strips cut out of every member's contour. Glass over
/// the strip therefore refracts the unblurred, unfaded content beneath it, as
/// native bar buttons do over a scroll edge effect, and a bar's effect and
/// capsules cost two backdrop captures together instead of two each. Place
/// the effect before the group's glass in paint order; an effect with a
/// [child] joins only when it paints first.
///
/// Under an ancestor that isolates the subtree in its own pass (an `Opacity`
/// below 1, an `ImageFiltered`, a filtered `Transform`) the strips filter the
/// child's own raster instead, so the blur stays correct through such
/// transitions; glass inside is outside the supported composition there.
///
/// With no active strip (empty [edges], zero sigma and no fade, the program not
/// yet loaded, or no shader support) it paints straight through with no layer,
/// so descendant state survives the effect toggling. Animate the effect by
/// scaling [GlassEdgeBlur.sigma] and [GlassEdgeBlur.fadeOpacity]; an ancestor
/// `Opacity` does not attenuate a backdrop blur.
class LiquidPrismEdgeBlur extends StatefulWidget {
  const LiquidPrismEdgeBlur({super.key, required this.edges, this.child});

  /// Up to two strips on one axis (top and bottom, or left and right) with
  /// distinct edges.
  final List<GlassEdgeBlur> edges;

  /// The content under the strips. Null blurs whatever is painted beneath
  /// this box.
  final Widget? child;

  /// Compiles the blur program ahead of the first strip. [LiquidPrism.preload]
  /// includes it.
  static Future<void> preload() => LiquidPrism.preload();

  @override
  State<LiquidPrismEdgeBlur> createState() => _LiquidPrismEdgeBlurState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<GlassEdgeBlur>('edges', edges));
  }
}

bool _debugValidateEdges(List<GlassEdgeBlur> edges) {
  assert(edges.length <= 2, 'LiquidPrismEdgeBlur takes at most two edges');
  if (edges.length == 2) {
    assert(
      edges[0].edge != edges[1].edge,
      'LiquidPrismEdgeBlur edges must be distinct',
    );
    assert(
      edges[0].edge.isHorizontal == edges[1].edge.isHorizontal,
      'LiquidPrismEdgeBlur edges must share one axis '
      '(top and bottom, or left and right)',
    );
  }
  return true;
}

class _LiquidPrismEdgeBlurState extends State<LiquidPrismEdgeBlur> {
  bool _loading = false;

  void _ensureProgram() {
    if (LiquidPrism._edgeProgram != null ||
        !LiquidPrism.isShaderSupported ||
        _loading ||
        !widget.edges.any((edge) => edge.blurs)) {
      return;
    }
    _loading = true;
    LiquidPrism.preload()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'liquid_prism',
              context: ErrorDescription('while compiling the edge blur shader'),
            ),
          );
        })
        .whenComplete(() => _loading = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureProgram();
  }

  @override
  void didUpdateWidget(LiquidPrismEdgeBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureProgram();
  }

  @override
  Widget build(BuildContext context) {
    assert(_debugValidateEdges(widget.edges), 'invalid LiquidPrismEdgeBlur');
    return _EdgeBlurRenderWidget(
      specs: widget.edges,
      program: LiquidPrism.isShaderSupported ? LiquidPrism._edgeProgram : null,
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      group: _GlassGroupScope.of(context),
      child: widget.child,
    );
  }
}

class _EdgeBlurRenderWidget extends SingleChildRenderObjectWidget {
  const _EdgeBlurRenderWidget({
    required this.specs,
    required this.program,
    required this.pixelRatio,
    required this.group,
    super.child,
  });
  final List<GlassEdgeBlur> specs;
  final ui.FragmentProgram? program;
  final double pixelRatio;
  final _GlassGroupData? group;

  @override
  _RenderEdgeBlur createRenderObject(BuildContext context) =>
      _RenderEdgeBlur(specs, program, pixelRatio, group);

  @override
  void updateRenderObject(BuildContext context, _RenderEdgeBlur renderObject) {
    renderObject
      ..program = program
      ..pixelRatio = pixelRatio
      ..group = group
      ..specs = specs;
  }
}

/// One pass's shader and the image filter built from its current uniforms.
///
/// `ImageFilter.shader` snapshots the shader's uniforms when the filter is
/// created, so one shader serves every uniform set: it is updated in place
/// and a new filter captures it, while a filter the previous frame's scene
/// still references keeps the values it was built with. Unchanged values
/// return the same filter object, so the backdrop layer keeps its engine layer.
class _EdgePassFilter {
  _EdgePassFilter(this._shader);
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
    return _filter = ui.ImageFilter.shader(_shader);
  }

  void dispose() => _shader.dispose();
}

/// Paints its child untouched, then blurs and fades the edge strips above it.
///
/// Every uniform that depends on where the box sits on screen is read at
/// scene composition, not paint: an ancestor transform (a route slide, the
/// scaled page under a sheet) moves this box without repainting it, and the
/// strip's screen origin must follow it frame by frame.
class _RenderEdgeBlur extends RenderProxyBox {
  _RenderEdgeBlur(this._specs, this._program, this.pixelRatio, this._group);

  final _contentLayer = LayerHandle<_EdgeContentLayer>();
  final _inputClipLayer = LayerHandle<ClipRectLayer>();
  final _hoistLayer = LayerHandle<_EdgeHoistLayer>();
  final _stripClipLayers = [
    LayerHandle<ClipPathLayer>(),
    LayerHandle<ClipPathLayer>(),
  ];
  final _passLayers = [
    LayerHandle<_EdgePassLayer>(),
    LayerHandle<_EdgePassLayer>(),
  ];
  final _fadeLayer = LayerHandle<_EdgeFadeLayer>();

  List<_EdgePassFilter>? _screenFilters;
  List<_EdgePassFilter>? _textureFilters;
  ({ui.ImageFilter inner, ui.ImageFilter outer, ui.ImageFilter filter})?
  _textureCompose;

  List<_EdgePassFilter> _createPassFilters() => [
    _EdgePassFilter(LiquidPrism._createEdgeShader()!),
    _EdgePassFilter(LiquidPrism._createEdgeShader()!),
  ];

  /// Whether the content layer found an isolating ancestor when it was last
  /// composited; the pass layers, composited right after it, read this.
  bool _isolated = false;

  List<GlassEdgeBlur> _specs;
  List<GlassEdgeBlur> get specs => _specs;
  set specs(List<GlassEdgeBlur> value) {
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

  /// Physical px per logical px of the screen the box is composited onto.
  double pixelRatio;

  _GlassGroupData? _group;
  set group(_GlassGroupData? value) {
    if (value == _group) return;
    if (attached) _group?.edges.remove(this);
    _group = value;
    if (attached) _group?.edges.add(this);
  }

  /// Strips that blur, given a program to run them.
  Iterable<GlassEdgeBlur> get _blurs =>
      _program == null ? const [] : _specs.where((spec) => spec.blurs);
  Iterable<GlassEdgeBlur> get _fades => _specs.where((spec) => spec.fades);
  bool get _blurring => _blurs.isNotEmpty;
  bool get _isActive => _blurring || _fades.isNotEmpty;
  bool get hasChild => child != null;

  @override
  bool get alwaysNeedsCompositing => _isActive;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _group?.edges.add(this);
  }

  @override
  void detach() {
    _group?.edges.remove(this);
    _contentLayer.layer?.blur = null;
    _hoistLayer.layer?.blur = null;
    _fadeLayer.layer?.blur = null;
    for (final handle in _passLayers) {
      handle.layer?.blur = null;
    }
    super.detach();
  }

  @override
  void dispose() {
    _releaseLayers();
    _disposeFilters();
    _fadePicture?.dispose();
    _hoistFadePicture?.dispose();
    super.dispose();
  }

  void _releaseLayers() {
    _contentLayer.layer?.blur = null;
    _contentLayer.layer = null;
    _inputClipLayer.layer = null;
    _hoistLayer.layer?.blur = null;
    _hoistLayer.layer = null;
    _fadeLayer.layer?.blur = null;
    _fadeLayer.layer = null;
    for (var pass = 0; pass < 2; pass++) {
      _stripClipLayers[pass].layer = null;
      _passLayers[pass].layer?.blur = null;
      _passLayers[pass].layer = null;
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

  // ─── Paint ─────────────────────────────────────────────────────────────────

  /// Where [paint] placed this box within its enclosing layer.
  Offset _paintOffset = Offset.zero;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_isActive || size.isEmpty) {
      _releaseLayers();
      super.paint(context, offset);
      return;
    }
    _paintOffset = offset;
    final content = _contentLayer.layer ??= _EdgeContentLayer();
    content
      ..blur = this
      ..paintOffset = offset;
    context.pushLayer(content, _paintContent, offset);

    // The group hoists this effect's passes from here, outside the strip
    // clips, so the members' shadows and frost it paints are not clipped.
    final hoist = _hoistLayer.layer ??= _EdgeHoistLayer();
    hoist.blur = this;
    context.pushLayer(hoist, (_, _) {}, offset);

    if (_blurring) {
      final strips = _stripPath(_blurs);
      final bounds = strips.getBounds();
      for (var pass = 0; pass < 2; pass++) {
        final passLayer = _passLayers[pass].layer ??= _EdgePassLayer(pass);
        passLayer.blur = this;
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
    if (_fades.isNotEmpty) {
      final fade = _fadeLayer.layer ??= _EdgeFadeLayer();
      fade
        ..blur = this
        ..offset = offset;
      context.pushLayer(fade, (_, _) {}, offset);
    } else {
      _fadeLayer.layer?.blur = null;
      _fadeLayer.layer = null;
    }
  }

  /// The strips [specs] cover, in this box's coordinates.
  Path _stripPath(Iterable<GlassEdgeBlur> specs) {
    final path = Path();
    for (final spec in specs) {
      path.addRect(_stripRect(spec));
    }
    return path;
  }

  /// The strip a spec covers, in this box's coordinates, clamped to its size.
  Rect _stripRect(GlassEdgeBlur spec) {
    final width = size.width;
    final height = size.height;
    return switch (spec.edge) {
      GlassEdge.top => Rect.fromLTWH(0, 0, width, spec.extent.clamp(0, height)),
      GlassEdge.bottom => Rect.fromLTWH(
        0,
        height - spec.extent.clamp(0, height),
        width,
        spec.extent.clamp(0, height),
      ),
      GlassEdge.left => Rect.fromLTWH(
        0,
        0,
        spec.extent.clamp(0, width),
        height,
      ),
      GlassEdge.right => Rect.fromLTWH(
        width - spec.extent.clamp(0, width),
        0,
        spec.extent.clamp(0, width),
        height,
      ),
    };
  }

  /// Paints the child clipped to the box. The texture frame measures its
  /// strips from the edges of the filter's input texture, which spans the
  /// child's painted coverage: content painting outside the bounds (shadows,
  /// overflow) would grow it mid-scroll and make the strips jump.
  void _paintContent(PaintingContext context, Offset offset) {
    _inputClipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintCoveragePinnedChild,
      oldLayer: _inputClipLayer.layer,
    );
  }

  /// Pins the texture frame's painted coverage to the full box before painting
  /// the child, whose own painting may start inside it (a list whose
  /// transparent top padding shows the background). The engine sizes that
  /// frame's input texture to painted coverage, so an under-covered texture
  /// would displace the strips as scrolling moves the first painted pixel.
  /// 1/255 alpha is imperceptible, while a fully transparent draw may be
  /// culled and not count toward coverage.
  void _paintCoveragePinnedChild(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.canvas.drawRect(offset & size, _coveragePaint);
    super.paint(context, offset);
  }

  static final Paint _coveragePaint = Paint()..color = const Color(0x01000000);

  // ─── Fade ──────────────────────────────────────────────────────────────────

  ui.Picture? _fadePicture;
  List<Object> _fadeSignature = const [];

  /// The fade strips as a picture in this box's enclosing layer space.
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
    for (final spec in _fades) {
      final rect = _stripRect(spec);
      if (rect.isEmpty) continue;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = GlassEdgeFade.shader(
            color: spec.fadeColor!,
            rect: rect,
            edge: spec.edge,
            plateau: spec.plateau,
            opacity: spec.fadeOpacity,
          ),
      );
    }
  }

  // ─── Filters ───────────────────────────────────────────────────────────────

  /// The self-contained two-pass filter for the texture frame, rebuilt only
  /// when the strips or the size change.
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

  /// Where the box sits on the screen at this composition: its top-left in
  /// physical px and the matrix taking logical box px to physical px.
  Offset _screenOrigin = Offset.zero;
  (double, double, double, double) _screenMatrix = (1, 0, 0, 1);

  void _locateOnScreen() {
    final transform = getTransformTo(null);
    final m = transform.storage;
    final dpr = pixelRatio;
    _screenOrigin = MatrixUtils.transformPoint(transform, Offset.zero) * dpr;
    _screenMatrix = (m[0] * dpr, m[1] * dpr, m[4] * dpr, m[5] * dpr);
  }

  /// One backdrop pass in the screen frame, located from the box's current
  /// transform to the root.
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

  static const _screenFrame = 0.0;
  static const _textureFrame = 1.0;

  /// The shader's float uniforms in declaration order after the engine-set
  /// texture size: u_pass, u_box, u_matrix, u_inverse, u_start, u_end. All
  /// lengths are in logical px; the frame's matrix takes them to texture px.
  List<double> _uniforms({
    required int pass,
    required double frame,
    Offset origin = Offset.zero,
    (double, double, double, double) matrix = (1, 0, 0, 1),
  }) {
    GlassEdgeBlur? start;
    GlassEdgeBlur? end;
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
      edge.isHorizontal ? 1 : 0,
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
      0,
      end?.extent ?? 0,
      end?.sigma ?? 0,
      end?.plateau ?? 0,
      0,
    ];
  }

  // ─── Hoisting ──────────────────────────────────────────────────────────────

  ui.Picture? _hoistFadePicture;
  List<Object> _hoistFadeSignature = const [];
  Path? _hoistStrips;
  List<Object> _hoistStripSignature = const [];

  /// Adds this effect's passes and fade to the scene inside a group hoist,
  /// in [host]'s enclosing layer space, cut out of [contours] (the shared
  /// members' glass contours in that space). The horizontal pass reads the
  /// frost capture and the vertical pass the optical capture, so the members'
  /// optical passes see neither the finished blur nor the fade.
  void _hoistInto(
    ui.SceneBuilder builder,
    _GlassGroupData group,
    Matrix4 toHost,
    List<Path> contours,
    List<Path> clips,
  ) {
    _locateOnScreen();
    final signature = <Object>[size, ...toHost.storage, ..._specs];
    for (final contour in contours) {
      signature.add(contour.getBounds());
    }
    final blurs = _blurs.toList();
    final fades = _fades.toList();
    if (_hoistStrips == null || !listEquals(signature, _hoistStripSignature)) {
      _hoistStripSignature = signature;
      var strips = _stripPath(_specs.where((spec) => spec.blurs || spec.fades))
          .transform(toHost.storage);
      for (final contour in contours) {
        strips = Path.combine(PathOperation.difference, strips, contour);
      }
      _hoistStrips = strips;
    }
    final strips = _hoistStrips!;
    for (final clip in clips) {
      builder.pushClipPath(clip);
    }
    if (blurs.isNotEmpty) {
      for (var pass = 0; pass < 2; pass++) {
        final layer = _passLayers[pass].layer;
        if (layer == null) continue;
        layer.filter
          ..filter = _screenFrameFilter(pass)
          ..backdropKey = pass == 0 ? group.frostKey : group.sharedKey;
        builder.pushClipPath(strips);
        layer.filter.addToScene(builder);
        builder.pop();
      }
    }
    if (fades.isNotEmpty) {
      final fadeSignature = <Object>[...signature];
      if (_hoistFadePicture == null ||
          !listEquals(fadeSignature, _hoistFadeSignature)) {
        _hoistFadeSignature = fadeSignature;
        _hoistFadePicture?.dispose();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..clipPath(strips)
          ..transform(toHost.storage);
        _drawFades(canvas);
        _hoistFadePicture = recorder.endRecording();
      }
      builder.addPicture(Offset.zero, _hoistFadePicture!);
    }
    for (final _ in clips) {
      builder.pop();
    }
  }
}

// ─── Layers ──────────────────────────────────────────────────────────────────

/// Whether an ancestor composites [layer]'s subtree through its own offscreen
/// pass, so a backdrop read inside it sees that pass rather than the screen.
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

/// Holds the child's paint. Composited plainly in the screen frame; in an
/// isolated subtree it wraps the child in the texture-frame image filter,
/// clipped to the box so the filter's padded output cannot smear a hairline
/// of edge content just outside it.
class _EdgeContentLayer extends ContainerLayer {
  _RenderEdgeBlur? blur;

  /// Where the child was painted in this layer's coordinates.
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

/// Where a group hoists shared members' shadows and frost together with this
/// effect's passes when the effect reaches the scene before any shared member.
class _EdgeHoistLayer extends ContainerLayer {
  _RenderEdgeBlur? blur;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    if (owner == null || !owner.attached) return;
    final group = owner._group;
    if (group == null ||
        owner._isolated ||
        group._hoistHost != null ||
        !group.hoistEdges.contains(owner)) {
      return;
    }
    group._hoistHost = owner;
    group._hoist(builder, owner, owner._paintOffset);
  }
}

/// One blur pass over the strips, as a backdrop filter whose uniforms follow
/// the box's screen transform at composition. Adds nothing while the subtree
/// is isolated (the content layer blurs in the texture frame instead) or
/// while a group has hoisted this effect.
class _EdgePassLayer extends ContainerLayer {
  _EdgePassLayer(this.pass);

  /// 0 = horizontal, 1 = vertical.
  final int pass;
  _RenderEdgeBlur? blur;

  // The handle keeps the child alive while it is detached between repaints.
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
    if (owner._group?._hoistedEdges.contains(owner) ?? false) return;
    filter
      ..filter = owner._screenFrameFilter(pass)
      ..backdropKey = null;
    addChildrenToScene(builder);
  }
}

/// The fade over the strips, painted after the blur. Adds nothing while a
/// group has hoisted this effect: the hoist paints the fade before the
/// members' optical passes, cut out of their contours.
class _EdgeFadeLayer extends ContainerLayer {
  _RenderEdgeBlur? blur;
  Offset offset = Offset.zero;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    if (owner == null || !owner.attached) return;
    if (owner._group?._hoistedEdges.contains(owner) ?? false) return;
    builder.addPicture(Offset.zero, owner._fadeFor(offset));
  }
}
