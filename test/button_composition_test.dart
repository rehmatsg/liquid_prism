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
}
