import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism_example/main.dart';
import 'package:liquid_prism_example/showcase/model.dart';
import 'package:liquid_prism_example/showcase/pages.dart' show ExploreHero;

void main() {
  testWidgets(
    'iOS navigation matches the native screen margin across bottom insets',
    (tester) async {
      phone(tester);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      await tester.pumpWidget(const LiquidPrismExample());
      final navigation = find.byKey(const ValueKey('showcase-navigation'));
      expect(tester.getBottomRight(navigation).dy, 874 - 21);

      tester.view.padding = const FakeViewPadding(top: 62);
      tester.view.viewPadding = const FakeViewPadding(top: 62);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(navigation).dy, 874 - 21);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(navigation, findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(navigation).dy, 874 - 21);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('iPhone Duo places navigation in the sensor-bar rail', (
    tester,
  ) async {
    phone(tester, size: const Size(466, 678));
    tester.view.padding = const FakeViewPadding(right: 84, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(right: 84, bottom: 34);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(const LiquidPrismExample());
    final navigation = tester.getRect(
      find.byKey(const ValueKey('showcase-navigation')),
    );
    expect(navigation.left, 466 - 84 + 12);
    expect(navigation.width, 48);
    // Content keeps the full window height and stays clear of the rail.
    final title = tester.getRect(
      find.byKey(const ValueKey('page-title:Explore')),
    );
    expect(title.right, lessThanOrEqualTo(466 - 84));
    await tab(tester, 'Library');
    expect(find.text('9 components'), findsOneWidget);
    await press(tester, 'Explore Tab Bars');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bent iPhone Duo reflows sections off the fold', (
    tester,
  ) async {
    phone(tester, size: const Size(951, 669));
    tester.view
      ..padding = const FakeViewPadding(right: 84, bottom: 34)
      ..viewPadding = const FakeViewPadding(right: 84, bottom: 34)
      ..displayFeatures = const [
        DisplayFeature(
          bounds: Rect.fromLTWH(455.5, 0, 40, 669),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ];
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const LiquidPrismExample());
    final hero = tester.getRect(find.byType(ExploreHero));
    final section = tester.getRect(find.text('Try it'));
    expect(hero.right, lessThanOrEqualTo(455.5));
    expect(section.left, greaterThanOrEqualTo(495.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'library finds all components, filters, and restores after a route',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(const LiquidPrismExample());
      expect(find.byKey(const ValueKey('page-title:Explore')), findsOneWidget);
      await tab(tester, 'Library');
      expect(find.text('9 components'), findsOneWidget);
      for (final info in components) {
        await press(tester, 'Explore ${info.title}');
        expect(
          find.text('LIVE PREVIEW'),
          info.kind == ComponentKind.surfaces ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('page-title:${info.title}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await press(tester, 'Back to showcase');
      }
      await tester.ensureVisible(find.byType(CupertinoTextField));
      await tester.enterText(find.byType(CupertinoTextField), 'slider');
      await tester.pumpAndSettle();
      expect(find.text('1 component'), findsOneWidget);
      expect(find.text('Buttons'), findsNothing);
      await press(tester, 'Explore Sliders');
      await press(tester, 'Back to showcase');
      expect(find.text('1 component'), findsOneWidget);
      await tester.enterText(
        find.byType(CupertinoTextField),
        'not-a-component',
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing here just yet.'), findsOneWidget);
      await press(tester, 'Reset library search');
      expect(find.text('9 components'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'studio settings propagate to routes and reset without losing interactions',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(const LiquidPrismExample());
      await tab(tester, 'Studio');
      await input(tester, 'Dark appearance');
      await input(tester, 'Clear material');
      await press(tester, 'Use purple tint');
      await tab(tester, 'Library');
      await press(tester, 'Explore Buttons');
      final button = find.byWidgetPredicate(
        (w) => w is LiquidPrismButton && w.label == 'Add a prominent tap',
      );
      final context = tester.element(button);
      expect(LiquidPrismTheme.brightnessOf(context), Brightness.dark);
      expect(LiquidPrismTheme.tintOf(context), GlassColors.dark.purple);
      expect(LiquidPrismTheme.of(context).glass, Glass.clear);
      await press(tester, 'Add a prominent tap');
      await press(tester, 'Favorite');
      expect(find.text('1 tap'), findsOneWidget);
      await press(tester, 'Back to showcase');
      await tab(tester, 'Studio');
      await press(tester, 'Restore defaults');
      await tab(tester, 'Library');
      await press(tester, 'Explore Buttons');
      expect(find.text('1 tap'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.heart_fill), findsOneWidget);
      expect(
        LiquidPrismTheme.tintOf(tester.element(button)),
        GlassColors.light.blue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets('showcase and every preview fit $size with larger text', (
      tester,
    ) async {
      phone(tester, size: size);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const LiquidPrismExample());
      expect(tester.takeException(), isNull);
      await tab(tester, 'Studio');
      expect(tester.takeException(), isNull);
      await tab(tester, 'Library');
      for (final info in components) {
        await press(tester, 'Explore ${info.title}');
        expect(tester.takeException(), isNull, reason: info.title);
        await press(tester, 'Back to showcase');
      }
      tester.view.physicalSize = const Size(600, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

void phone(WidgetTester tester, {Size size = const Size(402, 874)}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Finder action(String label) => find.byWidgetPredicate(
  (w) => w is LiquidPrismPressable && w.label == label,
);
Future<void> press(WidgetTester tester, String label) async {
  final target = action(label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> input(WidgetTester tester, String label) async {
  final target = find.byWidgetPredicate(
    (w) => w is LiquidPrismSwitch && w.label == label,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('showcase-navigation')),
      matching: find.bySemanticsLabel(label),
    ),
  );
  await tester.pumpAndSettle();
}
