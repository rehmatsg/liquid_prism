import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/rendering/layer_transform.dart';
import 'package:liquid_prism/src/rendering/prism.dart';
import 'package:liquid_prism/src/rendering/prism_display.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/superellipse.dart';
import 'package:liquid_prism/src/rendering/surface_render.dart';

/// Shares compatible backdrop captures and optical passes between surfaces.
class PrismGroup extends StatefulWidget {
  /// Creates a group whose members sample the same background.
  const new({super.key, required this.child});

  /// Content containing surfaces that share the background.
  final Widget child;
  @override
  State<PrismGroup> createState() => _PrismGroupState();
}

class _PrismGroupState extends State<PrismGroup> {
  final _data = PrismGroupData();
  @override
  Widget build(BuildContext context) => PrismGroupScope(
    data: _data,
    child: _PrismGroupRenderWidget(data: _data, child: widget.child),
  );
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('batchedSurfaces', _data.prepared.length))
      ..add(IntProperty('opticalBatches', _data._batches.length))
      ..add(IntProperty('sharedBackdropSurfaces', _data.shared.length));
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }
}

@internal
class PrismGroupHost extends StatefulWidget {
  const new({super.key, required this.child});
  final Widget child;
  @override
  State<PrismGroupHost> createState() => _PrismGroupHostState();
}

class _PrismGroupHostState extends State<PrismGroupHost> {
  final _data = PrismGroupData();
  @override
  Widget build(BuildContext context) => _PrismGroupHostScope(
    data: _data,
    child: _PrismGroupRenderWidget(data: _data, child: widget.child),
  );
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('batchedSurfaces', _data.prepared.length))
      ..add(IntProperty('opticalBatches', _data._batches.length))
      ..add(IntProperty('sharedBackdropSurfaces', _data.shared.length));
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }
}

class _PrismGroupHostScope extends InheritedWidget {
  const new({required this.data, required super.child});
  final PrismGroupData data;
  @override
  bool updateShouldNotify(_PrismGroupHostScope oldWidget) =>
      data != oldWidget.data;
}

