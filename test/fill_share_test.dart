import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/src/glass.dart';

void main() {
  // Surfaces store their blur fill under one backdrop key, captured once,
  // only while nothing else reaches the scene between them.
  ContainerLayer tree(List<Layer> children) {
    final root = ContainerLayer();
    children.forEach(root.append);
    return root;
  }

  test('surfaces share a backdrop across layers that draw nothing', () {
    final a = ContainerLayer();
    final b = ContainerLayer();
    tree([
      a,
      ClipRectLayer(clipRect: Rect.largest)..append(ContainerLayer()),
      OffsetLayer()..append(TransformLayer()..append(b)),
    ]);
    expect(sameBackdropBetween(a, b), isTrue);
  });

  test('content between two surfaces ends the shared backdrop', () {
    final a = ContainerLayer();
    final b = ContainerLayer();
    tree([a, OffsetLayer()..append(PictureLayer(Rect.zero)), b]);
    expect(sameBackdropBetween(a, b), isFalse);
  });

  test('a saveLayer around either surface ends the shared backdrop', () {
    var a = ContainerLayer();
    var b = ContainerLayer();
    tree([OpacityLayer(alpha: 128)..append(a), b]);
    expect(sameBackdropBetween(a, b), isFalse);

    a = ContainerLayer();
    b = ContainerLayer();
    tree([a, OpacityLayer(alpha: 128)..append(b)]);
    expect(sameBackdropBetween(a, b), isFalse);

    a = ContainerLayer();
    b = ContainerLayer();
    tree([
      a,
      ClipRectLayer(
        clipRect: Rect.largest,
        clipBehavior: Clip.antiAliasWithSaveLayer,
      )..append(b),
    ]);
    expect(sameBackdropBetween(a, b), isFalse);
  });

  test('a surface that does not follow the last one starts a new scene', () {
    final a = ContainerLayer();
    final b = ContainerLayer();
    tree([a, b]);
    expect(sameBackdropBetween(b, a), isNull);
    expect(sameBackdropBetween(a, a), isNull);
  });
}
