import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/pressable.dart';

Widget harness(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    CupertinoApp(
      home: LiquidPrismTheme(
        brightness: Brightness.dark,
        child: Directionality(
          textDirection: direction,
          child: Center(child: child),
        ),
      ),
    );

void main() {
  testWidgets('toolbar shares one native-sized capsule; group lifts on hold', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(
        LiquidPrismToolbarGroup(
          size: GlassToolbarSize.navigation,
          items: [
            GlassToolbarItem(
              icon: const Icon(CupertinoIcons.star),
              label: 'Favorite',
              width: 42 + 1 / 3,
              onPressed: () => taps++,
            ),
            GlassToolbarItem(
              icon: const Icon(CupertinoIcons.share),
              label: 'Share',
              width: 38 + 2 / 3,
              onPressed: () => taps++,
            ),
            const GlassToolbarItem(
              icon: Icon(CupertinoIcons.ellipsis),
              label: 'More',
              onPressed: null,
            ),
          ],
        ),
      ),
    );
    final glass = find.byType(LiquidPrism);
    expect(glass, findsOneWidget);
    expect(tester.getSize(glass), const Size(159, 44));
    final held = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Favorite')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      LiquidPrismPressFeedback.scaleOf(tester.element(glass)),
      closeTo(175 / 159, .002),
    );
    await held.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.tap(find.bySemanticsLabel('More'));
    expect(taps, 1);
    await tester.tap(find.bySemanticsLabel('Share'));
    await tester.pumpAndSettle();
    expect(taps, 2);
    // Gaps remain active touch regions, while a drag cancels activation.
    final groupRect = tester.getRect(glass);
    await tester.tapAt(Offset(groupRect.left + 50, groupRect.center.dy));
    await tester.pumpAndSettle();
    expect(taps, 3);
    final drag = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Favorite')),
    );
    await drag.moveBy(const Offset(100, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(taps, 3);
  });
  testWidgets('bottom toolbar keeps sizes in narrow/RTL parents and scrolls', (
    tester,
  ) async {
    var last = 0;
    final items = [
      for (var i = 0; i < 4; i++)
        GlassToolbarItem(
          icon: const Icon(CupertinoIcons.star),
          label: 'Item $i',
          onPressed: () => last = i,
        ),
    ];
    await tester.pumpWidget(
      harness(
        SizedBox(width: 100, child: LiquidPrismToolbarGroup(items: items)),
        direction: TextDirection.rtl,
      ),
    );
    expect(tester.getSize(find.byType(LiquidPrism)), const Size(100, 48));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(220, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Item 3'));
    await tester.pumpAndSettle();
    expect(last, 3);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'search matches native focus widths; clear/submit/cancel coordinate',
    (tester) async {
      final controller = TextEditingController(), node = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(node.dispose);
      final changes = <String>[];
      String? submitted;
      var cancelled = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 386,
            child: LiquidPrismSearchField(
              controller: controller,
              focusNode: node,
              restingInset: 20,
              onChanged: changes.add,
              onSubmitted: (text) => submitted = text,
              onCancel: () => cancelled++,
            ),
          ),
        ),
      );
      final glass = find.byType(LiquidPrism).first;
      expect(tester.getSize(glass), const Size(346, 48));
      await tester.tap(find.byType(LiquidPrismSearchField));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(tester.getSize(glass), const Size(326, 48));
      final cancelGlass = find.byType(LiquidPrism).last;
      final holdCancel = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Cancel search')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        LiquidPrismPressFeedback.scaleOf(tester.element(cancelGlass)),
        closeTo(64 / 48, .002),
      );
      await holdCancel.cancel();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), 'Prism');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, 'Prism');
      await tester.tap(find.bySemanticsLabel('Clear search'));
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(changes, ['Prism', '']);
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), 'Glass');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Cancel search'));
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(node.hasFocus, isFalse);
      expect(cancelled, 1);
      expect(tester.getSize(glass), const Size(346, 48));
    },
  );
  testWidgets(
    'search swaps borrowed controllers/focus nodes without disposing them',
    (tester) async {
      final a = TextEditingController(text: 'First'),
          b = TextEditingController(text: 'Second');
      final first = FocusNode(), second = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget field(TextEditingController? c, FocusNode? n) => harness(
        SizedBox(
          width: 300,
          child: LiquidPrismSearchField(
            key: const ValueKey('search'),
            controller: c,
            focusNode: n,
          ),
        ),
      );
      await tester.pumpWidget(field(a, first));
      first.requestFocus();
      await tester.pumpAndSettle();
      await tester.pumpWidget(field(b, second));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .controller,
        b,
      );
      await tester.pumpWidget(field(null, null));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .controller!
            .text,
        'Second',
      );
      await tester.pumpWidget(const SizedBox());
      a.text = 'Usable';
      b.text = 'Usable';
      first.addListener(() {});
      second.addListener(() {});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'disabled, narrow, large text and reduced motion search remain usable',
    (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
              textScaler: TextScaler.linear(2.5),
            ),
            child: SizedBox(
              width: 130,
              child: LiquidPrismSearchField(focusNode: node),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      expect(find.bySemanticsLabel('Cancel search'), findsNothing);
      expect(tester.getSize(find.byType(LiquidPrism)).height, greaterThan(48));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 130,
            child: LiquidPrismSearchField(focusNode: node, enabled: false),
          ),
        ),
      );
      await tester.tap(find.byType(LiquidPrismSearchField));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