@internal
class PrismGroupMembers extends StatelessWidget {
  const new({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final host = context
        .dependOnInheritedWidgetOfExactType<_PrismGroupHostScope>();
    if (host == null) return child;
    return PrismGroupScope(data: host.data, child: child);
  }
}

@internal
class PrismGroupScope extends InheritedWidget {
  const new({super.key, required this.data, required super.child});
  final PrismGroupData data;
  static PrismGroupData? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrismGroupScope>()?.data;
  @override
  bool updateShouldNotify(PrismGroupScope oldWidget) => data != oldWidget.data;
}

class _PrismGroupRenderWidget extends SingleChildRenderObjectWidget {
  const new({required this.data, required super.child});
  final PrismGroupData data;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPrismGroup(data);
}

class _RenderPrismGroup extends RenderProxyBox {
  new(this.data);
  final PrismGroupData data;
  final _layer = LayerHandle<PrismGroupLayer>();
  @override
  bool get alwaysNeedsCompositing => true;
  @override
  void paint(PaintingContext context, Offset offset) {
    final layer = (_layer.layer ??= PrismGroupLayer(data, this))
      ..offset = offset;
    context.pushLayer(layer, super.paint, offset);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

@internal
class PrismGroupLayer extends ContainerLayer {
  new(this.data, this.renderBox);
  final PrismGroupData data;
  final RenderBox renderBox;
  Offset offset = Offset.zero;
  ui.Picture? _shadows;
  List<Object> _signature = [];
  void _prepareShadows() {
    final signature = <Object>[offset];
    final transforms = <RenderPrismSurface, Matrix4>{};
    for (final member in data.prepared.keys) {
      final matrix = member.getTransformTo(renderBox);
      transforms[member] = matrix;
      signature.addAll([
        member.shape,
        member.size,
        member.recipe.shadowStrength,
        member.recipe.usesNativeControlShadow,
        member.hdrShadow,
        ...matrix.storage,
      ]);
    }
    if (listEquals(_signature, signature)) return;
    _signature = signature;
    _shadows?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(offset.dx, offset.dy);
    for (final entry in transforms.entries) {
      canvas
        ..save()
        ..transform(entry.value.storage);
      PrismExteriorShadow(
        entry.key.shape,
        strength: entry.key.recipe.shadowStrength,
        nativeControl: entry.key.recipe.usesNativeControlShadow,
        hdrSurface: entry.key.hdrShadow,
      ).paint(canvas, entry.key.size);
      canvas.restore();
    }
    _shadows = recorder.endRecording();
  }

  @override
  void dispose() {
    _shadows?.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsAddToScene => true;
  @override
  void addToScene(ui.SceneBuilder builder) {
    data.prepare(this);
    _prepareShadows();
    if (_shadows != null) builder.addPicture(Offset.zero, _shadows!);
    addChildrenToScene(builder);
  }
}

@internal
class PrismBatch {
  new() : shader = PrismShaderCache.batchProgram!.fragmentShader() {
    shader.setImageSampler(
      0,
      PrismShaderCache.linearSampler!,
      filterQuality: ui.FilterQuality.low,
    );
  }
  final BackdropKey key = BackdropKey();
  final ui.FragmentShader shader;
  late ui.ImageFilter filter;
  final _filterCache = PrismFilterCache();
}

class _PrismGroupGeometry {
  new({
    required this.transform,
    required this.bounds,
    required this.painted,
    required this.sampled,
    required this.footprint,
    required this.aligned,
  });
  factory measure(RenderPrismSurface member) {
    final transform = member.glassTransform();
    final rect = member.shape.rect(member.size);
    final globalRect = MatrixUtils.transformRect(transform, rect);
    final aligned = _pixelAlignedRect(globalRect, member.pixelRatio);
    final bounds = MatrixUtils.transformRect(transform, rect.inflate(2));
    final painted = MatrixUtils.transformRect(transform, rect.inflate(18));

    final displacement = math.min(
      member.style.refraction,
      math.min(rect.width, rect.height) * .55,
    );
    final spread = member.style.dispersion * (2 + displacement * .12);
    final reach = member.style.reflection > .001
        ? math.max(
            member.style.reflectionReach,
            1 + member.style.reflectionReach / 3,
          )
        : 0.0;
    final margin =
        math.max(displacement * .5 + spread, reach) +
        member.frostReach * 3 +
        20;

    final outside =
        math.max(
          member.style.reflection > .001 ? member.style.reflectionReach : 0,
          spread + 8 / member.pixelRatio,
        ) +
        member.frostReach * 3 +
        1;
    final sampled = MatrixUtils.transformRect(transform, rect.inflate(outside));
    final footprint = MatrixUtils.transformRect(
      transform,
      rect.inflate(margin),
    ).inflate(8 / member.pixelRatio);
    return _PrismGroupGeometry(
      transform: transform,
      bounds: bounds,
      painted: painted,
      sampled: sampled,
      footprint: footprint,
      aligned: aligned,
    );
  }

  final Matrix4 transform;
  final Rect bounds;
  final Rect painted;
  final Rect sampled;
  final Rect footprint;
  final bool aligned;

  bool isNear(_PrismGroupGeometry other) =>
      footprint.overlaps(other.bounds) || other.footprint.overlaps(bounds);

  bool conflictsWith(_PrismGroupGeometry other) =>
      sampled.overlaps(other.painted) || other.sampled.overlaps(painted);

  bool get hasUnitScale {
    final m = transform.storage;
    return m[0] == 1 &&
        m[5] == 1 &&
        m[1] == 0 &&
        m[4] == 0 &&
        m[3] == 0 &&
        m[7] == 0 &&
        m[15] == 1;
  }
}

@internal
class PrismGroupData {
  final members = <RenderPrismSurface>{};
  final prepared = <RenderPrismSurface, PrismBatch>{};

  final shared = <RenderPrismSurface>{};
  final sharedKey = BackdropKey();

  final frostKey = BackdropKey();
  final _batches = <PrismBatch>[];
  bool _disposed = false;

  final _clips = <RenderObject, List<Path>>{};

  RenderPrismSurface? hoistHost;
  ui.Picture? _sharedShadows;
  List<Object> _sharedSignature = [];

  void hoist(ui.SceneBuilder builder, RenderPrismSurface host, Offset offset) {
    final hostInverse = Matrix4.inverted(host.getTransformTo(null));
    final toHost = Matrix4.translationValues(offset.dx, offset.dy, 0)
      ..multiply(hostInverse);
    final transforms = <RenderPrismSurface, Matrix4>{};
    final clips = <RenderObject, List<Path>>{};
    final signature = <Object>[offset, host];
    for (final member in shared) {
      final matrix = toHost.clone()..multiply(member.glassTransform());
      transforms[member] = matrix;
      clips[member] = [
        for (final clip in _clips[member] ?? const <Path>[])
          clip.transform(toHost.storage),
      ];
      signature.addAll([
        member,
        member.shape,
        member.size,
        member.recipe.shadowStrength,
        member.recipe.usesNativeControlShadow,
        member.hdrShadow,
        ...matrix.storage,
        for (final clip in clips[member]!) clip.getBounds(),
      ]);
    }
    if (!listEquals(_sharedSignature, signature)) {
      _sharedSignature = signature;
      _sharedShadows?.dispose();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final entry in transforms.entries) {
        canvas.save();
        clips[entry.key]!.forEach(canvas.clipPath);
        canvas.transform(entry.value.storage);
        PrismExteriorShadow(
          entry.key.shape,
          strength: entry.key.recipe.shadowStrength,
          nativeControl: entry.key.recipe.usesNativeControlShadow,
          hdrSurface: entry.key.hdrShadow,
        ).paint(canvas, entry.key.size);
        canvas.restore();
      }
      _sharedShadows = recorder.endRecording();
    }
    builder.addPicture(Offset.zero, _sharedShadows!);
    var joined = false;
    for (final entry in transforms.entries) {
      final member = entry.key;
      final frost = member.frostLayer;
      final blur = member.blurPass;
      final sigma = member.fillSigma;
      if (frost == null || (blur == null && sigma == null)) continue;
      final contour = member.shape
          .path(member.size)
          .transform(entry.value.storage);
      final memberClips = clips[member]!..forEach(builder.pushClipPath);
      builder.pushClipPath(contour);
      if (blur != null) {
        frost.configureBlur(blur, frostKey);
        frost.blur.addToScene(builder);
      }
      if (sigma != null) {
        frost.configureFill(
          sigma,
          PrismFillShare.keyFor(member, host.shadowLayer!, sigma, join: joined),
        );
        joined = true;
        frost.addFill(builder, contour.getBounds());
      }
      builder.pop();
      for (final _ in memberClips) {
        builder.pop();
      }
    }
  }

  static List<Path>? _clipsToGroup(
    Layer? layer,
    Layer groupLayer,
    double pixelRatio,
  ) {
    final clips = <Path>[];
    for (var ancestor = layer; ancestor != groupLayer;) {
      if (ancestor == null) return null;
      Path? path;
      switch (ancestor) {
        case ClipRectLayer(:final clipRect?, :final clipBehavior)
            when clipBehavior != Clip.antiAliasWithSaveLayer:
          path = Path()..addRect(clipRect);
        case ClipRRectLayer(:final clipRRect?, :final clipBehavior)
            when clipBehavior != Clip.antiAliasWithSaveLayer:
          path = Path()..addRRect(clipRRect);
        case ClipRSuperellipseLayer(
              :final clipRSuperellipse?,
              :final clipBehavior,
            )
            when clipBehavior != Clip.antiAliasWithSaveLayer:
          path = Path()..addRSuperellipse(clipRSuperellipse);
        case ClipPathLayer(:final clipPath?, :final clipBehavior)
            when clipBehavior != Clip.antiAliasWithSaveLayer:
          path = clipPath;
        case OffsetLayer() || TransformLayer() || AnnotatedRegionLayer():
          break;
        case _ when ancestor.runtimeType == ContainerLayer:
          break;
        default:
          return null;
      }
      if (path != null) {
        final toRoot = Matrix4.diagonal3Values(
          1 / pixelRatio,
          1 / pixelRatio,
          1,
        )..multiply(compositedTransform(ancestor));
        clips.add(path.transform(toRoot.storage));
      }
      ancestor = ancestor.parent;
    }
    return clips;
  }

  void prepare(PrismGroupLayer groupLayer) {
    prepared.clear();
    shared.clear();
    _clips.clear();
    hoistHost = null;
    if (_disposed) return;
    final canBatch = PrismShaderCache.batchProgram != null;
    final surfaces = members
        .where(
          (m) =>
              m.attached &&
              m.hasSize &&
              !m.size.isEmpty &&
              m.getTransformTo(null).determinant() != 0,
        )
        .toList();
    final geometry = {
      for (final member in surfaces)
        member: _PrismGroupGeometry.measure(member),
    };
    final groups = <double, List<RenderPrismSurface>>{};
    for (final member in surfaces) {
      final measured = geometry[member]!;
      final near = surfaces.any(
        (other) => other != member && measured.isNear(geometry[other]!),
      );

      var ancestor = member.clipLayer?.parent;
      var independentLayers = true;
      while (ancestor != null && ancestor != groupLayer) {
        if (ancestor is! OffsetLayer &&
            ancestor is! TransformLayer &&
            ancestor.runtimeType != ContainerLayer) {
          independentLayers = false;
          break;
        }
        ancestor = ancestor.parent;
      }
      final sameLayers = independentLayers && ancestor == groupLayer;
      final clips = sameLayers
          ? const <Path>[]
          : _clipsToGroup(
              member.clipLayer?.parent,
              groupLayer,
              member.pixelRatio,
            );
      final excluded = surfaces.any(
        (other) => other != member && measured.conflictsWith(geometry[other]!),
      );
      if (clips != null && !excluded) {
        shared.add(member);
        _clips[member] = clips;
      }

      if (!canBatch ||
          near ||
          !member.plainFrost ||
          member.shape.isSmooth ||
          member.recipe.kind != 1 ||
          member.recipe.role == PrismRole.tabBar) {
        continue;
      }

      if (!sameLayers ||
          !measured.aligned ||
          member.pixelRatio < 1 ||
          !measured.hasUnitScale) {
        continue;
      }
      groups.putIfAbsent(member.style.frost, () => []).add(member);
    }
    _prepareBatches(groups, geometry);
    shared.removeAll(prepared.keys);
    if (shared.length < 2) shared.clear();
  }

  void _prepareBatches(
    Map<double, List<RenderPrismSurface>> groups,
    Map<RenderPrismSurface, _PrismGroupGeometry> geometry,
  ) {
    var used = 0;
    for (final group in groups.values) {
      for (var start = 0; start < group.length; start += batchMaxLenses) {
        final chunk = group.skip(start).take(batchMaxLenses).toList();
        if (chunk.length < 2) continue;
        if (used == _batches.length) _batches.add(PrismBatch());
        final batch = _batches[used++];
        final values = <double>[
          0,
          0,
          chunk.length.toDouble(),
          PrismDisplay.headroom.value,
        ];
        for (final member in chunk) {
          final rect = geometry[member]!.bounds;
          final dpr = member.pixelRatio;
          final uniforms = member.uniforms(geometry[member]!.transform);
          values.addAll(batchLensUniforms(rect, dpr, uniforms));
          prepared[member] = batch;
        }
        batch.filter = batch._filterCache.resolve(
          batch.shader,
          values,
          chunk.first.style.frost,
        );
      }
    }
    while (_batches.length > used) {
      _batches.removeLast().shader.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    prepared.clear();
    shared.clear();
    _clips.clear();
    members.clear();
    _sharedShadows?.dispose();
    _sharedShadows = null;
    for (final batch in _batches) {
      batch.shader.dispose();
    }
    _batches.clear();
  }
}

bool _pixelAlignedRect(Rect rect, double pixelRatio) {
  for (final value in [rect.left, rect.top, rect.right, rect.bottom]) {
    final physical = value * pixelRatio;
    if (!physical.isFinite ||
        (physical - physical.roundToDouble()).abs() >= 1e-6) {
      return false;
    }
  }
  return true;
}

/// Packs bounds and surface values for one batched lens.
@visibleForTesting
List<double> batchLensUniforms(Rect bounds, double dpr, List<double> scalar) =>
    [
      bounds.left * dpr,
      bounds.top * dpr,
      bounds.right * dpr,
      bounds.bottom * dpr,
      ...scalar.skip(2).take(44),
      ...scalar.skip(46 + superellipseUniformCount).take(20),
    ];

/// Number of scalar uniforms reserved for each batched lens.
@visibleForTesting
const int batchLensStride = 68;

/// Maximum number of lenses supported by one shader batch.
@visibleForTesting
const int batchMaxLenses = 15;
