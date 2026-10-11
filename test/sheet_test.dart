import 'dart:ui' show SemanticsAction;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Widget harness({
  required LiquidPrismSheetBuilder builder,
  bool dismissible = true,
  bool drag = true,
  List<GlassSheetDetent> detents = const [
    GlassSheetDetent.medium,
    GlassSheetDetent.large,
  ],
  ValueChanged<String?>? onResult,
}) => CupertinoApp(
  home: LiquidPrismTheme(
    data: const LiquidPrismThemeData(
      brightness: Brightness.dark,
      tint: Color(0xFFFF9230),
    ),
    child: Builder(
      builder: (context) => Center(
        child: CupertinoButton(
          onPressed: () async {
            final result = await showLiquidPrismSheet<String>(
              context: context,
              builder: builder,
              isDismissible: dismissible,
              enableDrag: drag,
              detents: detents,
            );
            onResult?.call(result);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);
Widget body(BuildContext context, ScrollController scroll) => ListView(
  controller: scroll,
  children: [
    Text('Sheet body ${LiquidPrismTheme.brightnessOf(context).name}'),
    CupertinoButton(
      onPressed: () => Navigator.of(context).pop('Done'),
      child: const Text('Done'),
    ),
    for (var i = 0; i < 30; i++) SizedBox(height: 50, child: Text('Row $i')),
  ],
);

void main() {
  testWidgets(
    'captures theme, matches native settled bounds and returns result',
    (tester) async {
      phone(tester);
      String? result;
      await tester.pumpWidget(
        harness(builder: body, onResult: (value) => result = value),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body dark'), findsOneWidget);
      final lens = find.byType(LiquidPrism).last;
      final rect = tester.getRect(lens);
      expect(rect.left, closeTo(8, .02));
      expect(rect.top, closeTo(415.026534, .02));
      expect(rect.width, closeTo(386, .02));
      expect(rect.bottom, closeTo(866, .02));
      expect(
        LiquidPrismTheme.tintOf(tester.element(find.text('Done'))),
        const Color(0xFFFF9230),
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result, 'Done');
      expect(find.text('Sheet body dark'), findsNothing);
    },
  );
  testWidgets('header resizes to large then medium; body scroll coordinates', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(harness(builder: body));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final handle = find.bySemanticsLabel('Resize sheet');
    await tester.drag(handle, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(LiquidPrism).last).top, closeTo(62, .1));
    await tester.drag(find.text('Row 3'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byType(ListView).last).controller!.offset,
      greaterThan(100),
    );
    tester.semantics.performAction(
      find.semantics.byLabel('Resize sheet'),
      SemanticsAction.decrease,
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(LiquidPrism).last).left, closeTo(8, .1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('dismisses by barrier, Escape and downward drag repeatedly', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(harness(builder: body));
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      if (attempt == 0) {
        await tester.tapAt(const Offset(200, 180));
      }
      if (attempt == 1) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      }
      if (attempt == 2) {
        await tester.drag(
          find.bySemanticsLabel('Resize sheet'),
          const Offset(0, 500),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Sheet body dark'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'non-dismissable single-detent sheet still supports explicit close',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        harness(
          builder: body,
          dismissible: false,
          drag: false,
          detents: const [GlassSheetDetent.large],
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 30));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Sheet body dark'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body dark'), findsNothing);
    },
  );
  testWidgets('keyboard expands and small/resized layouts avoid overflow', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      harness(
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: const [
            CupertinoTextField(placeholder: 'Name'),
            SizedBox(height: 700),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(LiquidPrism).last).top, closeTo(62, .1));
    tester.view.physicalSize = const Size(1800, 1080);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
