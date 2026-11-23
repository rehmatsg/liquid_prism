import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

@internal
Matrix4 compositedTransform(Layer layer) {
  final path = <Layer>[layer];
  for (Layer? ancestor = layer.parent; ancestor != null;) {
    path.add(ancestor);
    ancestor = ancestor.parent;
  }
  final transform = Matrix4.identity();
  for (var index = path.length - 1; index > 0; index--) {
    (path[index] as ContainerLayer).applyTransform(path[index - 1], transform);
  }
  return transform;
}

@internal
Path? compositedAncestorClip(Layer layer) {
  final toLocal = Matrix4.tryInvert(compositedTransform(layer));
  if (toLocal == null) return Path();
  Path? result;
  var shaped = false;
  for (
    Layer? ancestor = layer.parent;
    ancestor != null;
    ancestor = ancestor.parent
  ) {
    final path = switch (ancestor) {
      ClipRectLayer(:final clipRect?) => Path()..addRect(clipRect),
      ClipRRectLayer(:final clipRRect?) => Path()..addRRect(clipRRect),
      ClipRSuperellipseLayer(:final clipRSuperellipse?) =>
        Path()..addRSuperellipse(clipRSuperellipse),
      ClipPathLayer(:final clipPath?) => clipPath,
      _ => null,
    };
    if (path != null) {
      shaped |= ancestor is! ClipRectLayer;
      final transform = toLocal.clone()
        ..multiply(compositedTransform(ancestor));
      final local = path.transform(transform.storage);
      result = result == null
          ? local
          : Path.combine(PathOperation.intersect, result, local);
    }
    final isolated = switch (ancestor) {
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
    if (isolated) break;
  }
  return shaped ? result : null;
}

@internal
bool transformedAfterRaster({
  required Matrix4 composited,
  required Offset paintOffset,
  required Matrix4 global,
  required double pixelRatio,
  required Rect bounds,
  double tolerance = 0.5,
}) {
  for (final corner in [
    bounds.topLeft,
    bounds.topRight,
    bounds.bottomLeft,
    bounds.bottomRight,
  ]) {
    final raster = MatrixUtils.transformPoint(composited, corner + paintOffset);
    final laidOut = MatrixUtils.transformPoint(global, corner) * pixelRatio;
    if ((raster - laidOut).distance > tolerance) return true;
  }
  return false;
}

/// Shrinks [rect] to the whole device pixels it covers under [toDevice].
@internal
Rect? pixelAlignedInterior(Rect rect, Matrix4 toDevice) {
  final m = toDevice.storage;
  if (m[1] != 0 || m[4] != 0 || m[3] != 0 || m[7] != 0 || m[15] != 1) {
    return null;
  }
  final sx = m[0];
  final sy = m[5];
  if (sx <= 0 || sy <= 0) return null;
  const slack = 1e-3;
  final left = (rect.left * sx + m[12] - slack).ceilToDouble();
  final top = (rect.top * sy + m[13] - slack).ceilToDouble();
  final right = (rect.right * sx + m[12] + slack).floorToDouble();
  final bottom = (rect.bottom * sy + m[13] + slack).floorToDouble();
  if (right <= left || bottom <= top) return null;
  return Rect.fromLTRB(
    (left - m[12]) / sx,
    (top - m[13]) / sy,
    (right - m[12]) / sx,
    (bottom - m[13]) / sy,
  );
}

/// Moves a vertical split at [x] onto the nearest device pixel boundary.
@internal
double pixelAlignedSplit(double x, Matrix4 toDevice) {
  final m = toDevice.storage;
  final sx = m[0];
  if (m[1] != 0 || m[4] != 0 || sx <= 0) return x;
  return ((x * sx + m[12]).roundToDouble() - m[12]) / sx;
}
