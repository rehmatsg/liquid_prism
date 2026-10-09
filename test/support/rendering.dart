import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget glassHarness({
  required Widget child,
  required GlobalKey imageKey,
  Brightness platformBrightness = Brightness.dark,
  bool reduceMotion = false,
  Color background = const Color(0xFF666666),
}) => WidgetsApp(
  color: const Color(0xFF666666),
  builder: (context, _) => MediaQuery(
    data: MediaQueryData(
      platformBrightness: platformBrightness,
      disableAnimations: reduceMotion,
    ),
    child: Center(
      child: RepaintBoundary(
        key: imageKey,
        child: SizedBox(
          width: 240,
          height: 160,
          child: ColoredBox(
            color: background,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  ),
);

Future<List<List<int>>> pixelsAt(
  WidgetTester tester,
  GlobalKey imageKey,
  List<Offset> points,
) async {
  final boundary =
      imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final bytes = data.buffer.asUint8List();
    final pixels = [
      for (final point in points)
        bytes.sublist(
          (point.dy.toInt() * image.width + point.dx.toInt()) * 4,
          (point.dy.toInt() * image.width + point.dx.toInt()) * 4 + 4,
        ),
    ];
    image.dispose();
    return pixels;
  }))!;
}

double visibleWidth(WidgetTester tester, Finder finder) =>
    tester.getBottomRight(finder).dx - tester.getTopLeft(finder).dx;
