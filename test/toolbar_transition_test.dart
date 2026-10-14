import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

Widget harness(Widget child, {bool reduceMotion = false}) => CupertinoApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: LiquidPrismTheme(
      brightness: Brightness.dark,
      child: Center(child: child),
    ),
  ),
);

GlassToolbarItem item(String label, {VoidCallback? onPressed}) =>
    GlassToolbarItem(
      icon: const Icon(CupertinoIcons.star),
      label: label,
      onPressed: onPressed ?? () {},
    );

void main() {
  testWidgets('an added item materializes in while the capsule widens', (
    tester,
  ) async {
    Widget group(List<GlassToolbarItem> items) => harness(
      LiquidPrismToolbarGroup(size: GlassToolbarSize.navigation, items: items),
    );
    await tester.pumpWidget(group([item('Share'), item('More')]));
    final glass = find.byType(LiquidPrism);
    // Two 38-point items, a 16-point gap and 4-point insets.
    expect(tester.getSize(glass).width, 100);

    await tester.pumpWidget(group([item('Share'), item('Edit'), item('More')]));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    final growing = tester.getSize(glass).width;
    expect(growing, greaterThan(100));
    expect(growing, lessThan(154));
    await tester.pumpAndSettle();
    expect(tester.getSize(glass).width, 154);
    // Items stay in list order with the newcomer in the middle.
    expect(
      tester.getCenter(find.bySemanticsLabel('Edit')).dx,
      inExclusiveRange(
        tester.getCenter(find.bySemanticsLabel('Share')).dx,
        tester.getCenter(find.bySemanticsLabel('More')).dx,
      ),
    );

    await tester.pumpWidget(group([item('Share'), item('More')]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.bySemanticsLabel('Edit'),
      findsNothing,
      reason: 'a leaving item is out of the semantics tree at once',
    );
    expect(tester.getSize(glass).width, inExclusiveRange(100, 154));
    await tester.pumpAndSettle();
    expect(tester.getSize(glass).width, 100);
  });

  testWidgets('a lone item re-forms its circle as its neighbour leaves', (
    tester,
  ) async {
    Widget group(List<GlassToolbarItem> items) => harness(
      LiquidPrismToolbarGroup(size: GlassToolbarSize.navigation, items: items),
    );
    await tester.pumpWidget(group([item('Share'), item('More')]));
    await tester.pumpWidget(group([item('More')]));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LiquidPrism)), const Size(44, 44));
  });

  testWidgets('Reduce Motion and identity swap items at once', (tester) async {
    for (final (reduce, transition) in [
      (true, null),
      (false, GlassTransition.identity),
    ]) {
      Widget group(List<GlassToolbarItem> items) => harness(
        reduceMotion: reduce,
        LiquidPrismToolbarGroup(
          size: GlassToolbarSize.navigation,
          style: GlassToolbarStyle(itemTransition: transition),
          items: items,
        ),
      );
      await tester.pumpWidget(group([item('Share')]));
      await tester.pumpWidget(group([item('Share'), item('More')]));
      await tester.pump();
      expect(tester.getSize(find.byType(LiquidPrism)).width, 100);
    }
  });

  testWidgets('an emptied group materializes out and keeps no capsule', (
    tester,
  ) async {
    Widget group(List<GlassToolbarItem> items) => harness(
      LiquidPrismToolbarGroup(size: GlassToolbarSize.navigation, items: items),
    );
    await tester.pumpWidget(group([item('Share')]));
    expect(find.byType(LiquidPrism), findsOneWidget);
    await tester.pumpWidget(group(const []));
    await tester.pump();
    expect(find.byType(LiquidPrismPresence), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(LiquidPrism), findsNothing);
    expect(tester.getSize(find.byType(LiquidPrismToolbarGroup)), Size.zero);

    await tester.pumpWidget(group([item('Share'), item('More')]));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LiquidPrism)).width, 100);
  });

  testWidgets('a toolbar lays out groups with a gap and collapses empty ones', (
    tester,
  ) async {
    Widget toolbar(List<List<GlassToolbarItem>> groups) => harness(
      LiquidPrismToolbar(size: GlassToolbarSize.navigation, groups: groups),
    );
    await tester.pumpWidget(
      toolbar([
        [item('Suggest')],
        [item('Sort'), item('More')],
      ]),
    );
    final capsules = find.byType(LiquidPrism);
    expect(capsules, findsNWidgets(2));
    final first = tester.getRect(capsules.first);
    final second = tester.getRect(capsules.last);
    expect(first.width, 44, reason: 'a lone item is a circle');
    expect(second.left - first.right, 8);
    expect(tester.getSize(find.byType(LiquidPrismToolbar)).width, 44 + 8 + 100);

    await tester.pumpWidget(
      toolbar([
        const [],
        [item('Sort'), item('More')],
      ]),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final shrinking = tester.getSize(find.byType(LiquidPrismToolbar)).width;
    expect(shrinking, inExclusiveRange(100, 152));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LiquidPrismToolbar)).width, 100);
    expect(capsules, findsOneWidget);

    await tester.pumpWidget(
      toolbar([
        [item('Suggest')],
        [item('Sort'), item('More')],
      ]),
    );
    await tester.pumpAndSettle();
    expect(capsules, findsNWidgets(2));
    expect(tester.getSize(find.byType(LiquidPrismToolbar)).width, 152);
  });

  test('toolbar style merges the transition and spacing fields', () {
    const base = GlassToolbarStyle(
      itemTransition: GlassTransition.identity,
      groupSpacing: 12,
      itemTransitionStyle: GlassTransitionStyle(contentBlur: 2),
    );
    final merged = base.merge(
      const GlassToolbarStyle(
        groupSpacing: 6,
        itemTransitionStyle: GlassTransitionStyle(
          enterSpring: GlassSpring(response: Duration(milliseconds: 100)),
        ),
      ),
    );
    expect(merged.itemTransition, GlassTransition.identity);
    expect(merged.groupSpacing, 6);
    expect(merged.itemTransitionStyle!.contentBlur, 2);
    expect(
      merged.itemTransitionStyle!.enterSpring!.response,
      const Duration(milliseconds: 100),
    );
    expect(base.copyWith(groupSpacing: 0).groupSpacing, 0);
  });

  testWidgets('an entering item holds its final size and place, and blurs in', (
    tester,
  ) async {
    // A top-trailing group: its trailing edge stays put as it widens.
    Widget group(List<GlassToolbarItem> items) => CupertinoApp(
      home: Align(
        alignment: Alignment.topRight,
        child: LiquidPrismToolbarGroup(
          size: GlassToolbarSize.navigation,
          items: items,
        ),
      ),
    );
    final icon = find.descendant(
      of: find.bySemanticsLabel('Edit'),
      matching: find.byType(Icon),
    );
    await tester.pumpWidget(group([item('Share'), item('Edit')]));
    await tester.pumpAndSettle();
    final settled = tester.getRect(icon);

    await tester.pumpWidget(group([item('Share')]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(group([item('Share'), item('Edit')]));
    for (final ms in [40, 80, 120]) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getRect(icon), settled, reason: 'at $ms ms');
      final blur = tester
          .widgetList<ImageFiltered>(
            find.ancestor(of: icon, matching: find.byType(ImageFiltered)),
          )
          .first;
      expect(blur.enabled, isTrue, reason: 'it sharpens in at $ms ms');
    }
    expect(
      find
          .ancestor(of: icon, matching: find.byType(Transform))
          .evaluate()
          .where((e) => !(e.widget as Transform).transform.isIdentity()),
      isEmpty,
      reason: 'nothing scales or slides the item',
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(icon), settled);
  });

  testWidgets('a leading-aligned group pins entering items to its start', (
    tester,
  ) async {
    Widget group(List<GlassToolbarItem> items) => CupertinoApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: LiquidPrismToolbarGroup(
          size: GlassToolbarSize.navigation,
          items: items,
        ),
      ),
    );
    final icon = find.descendant(
      of: find.bySemanticsLabel('Edit'),
      matching: find.byType(Icon),
    );
    await tester.pumpWidget(group([item('Share'), item('Edit'), item('More')]));
    await tester.pumpAndSettle();
    final settled = tester.getRect(icon);
    await tester.pumpWidget(group([item('Share'), item('More')]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(group([item('Share'), item('Edit'), item('More')]));
    // The first frame learns which edge holds still; from then on the item
    // sits at its final place.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getRect(icon), settled);
    }
  });
}
