import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/controls/prism_pressable.dart';
import 'package:liquid_prism/src/rendering/surface.dart';

Widget harness(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    CupertinoApp(
      home: PrismTheme(
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
        PrismToolbar.group(
          size: PrismToolbarSize.navigation,
          items: [
            PrismToolbarItem(
              icon: const Icon(CupertinoIcons.star),
              label: 'Favorite',
              width: 42 + 1 / 3,
              onPressed: () => taps++,
            ),
            PrismToolbarItem(
              icon: const Icon(CupertinoIcons.share),
              label: 'Share',
              width: 38 + 2 / 3,
              onPressed: () => taps++,
            ),
            const PrismToolbarItem(
              icon: Icon(CupertinoIcons.ellipsis),
              label: 'More',
              onPressed: null,
            ),
          ],
        ),
      ),
    );
    final glass = find.byType(RawPrismSurface);
    expect(glass, findsOneWidget);
    expect(tester.getSize(glass), const Size(159, 44));
    final held = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Favorite')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      PrismPressFeedback.scaleOf(tester.element(glass)),
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
  group('a lone toolbar item', () {
    PrismToolbarItem item({double? width}) => PrismToolbarItem(
      icon: const Icon(CupertinoIcons.slider_horizontal_3),
      label: 'Preferences',
      width: width,
      onPressed: () {},
    );

    for (final (size, extent) in [
      (PrismToolbarSize.navigation, 44.0),
      (PrismToolbarSize.bottom, 48.0),
    ]) {
      for (final axis in Axis.values) {
        testWidgets('is a ${extent.toInt()}-point circle (${size.name}, '
            '${axis.name})', (tester) async {
          await tester.pumpWidget(
            harness(
              PrismToolbar.group(size: size, axis: axis, items: [item()]),
            ),
          );
          expect(
            tester.getSize(find.byType(RawPrismSurface)),
            Size.square(extent),
          );

          final action = find.bySemanticsLabel('Preferences');
          expect(tester.getSize(action), Size.square(extent));
          expect(
            tester.getCenter(action),
            tester.getCenter(find.byType(RawPrismSurface)),
          );
        });
      }
    }

    testWidgets('follows a custom height and inset', (tester) async {
      await tester.pumpWidget(
        harness(
          PrismToolbar.group(
            style: const PrismToolbarStyle(height: 52, inset: 6),
            items: [item()],
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(RawPrismSurface)),
        const Size.square(52),
      );
    });

    testWidgets('keeps an explicit width as a capsule', (tester) async {
      await tester.pumpWidget(
        harness(
          PrismToolbar.group(
            size: PrismToolbarSize.navigation,
            items: [item(width: 60)],
          ),
        ),
      );
      expect(tester.getSize(find.byType(RawPrismSurface)), const Size(68, 44));
    });

    testWidgets('does not change groups of several default items', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(PrismToolbar.group(items: [item(), item()])),
      );
      expect(tester.getSize(find.byType(RawPrismSurface)), const Size(100, 48));
    });
  });
  testWidgets('bottom toolbar keeps sizes in narrow/RTL parents and scrolls', (
    tester,
  ) async {
    var last = 0;
    final items = [
      for (var i = 0; i < 4; i++)
        PrismToolbarItem(
          icon: const Icon(CupertinoIcons.star),
          label: 'Item $i',
          onPressed: () => last = i,
        ),
    ];
    await tester.pumpWidget(
      harness(
        SizedBox(width: 100, child: PrismToolbar.group(items: items)),
        direction: TextDirection.rtl,
      ),
    );
    expect(tester.getSize(find.byType(RawPrismSurface)), const Size(100, 48));
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
            child: PrismSearchField(
              controller: controller,
              focusNode: node,
              style: const PrismSearchStyle(restingInset: 20),
              onChanged: changes.add,
              onSubmitted: (text) => submitted = text,
              onCancel: () => cancelled++,
            ),
          ),
        ),
      );
      final glass = find.byType(RawPrismSurface).first;
      expect(tester.getSize(glass), const Size(346, 48));
      await tester.tap(find.byType(PrismSearchField));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      final field = find.byType(PrismSearchField);
      final restingEnd = tester.getTopRight(field).dx - 48;
      final entering = find.byType(RawPrismSurface).last;
      expect(tester.getSize(entering), const Size(48, 48));
      expect(tester.getTopLeft(entering).dx, greaterThan(restingEnd));
      expect(tester.getSize(glass).width, lessThan(346));

      final cancelBlur = tester.widget<ImageFiltered>(
        find
            .descendant(of: entering, matching: find.byType(ImageFiltered))
            .first,
      );
      expect(cancelBlur.enabled, isTrue);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(
        tester.getTopLeft(find.byType(RawPrismSurface).last).dx,
        restingEnd,
      );
      expect(tester.getSize(glass), const Size(326, 48));
      final cancelGlass = find.byType(RawPrismSurface).last;
      final holdCancel = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Cancel search')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        PrismPressFeedback.scaleOf(tester.element(cancelGlass)),
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
      await tester.enterText(find.byType(CupertinoTextField), 'PrismGlass');
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
          child: PrismSearchField(
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
              child: PrismSearchField(focusNode: node),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      expect(find.bySemanticsLabel('Cancel search'), findsNothing);
      expect(
        tester.getSize(find.byType(RawPrismSurface)).height,
        greaterThan(48),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 130,
            child: PrismSearchField(focusNode: node, enabled: false),
          ),
        ),
      );
      await tester.tap(find.byType(PrismSearchField));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search anchors a consumer dropdown to its capsule and shares its taps',
    (tester) async {
      final node = FocusNode();
      final portal = OverlayPortalController();
      final link = LayerLink();
      final group = Object();
      addTearDown(node.dispose);
      final focusChanges = <bool>[];
      final picked = <String>[];
      var builds = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 386,
            child: PrismSearchField(
              focusNode: node,
              style: const PrismSearchStyle(restingInset: 20),
              groupId: group,
              onTapOutside: (_) => node.unfocus(),
              onFocusChange: focusChanges.add,
              fieldBuilder: (context, field) {
                builds++;
                return OverlayPortal(
                  controller: portal,
                  overlayChildBuilder: (_) => CompositedTransformFollower(
                    link: link,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.bottomLeft,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: TapRegion(
                        groupId: group,
                        child: GestureDetector(
                          key: const ValueKey('dropdown'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => picked.add('Prism'),
                          child: SizedBox(
                            width: link.leaderSize?.width ?? 0,
                            height: 120,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: CompositedTransformTarget(link: link, child: field),
                );
              },
            ),
          ),
        ),
      );
      portal.show();
      await tester.pump();
      await tester.pump();
      final glass = find.byType(RawPrismSurface).first;
      final dropdown = find.byKey(const ValueKey('dropdown'));

      expect(tester.getTopLeft(dropdown), tester.getBottomLeft(glass));
      expect(tester.getSize(dropdown).width, tester.getSize(glass).width);

      final restingBuilds = builds;
      await tester.tap(glass);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);

      expect(builds - restingBuilds, lessThan(3));

      expect(tester.getTopLeft(dropdown), tester.getBottomLeft(glass));
      expect(tester.getSize(glass).width, 326);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      expect(picked, ['Prism']);
      expect(node.hasFocus, isTrue, reason: 'the dropdown shares the group');

      await tester.tapAt(const Offset(5, 590));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      expect(focusChanges, [true, false]);
      expect(tester.getSize(glass).width, 346);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('search cancel is part of the field tap group', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var outside = 0, cancelled = 0;
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 386,
          child: PrismSearchField(
            focusNode: node,
            onTapOutside: (_) => outside++,
            onCancel: () => cancelled++,
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Cancel search'));
    await tester.pumpAndSettle();
    expect(cancelled, 1);
    expect(outside, 0);
  });
  testWidgets(
    'search suffix builder decorates or replaces the owned clear action',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      var cleared = 0;
      var loading = false;
      final received = <bool>[];
      Widget field({Widget? suffix}) => harness(
        SizedBox(
          width: 300,
          child: PrismSearchField(
            controller: controller,
            onChanged: changes.add,
            onCleared: () => cleared++,
            suffix: suffix,
            suffixBuilder: (context, clearButton) {
              received.add(clearButton != null);
              return loading
                  ? const SizedBox(key: ValueKey('spinner'), width: 20)
                  : clearButton;
            },
          ),
        ),
      );
      await tester.pumpWidget(field());
      expect(received.last, isFalse, reason: 'empty fields cannot clear');
      await tester.enterText(find.byType(CupertinoTextField), 'Prism');
      await tester.pump();
      expect(received.last, isTrue);

      loading = true;
      await tester.pumpWidget(field());
      expect(find.byKey(const ValueKey('spinner')), findsOneWidget);
      expect(find.bySemanticsLabel('Clear search'), findsNothing);

      loading = false;
      await tester.pumpWidget(field());
      await tester.tap(find.bySemanticsLabel('Clear search'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(changes, ['Prism', '']);
      expect(cleared, 1);

      controller.text = 'PrismGlass';
      await tester.pumpWidget(field(suffix: const Text('Direct')));
      expect(find.text('Direct'), findsOneWidget);
      expect(find.bySemanticsLabel('Clear search'), findsNothing);
    },
  );
  testWidgets('search focus callback ignores rebuilds and node swaps', (
    tester,
  ) async {
    final first = FocusNode(), second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final changes = <bool>[];
    Widget field(FocusNode node) => harness(
      SizedBox(
        width: 300,
        child: PrismSearchField(focusNode: node, onFocusChange: changes.add),
      ),
    );
    await tester.pumpWidget(field(first));
    first.requestFocus();
    await tester.pumpAndSettle();
    await tester.pumpWidget(field(first));
    await tester.pumpWidget(field(second));
    await tester.pumpAndSettle();
    expect(changes, [true]);
    second.requestFocus();
    await tester.pumpAndSettle();
    second.unfocus();
    await tester.pumpAndSettle();
    expect(changes, [true, true, false]);
  });
  testWidgets('search padding styles merge below direct theme choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: PrismTheme(
          data: PrismThemeData(
            search: PrismSearchStyle(
              padding: EdgeInsets.all(2),
              prefixPadding: EdgeInsetsDirectional.only(start: 16, end: 12),
            ),
          ),
          child: Center(
            child: SizedBox(
              width: 300,
              child: PrismSearchField(
                style: PrismSearchStyle(
                  padding: EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final editor = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(editor.padding, const EdgeInsets.symmetric(vertical: 4));
    final glass = find.byType(RawPrismSurface).first;
    final icon = find.byIcon(CupertinoIcons.search);

    expect(
      tester.getTopLeft(icon).dx - tester.getTopLeft(glass).dx,
      moreOrLessEquals(16, epsilon: .01),
    );
  });
}
