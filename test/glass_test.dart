import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  testWidgets('fallback keeps lens bounds and child while updating its tint', (
    tester,
  ) async {
    expect(LiquidPrism.isShaderSupported, isFalse);
    final imageKey = GlobalKey();
    const lensKey = ValueKey('lens');
    Widget harness(ui.Color tint) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: imageKey,
            child: SizedBox(
              width: 100,
              height: 100,
              child: LiquidPrism(
                key: lensKey,
                optics: LiquidPrismStyle.clear.copyWith(
                  tint: tint,
                  cornerRadius: 20,
                ),
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: Text('Lens', style: TextStyle(fontSize: 10)),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Future<List<int>> centerPixel() async {
      final boundary =
          imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = (await image.toByteData())!;
        final bytes = data.buffer.asUint8List();
        final offset = (50 * image.width + 50) * 4;
        final result = bytes.sublist(offset, offset + 4);
        image.dispose();
        return result;
      }))!;
    }

    await tester.pumpWidget(harness(const ui.Color(0xFFFF0000)));
    expect(tester.getSize(find.byKey(lensKey)), const ui.Size(100, 100));
    expect(find.text('Lens'), findsOneWidget);
    expect(await centerPixel(), [255, 0, 0, 255]);

    await tester.pumpWidget(harness(const ui.Color(0xFF00FF00)));
    expect(await centerPixel(), [0, 255, 0, 255]);
    expect(find.text('Lens'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await LiquidPrism.preload();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
