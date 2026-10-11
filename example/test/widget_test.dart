import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism_example/main.dart';

void main() {
  testWidgets(
    'button actions and favorite survive appearance and material changes',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(const LiquidPrismExample());
      await _press(tester, 'Add a tap');
      await _press(tester, 'Add a prominent tap');
      expect(find.text('2 taps'), findsOneWidget);
      await _press(tester, 'Favorite');
      expect(_favorite(tester), ui.Tristate.isTrue);
      expect(find.byIcon(CupertinoIcons.heart_fill), findsOneWidget);
      await _press(tester, 'Toggle appearance');
      expect(find.text('Light'), findsOneWidget);
      expect(
        CupertinoTheme.of(tester.element(_button('Toggle appearance')))
            .brightness,
        Brightness.light,
      );
      await _press(tester, 'Toggle glass material');
      expect(find.text('Clear'), findsOneWidget);
      expect(
        LiquidPrismTheme.of(tester.element(_button('Toggle glass material')))
            .glass,
        Glass.clear,
      );
      expect(find.text('2 taps'), findsOneWidget);
      expect(_favorite(tester), ui.Tristate.isTrue);
      await _press(tester, 'Add a tap');
      expect(find.text('3 taps'), findsOneWidget);
      await _press(tester, 'Favorite');
      expect(_favorite(tester), ui.Tristate.isFalse);
      expect(find.byIcon(CupertinoIcons.heart), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tabs commit visible content on tap and drag with accessible hidden labels',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(const LiquidPrismExample());
      expect(_title('Explore'), findsOneWidget);
      await tester.tap(_tab('Saved'));
      await tester.pumpAndSettle();
      expect(_title('Saved'), findsOneWidget);
      _expectSelection(tester, 'Saved');
      final held = await tester.startGesture(tester.getCenter(_tab('Saved')));
      await tester.pump(const Duration(milliseconds: 120));
      await held.moveTo(tester.getCenter(_tab('Explore')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        _title('Saved'),
        findsOneWidget,
        reason: 'Dragging only previews until the consumer accepts on release',
      );
      await held.up();
      await tester.pumpAndSettle();
      expect(_title('Explore'), findsOneWidget);
      _expectSelection(tester, 'Explore');
      await _press(tester, 'Toggle tab labels');
      for (final label in ['Explore', 'Saved', 'Settings']) {
        expect(
          find.descendant(
            of: find.byType(LiquidPrismTabBar),
            matching: find.text(label),
          ),
          findsNothing,
        );
        expect(tester.getSemantics(_tab(label)).label, label);
      }
      tester.semantics.tap(find.semantics.byLabel('Settings'));
      await tester.pumpAndSettle();
      expect(_title('Settings'), findsOneWidget);
      _expectSelection(tester, 'Settings');
      await _press(tester, 'Toggle tab labels');
      expect(
        find.descendant(
          of: find.byType(LiquidPrismTabBar),
          matching: find.text('Settings'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native tint picker updates controls and resolves the new appearance',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(const LiquidPrismExample());
      await _press(tester, 'Use purple tint');
      final selected = tester.widget<LiquidPrismButton>(
        _button('Use purple tint'),
      );
      expect(selected.selected, isTrue);
      expect(selected.glass?.tintColor, GlassColors.dark.purple);
      var context = tester.element(_button('Add a prominent tap'));
      expect(LiquidPrismTheme.tintOf(context), GlassColors.dark.purple);
      await _press(tester, 'Toggle appearance');
      context = tester.element(_button('Add a prominent tap'));
      expect(LiquidPrismTheme.tintOf(context), GlassColors.light.purple);
      expect(
        tester
            .widget<LiquidPrismButton>(_button('Use purple tint'))
            .glass
            ?.tintColor,
        GlassColors.light.purple,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact large-text layout keeps the demo controls reachable', (
    tester,
  ) async {
    _phone(tester, size: const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const LiquidPrismExample());
    expect(tester.takeException(), isNull);
    await _press(tester, 'Add a prominent tap');
    await tester.ensureVisible(find.text('1 taps'));
    await tester.pumpAndSettle();
    expect(find.text('1 taps').hitTestable(), findsOneWidget);
    await _press(tester, 'Toggle appearance');
    await _press(tester, 'Toggle glass material');
    await _press(tester, 'Toggle tab labels');
    await tester.tap(_tab('Saved'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_title('Saved'));
    await tester.pumpAndSettle();
    expect(_title('Saved').hitTestable(), findsOneWidget);
    _expectSelection(tester, 'Saved');
    await _press(tester, 'Open another page');
    expect(find.text('Another page'), findsOneWidget);
    await tester.ensureVisible(find.text('Another page'));
    await tester.pumpAndSettle();
    expect(find.text('Another page').hitTestable(), findsOneWidget);
    await _press(tester, 'Back to gallery');
    expect(find.text('Another page'), findsNothing);
    _expectSelection(tester, 'Saved');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pushed routes inherit settings and cancel or complete swipe-back without losing home state',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(const LiquidPrismExample());
      await _press(tester, 'Add a tap');
      await _press(tester, 'Favorite');
      await tester.tap(_tab('Saved'));
      await tester.pumpAndSettle();

      Future<double> openDetail() async {
        final open = _button('Open another page');
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        final offset = _scrollOffset(tester);
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(find.text('Another page'), findsOneWidget);
        expect(open, findsNothing);
        return offset;
      }

      void expectDetailTheme(Brightness brightness, Glass glass) {
        final context = tester.element(_button('Back to gallery'));
        final theme = LiquidPrismTheme.of(context);
        expect(theme.brightness, brightness);
        expect(CupertinoTheme.of(context).brightness, brightness);
        expect(theme.glass, glass);
      }

      Future<void> expectHome(double scrollOffset) async {
        expect(find.text('Another page'), findsNothing);
        expect(_scrollOffset(tester), closeTo(scrollOffset, .01));
        expect(find.text('1 taps'), findsOneWidget);
        expect(_title('Saved'), findsOneWidget);
        _expectSelection(tester, 'Saved');
        await tester.ensureVisible(_button('Favorite'));
        await tester.pumpAndSettle();
        expect(_favorite(tester), ui.Tristate.isTrue);
      }

      final firstOffset = await openDetail();
      expectDetailTheme(Brightness.dark, Glass.regular);
      await _press(tester, 'Back to gallery');
      await expectHome(firstOffset);

      await _press(tester, 'Toggle appearance');
      await _press(tester, 'Toggle glass material');
      final secondOffset = await openDetail();
      expectDetailTheme(Brightness.light, Glass.clear);
      final restingTitle = tester.getTopLeft(find.text('Another page'));
      final cancelled = await tester.startGesture(const Offset(1, 300));
      await cancelled.moveTo(
        const Offset(41, 300),
        timeStamp: const Duration(milliseconds: 120),
      );
      await tester.pump();
      await cancelled.moveTo(
        const Offset(81, 300),
        timeStamp: const Duration(milliseconds: 240),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('Another page')).dx,
        greaterThan(restingTitle.dx + 10),
        reason: 'The edge gesture must visibly control the route before cancellation',
      );
      // A stationary sample removes fling velocity; distance controls release.
      await cancelled.moveTo(
        const Offset(81, 300),
        timeStamp: const Duration(milliseconds: 600),
      );
      await cancelled.up(timeStamp: const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.text('Another page'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Another page')), restingTitle);
      expectDetailTheme(Brightness.light, Glass.clear);

      final completed = await tester.startGesture(const Offset(1, 300));
      await completed.moveTo(
        const Offset(151, 300),
        timeStamp: const Duration(milliseconds: 200),
      );
      await tester.pump();
      await completed.moveTo(
        const Offset(331, 300),
        timeStamp: const Duration(milliseconds: 400),
      );
      await tester.pump();
      await completed.moveTo(
        const Offset(331, 300),
        timeStamp: const Duration(milliseconds: 650),
      );
      await completed.up(timeStamp: const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await expectHome(secondOffset);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

double _scrollOffset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .pixels;

void _phone(WidgetTester tester, {Size size = const Size(402, 874)}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is LiquidPrismButton && widget.label == label,
);

Finder _tab(String label) => find.descendant(
  of: find.byType(LiquidPrismTabBar),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  ),
);

Finder _title(String label) => find.descendant(
  of: find.byType(SingleChildScrollView),
  matching: find.text(label),
);

Future<void> _press(WidgetTester tester, String label) async {
  final control = _button(label);
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

ui.Tristate _favorite(WidgetTester tester) =>
    tester.getSemantics(_button('Favorite')).flagsCollection.isSelected;

void _expectSelection(WidgetTester tester, String selected) {
  for (final label in ['Explore', 'Saved', 'Settings']) {
    final node = tester.getSemantics(_tab(label));
    expect(node.label, label);
    expect(node.flagsCollection.isButton, isTrue);
    expect(
      node.flagsCollection.isSelected,
      label == selected ? ui.Tristate.isTrue : ui.Tristate.isFalse,
    );
  }
}
