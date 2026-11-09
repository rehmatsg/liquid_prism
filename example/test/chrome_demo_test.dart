import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism_example/chrome_demo.dart';
import 'package:liquid_prism_example/showcase/sheet_route.dart';

void main() {
  testWidgets(
    'showcase sheets keep raster and layout aligned through stacking and dismissal',
    (tester) async {
      tester.view
        ..devicePixelRatio = 3
        ..physicalSize = const Size(1206, 2622)
        ..padding = const FakeViewPadding(top: 186, bottom: 102)
        ..viewPadding = const FakeViewPadding(top: 186, bottom: 102);
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      const home = Key('covered home');
      const sheets = [Key('first sheet'), Key('second sheet')];
      final routes = <ShowcaseSheetRoute>[];
      final dismissed = <int>[];
      void pushSheet(int number) {
        final route = ShowcaseSheetRoute(
          scrollableBuilder: (context, controller) => RepaintBoundary(
            key: sheets[number - 1],
            child: CupertinoPageScaffold(
              child: ListView(
                controller: controller,
                children: [
                  if (number == 1)
                    CupertinoButton(
                      onPressed: () => pushSheet(2),
                      child: const Text('Stack sheet'),
                    ),
                  Text('Sheet $number'),
                  const SizedBox(height: 1600),
                ],
              ),
            ),
          ),
        );
        routes.add(route);
        unawaited(
          navigator.currentState!
              .push(route)
              .then((_) => dismissed.add(number)),
        );
      }

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigator,
          home: RepaintBoundary(
            key: home,
            child: CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () => pushSheet(1),
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      Rect geometry(Key key) =>
          tester.getRect(find.byKey(key, skipOffstage: false));
      void matchesRaster(Key key) {
        final box = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key, skipOffstage: false),
        );
        final layer = box.debugLayer! as OffsetLayer;
        final ancestry = <Layer>[layer];
        for (
          Layer? parent = layer.parent;
          parent != null;
          parent = parent.parent
        ) {
          ancestry.add(parent);
        }
        final composited = Matrix4.identity();
        for (var index = ancestry.length - 1; index > 0; index--) {
          (ancestry[index] as ContainerLayer).applyTransform(
            ancestry[index - 1],
            composited,
          );
        }
        final bounds = Offset.zero & box.size;
        for (final point in [
          bounds.topLeft,
          bounds.topRight,
          bounds.bottomRight,
        ]) {
          final raster = MatrixUtils.transformPoint(
            composited,
            point + layer.offset,
          );
          final layout =
              box.localToGlobal(point) * tester.view.devicePixelRatio;
          expect((raster - layout).distance, lessThan(.01));
        }
      }

      void nativeSheetContour(Key key) {
        final box = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key, skipOffstage: false),
        );
        var contours = 0;
        for (
          Layer? layer = box.debugLayer;
          layer != null;
          layer = layer.parent
        ) {
          if (layer case ClipRSuperellipseLayer(:final clipRSuperellipse?)) {
            if (clipRSuperellipse.tlRadiusX == 0) continue;
            contours++;
            expect(clipRSuperellipse.tlRadiusX, closeTo(12, .01));
            expect(clipRSuperellipse.trRadiusX, closeTo(12, .01));
            expect(clipRSuperellipse.blRadiusX, 0);
            expect(clipRSuperellipse.brRadiusX, 0);
          }
        }
        expect(contours, greaterThan(0));
      }

      final homeRest = geometry(home);
      matchesRaster(home);
      await tester.tap(find.text('Open sheet'));
      await tester.pump();
      await tester.pump(routes.first.transitionDuration ~/ 4);
      expect(geometry(home).width, lessThan(homeRest.width));
      expect(geometry(home).top, greaterThan(homeRest.top));
      matchesRaster(home);
      await tester.pumpAndSettle();
      expect(geometry(home).width, closeTo(homeRest.width * .9165, .01));
      matchesRaster(home);
      final firstRest = geometry(sheets.first);
      nativeSheetContour(sheets.first);

      await tester.tap(find.text('Stack sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(routes.last.animation!.value, greaterThan(0));
      expect(geometry(sheets.first).width, lessThan(firstRest.width));
      nativeSheetContour(sheets.first);
      matchesRaster(sheets.first);
      await tester.pumpAndSettle();
      expect(
        geometry(sheets.first).width,
        closeTo(firstRest.width * .9165, .01),
      );
      nativeSheetContour(sheets.first);
      matchesRaster(sheets.first);

      for (final key in sheets.reversed) {
        final start = geometry(key);
        final gesture = await tester.startGesture(start.center);
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 420));
        await tester.pump();
        expect(geometry(key).top, greaterThan(start.top));
        matchesRaster(key);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(key), findsNothing);
        if (key == sheets.last) {
          expect(dismissed, [2]);
          expect(geometry(sheets.first), firstRest);
          matchesRaster(sheets.first);
        }
      }
      expect(dismissed, [2, 1]);
      expect(geometry(home), homeRest);
      matchesRaster(home);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search demo matches captured resting and keyboard geometry', (
    tester,
  ) async {
    final source = jsonDecode(
      File('../doc/native_chrome_spec.json').readAsStringSync(),
    );
    Rect reference(String profile) {
      final frame =
          source['profiles'][profile]['surfaces'][0]['windowFrame'] as String;
      final values = RegExp(r'-?\d+(?:\.\d+)?')
          .allMatches(frame)
          .map((m) => double.parse(m[0]!))
          .toList();
      return Rect.fromLTWH(values[0], values[1], values[2], values[3]);
    }

    void match(Rect actual, Rect expected) {
      expect(actual.left, closeTo(expected.left, .01));
      expect(actual.top, closeTo(expected.top, .01));
      expect(actual.width, closeTo(expected.width, .01));
      expect(actual.height, closeTo(expected.height, .01));
    }

    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      const CupertinoApp(home: ChromeDemo(standalone: true)),
    );
    await tester.pumpAndSettle();
    final editor = find.byType(CupertinoTextField);
    match(tester.getRect(editor), reference('dark-search-rest'));
    await tester.tap(editor);
    tester.view.viewInsets = const FakeViewPadding(bottom: 1005);
    await tester.pumpAndSettle();
    match(tester.getRect(editor), reference('dark-search-focused'));
    expect(tester.takeException(), isNull);
  });
}
