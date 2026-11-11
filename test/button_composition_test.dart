import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'support/rendering.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    TextDirection direction = TextDirection.ltr,
  }) => tester.pumpWidget(
    glassHarness(
      imageKey: GlobalKey(),
      child: Directionality(textDirection: direction, child: child),
    ),
  );

  testWidgets('text and custom content share one named activation target', (
    tester,
  ) async {
    var taps = 0;
    await show(
      tester,
      LiquidPrismButton(label: 'Save', onPressed: () => taps++),
    );
    expect(find.text('Save'), findsOneWidget);
    expect(find.bySemanticsLabel('Save'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    await show(
      tester,
      LiquidPrismButton(
        label: 'Save document',
        onPressed: () => taps++,
        child: const Text('Custom'),
      ),
    );
    expect(find.text('Custom'), findsOneWidget);
    expect(find.bySemanticsLabel('Save document'), findsOneWidget);
    expect(find.bySemanticsLabel('Custom'), findsNothing);
    // A semantic label renames the target without changing the visible text.
    await show(
      tester,
      LiquidPrismButton(
        label: 'Save',
        semanticLabel: 'Save draft',
        onPressed: () => taps++,
      ),
    );
    expect(find.text('Save'), findsOneWidget);
    expect(find.bySemanticsLabel('Save draft'), findsOneWidget);
    expect(find.bySemanticsLabel('Save'), findsNothing);
    tester.semantics.tap(find.semantics.byLabel('Save draft'));
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('custom content keeps ambient icon sizing unless overridden', (
    tester,
  ) async {
    Future<void> render(GlassButtonStyle? style) => show(
      tester,
      IconTheme(
        data: const IconThemeData(size: 32),
        child: LiquidPrismButton(
          label: 'Custom',
          onPressed: () {},
          style: style,
          child: const Icon(CupertinoIcons.star, key: ValueKey('custom-icon')),
        ),
      ),
    );
    await render(null);
    expect(
      tester.getSize(find.byKey(const ValueKey('custom-icon'))),
      const Size(32, 32),
    );
    await render(const GlassButtonStyle(iconSize: 20));
    expect(
      tester.getSize(find.byKey(const ValueKey('custom-icon'))),
      const Size(20, 20),
    );
  });

  testWidgets(
    'label position follows direction and supports vertical composition',
    (tester) async {
      Widget button(GlassLabelPlacement placement) => LiquidPrismButton(
        label: 'Save',
        icon: const SizedBox(key: ValueKey('icon'), width: 16, height: 16),
        onPressed: () {},
        style: GlassButtonStyle(labelPlacement: placement, spacing: 6),
      );
      final icon = find.byKey(const ValueKey('icon'));
      await show(tester, button(GlassLabelPlacement.trailing));
      expect(
        tester.getCenter(icon).dx,
        lessThan(tester.getCenter(find.text('Save')).dx),
      );
      await show(
        tester,
        button(GlassLabelPlacement.trailing),
        direction: TextDirection.rtl,
      );
      expect(
        tester.getCenter(icon).dx,
        greaterThan(tester.getCenter(find.text('Save')).dx),
      );
      await show(tester, button(GlassLabelPlacement.above));
      expect(
        tester.getBottomRight(find.text('Save')).dy + 6,
        closeTo(tester.getTopLeft(icon).dy, .01),
      );
      await show(tester, button(GlassLabelPlacement.below));
      expect(
        tester.getBottomRight(icon).dy + 6,
        closeTo(tester.getTopLeft(find.text('Save')).dy, .01),
      );

      // A trailing icon follows the icon and label, one gap after the label.
      final trailing = find.byKey(const ValueKey('trailing'));
      for (final rtl in [false, true]) {
        await show(
          tester,
          LiquidPrismButton(
            label: 'Save',
            icon: const SizedBox(key: ValueKey('icon'), width: 16, height: 16),
            trailingIcon: const SizedBox(
              key: ValueKey('trailing'),
              width: 16,
              height: 16,
            ),
            onPressed: () {},
            style: const GlassButtonStyle(spacing: 6),
          ),
          direction: rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        final label = tester.getRect(find.text('Save'));
        final leading = tester.getRect(icon);
        final end = tester.getRect(trailing);
        if (rtl) {
          expect(leading.left, greaterThan(label.right), reason: 'RTL');
          expect(end.right + 6, closeTo(label.left, .01), reason: 'RTL');
        } else {
          expect(leading.right, lessThan(label.left));
          expect(label.right + 6, closeTo(end.left, .01));
        }
      }
    },
  );

  testWidgets('small platters retain a 44-point action region', (tester) async {
    var taps = 0;
    await show(
      tester,
      LiquidPrismButton(
        label: 'A',
        size: GlassControlSize.small,
        onPressed: () => taps++,
      ),
    );
    final action = find.byType(LiquidPrismButton);
    expect(tester.getSize(action).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(find.byType(LiquidPrism)).height, lessThan(44));
    await tester.tapAt(tester.getTopLeft(action) + const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('fill respects bounds and remains usable in an unbounded row', (
    tester,
  ) async {
    Widget button({Size? maximum}) => LiquidPrismButton(
      label: 'A label that needs to fit',
      icon: const Icon(IconData(0x4D, fontFamily: 'Ahem')),
      onPressed: () {},
      style: GlassButtonStyle(
        sizing: GlassButtonSizing.fill,
        maximumSize: maximum,
      ),
    );
    await show(tester, button());
    expect(tester.getSize(find.byType(LiquidPrism)).width, 240);
    await show(tester, button(maximum: const Size(150, 100)));
    expect(tester.getSize(find.byType(LiquidPrism)).width, 150);
    await show(
      tester,
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: button()),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct variants and sizes override merged component styles', (
    tester,
  ) async {
    await show(
      tester,
      LiquidPrismTheme(
        data: const LiquidPrismThemeData(
          button: GlassButtonStyle(
            variant: GlassButtonVariant.prominent,
            size: GlassControlSize.large,
            spacing: 20,
            minimumSize: Size(100, 60),
          ),
        ),
        child: LiquidPrismButton(
          label: 'Save',
          variant: GlassButtonVariant.regular,
          size: GlassControlSize.small,
          onPressed: () {},
          style: const GlassButtonStyle(minimumSize: Size.zero),
        ),
      ),
    );
    expect(
      tester.widget<LiquidPrism>(find.byType(LiquidPrism)).glass!.tintColor,
      isNull,
    );
    expect(
      DefaultTextStyle.of(tester.element(find.text('Save'))).style.fontSize,
      15,
    );
    expect(tester.getSize(find.byType(LiquidPrism)).height, lessThan(60));
  });

  testWidgets(
    'borrowed focus drives keyboard activation and survives unmount',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var taps = 0;
      final changes = <bool>[];
      await show(
        tester,
        LiquidPrismButton(
          label: 'Save',
          focusNode: focus,
          autofocus: true,
          onFocusChange: changes.add,
          onPressed: () => taps++,
        ),
      );
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(changes, contains(true));
      await tester.pumpWidget(const SizedBox());
      expect(() => focus.addListener(() {}), returnsNormally);
    },
  );

  group('activation state', () {
    const label = 'Save changes';
    final button = find.byType(LiquidPrismButton);
    late List<String> log;
    setUp(() => log = []);

    /// Haptics land in [log] beside the callbacks, so order is observable.
    Widget themed(Widget child) => LiquidPrismTheme(
      data: LiquidPrismThemeData(
        haptics: GlassHaptics(
          (_, event) =>
              log.add('haptic ${event.component.name} ${event.kind.name}'),
        ),
      ),
      child: child,
    );
    bool labelPainted(WidgetTester tester) {
      try {
        expect(tester.renderObject(button), paints..paragraph());
        return true;
      } on TestFailure {
        return false;
      }
    }

    Color? labelColor(WidgetTester tester) =>
        DefaultTextStyle.of(tester.element(find.text(label))).style.color;
    SemanticsNode semantics(WidgetTester tester) =>
        tester.getSemantics(find.bySemanticsLabel(label));

    testWidgets('enabled false disables every activation path and dims', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var enabled = false;
      late StateSetter update;
      await show(
        tester,
        themed(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return LiquidPrismButton(
                label: label,
                enabled: enabled,
                focusNode: focus,
                onPressed: () => log.add('tap'),
                onLongPress: () => log.add('long press'),
              );
            },
          ),
        ),
      );
      final colors = LiquidPrismTheme.colorsOf(tester.element(button));
      await tester.tap(button);
      await tester.longPress(button);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(focus.hasFocus, isFalse);
      expect(semantics(tester).flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(
        semantics(tester).getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      expect(
        semantics(tester)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.longPress),
        isFalse,
      );
      expect(labelColor(tester), colors.disabledLabel);

      update(() => enabled = true);
      await tester.pump();
      expect(labelColor(tester), isNot(colors.disabledLabel));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(log, ['tap']);
    });

    testWidgets(
      'a long press plays the button haptic before its callback and wins '
      'over the tap',
      (tester) async {
        await show(
          tester,
          themed(
            LiquidPrismButton(
              label: label,
              onPressed: () => log.add('tap'),
              onLongPress: () => log.add('long press'),
            ),
          ),
        );
        await tester.longPress(button);
        await tester.pumpAndSettle();
        expect(log, ['haptic button longPress', 'long press']);
        tester.semantics.longPress(find.semantics.byLabel(label));
        await tester.pump();
        expect(log, [
          'haptic button longPress',
          'long press',
          'haptic button longPress',
          'long press',
        ]);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(log.skip(4), ['tap']);
      },
    );

    testWidgets(
      'loading keeps the size, colors, focus and enabled semantics and '
      'ignores every activation',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        var loading = false;
        late StateSetter update;
        await show(
          tester,
          themed(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return LiquidPrismButton(
                  label: label,
                  focusNode: focus,
                  autofocus: true,
                  isLoading: loading,
                  onPressed: () => log.add('tap'),
                  onLongPress: () => log.add('long press'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final size = tester.getSize(find.byType(LiquidPrism));
        final color = labelColor(tester);
        expect(labelPainted(tester), isTrue);
        expect(focus.hasFocus, isTrue);

        update(() => loading = true);
        await tester.pump();
        expect(labelPainted(tester), isFalse, reason: 'the indicator shows');
        expect(tester.getSize(find.byType(LiquidPrism)), size);
        expect(labelColor(tester), color);
        expect(focus.hasFocus, isTrue);
        expect(semantics(tester).flagsCollection.isEnabled, ui.Tristate.isTrue);
        await tester.tap(button);
        await tester.longPress(button);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        tester.semantics.tap(find.semantics.byLabel(label));
        await tester.pump();
        expect(log, isEmpty);
        expect(focus.hasFocus, isTrue);

        update(() => loading = false);
        await tester.pumpAndSettle();
        expect(labelPainted(tester), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(log, ['tap']);
      },
    );

    testWidgets(
      'auto loading takes one activation until the future settles and keeps '
      'focus',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        final pending = <Completer<void>>[];
        await show(
          tester,
          LiquidPrismButton(
            label: label,
            focusNode: focus,
            autofocus: true,
            autoLoading: true,
            onPressed: () {
              pending.add(Completer<void>());
              return pending.last.future;
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(pending, hasLength(1));
        expect(labelPainted(tester), isFalse);
        expect(focus.hasFocus, isTrue);
        expect(semantics(tester).flagsCollection.isEnabled, ui.Tristate.isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.tap(button);
        tester.semantics.tap(find.semantics.byLabel(label));
        await tester.pump();
        expect(pending, hasLength(1), reason: 'pending work ignores repeats');

        pending.single.complete();
        await tester.pump();
        expect(labelPainted(tester), isTrue);
        expect(focus.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(pending, hasLength(2));
        pending.last.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a synchronous action never enters auto loading', (
      tester,
    ) async {
      await show(
        tester,
        LiquidPrismButton(
          label: label,
          autoLoading: true,
          onPressed: () => log.add('tap'),
        ),
      );
      await tester.tap(button);
      await tester.pump();
      expect(labelPainted(tester), isTrue);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(log, ['tap', 'tap']);
    });

    testWidgets('a failed action ends loading and its error reaches the zone', (
      tester,
    ) async {
      late Completer<void> action;
      final errors = <Object>[];
      await show(
        tester,
        LiquidPrismButton(
          label: label,
          autoLoading: true,
          onPressed: () {
            // Created in the guarded zone below, so its error stays there.
            action = Completer<void>();
            return action.future;
          },
        ),
      );
      runZonedGuarded(
        () => tester.semantics.tap(find.semantics.byLabel(label)),
        (error, _) => errors.add(error),
      );
      await tester.pump();
      expect(labelPainted(tester), isFalse);
      final failure = StateError('offline');
      action.completeError(failure);
      await tester.pump();
      expect(errors, [failure]);
      expect(labelPainted(tester), isTrue);
    });

    testWidgets('a new action given while one is pending waits for it', (
      tester,
    ) async {
      final first = Completer<void>();
      var second = false;
      late StateSetter update;
      await show(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidPrismButton(
              label: label,
              autoLoading: true,
              onPressed: second
                  ? () => log.add('second')
                  : () {
                      log.add('first');
                      return first.future;
                    },
            );
          },
        ),
      );
      await tester.tap(button);
      await tester.pump();
      update(() => second = true);
      await tester.pump();
      expect(labelPainted(tester), isFalse, reason: 'still loading');
      await tester.tap(button);
      await tester.pump();
      expect(log, ['first']);
      first.complete();
      await tester.pump();
      expect(labelPainted(tester), isTrue);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(log, ['first', 'second']);
    });

    testWidgets('custom content keeps its state while loading comes and goes', (
      tester,
    ) async {
      var inits = 0;
      var loading = false;
      late StateSetter update;
      final action = Completer<void>();
      await show(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidPrismButton(
              label: label,
              isLoading: loading,
              autoLoading: true,
              onPressed: () => action.future,
              child: _StateProbe(onInit: () => inits++),
            );
          },
        ),
      );
      expect(inits, 1);
      update(() => loading = true);
      await tester.pump();
      update(() => loading = false);
      await tester.pump();
      expect(inits, 1, reason: 'isLoading on and off');
      await tester.tap(button);
      await tester.pump();
      action.complete();
      await tester.pump();
      expect(inits, 1, reason: 'an auto-loading action starts and ends');
      await tester.pumpAndSettle();
    });

    testWidgets('unmounting while an action is pending is safe', (
      tester,
    ) async {
      final action = Completer<void>();
      await show(
        tester,
        LiquidPrismButton(
          label: label,
          autoLoading: true,
          onPressed: () => action.future,
        ),
      );
      await tester.tap(button);
      await tester.pump();
      expect(labelPainted(tester), isFalse);
      await tester.pumpWidget(const SizedBox());
      action.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the loading indicator comes from the button, then its style, then '
      'the theme, in the button foreground',
      (tester) async {
        const direct = SizedBox(key: ValueKey('direct'), width: 8, height: 8);
        const local = SizedBox(key: ValueKey('style'), width: 8, height: 8);
        const themed = SizedBox(key: ValueKey('theme'), width: 8, height: 8);
        const foreground = Color(0xFF12AB34);
        for (final (expected, indicator, style) in [
          ('direct', direct, const GlassButtonStyle(loadingIndicator: local)),
          ('style', null, const GlassButtonStyle(loadingIndicator: local)),
          // A local style without one keeps the theme's through the merge.
          ('theme', null, const GlassButtonStyle(spacing: 4)),
        ]) {
          await show(
            tester,
            LiquidPrismTheme(
              data: LiquidPrismThemeData(
                // Built through copyWith, which must keep the indicator.
                button: const GlassButtonStyle(loadingIndicator: themed)
                    .copyWith(spacing: 2),
              ),
              child: LiquidPrismButton(
                label: label,
                isLoading: true,
                loadingIndicator: indicator,
                style: style,
                foregroundColor: foreground,
                onPressed: () {},
              ),
            ),
          );
          for (final key in ['direct', 'style', 'theme']) {
            expect(
              find.byKey(ValueKey(key)),
              key == expected ? findsOneWidget : findsNothing,
              reason: expected,
            );
          }
          expect(
            IconTheme.of(tester.element(find.byKey(ValueKey(expected)))).color,
            foreground,
          );
        }
      },
    );

    testWidgets(
      'destructive draws the system red unless an explicit color wins',
      (tester) async {
        const explicit = Color(0xFF2266AA);
        for (final brightness in Brightness.values) {
          for (final (name, prominent, foreground, tint, enabled) in [
            ('regular', false, null, null, true),
            ('prominent', true, null, null, true),
            ('explicit foreground', false, explicit, null, true),
            ('explicit tint', true, null, explicit, true),
            ('disabled', false, null, null, false),
          ]) {
            await show(
              tester,
              LiquidPrismTheme(
                brightness: brightness,
                child: LiquidPrismButton(
                  label: label,
                  destructive: true,
                  enabled: enabled,
                  variant: prominent
                      ? GlassButtonVariant.prominent
                      : GlassButtonVariant.regular,
                  foregroundColor: foreground,
                  tintColor: tint,
                  onPressed: () {},
                ),
              ),
            );
            final colors = LiquidPrismTheme.colorsOf(tester.element(button));
            final glass = tester
                .widget<LiquidPrism>(find.byType(LiquidPrism))
                .glass!;
            final reason = '$name, $brightness';
            switch (name) {
              case 'regular':
                expect(labelColor(tester), colors.red, reason: reason);
                expect(glass.tintColor, isNull, reason: reason);
              case 'prominent':
                expect(labelColor(tester), const Color(0xFFFFFFFF));
                expect(glass.tintColor, colors.red, reason: reason);
              case 'explicit foreground':
                expect(labelColor(tester), explicit, reason: reason);
              case 'explicit tint':
                expect(glass.tintColor, explicit, reason: reason);
              case 'disabled':
                expect(labelColor(tester), colors.disabledLabel);
            }
          }
        }
        // Without destructive, a tint color still tints a regular button.
        await show(
          tester,
          LiquidPrismButton(
            label: label,
            tintColor: explicit,
            onPressed: () {},
          ),
        );
        expect(
          tester.widget<LiquidPrism>(find.byType(LiquidPrism)).glass!.tintColor,
          explicit,
        );
      },
    );
  });
}

/// Counts how often its state is created.
class _StateProbe extends StatefulWidget {
  const _StateProbe({required this.onInit});
  final VoidCallback onInit;

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 60, height: 20);
}
